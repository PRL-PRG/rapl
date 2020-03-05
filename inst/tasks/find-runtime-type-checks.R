#!/usr/bin/env Rscript

library(fs)
library(magrittr)
suppressPackageStartupMessages(library(purrr))
library(readr)
library(tibble)
library(withr)

library(rapr)

RUNTIME_CHECKS_FILE <- "runtime-checks.csv"
FUNCTIONS <- c(
  "base:::stopifnot",
  "assertthat:::assert_that",
  "assertthat:::see_if",
  "assertthat:::validate_that"
)

make_row <- function(call) {
  deparse_arg <- function(arg) {
    paste(deparse(arg, width.cutoff=180L), collapse="")
  }

  lst <- as.list(call)
  fun <- lst[[1L]]
  fun <- if (is.call(fun)) {
    if (length(fun) == 3) {
      as.character(fun)[3]
    } else {
      format(fun)
    }
  } else {
    as.character(fun)
  }
  args <- paste(map_chr(lst[-1L], deparse_arg), collapse=", ")

  tibble(fun, args)
}

process_one <- function(file) {
  ast <- withr::with_options(c("keep.parse.data.pkgs" = TRUE), {
    tryCatch({
      # getting locations from the srcrefs is quite tricky
      # so unless we find out that we need that, I just drop it
      parse(file, keep.source=FALSE)
    }, error=function(e) stop("Unable to parse ", file, ": ", e, call=FALSE))
  })

  calls <-
    map(ast, ~search_function_calls(., FUNCTIONS)) %>%
    unlist() %>%
    discard(is.null)

  df <- map_dfr(calls, make_row)
  add_column(df, file=file, .before=1L)
}

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

path <- args[1]

r_files <- dir_ls(path, regexp=".*\\.[Rr]$", recurse=TRUE)
df <- map_dfr(r_files, process_one)

if (nrow(df) > 0) {
  write_csv(df, RUNTIME_CHECKS_FILE)
}
