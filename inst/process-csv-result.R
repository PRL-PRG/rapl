#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))
library(fs)
library(purrr)
library(readr)

library(rapr)

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 2) {
  message("Usage: merge-csvs.R <directory-with-parallel.log> <filename.csv> [<column-types>]")
  q(status=1)
}

stopifnot(fs::is_dir(args[1]))

run_dir <- args[1]
file <- args[2]
col_types <- if (length(args) == 3) args[3] else NULL

results <- read_parallel_results(run_dir)
good_results <- filter(results, exitval==0)

paths <- good_results$path
jobs <- basename(paths)
files <- path(paths, file)
merged_csv_file <- path(run_dir, file)
parallel_results_file <- path(run_dir, "parallel-results.csv")

if (file_exists(merged_csv_file)) {
  file_delete(merged_csv_file)
}

df <- read_files(
  jobs,
  files,
  readf=function(file) suppressMessages(read_csv(file, col_types=col_types)),
  mapf=function(job, df) {
    df %>%
      mutate(package=job) %>%
      select(package, everything()) %>%
      write_csv(merged_csv_file, append=file_exists(merged_csv_file))
    NULL
  },
  mapf_error=function(job, file, message) {
    if (file_exists(file)) tibble(job, load_error=message) else NULL
  },
  reducef=bind_rows
)

if (nrow(df) > 0) {
  results <- left_join(results, df, by="job")
}
write_csv(results, parallel_results_file)
