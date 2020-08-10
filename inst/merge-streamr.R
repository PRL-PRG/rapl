#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(rapr))
suppressPackageStartupMessages(library(streamr))

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 1) {
  message("Usage: merge-streamr.R <dir> <file1> [... <fileN>]")
  q(status=1)
}

run_dir <- args[1]
if (!dir.exists(run_dir)) {
  stop(run_dir, ": no such a directory")
}

file_names <- args[-1]

cat("Merging streamr files:\n\n")

for (file in file_names) {
  
  files <- list.files(run_dir, pattern=file, full.name=TRUE, recursive=TRUE)
  merged_file <- file.path(run_dir, file)

  if (file.exists(merged_file)) {
    unlink(merged_file)
  }

  df <- read_files(
    dirname(files),
    files,
    readf=function(file) {
      tmp <- streamr::read_table(file)
      if (!is.data.frame(tmp)) stop(file, ": not a data frame: ", typeof(tmp))
      tmp
    },
    mapf=function(job, df) {
      cbind(package=job, df)
    },
    mapf_error=function(job, file, message) {
      if (file.exists(file)) warning(job, ": ", file, ": ", message)
      NULL
    },
    reducef=function(x) {
      do.call(rbind, x)
    }
  )

  streamr::write_table(df, merged_file)
}
