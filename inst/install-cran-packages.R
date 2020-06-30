#!/usr/bin/env Rscript

CRAN_LOCAL_MIRROR <- Sys.getenv("CRAN_LOCAL_MIRROR")
R_LIBS <- Sys.getenv("R_LIBS")

if (!dir.exists(R_LIBS)) {
  dir.create(R_LIBS, recursive=TRUE)
}

stopifnot(!is.null(CRAN_LOCAL_MIRROR))
stopifnot(!is.null(R_LIBS))

options(repos=CRAN_LOCAL_MIRROR)

pkgs_file <- commandArgs(trailingOnly=TRUE)[1]
available <- if (!is.na(pkgs_file)) readLines(pkgs_file) else available.packages()[,1]
installed <- installed.packages(lib.loc=R_LIBS)[,1]
missing <- setdiff(available, installed)

sessionInfo()
message("Installing ", length(missing), " packages from ", CRAN_LOCAL_MIRROR ," into ", R_LIBS)

# CRAN repository to use e.g. https://cloud.r-project.org
install.packages(
  missing,
  lib=R_LIBS,
  dependencies=TRUE,
  INSTALL_opts=c("--example", "--install-tests", "--with-keep.source", "--no-multiarch"),
  Ncpus=parallel::detectCores()
)
