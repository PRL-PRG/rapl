#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(readr)
library(stringr)
library(tibble)
library(optparse)

COVERAGE_FILE <- "coverage.csv"
COVERAGE_DETAILS_FILE <- "coverage-details-{by}.csv"
COVERAGE_RAW_FILE <- "coverage-raw-{type}.RDS"
COVERAGE_BY <- c("line", "expression")

do_coverage <- function(path, type, quiet, clean) {
  library(covr)

  pc <- package_coverage(path, type=type, quiet=quiet, clean=clean)
  saveRDS(pc, str_glue(COVERAGE_RAW_FILE))

  df <- tibble(type, error=NA)

  for (by in COVERAGE_BY) {
    file <- str_glue(COVERAGE_DETAILS_FILE)

    cvr <- tally_coverage(pc, by=by)
    cvr <- add_column(cvr, type=type, .before="filename")

    write_csv(cvr, file, append=file.exists(file))

    pct <- percent_coverage(cvr, by=by)

    df <- add_column(df, !!(str_c("coverage_", by)) := pct)
  }

  df
}

run <- function(path, options) {
  str(options)
  for (by in COVERAGE_BY) {
    file <- str_glue(COVERAGE_DETAILS_FILE)
    if (file.exists(file)) {
      file.remove(file)
    }
  }

  Sys.setenv(
    R_TESTS="",
    R_BROWSER="false",
    R_PDFVIEWER="false",
    R_BATCH="1"
  )

  path <- normalizePath(path, mustWork=TRUE)
  pkg_src <- tempfile()
  stopifnot(dir.create(pkg_src, recursive=TRUE))
  message("Using: ", pkg_src, " as temp file for package source")
  stopifnot(file.copy(str_c(path, .Platform$file.sep, .Platform$file.sep), pkg_src, recursive=TRUE))
  if (options$clean) {
    on.exit(unlink(pkg_src, recursive=TRUE))
  }

  types <- str_split(options$type, ",")[[1L]]
  print(types)

  coverage <- lapply(types, function(type) {
    tryCatch({
      do_coverage(
        pkg_src,
        type=type,
        quiet=options$quiet,
        clean=options$clean
      )
    }, error=function(e) {
      message("Error getting coverage for ", pkg_src, " type ", type, ": ", e$message)
      tibble(type, error=e$message)
    })
  })

  coverage_df <- do.call(rbind, coverage)

  write_csv(coverage_df, COVERAGE_FILE)

  stopifnot(all(is.na(coverage_df$error)))
}

option_list <- list(
  make_option(
    c("-q", "--quiet"), action="store_true", default=FALSE,
    dest="quiet", help="Do not print extra output"
  ),
  make_option(
    c("--no-clean"), action="store_false", default=TRUE,
    dest="clean", help="Do not clean the intermediate output"
  ),
  make_option(
    c("--type"), default="all,examples,tests,vignettes",
    help="Coma separated list of things to run individually [default %default]",
    metavar="TYPE"
  )
)

opt_parser <- OptionParser(option_list=option_list)
opts <- parse_args(opt_parser, positional_arguments=1)

if (length(opts$args) != 1) {
  message("Missing path to a package source")
  q(1, save="no")
}

package_path <- opts$args

if (!dir.exists(package_path)) {
  message(package_path, ": no such directory")
  q(1, save="no")
}

run(package_path, opts$options)
