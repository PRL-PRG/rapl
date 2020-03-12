#!/usr/bin/env Rscript

options(error = function() {traceback(3); q(status=1) })

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

package <- basename(args[1])

library(package, character.only=TRUE)
