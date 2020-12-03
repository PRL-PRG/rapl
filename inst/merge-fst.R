#!/usr/bin/env Rscript

library(fst)
library(optparse)
library(progress)
library(purrr)
library(runr)
library(stringr)
library(tibble)
library(tools)

option_list <- list(
  make_option(
    c("-q", "--quiet"), action="store_true", default=FALSE,
    dest="quiet", help="Do not print extra output"
  ),
  make_option(
    "--in",
    help="The directory in where to find files",
    dest="in_dir", metavar="DIR"
  ),
  make_option(
    "--depth",
    help="Limit directory traversal for the given depth [default: %default]", type="integer",
    default=0,
    metavar="NUM"
  ),
  make_option(
    "--limit",
    help="Limit number of processed files [default: %default]", type="integer",
    default=0,
    metavar="NUM"
  )
)

opt_parser <- OptionParser(option_list=option_list)
opts <- parse_args(opt_parser, positional_arguments=c(1, Inf))

options <- opts$options
file_names <- opts$args
in_dir <- options$in_dir

if (!dir.exists(in_dir)) {
  stop(in_dir, ": no such in directory")
}

find_files <- function(dir, file_name, depth, limit, quiet) {
  args <- c("-t", "f", "-F", "-c", "never")

  if (depth > 0) {
    args <- c(args, "--exact-depth", depth)
  } else {
    args <- c(args, "--min-depth", 2)
  }

  if (limit > 0) {
    args <- c(args, "--max-results", limit)
  }

  args <- c(args, file_name, dir)

  if (!quiet) {
    cat("- running: fd", str_c(args), "...\n")
  }

  system2("fd", args, stdout=TRUE, stderr=FALSE)
}

with_stopwatch <- function(message, code) {
  cat(message, " ... ")
  time <- system.time(res <- force(code))
  cat("done (in ", time["elapsed"], ")\n")
  res
}

for (file_name in file_names) {
  cat("Merging", file_name, "from", in_dir, "...\n")

  files <- find_files(
    in_dir,
    file_name,
    depth=options$depth,
    limit=options$limit,
    quiet=options$quiet
  )
  merged_file <- file.path(in_dir, file_name)
  merged_errors_file <- file.path(
    in_dir,
    str_glue("{file_path_sans_ext(file_name)}-errors.{file_ext(file_name)}")
  )

  cat("- found:", length(files), "\n")
  cat("- merged file:", merged_file, "\n")
  cat("- merged errors file:", merged_errors_file, "\n")
  cat("\n")

  pb <- progress_bar$new(
    format="Reading [:bar] :current/:total :percent, :eta",
    total=length(files),
    clear=FALSE,
    width=80
  )

  res <- map(
    files,
    ~tryCatch({
      tmp <- read_fst(.)
      if (!is.data.frame(tmp)) stop("Not a data frame: ", typeof(tmp))
      add_column(tmp, file=., .before=1)
    }, error=function(e) {
      tmp <- tibble(file=., error=e$message)
      attr(tmp, "error") <- TRUE
      tmp
    }, finally= {
      pb$tick()
    })
  )

  cat("\nFiltering", length(res), "loaded data frames...\n")

  errors <- map_lgl(res, ~isTRUE(attr(., "error")))
  data_df <- map_dfr(res[!errors], identity)
  errors_df <- map_df(res[errors], identity)

  if (nrow(data_df) > 0) {
    with_stopwatch(paste("Saving", nrow(data_df), "records into:", merged_file), {
      unlink(merged_file)
      write_fst(data_df, merged_file)
    })
  }

  if (nrow(errors_df) > 0) {
    with_stopwatch(paste("Saving", nrow(errors_df), "errors into:", merged_errors_file), {
      unlink(merged_errors_file)
      write_fst(errors_df, merged_errors_file)
    })
  }
}
