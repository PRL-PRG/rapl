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
COVERAGE_TYPES <- Sys.getenv("RUNR_PACKAGE_COVERAGE_TYPE", "all,examples,tests,vignettes")

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
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

path <- args[1]


for (by in COVERAGE_BY) {
  file <- str_glue(COVERAGE_DETAILS_FILE)
  if (file_exists(file)) {
    file_delete(file)
  }
}

types <- map_chr(str_split(COVERAGE_TYPES, ",")[[1]], ~trimws(., "both"))

Sys.setenv(
  R_TESTS="",
  R_BROWSER="false",
  R_PDFVIEWER="false",
  R_BATCH="1"
)

coverage <- map_dfr(types, do_coverage_checked)

write_csv(coverage, COVERAGE_FILE)

stopifnot(all(is.na(coverage$error)))
