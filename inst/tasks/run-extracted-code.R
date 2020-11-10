#!/usr/bin/env Rscript

# NOTE: this file is used for coverage, should not have
# any dependencies except for base R with the exception
# of runr

library(runr)
library(stringr)

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 2) {
  stop("Usage: <package-src-path> <runnable-code-path> [<file-to-run>]")
}

package_path <- args[1]
if (!dir.exists(package_path)) {
  stop(package_path, ": no such package path, (wd=", getwd(), ")")
}

package <- basename(package_path)
if (!require(package, character.only=TRUE)) {
  stop(
    package,
    ": no such package, (.libPaths=", paste0(.libPaths(), col=":"), ")"
  )
}

runnable_code_path <- args[2]

filter <- NULL
run_dir <- tempfile()
run_file <- "run.csv"

if (length(args) == 3) {
  filter <- str_c(fixed(args[3]), "$")
  run_dir <- runnable_code_path
  run_file <- str_c("run-", args[3], ".csv")
}

Sys.setenv(RAPR_CWD=getwd())
Sys.setenv(RUNR_CWD=getwd())

df <- runr::run_all(runnable_code_path, run_dir=run_dir, filter=filter, quiet=FALSE)

write.csv(df, run_file, row.names=FALSE)
