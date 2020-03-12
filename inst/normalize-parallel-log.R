#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(dplyr))
library(fs)
library(readr)

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  message("Usage: normalize-parallel-log.R <parallel.log>")
  q(status=1)
}

log_file <- args[1]

stopifnot(fs::is_file(log_file))

log <- read_tsv(log_file)

message("Exitval count before normalization:")
print(count(log, Exitval))
message("Duplicate jobs:", group_by(log, Seq) %>% filter(n() > 1) %>% nrow())

updated_parallel_log <- group_by(log, Seq) %>% top_n(1, Starttime) %>% ungroup()
message("Exitval count after normalization:")
print(count(updated_parallel_log, Exitval))

write_tsv(updated_parallel_log, log_file)
