#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(optparse)
library(runr)
library(stringr)

OUTPUT_FILE <- "run.csv"

Sys.setenv(RUNR_CWD=getwd())

run <- function(path, options) {
  df <- run_all(
    path,
    quiet=options$quiet,
    clean=options$clean,
    skip_if_out_exists=options$skip
  )

  write.csv(df, OUTPUT_FILE, row.names=FALSE)
}

option_list <- list(
  make_option(
    c("-q", "--quiet"), action="store_true", default=FALSE,
    dest="quiet", help="Do not print extra output"
  ),
  make_option(
    "--no-clean", action="store_false", default=TRUE,
    dest="clean", help="Do not clean the intermediate output"
  ),
  make_option(
    "--force", action="store_false", default=TRUE,
    dest="skip", help="For run on files that have already been run"
  )
)

opt_parser <- OptionParser(option_list=option_list)
opts <- parse_args(opt_parser, positional_arguments=1)

if (length(opts$args) != 1) {
  message("Missing path to a package source")
  q(1, save="no")
}

package_path <- opts$args

if (!dir.exists(package_path)) {
  message(package_path, ": no such directory")
  q(1, save="no")
}

run(package_path, opts$options)
