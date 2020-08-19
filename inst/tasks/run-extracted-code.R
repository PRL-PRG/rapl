#!/usr/bin/env Rscript

# NOTE: this file is used for coverage, should not have
# any dependencies except for base R with the exception
# of runr

library(runr)

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 2) {
  stop("Missing a path to the package source and the path to runnable-code.csv")
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
runnable_code_file <- file.path(runnable_code_path, "runnable-code.csv")

cat("Lib paths: ", paste0(.libPaths(), collapse=":"), "\n")
Sys.setenv(RUNR_CWD=getwd())
Sys.setenv(RUNR_CWD=getwd())

df <- local({
  runr::run_all(
    package,
    runnable_code_file,
    run_before=getOption("runr.run_before"),
    run_after=getOption("runr.run_after")
  )
})

write.csv(df, "run.csv", row.names=FALSE)
