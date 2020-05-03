#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(dplyr)
library(fst)
library(fs)

args <- commandArgs(trailingOnly=TRUE)

print(args)

data_dir <- args[1]

files <- dir_ls(data_dir, recurse = TRUE, type = "file", regexp = "eval-calls.fst")

df <- bind_rows(Map(read_fst, files))

write_fst(df, path(data_dir, "eval-calls.fst"))
