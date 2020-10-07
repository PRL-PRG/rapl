#' @param wrap_fun either a NULL or a function(package, file, type, body) which
#'   will be called for each extracted file and allows one to alter the file
#'   content.
#' @importFrom dplyr select mutate filter vars bind_rows rename
#' @importFrom purrr keep imap_dfr
#' @export
extract_package_code <- function(pkg, pkg_dir=find.package(pkg),
                                 types=c("examples", "tests", "vignettes", "all"),
                                 output_dir, wrap_fun=NULL, filter=NULL,
                                 compute_sloc=FALSE, quiet=FALSE) {

  stopifnot(is.character(pkg) && length(pkg) == 1)
  stopifnot(dir.exists(pkg_dir))
  stopifnot(is.null(filter) || is.character(filter))

  if ("all" %in% types) {
    types <- c("examples", "tests", "vignettes")
  }

  types <- match.arg(types, c("examples", "tests", "vignettes"), several.ok=TRUE)

  # so the output list is named
  names(types) <- types

  extracted_files <- lapply(types, function(type) {
    fun <- switch(
      type,
      examples=extract_package_examples,
      tests=extract_package_tests,
      vignettes=extract_package_vignettes
    )

    # each type has its own folder not to clash with one another
    output <- file.path(output_dir, type)
    stopifnot(dir.exists(output) || dir.create(output, recursive=TRUE))

    files <- fun(pkg, pkg_dir, output_dir=output)

    if (!is.null(filter)) {
      files <- files[grepl(filter, tools::file_path_sans_ext(files))]
    }

    names(files) <- NULL
    files
  })

  extracted_files <- purrr::discard(
    extracted_files,
    ~length(.) == 0
  )

  df <- purrr::imap_dfr(extracted_files, ~data.frame(file=.x, type=.y))

  if (compute_sloc) {
    sloc <- cloc(output_dir, by_file=TRUE, r_only=TRUE)
    sloc <- dplyr::rename(sloc, file=filename)


    tt_driver <- purrr::keep(sloc$file, is_testthat_driver)
    if (length(tt_driver) == 1) {
      sloc <- dplyr::mutate(
        sloc,
        testthat=startsWith(file, "./tests/testthat/")
      )

      tt_sloc <- dplyr::filter(sloc, testthat)

      sloc <- dplyr::bind_rows(
        dplyr::filter(sloc, !testthat, file != tt_driver),
        data.frame(
          language="R",
          file=tt_driver,
          blank=sum(tt_sloc$blank),
          comment=sum(tt_sloc$comment),
          code=sum(tt_sloc$code)
        )
      )

      sloc <- dplyr::select(sloc, -testthat, -language)
    }

    df <- dplyr::left_join(df, sloc, by="file")
    df <- dplyr::mutate(
      df,
      blank=ifelse(is.na(blank), 0, blank),
      comment=ifelse(is.na(comment), 0, blank),
      code=ifelse(is.na(code), 0, blank)
    )
  }

  if (!is.null(wrap_fun)) {
    wrap_files(pkg, df$file, df$type, wrap_fun, quiet)
  }

  df
}

#' @importFrom tools Rd_db Rd2ex
extract_package_examples <- function(pkg, pkg_dir, output_dir) {
  db <- tryCatch({
    tools::Rd_db(basename(pkg_dir), dir=dirname(pkg_dir))
  }, error=function(e) {
    c()
  })

  if (!length(db)) {
    return(character())
  }

  files <- names(db)

  examples <- sapply(files, function(x) {
    f <- file.path(output_dir, paste0(basename(x), ".R"))
    tools::Rd2ex(db[[x]], f, defines=NULL)

    if (!file.exists(f)) {
      message("Rd file `", x, "' does not contain any code to be run")
      NA
    } else {
      # prepend the file with library call
      txt <- c(
        paste0("library(", pkg, ")"),
        "",
        "",
        readLines(f)
      )
      writeLines(txt, f)
      f
    }
  })

  na.omit(examples)
}

extract_package_tests <- function(pkg, pkg_dir, output_dir) {
  test_dir <- file.path(pkg_dir, "tests")

  if (!dir.exists(test_dir)) {
    return(character())
  }

  files <- Sys.glob(file.path(test_dir, "*"))
  file.copy(files, output_dir, recursive=TRUE)

  tests <- file.path(output_dir, basename(files))
  tests <- tests[!dir.exists(tests)]
  tests <- tests[grepl("\\.[rR]$", tests)]

  tests
}

#' @importFrom tools pkgVignettes checkVignettes
extract_package_vignettes <- function(pkg, pkg_dir, output_dir) {
  vinfo <- tools::pkgVignettes(pkg, source=T)
  if (length(vinfo$docs) == 0) {
    return(character())
  }

  if (length(vinfo$sources) == 0) {
    # so far no sources. The following should generate them if there are any
    # sources in the R code. It might actually run the vignettes as well.
    # That is a pity, but there is no way to tell it not to (the tangle is
    # needed to it extracts the R code)
    tools::checkVignettes(pkg, pkg_dir, tangle=TRUE, weave=FALSE, workdir="src")
  }

  # check if there are some sources
  vinfo <- tools::pkgVignettes(pkg, source=T)
  files <- as.character(unlist(vinfo$sources))
  if (length(files) == 0) {
    return(character())
  }

  dirs <- unique(dirname(files))
  for (d in dirs) {
      fs <- Sys.glob(file.path(d, "*"))
      file.copy(fs, output_dir, recursive=TRUE)
  }

  file.copy(files, to=output_dir)
  vignettes <- file.path(output_dir, basename(files))

  vignettes
}

is_testthat_driver <- function(file) {
    dir <- dirname(file)
    file_lower <- tolower(file)
    dir.exists(file.path(dir, "testthat")) &&
      (endsWith(file_lower, "tests/testthat.r") ||
         endsWith(file_lower, "tests/test-all.r") ||
         endsWith(file_lower, "tests/run-all.r"))
}

wrap_files <- Vectorize(function(package, file, type, wrap_fun, quiet) {
    # poor man's testthat detection
    file_lower <- tolower(file)
    if (type == "tests" && is_testthat_driver(file)) {
      tt_dir <- file.path(dirname(file), "testthat")
      tt_helpers <- list.files(tt_dir, pattern="helper.*\\.[rR]$", full.names=T, recursive=T)
      tt_tests <- list.files(tt_dir, pattern="test.*\\.[rR]$", full.names=T, recursive=T)
      tt_files <- c(tt_helpers, tt_tests)

      wrap_files(package, tt_files, rep("tests", length(tt_files)), wrap_fun, quiet)
    } else {
      if (!quiet) {
        message("- updating ", file, " (", type, ")")
      }

      body <- readLines(file)
      new_body <- wrap_fun(package, file, type, body)
      tryCatch({
        parse(text=new_body)
      }, error=function(e) {
        warning("E unable to parse wrapped file", file, ": ", e$message)
      })
      writeLines(new_body, file)
    }
}, vectorize.args=c("file", "type"))
