#!/usr/bin/env Rscript

# NOTE: this file is used for coverage, should not have
# any dependencies except for base R with the exception
# of rapr

options(error = function() { traceback(3); q(status=1) })

library(contractr)
library(fst)

options(
    rapr.run_before=function(package, file, type) {
        clear_contracts()
    },
  rapr.run_after=function(package, file, type) {
      contracts <- get_contracts()
      if(nrow(contracts) != 0) {
          contracts <- cbind(package = package,
                             type = type,
                             file = file,
                             contracts)
          filename <- sprintf("%s-contracts.fst", basename(file))
          fst::write_fst(contracts, filename)
      }
  }
)
script <- system.file("tasks/run-extracted-code.R", package="rapr")

sys.source(script, envir=new.env())

