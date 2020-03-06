#!/usr/bin/env Rscript

options(error = function() traceback(3))

library(covr)
library(fs)
library(purrr)
library(readr)
library(stringr)
library(tibble)

COVERAGE_FILENAME <- "coverage.csv"
COVERAGE_DETAILS_FILENAME <- "coverage-details.csv"
COVERAGE_BY="expression"
TYPES <- c("all", "examples", "tests", "vignettes")

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

path <- args[1]

do_coverage <- function(type) {
  df <- tryCatch({
    pc <- package_coverage(path, type=type)
    saveRDS(pc, str_glue("coverage-raw-{type}.RDS"))

    df <- tally_coverage(pc, by=COVERAGE_BY)
    df <- add_column(df, type=type, .before="filename")
    write_csv(df, COVERAGE_DETAILS_FILENAME, append=TRUE)

    coverage_expression <- percent_coverage(df, by="expression")
    coverage_line <- percent_coverage(df, by="line")
    tibble(type, coverage_expression, coverage_line)
  }, error=function(e) {
    tibble(type, error=e$message)
  })
}

if (file_exists(COVERAGE_DETAILS_FILENAME)) {
  file_delete(COVERAGE_DETAILS_FILENAME)
}

coverage <- map_dfr(TYPES, do_coverage)

write_csv(coverage, COVERAGE_FILENAME)
