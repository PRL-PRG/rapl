#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(covr)
library(fs)
library(rapr)
library(stringr)

REVDEP_RUNS_FILE <- "revdep-runs.csv"

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 2) {
  stop("Usage: package-revdep-coverage.R <path/to/package/source> <path/to/extracted-code>")
}

package_path <- args[1]
if (!dir.exists(package_path)) {
  stop(package_path, ": no such directory")
}

runnable_code_path <- args[2]
if (!dir.exists(runnable_code_path)) {
  stop(runnable_code_path, ": no such directory")
}

package <- basename(package_path)
revdep <- basename(runnable_code_path)

runnable_code_file <- path(runnable_code_path, "runnable-code.csv")
if (!file_exists(runnable_code_file)) {
  stop(str_glue("{runnable_code_file} for {revdep}: no such file"))
}

coverage_code <- str_glue("
  df <- rapr::run_all('{revdep}', '{runnable_code_file}')
  df <- cbind(data.frame(package='{revdep}', row.names=FALSE, stringsAsFactors=FALSE), df)
  write.table(
    df,
    '{REVDEP_RUNS_FILE}',
    sep=',',
    qmethod='double',
    append=TRUE,
    col.names=!file.exists('{REVDEP_RUNS_FILE}'),
    row.names=FALSE
  )
")

pc <- package_coverage(package_path, type="none", code=code, quiet=FALSE)
output <- str_glue("revdep-coverage-{revdep}.RDS")
saveRDS(pc, output)
