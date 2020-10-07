#' @importFrom readr read_csv
#' @importFrom tibble add_column
#' @importFrom dplyr filter
#' @export
cloc <- function(path, by_file=FALSE, r_only=FALSE, cloc_bin="cloc") {
  args <- c(
    "--follow-links",
    "-q",
    "--csv",
    if (by_file) "--by-file" else NULL,
    path
  )

  sloc <- system2(cloc_bin, args, stdout = TRUE)[-1]
 
  if (length(sloc) > 1) {
    sloc[1] <- str_replace(sloc[1], ',"github.com/AlDanial/cloc.*', "")
    df <- read_csv(sloc, col_types="cciii")

    if (!by_file) {
      df <- add_column(df, path=path, .before="files")
    }

    if (r_only) {
      df <- filter(df, language=="R")
    }

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
