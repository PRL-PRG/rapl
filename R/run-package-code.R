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

rcmd_batch_runner <- function(file, out_file, quiet=F) {
  callr::rcmd(
    "BATCH",
    list(file, out_file),
    spinner=T,
    env=c(
      "LANGUAGE"="en",
      "LC_COLLATE"="C",
      "LC_TIME"="C",
      "SRCDIR"="."
    )
  )
}

run_one <- function(file, out_file, cwd=TRUE, quiet=TRUE) {
  stopifnot(file.exists(file))
  stopifnot(dir.exists(dirname(out_file)))

  # TODO insert code that will time the script
  error <- as.character(NA)
  time <- as.double(NA)

  cmd <- file.path(R.home("bin"), "R")
  args <- c(
    "--no-save",
    "--quiet",
    "--no-readline",
    "--silent"
  )
  env <- c(
    "LANGUAGE=en",
    "LC_COLLATE=C",
    "LC_TIME=C",
    "LC_ALL=C",
    "SRCDIR=.",
    'R_TESTS=""',
    "R_BROWSER=false",
    "R_PDFVIEWER=false",
    "R_BATCH=1",
    "R_KEEP_PKG_SOURCE=yes",
    "R_KEEP_PKG_PARSE_DATA=yes"
  )

  if (!quiet) {
    cat("Running:",
        paste(env, collapse=" "),
        cmd,
        paste(args, collapse=" "),
        "<", file, "2>&1", out_file,
        "\n"
    )
  }

  if (cwd) {
    wd <- dirname(file)
    file <- basename(file)
  } else {
    wd <- getwd()
  }

  withr::with_dir(wd, {
    exitval <- system2(
      cmd,
      args,
      stdin=file,
      stdout=out_file,
      stderr=out_file,
      env=env
    )
  })

  time <- NA
  if (exitval == 0L) {
    tryCatch({
      tmp <- readLines(out_file)
      if (tmp[length(tmp)-2] == "> proc.time()") {
        x <- tmp[length(tmp)]
        x <- strsplit(x, " ")[[1]]
        x <- trimws(x, "both")
        x <- x[x != ""]
        x <- as.double(x)
        time <- x[3]
      }
    }, error=function(e) {
      warning("Unable to get timing from: ", out_file)
    })
  }

  data.frame(exitval, time)
}

#' @importFrom stringr str_detect
#' @export
run_all <- function(path, output_dir=getwd(), run_dir=tempfile(),
                    wrap_code_fun=NULL, clean=TRUE, quiet=TRUE) {
  stopifnot(dir.exists(path))
  stopifnot(dir.exists(output_dir))

  result <- data.frame(
    file=character(0),
    out_file=character(0),
    exitval=integer(0),
    time=double(0),
    error=character(0)
  )

  if (dir.exists(run_dir)) unlink(run_dir, recursive=TRUE)
  dir.create(run_dir)
  if (clean) {
    on.exit({
      if (!quiet) cat("Removing running dir", run_dir, "\n")
      unlink(run_dir, recursive=TRUE)
    })
  }

  files <- Sys.glob(file.path(path, "*"))
  if (length(files) == 0) {
    return(result)
  }

  if (!quiet) cat("Copying files from:", path, "to:", run_dir, "...\n")
  ret <- file.copy(files, run_dir, recursive=TRUE)
  if (!all(ret)) stop("Unable to copy:", files[!ret])

  files <- list.files(run_dir, pattern=".*\\.[rR]$", full.names=TRUE, recursive=TRUE)
  # we need to exclude the individual testthat tests as they will be run by the
  # testthat driver
  files <- files[!str_detect(files, "/testthat/")]
  if (!quiet) cat("Running", length(files), "R files ...\n")

  rows <- lapply(files, function(file) {
    out_file <- file.path(
      output_dir,
      paste0(tools::file_path_sans_ext(basename(file)), ".out")
    )

    if (!quiet) cat("-", file, "(output", out_file, ") ... ")

    tryCatch({
      if (!is.null(wrap_code_fun)) {
        code <- readChar(file, file.info(file)$size)
        code <- wrap_code_fun(code)
        writeChar(code, file)
      }

      res <- run_one(file, out_file, cwd=TRUE, quiet=TRUE)

      if (!quiet) {
        if (res$exitval == 0) {
          cat("done (in", res$time, ")\n")
        } else {
          cat("failed (exitval", res$exitval, ")\n")
        }
      }

      cbind(file, out_file, res, error=NA)
    }, error=function(e) {
      if (!quiet) cat("failed (", e$message, ")\n")
      
      data.frame(file, out_file=NA, exitval=NA, time=NA, error=e$message)
    })
  })

  result <- if (length(rows) > 0) {
    do.call(rbind, rows)
  }

  result
}
