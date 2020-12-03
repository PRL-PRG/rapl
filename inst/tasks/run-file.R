#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Usage: run-file.R file")
}

path <- args[1]

if (file.access(path, 4) != 0) {
  message(path, ": unable to access")
  q(status=1, save="no")
}

df <- runr::run_one(path, NULL, quiet=FALSE, stats=FALSE)
q(status=df$exitval, save="no")
