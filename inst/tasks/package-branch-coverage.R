#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(covr)
library(fs)
library(purrr)
library(readr)
library(stringr)
library(tibble)

message("Using covr: ", utils::packageVersion("covr"))

COVERAGE_FILENAME <- "coverage.csv"
COVERAGE_DETAILS_FILENAME <- "coverage-details.csv"
BRANCH_COVERAGE_DETAILS_FILENAME <- "branch-coverage-details.csv"
COVERAGE_BY="expression"
TYPES <- c("all", "examples", "tests", "vignettes")

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

path <- args[1]

message(tempfile())
message(paste0(.libPaths(), col="\n"))

do_coverage <- function(type) {
  df <- tryCatch({
    pc <- package_coverage(path, type=type, quiet=FALSE)
    saveRDS(pc, str_glue("coverage-raw-{type}.RDS"))

    df <- tally_coverage(pc, by=COVERAGE_BY)
    df <- add_column(df, type=type, .before="filename")
    write_csv(df, COVERAGE_DETAILS_FILENAME, append=TRUE)

    df_br <- tally_branch_coverage(pc)
    df_br <- add_column(df_br, type=type, .before="filename")
    write_csv(df_br, BRANCH_COVERAGE_DETAILS_FILENAME, append=TRUE)

    coverage_expression <- percent_coverage(df, by="expression")
    coverage_line <- percent_coverage(df, by="line")
    coverage_branch <- (sum(df_br$value > 0) / length(df_br$value)) * 100

    tibble(type, coverage_expression, coverage_line, coverage_branch, error=NA)
  }, error=function(e) {
    tibble(type, coverage_expression=NA, coverage_line=NA, coverage_branch=NA, error=e$message)
  })
}

if (file_exists(COVERAGE_DETAILS_FILENAME)) {
  file_delete(COVERAGE_DETAILS_FILENAME)
}

coverage <- map_dfr(TYPES, do_coverage)
write_csv(coverage, COVERAGE_FILENAME)

stopifnot(all(is.na(coverage$error)))
