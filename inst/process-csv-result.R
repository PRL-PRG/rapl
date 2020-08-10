#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))
library(knitr)
library(purrr)
library(readr)
library(stringr)

library(rapr)

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 1) {
  message("Usage: merge-csvs.R <directory-with-parallel.log> <CSV files>")
  q(status=1)
}

stopifnot(dir.exists(args[1]))

run_dir <- args[1]
csv_files <- args[-1]

cat("Reading GNU parallel run data...\n\n")
parallel_results_file <- file.path(run_dir, "parallel-results.csv")
results <- read_parallel_results(run_dir)

cat(str_glue("Writing results into {parallel_results_file}\n"))
write_csv(results, parallel_results_file)

cat("\nTask success status:\n")
cat(str_c(knitr::kable(count(results, exitval)), collapse="\n"))
cat("\n\n")

good_results <- filter(results, exitval==0)
paths <- good_results$path

cat("Processing results:\n\n")
for (file in csv_files) {
  jobs <- map_dfr(paths, ~tibble(job=basename(.x), file=list.files(.x, pattern=file, recursive=TRUE)))
  merged_csv_file <- file.path(run_dir, file)

  if (file.exists(merged_csv_file)) {
    unlink(merged_csv_file)
  }

  df <- read_files(
    jobs$job,
    jobs$file,
    readf=function(file) read_csv(file),
    mapf=function(job, df) {
      # this is a bit misuse, the work here is done by a side-effect
      # appending to the CSV file - otherwise it will be too slow
      # and use all memory since since some CSV files are rather large
      # this demonstrates a bad API!
      warning(typeof(df))
      df %>%
        mutate(package=job) %>%
        select(package, everything()) %>%
        write_csv(merged_csv_file, append=file_exists(merged_csv_file))
      NULL
    },
    mapf_error=function(job, file, message) {
      if (file.exists(file)) warning(job, ": ", file, ": ", message)
      NULL
    }
  )
}
