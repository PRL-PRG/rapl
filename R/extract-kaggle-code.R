#' @importFrom stringr str_ends
#' @importFrom knitr purl
#' @export
extract_kaggle_code <- function(source_file, target_file, quiet=TRUE) {
  if (str_ends(source_file, "\\.[rR]")) {
    file.copy(source_file, target_file, overwrite=TRUE)
  } else if (str_ends(source_file, "\\.Rmd")) {
    knitr::purl(source_file, target_file, quiet=quiet)
  } else if (str_ends(source_file, "\\.irnb") || str_ends(source_file, "\\.ipynb")) {
    tmp <- tempfile(fileext = ".Rmd")
    rmarkdown:::convert_ipynb(source_file, tmp)
    extract_kaggle_code(tmp, target_file)
  } else {
    stop("Unsupported file type: ", source_file)
  }

  target_file
}
