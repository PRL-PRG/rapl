#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })
options(repos=Sys.getenv("CRAN_LOCAL_MIRROR", "https://cloud.r-project.org"))

library(covr)
library(fs)
library(purrr)
library(rapr)
library(readr)
library(stringr)
library(tibble)

WHICH_DEPENDENCIES <- c("Depends", "Imports")
REVDEP_RUNS_FILE <- "revdep-runs.csv"

# this is a timeout for one reverse dependency
# the reason for this is that some runnable code spawns
# long running processes
REVDEP_RUN_TIMEOUT <- 30*60

coverage_one <- function(revdep, tmp_lib) {
  cat(
    "**********************************************************************\n",
    "*** COVERAGE BY ", revdep, "\n",
    "**********************************************************************\n",
    "\n",
    sep=""
  )

  runnable_code_file <- path(runnable_code_path, revdep, "runnable-code.csv")
  if (!file_exists(runnable_code_file)) {
    message(str_glue("{runnable_code_file} for {revdep}: no such file - skipping"))
    return(NULL)
  }

  coverage_code <- str_glue("
    df <- rapr::run_all('{revdep}', '{runnable_code_file}')
    df <- cbind(data.frame(package='{revdep}', row.names=FALSE, stringsAsFactors=FALSE), df)
    write.table(
      df,
      '{REVDEP_RUNS_FILE}',
      sep=',',
      qmethod='double',
      append=TRUE,
      col.names=!file.exists('{REVDEP_RUNS_FILE}'),
      row.names=FALSE
    )
  ")

  tryCatch({
    ## pc <- rapr::package_coverage(package_path, tmp_lib, type="none", code=coverage_code, quiet=FALSE)
    pc <- callr::r_copycat(
      function(...) rapr::package_coverage(...),
      list(
        package_path,
        tmp_lib=tmp_lib,
        type="none",
        code=coverage_code,
        quiet=FALSE
      ),
      show=T,
      timeout=REVDEP_RUN_TIMEOUT
    )

    output <- gen_output_filename(revdep)
    saveRDS(pc, output)
    output
  }, error=function(e) {
    message(str_glue("{runnable_code_file} for {revdep}: failed - skipping: {e$message}"))
    output <- paste0(gen_output_filename(revdep), ".fail")
    saveRDS(list(revdep=revdep, error=e), output)
    NULL
  })
}

gen_output_filename <- function(revdep) {
  str_glue("revdep-coverage-raw-{revdep}.RDS")
}

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 2) {
  stop("Usage: package-revdep-coverage.R <path/to/package/source> <path/to/extracted-code> [<max-revdeps>]")
}

package_path <- args[1]
stopifnot(dir_exists(package_path))

runnable_code_path <- args[2]
stopifnot(dir_exists(runnable_code_path))

# option handy for manual testing
max_revdeps <- if (length(args) == 3) {
  as.integer(args[3])
} else {
  Inf
}

package <- basename(package_path)

revdeps <- unlist(
  tools::package_dependencies(
    package,
    which=WHICH_DEPENDENCIES,
    reverse=TRUE,
    recursive=FALSE
  )
)

if (!is.infinite(max_revdeps)) {
  revdeps <- sample(revdeps, max_revdeps, TRUE)
}

tmp_lib <- path(getwd(), "tmp_lib")
if (dir_exists(tmp_lib)) {
  message(tmp_lib, ": tmp_lib exists")
}

cat("tmp_lib: ", tmp_lib, "\n")
cat("libPaths: ", str_c(.libPaths(), col=":"), "\n")
cat("repos: ", getOption("repos"), "\n")

for (revdep in revdeps) {
  output <- gen_output_filename(revdep)
  if (file_exists(output)) {
    cat("*** ", revdep, " already run, skipping...\n")
    next
  }

  fail_output <- paste0(gen_output_filename(revdep), ".fail")
  if (file_exists(fail_output)) {
    cat("*** ", revdep, " already run and failed, skipping...\n")
    next
  }

  coverage_one(revdep, tmp_lib=tmp_lib)
}

trace_files <-
  revdeps %>%
  map(gen_output_filename) %>%
  keep(file_exists) %>%
  as.character()

pc <- covr:::merge_coverage(trace_files)

pc_line <- tally_coverage(pc, by="line")
write_csv(pc_line, "revdep-coverage-details-line.csv")

pc_expr <- tally_coverage(pc, by="expression")
write_csv(pc_expr, "revdep-coverage-details-expr.csv")

revdep_coverage_line <- percent_coverage(pc, by="line")
revdep_coverage_expression <- percent_coverage(pc, by="expression")

df <- tibble(
  revdep_coverage_expression,
  revdep_coverage_line,
  n_revdeps=length(revdeps),
  n_ran_revdeps=length(trace_files)
)

write_csv(df, "revdep-coverage.csv")
