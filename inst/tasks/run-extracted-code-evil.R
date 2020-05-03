#!/usr/bin/env Rscript

## NOTE: this file is used for coverage, should not have
## any dependencies except for base R with the exception
## of rapr

options(error = function() { traceback(3); q(status=1) })

library(evil)
library(fst)

script <- system.file("tasks/run-extracted-code.R", package="rapr")

sys.source(script, envir=new.env())

fst::write_fst(get_eval_calls(), "eval-calls.fst")
