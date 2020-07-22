#' Create a package environment with access to all package functions.
#' Based on testthat:::test_pkg_env.
#
#' @export
run_test_env <- function(package) {
  list2env(
    as.list(getNamespace(package), all.names=TRUE),
    parent=parent.env(getNamespace(package))
  )
}

#' Simpulate test_check ortherwise running test_dir might skip some tests.
#' Based on testthat:::test_package_dir.
#
#' @importFrom testthat test_dir
#' @importFrom withr local_options local_envvar
#' @export
run_test_dir <- function(package, path, ...) {
  env <- run_test_env(package)
  withr::local_options(
    list(
      topLevelEnvironment=env,
      # need to set this to prevent quick death when the error is set to quit
      # the session
      error=NULL
    )
  )
  withr::local_envvar(list(TESTTHAT_PKG=package, TESTTHAT_DIR=path))
  # TODO use external R process
  testthat::test_dir(path=path, env=env, ...)
}

#' on purpose it only uses base functions
#'
run_one <- function(package, file) {
  error <- as.character(NA)
  time <- as.double(NA)

  cat(
    "**********************************************************************\n",
    "*** PACKAGE ", package, " FILE ", file, "\n",
    "**********************************************************************\n",
    "\n",
    sep=""
  )

  output <- capture.output({
    tryCatch({
      dir <- dirname(file)
      # poor man's testthat detection
      if ((endsWith(tolower(file), "tests/testthat.r") ||
             endsWith(tolower(file), "tests/run-all.r")) &&
            dir.exists(file.path(dir, "testthat"))) {
        time <- system.time(
          run_test_dir(package, file.path(dir, "testthat"))
        )
      } else {
        out_file <- paste0(tools::file_path_sans_ext(file), ".out")
        time <- system.time(
          callr::r_vanilla(
            sys.source,
            args=list(
              file=file,
              envir=run_test_env(package),
              chdir=TRUE
            ),
            stdout=out_file,
            stderr=out_file,
            env=c(
              "LANGUAGE"="en",
              "LC_COLLATE"="C",
              "LC_TIME"="C",
              "SRCDIR"="."
            )
          )
        )
      }
    }, error=function(e) {
      error <<- e$message
    })
  }, split=TRUE)

  if (is(time, "proc_time")) {
    time <- as.numeric(time["elapsed"])
  }

  output <- paste0(output, collapse="\n")

  data.frame(
    time=time,
    error=error,
    output=output,
    stringsAsFactors=FALSE,
    row.names=NULL
  )
}

#' on purpose it only uses base functions
#'
#' @export
run_all <- function(package, runnable_code_file,
                    runnable_code_path=dirname(runnable_code_file),
                    runner=run_one, run_before=NULL, run_after=NULL) {

  if (!file.exists(runnable_code_file)) {
    stop(runnable_code_file, ": no such runnable code file (wd=", getwd(), ")")
  }

  if (!dir.exists(runnable_code_path)) {
    stop(runnable_code_path, ": no such runnable code path (wd=", getwd(), ")")
  }

  files <- read.csv(runnable_code_file)

  rows <- apply(files, 1, function(x) {
    file <- file.path(runnable_code_path, x["path"])
    type <- x["type"]
    i <- data.frame(file=x["path"], type=type, row.names=NULL, stringsAsFactors=FALSE)

    if (!is.null(run_before)) {
      run_before(package, file, type)
    }

    r <- runner(package, file)
    v <- cbind(i, r)

    if (!is.null(run_after)) {
      run_after(package, file, type)
    }

    v
  })

  df <- if (length(rows) > 0) {
    do.call(rbind, rows)
  } else {
    data.frame(
      file=character(0),
      type=character(0),
      time=double(0),
      error=character(0),
      output=character(0),
      stringsAsFactors=FALSE,
      row.names=NULL
    )
  }

  df
}
