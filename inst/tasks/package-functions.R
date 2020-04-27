#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(readr)
library(tibble)

OUTPUT_FILE <- "functions.csv"

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

package <- basename(args[1])

ns <- getNamespace(package)
exports <- getNamespaceExports(package)
bindings <- ls(env=ns, all.names=TRUE)

function_bindings <- sapply(bindings, function(x) {
    f <- get0(x, envir=ns)
    if (!is.function(f)) NA else x
})
function_bindings <- na.omit(function_bindings)
functions <- lapply(function_bindings, get0, envir=ns)

params <- lapply(functions, function(x) names(formals(x)))

num_params <- sapply(params, length)

has_elipsis <- sapply(params, function(x) "..." %in% x)

df <- tibble(fun=function_bindings, num_params, has_elipsis, exported=function_bindings %in% exports)

write_csv(df, OUTPUT_FILE)
