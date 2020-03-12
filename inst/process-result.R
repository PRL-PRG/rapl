#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))
library(fs)
library(readr)

library(rapr)

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 1) {
  message("Usage: merge-csvs.R <directory-with-parallel.log>")
  q(status=1)
}

stopifnot(fs::is_dir(args[1]))

run_dir <- args[1]

results <- read_parallel_results(run_dir)

parallel_results_file <- path(run_dir, "parallel-results.csv")

write_csv(results, parallel_results_file)

cat("Exitval status:\n")
print(count(results, exitval))
