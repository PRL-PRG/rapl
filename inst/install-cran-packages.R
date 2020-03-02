#!/usr/bin/env Rscript

CRAN_LOCAL_MIRROR <- Sys.getenv("CRAN_LOCAL_MIRROR")
LIB_DIR <- Sys.getenv("LIB_DIR")

if (!dir.exists(LIB_DIR)) {
  dir.create(LIB_DIR, recursive=TRUE)
}

stopifnot(!is.null(CRAN_LOCAL_MIRROR))
stopifnot(!is.null(LIB_DIR))

options(repos=CRAN_LOCAL_MIRROR)

pkgs_file <- commandArgs(trailingOnly=TRUE)[1]
available <- if (!is.na(pkgs_file)) readLines(pkgs_file) else available.packages()[,1]
installed <- installed.packages(lib.loc=LIB_DIR)[,1]
missing <- setdiff(available, installed)

message("Installing ", length(missing), " packages from ", CRAN_LOCAL_MIRROR ," into ", LIB_DIR)

# CRAN repository to use e.g. https://cloud.r-project.org
install.packages(
  missing,
  lib=LIB_DIR,
  dependencies=TRUE,
  INSTALL_opts=c("--example", "--install-tests", "--with-keep.source", "--no-multiarch"),
  Ncpus=parallel::detectCores()
)
