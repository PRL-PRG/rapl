#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(covr))
suppressPackageStartupMessages(library(fs))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(tibble))

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 2) {
  message("Usage: merge-coverage.R <path> <file-pattern>")
  q(status=1)
}

coverage_path <- args[1]
if (!is_dir(coverage_path)) {
  stop(coverage_path, ": no such a siectory")
}

coverage_file_pattern <- args[2]

files <- dir_ls(coverage_path, recurse=T, regexp=coverage_file_pattern)

if (length(files) == 0) {
  message("No files to merge in ", coverage_path)
  q(status=0)
}

cat("Merging ", length(files), "files ...\n\n")

pc <- covr:::merge_coverage(files)
print(pc)

saveRDS(pc, "coverage.RDS")

pc_line <- tally_coverage(pc, by="line")
write_csv(pc_line, "coverage-details-line.csv")

pc_expr <- tally_coverage(pc, by="expression")
write_csv(pc_expr, "coverage-details-expr.csv")

coverage_line <- percent_coverage(pc, by="line")
coverage_expr <- percent_coverage(pc, by="expression")

df <- tibble(
  coverage_expr,
  coverage_line,
  coverage_merged_files=length(files)
)

write_csv(df, "coverage.csv")
