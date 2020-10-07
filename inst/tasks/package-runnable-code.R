#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(runr)

OUTPUT_FILE <- "runnable-code.csv"

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

package_path <- args[1]
package <- basename(package_path)

files <- runr::extract_package_code(
  package,
  package_path,
  types="all",
  output_dir=".",
  compute_sloc=TRUE
)

write.csv(df, OUTPUT_FILE, row.names=FALSE)
