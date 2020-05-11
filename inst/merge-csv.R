#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(knitr))
suppressPackageStartupMessages(library(fs))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(rapr))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(stringr))


args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 1) {
  message("Usage: merge-csvs.R <directory-with-parallel-results.csv> <CSV files>")
  q(status=1)
}

run_dir <- args[1]
if (!is_dir(run_dir)) {
  stop(run_dir, ": no such a directory")
}

parallel_results_file <- path(run_dir, "parallel-results.csv")
if (!file_exists(parallel_results_file)) {
  stop(parallel_results_file, ": no such a file")
}

csv_files <- args[-1]

cat(str_glue("Reading results into {parallel_results_file}\n"))
parallel_results <- suppressMessages(read_csv(parallel_results_file))

cat("\nTask success status:\n")
cat(str_c(knitr::kable(count(parallel_results, Exitval)), collapse="\n"))
cat("\n\n")

succ_results <- filter(parallel_results, Exitval==0)
jobs <- unique(succ_results$V1)
paths <- path(run_dir, jobs)

cat("Merging CSVs:\n\n")
for (file in csv_files) {
  files <- path(paths, file)
  merged_csv_file <- path(run_dir, file)

  if (file_exists(merged_csv_file)) {
    file_delete(merged_csv_file)
  }

  df <- read_files(
    jobs,
    files,
    readf=function(file) suppressMessages(read_csv(file)),
    mapf=function(job, df) {
      # this is a bit misuse, the work here is done by a side-effect
      # appending to the CSV file - otherwise it will be too slow
      # and use all memory since since some CSV files are rather large
      # this demonstrates a bad API!
      df %>%
        mutate(package=job) %>%
        select(package, everything()) %>%
        write_csv(merged_csv_file, append=file_exists(merged_csv_file))
      NULL
    },
    mapf_error=function(job, file, message) {
      if (file_exists(file)) warning(job, ": ", file, ": ", message)
      NULL
    }
  )
}
