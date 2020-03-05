#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))
library(fs)
library(purrr)
library(readr)

library(rapr)

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 3) {
  message("Usage: merge-csvs.R <directory-with-parallel.log> <filename.csv> <column-types>")
  q(status=1)
}

stopifnot(length(args) == 3)
stopifnot(fs::is_dir(args[1]))

run_dir <- args[1]
file <- args[2]
col_types <- args[3]

load_csv <- function(file) {
  read_csv(file, col_types=col_types) %>%
    mutate(job=job, error=NA) %>%
    select(job, everything())
}

results <- read_parallel_results(run_dir)
good_results <- filter(results, exitval==0)

paths <- good_results$path
jobs <- basename(paths)
files <- path(paths, file)

df <- read_files(
  jobs,
  files,
  readf=function(file) read_csv(file, col_types=col_types),
  mapf=function(job, df) mutate(df, package=job, error=NA) %>% select(package, everything()),
  mapf_error=function(job, file, message) tibble(package=job, error=message),
  reducef=bind_rows
)

write_csv(results, path(run_dir, "results.csv"))
write_csv(df, path(run_dir, file))
