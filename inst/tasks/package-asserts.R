#!/usr/bin/env Rscript

library(fs)
library(magrittr)
suppressPackageStartupMessages(library(purrr))
library(readr)
library(tibble)
library(withr)

library(rapr)

OUTPUT_FILE <- "package-asserts.csv"
FUNCTIONS <- c(
  "base:::stopifnot",
  "assertthat:::assert_that",
  "assertthat:::see_if",
  "assertthat:::validate_that"
)

make_row <- function(call, fun_name) {
  deparse_arg <- function(arg) {
    paste(deparse(arg, width.cutoff=180L), collapse="")
  }

  lst <- as.list(call)
  assert <- lst[[1L]]
  assert <- if (is.call(assert)) {
    if (length(assert) == 3) {
      as.character(assert)[3]
    } else {
      format(assert)
    }
  } else {
    as.character(assert)
  }
  args <- paste(map_chr(lst[-1L], deparse_arg), collapse=", ")

  line1 <- NA
  line2 <- NA
  col1 <- NA
  col2 <- NA
  file <- NA

  srcref <- attr(call, "srcref")
  if (!is.null(srcref)) {
    line1 <- srcref[1]
    col1 <- srcref[2]
    line2 <- srcref[3]
    col2 <- srcref[4]
    file <- attr(srcref, "srcfile")$filename
    if (is.null(file)) file <- NA
  }

  tibble(fun_name, file, line1, col1, line2, col2, assert, args)
}

make_rows <- function(calls, fun_name) {
  map_dfr(calls, make_row, fun_name=fun_name)
}

process_fun <- function(fun, fun_name) {
  ast <- body(fun)
  srcref <- attr(fun, "srcref")

  search_function_calls(ast, functions=FUNCTIONS, srcref=srcref)
}

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

path <- args[1]
package <- basename(path)

ns <- as.list(getNamespace(package))

funs <- keep(ns, is.function)

checks <- imap(funs, process_fun) %>% discard(~is.null(.) || length(.) == 0)

df <- imap_dfr(checks, make_rows)

if (nrow(df) > 0) {
  write_csv(df, OUTPUT_FILE)
}
