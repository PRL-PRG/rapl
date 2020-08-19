#' @importFrom readr read_csv
#' @importFrom tibble add_column
#' @export
cloc <- function(path, cloc_bin="cloc") {
  sloc <- system2(cloc_bin, c("--follow-links", "-q", "--csv", path), stdout = TRUE)[-1]
  if (length(sloc) > 1) {
    sloc[1] <- "files,language,blank,comment,code"
    df <- read_csv(sloc, col_types="cciii")
    df <- add_column(df, path=path, .before="files")
    df
  } else {
    NULL
  }
}

# from: https://stackoverflow.com/a/15373917
#' @export
current_script <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  arg_to_match <- "^--file="
  match <- grep(arg_to_match, args)
  if (length(match) > 0) {
    # in Rscript
    normalizePath(sub(arg_to_match, "", args[match]))
  } else {
    # in source
    file <- sys.frames()[[1]]$ofile
    if (!is.null(file)) {
      normalizePath(file)
    } else {
      NULL
    }
  }
}

#' @importFrom codetools findGlobals
#' @export
is_s3_dispatch_method <- function(fun) {
  globals <- codetools::findGlobals(fun, merge = FALSE)$functions
  any(globals == "UseMethod" | globals == "NextMethod")
}
