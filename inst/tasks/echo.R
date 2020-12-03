#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

args <- commandArgs(trailingOnly=TRUE)
cat("*** ENV:\n")
cat(paste(names(Sys.getenv()), Sys.getenv(), sep="="), sep="\n")
cat("\n\n")
cat("*** ARGS:\n")
cat(args, sep="\n")
cat("*** HOSTNAME:", Sys.info()["nodename"], "\n")
cat("*** PWD:", getwd(), "\n")
cat("*** :", file.exists(args[2]), "\n")
