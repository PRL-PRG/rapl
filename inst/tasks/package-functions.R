#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(readr)
library(tibble)

OUTPUT_FILE <- "functions.csv"

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

package <- basename(args[1])

ns <- getNamespace(package)
exports <- getNamespaceExports(package)
functions <- ls(env=ns, all.names=TRUE)

df <- tibble(functions, exported=functions %in% exports)
write_csv(df, OUTPUT_FILE)
