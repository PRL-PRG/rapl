#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

args <- commandArgs(trailingOnly=TRUE)
cat("*** ENV:\n")
cat(Sys.getenv(), sep="\n")
cat("\n\n")
cat("*** ARGS:\n")
cat(args, sep="\n")
