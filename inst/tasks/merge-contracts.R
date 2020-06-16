#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(dplyr)
library(fst)
library(fs)
library(purrr)

args <- commandArgs(trailingOnly=TRUE)

print(args)

data_dir <- args[1]

files <-
    dir_ls(data_dir, recurse = TRUE, type = "file", regexp = ".*contracts.fst") %>%
    discard(function(f) f %in% c("run/run-extracted-code-contractr/animint2/contracts.fst",
                                 "run/run-extracted-code-contractr/stats19/contracts.fst"))

df <- bind_rows(Map(function(f) { print(f); tryCatch(read_fst(f), error = function(e) data.frame()) }, files))

write_fst(df, path(data_dir, "contracts.fst"))
