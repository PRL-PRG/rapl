#!/usr/bin/env Rscript

options(error = function() traceback(3))

suppressPackageStartupMessages(library(devtools))
library(fs)
library(purrr)
library(runr)
library(readr)
library(stringr)
library(tibble)

METADATA_FILENAME <- "metadata.csv"
SLOC_FILENAME <- "sloc.csv"

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

path <- args[1]
pkg <- devtools::as.package(path)

package_name <- pkg$package
version <- pkg$version
title <- pkg$title

tryCatch({
  size <- system2("du", c("-sb", path), stdout = TRUE)
  size <- str_replace(size, "(\\d+).*", "\\1")
  size <- as.double(size)

  df <- tibble(package_name, version, title, size)

  write_csv(df, METADATA_FILENAME)
}, error=function(e) {
  message("Unable to get package size: ", e$message)
})

paths <- fs::path(path, c("R", "src", "inst", "tests", "vignettes"))
paths <- paths[is_dir(paths)]

sloc <- map_dfr(paths, cloc)

write_csv(sloc, SLOC_FILENAME)
