#!/usr/bin/env Rscript

options(repos=Sys.getenv("CRAN_LOCAL_MIRROR", "https://cloud.r-project.org"))

library(readr)
library(tibble)

OUTPUT_FILE <- "revdeps.csv"

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

package <- basename(args[1])

revdeps <- unlist(
  tools::package_dependencies(
    package,
    which=c("Depends", "Imports"),
    reverse=TRUE,
    recursive=FALSE
  ),
  use.names=FALSE
)

df <- tibble(revdep=unique(revdeps))

write_csv(df, OUTPUT_FILE)
