#!/usr/bin/env Rscript

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
  ),
  make_option(
    "--csv-cols",
    help="CSV col_types specification (c - string, i - int, d - double, l - logical)",
    dest="csv_cols", metavar="TYPES"
  ),
  make_option(
    "--key", default="file",
    help="Name of key column [default: %default]",
    dest="key_name", metavar="STR"
  ),
  make_option(
    "--key-use-dirname", default=FALSE,
    action="store_true",
    help="Use basename of the dirname of the file name",
    dest="key_use_dirname"
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
  ext <- tools::file_ext(file_name)

  read_fun <- NULL
  write_fun <- NULL

  # this will also trigger the library loading
  switch(
    ext,
    csv={
      read_args <- list()
      if (!is.null(options$csv_cols)) {
        read_args <- c(read_args, col_types=options$csv_cols)
      }

      read_fun <- if (length(read_args) > 0) {
        function(file) do.call(readr::read_csv, c(file=file, read_args))
      } else {
        readr::read_csv
      }

      write_fun <- readr::write_csv
    },
    fst={
      read_fun <- fst::read_fst
      write_fun <- fst::write_fst
    }
  )

  files <- find_files(
    in_dir,
    file_name,
    depth=options$depth,
    limit=options$limit,
    quiet=options$quiet
  )

  if (length(files) == 0) {
    cat("No files found")
    q(status=0)
  }

  merged_file <- file.path(in_dir, file_name)
  merged_errors_file <- file.path(
    in_dir,
    str_glue("{file_path_sans_ext(file_name)}-errors.{file_ext(file_name)}")
  )

  cat("- found:", length(files), "\n")
  cat("- merged file:", merged_file, "\n")
  cat("- merged errors file:", merged_errors_file, "\n")

  pb <- progress_bar$new(
    format="- reading [:bar] :current/:total :percent, :eta",
    total=length(files),
    clear=FALSE,
    width=80
  )

  res <- map(
    files,
    function(f) {
      tryCatch({
        tmp <- read_fun(f)

        if (!is.data.frame(tmp)) {
          stop("Not a data frame: ", typeof(tmp))
        }

        if (nrow(tmp) > 0) {
          key <- if (isTRUE(options$key_use_dirname)) basename(dirname(f)) else f
          key_name <- options$key_name
          add_column(tmp, !!key_name := key, .before=1)
        }

      }, error=function(e) {
        tmp <- tibble(file=f, error=e$message)
        attr(tmp, "__error") <- TRUE
        tmp
      }, finally= {
        pb$tick()
      })
    }
  )

  cat("- filtering", length(res), "loaded data frames...\n")

  errors <- map_lgl(res, ~isTRUE(attr(., "__error")))

  browser()

  data_df <- map_dfr(res[!errors], identity)

  errors_df <- map_df(res[errors], identity)

  if (nrow(data_df) > 0) {
    with_stopwatch(paste("- saving", nrow(data_df), "records into:", merged_file), {
      unlink(merged_file)
      write_fun(data_df, merged_file)
    })
  }

  if (nrow(errors_df) > 0) {
    with_stopwatch(paste("- saving", nrow(errors_df), "errors into:", merged_errors_file), {
      unlink(merged_errors_file)
      write_fun(errors_df, merged_errors_file)
    })
  }
}
