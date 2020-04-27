#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

args <- commandArgs(trailingOnly=TRUE)
print(Sys.getenv())
print(args)
