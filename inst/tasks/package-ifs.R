#!/usr/bin/env Rscript

library(fs)
library(magrittr)
suppressPackageStartupMessages(library(purrr))
library(readr)
library(tibble)
library(withr)

library(rapr)

OUTPUT_FILE <- "package-ifs.csv"
FUNCTIONS <- c(
  "if"
)

make_row <- function(call, fun_name) {
  deparse_arg <- function(arg) {
    paste(deparse(arg, width.cutoff=180L), collapse="")
  }

  lst <- as.list(call)

  call_fun_name <- lst[[1L]]
  call_fun_name <- if (is.call(call_fun_name)) {
    if (length(call_fun_name) == 3) {
      as.character(call_fun_name)[3]
    } else {
      format(call_fun_name)
    }
  } else {
    as.character(call_fun_name)
  }
  args <- paste(map_chr(lst[2L], deparse_arg), collapse=", ")

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

  tibble(fun_name, file, line1, col1, line2, col2, call_fun_name, args)
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

calls <- imap(funs, process_fun) %>% discard(~is.null(.) || length(.) == 0)

df <- imap_dfr(calls, make_rows)

if (nrow(df) > 0) {
  write_csv(df, OUTPUT_FILE)
}
