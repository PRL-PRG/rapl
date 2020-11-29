#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(optparse)
library(runr)
library(stringr)

OUTPUT_FILE <- "runnable-code.csv"

run <- function(path, options) {
  package <- basename(path)

  types <- str_split(options$type, ",")[[1L]]

  df <- extract_package_code(
    package,
    path,
    output_dir=getwd(),
    types=types,
    compute_sloc=options$sloc,
    quiet=options$quiet
  )

  write.csv(df, OUTPUT_FILE, row.names=FALSE)
}


option_list <- list(
  make_option(
    c("-q", "--quiet"), action="store_true", default=FALSE,
    dest="quiet", help="Do not print extra output"
  ),
  make_option(
    "--no-sloc", action="store_false", default=TRUE,
    dest="sloc", help="Do not compute the number of lines of code"
  ),
  make_option(
    "--type", default="all",
    help="What to extract: 'all' or a combination of 'examples', 'tests', 'vignettes' [default %default]",
    metavar="TYPE"
  ),
  make_option(
    "--wrap",
    help="A template to use to wrap the resulting code",
    metavar="FILE"
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
