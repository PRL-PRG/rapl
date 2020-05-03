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

#' @export
current_script <- function() {
  cmdArgs <- commandArgs(trailingOnly = FALSE)
  match <- grep("--file=", cmdArgs)
  if (length(match) > 0) {
    # in Rscript
    normalizePath(sub(needle, "", cmdArgs[match]))
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
