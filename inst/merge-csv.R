#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(knitr))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(runr))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(stringr))

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 1) {
  message("Usage: merge-csvs.R <dir> <csv_file1> [... <csv_fileN>]")
  q(status=1)
}

run_dir <- args[1]
if (!dir.exists(run_dir)) {
  stop(run_dir, ": no such a directory")
}

csv_files <- args[-1]

cat("Merging CSVs:\n\n")
for (file in csv_files) {
  merged_csv_file <- file.path(run_dir, file)

  if (file.exists(merged_csv_file)) {
    unlink(merged_csv_file)
  }

  files <- list.files(run_dir, pattern=file, full.name=TRUE, recursive=TRUE)
  df <- read_files(
    dirname(files),
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
        write_csv(merged_csv_file, append=file.exists(merged_csv_file))
      NULL
    },
    mapf_error=function(job, file, message) {
      if (file.exists(file)) warning(job, ": ", file, ": ", message)
      NULL
    }
  )
}
