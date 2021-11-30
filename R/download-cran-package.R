#' @importFrom remotes download_version
#' @export
download_cran_package_source <- function(package, version = NULL, dest_dir = NULL,
                                  repos = getOption("repos")) {
  archive <- remotes::download_version(package, version, repos)

  utils::untar(archive, exdir = dest_dir)

  dir <- file.path(dest_dir, package)
  if (!dir.exists(dir)) {
    stop("Expected extracted sources in ", dir, " but it does not exist")
  }

  dir
}
