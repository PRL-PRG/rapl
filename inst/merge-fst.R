#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(rapr))
library(tibble)
library(pbapply)

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 1) {
  message("Usage: merge-fst.R <dir> <file1> [... <fileN>]")
  q(status=1)
}

run_dir <- args[1]
if (!dir.exists(run_dir)) {
  stop(run_dir, ": no such a directory")
}

file_names <- args[-1]

cat("Merging fst files:\n\n")

for (file_name in file_names) {

  files <- list.files(run_dir, pattern=paste0("^", file_name, "$"), full.name=TRUE, recursive=TRUE)
  merged_file <- file.path(run_dir, file_name)
  merged_errors_file <- file.path(
    run_dir,
    paste0(tools::file_path_sans_ext(file_name), "-errors.", tools::file_ext(file_name))
  )

  pb <- progress::progress_bar$new(
    format="reading [:bar] :current/:total :percent, :eta",
    total=length(files),
    clear=FALSE,
    width=80
  )

  res <- purrr::map(files, .progress=TRUE, ~tryCatch({
      cat("\n- ", ., "\n")
      tmp <- fst::read_fst(.)
      if (!is.data.frame(tmp)) stop("Not a data frame: ", typeof(tmp))
      add_column(tmp, file=., .before=1)
    }, error=function(e) {
      tmp <- tibble(file=., error=e$message)
      attr(tmp, "error") <- TRUE
      tmp
    }, finally= {
      pb$tick()
    })
  )

  cat("\nFiltering...\n")
  errors <- purrr::map_lgl(res, ~isTRUE(attr(., "error")), .progress=TRUE)
  data_df <- purrr::map_dfr(res[!errors], identity)
  errors_df <- purrr::map_df(res[errors], identity)

  if (nrow(data_df) > 0) {
    cat("Saving ", nrow(data_df)," records into: ", merged_file, " ... ")
    if (file.exists(merged_file)) {
      unlink(merged_file)
    }
    time <- system.time(fst::write_fst(data_df, merged_file))
    cat("done (in ", time["elapsed"], ")\n")
  }

  if (nrow(errors_df) > 0) {
    cat("Saving ", nrow(errors_df)," errors into: ", merged_errors_file, " ... ")

    if (file.exists(merged_errors_file)) {
      unlink(merged_errors_file)
    }
    time <- system.time(fst::write_fst(errors_df, merged_errors_file))
    cat("done (in ", time["elapsed"], ")\n")
  }
}
