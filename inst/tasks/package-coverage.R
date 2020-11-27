#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(covr)
library(fs)
library(purrr)
library(readr)
library(stringr)
library(tibble)

COVERAGE_FILE <- "coverage.csv"
COVERAGE_DETAILS_FILE <- "coverage-details-{by}.csv"
COVERAGE_BY <- c("line", "expression")
ALL_TYPES <- eval(formals(package_coverage)$type)

do_coverage <- function(type) {
  pc <- package_coverage(path, type=type, quiet=FALSE)
  saveRDS(pc, str_glue("coverage-raw-{type}.RDS"))

  df <- tibble(type, error=NA)

  for (by in COVERAGE_BY) {
    file <- str_glue(COVERAGE_DETAILS_FILE)

    cvr <- tally_coverage(pc, by=by)
    cvr <- add_column(cvr, type=type, .before="filename")

    write_csv(cvr, file, append=file_exists(file))

    pct <- percent_coverage(cvr, by=by)

    df <- add_column(df, !!(str_c("coverage_", by)) := pct)
  }

  df
}

do_coverage_checked <- function(type) {
  tryCatch(do_coverage(type), error=function(e) tibble(type, error=e$message))
}

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 2) {
  stop("Usage: <path-to-package-src-dir> <--all|--tests|--examples|--vignettes>")
}

path <- args[1]
types <- c()

for (arg in args[2:length(args)]) {
  if (startsWith(arg, "--")) {
    val <- substr(arg, 3, nchar(arg))
    if (val %in% ALL_TYPES) types <- append(types, val)
    else stop("unknown arg: ", arg)
  } else {
    stop("unknown arg: ", arg)
  }
}

if (length(types) == 0) {
  stop("Missing types arguments (e.g. --all, --tests, ...)")
}

for (by in COVERAGE_BY) {
  file <- str_glue(COVERAGE_DETAILS_FILE)
  if (file_exists(file)) {
    file_delete(file)
  }
}

Sys.setenv(
  R_TESTS="",
  R_BROWSER="false",
  R_PDFVIEWER="false",
  R_BATCH="1"
)

coverage <- map_dfr(types, do_coverage_checked)

write_csv(coverage, COVERAGE_FILE)

stopifnot(all(is.na(coverage$error)))
