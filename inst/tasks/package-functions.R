#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(readr)
library(tibble)

OUTPUT_FILE <- "functions.csv"
OUTPUT_CLASSES_FILE <- "classes.csv"

is_s3 <- function(fun) {
  globals <- codetools::findGlobals(fun, merge = FALSE)$functions
  any(globals == "UseMethod" | globals == "NextMethod")
}

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

s3_methods <- if (exists(".__S3MethodsTable__.", envir=ns)) {
  ms <- ns$.__S3MethodsTable__.
  ls(envir=ms, all.names=T)
} else {
  character(0)
}

s3_methods <- NULL
if (exists(".__NAMESPACE__.", envir=ns)) {
  s3_methods <- ns$.__NAMESPACE__.$S3methods[,3]
}

if (is.null(s3_methods)) {
  s3_methods <- character(0)
}

is_s3_dispatch <- sapply(functions, is_s3)
is_s3_method <- function_bindings %in% s3_methods

df <- tibble(
  fun=function_bindings,
  exported=function_bindings %in% exports,
  is_s3_dispatch,
  is_s3_method,
  params=sapply(params, paste0, collapse=";")
)

write_csv(df, OUTPUT_FILE)

s3_classes <-  if (exists(".S3MethodsClasses", envir=ns)) {
  cs <- ns$.S3MethodsClasses
  ls(envir=cs, all.names=T)
} else {
  character(0)
}

df <- tibble(
  class=s3_classes
)

write_csv(df, OUTPUT_CLASSES_FILE)
