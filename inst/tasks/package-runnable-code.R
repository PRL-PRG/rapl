#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(glue)
library(purrr)
library(runr)
library(readr)
library(tibble)

OUTPUT_FILE <- "runnable-code.csv"
METADATA_FILE <- "runnable-code-metadata.csv"
CODE_FILE <- "run-all.R"

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

package_path <- args[1]
package <- basename(package_path)

files <- extract_package_code(package, package_path, types="all", output_dir=".")
df <- imap_dfr(files, ~tibble(path=.x, type=.y))

write_csv(df, OUTPUT_FILE)

df_sloc <- map_dfr(c("examples", "tests", "vignettes"), ~cloc(.))
write_csv(df_sloc, METADATA_FILE)

