#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(magrittr))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(tibble))

R_LIBS <- Sys.getenv("R_LIBS")
stopifnot(nchar(R_LIBS) > 0)

message("R_LIBS: ", R_LIBS)

pkgs <- unique(installed.packages(lib.loc=R_LIBS))

message("Packages: ", length(pkgs[, 1]))

tools::package_dependencies(
  pkgs[,1],
  db=pkgs,
  which=c("Depends", "Imports"),
  reverse=TRUE,
  recursive=FALSE
) %>%
  imap_dfr(~tibble(package=.y, revdep=.x)) %>%
  format_csv() %>%
  cat()
