#!/usr/bin/env Rscript

options(
  genthat.debug=T,
  genthat.source_paths=Sys.getenv("PACKAGES_SRC_DIR"),
  genthat.keep_failed_tests=T,
  genthat.keep_failed_traces=T,
  genthat.keep_all_traces=F
)

library(genthat)
library(readr)

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

package <- basename(args[1])

df <- gen_from_package(
  package,
  types="all",
  action="generate",
  prune_tests=T,
  quiet=F,
  working_dir=file.path(getwd(), "working-dir")
)

write_csv(df, "genthat.csv")

errors <- attr(df, "errors")
if (!is.null(errors)) {
  write_csv(errors, "errors.csv")
}

stats <- attr(df, "stats")
if (!is.null(stats) && is.numeric(stats) && length(stats) == 6) {
  stats <- data.frame(
    all=stats[1],
    generated=stats[2],
    ran=stats[3],
    kept=stats[4],
    coverage=stats[5],
    elapsed=stats[6]
  )
  write_csv(stats, "stats.csv")
}

raw_coverage <- attr(df, "raw_coverage")
if (!is.null(raw_coverage)) {
  write_csv(raw_coverage, "raw-coverage.csv")
}
