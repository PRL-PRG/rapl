#!/usr/bin/env Rscript

library(parallel)

download_file <- function(url, destfile) {
  tryCatch(download.file(url, destfile), error=function(e) -1)
}

download_package <- function(destdir, package, version) {
  filename <- paste0(package, "_", version, ".tar.gz")

  mirror <- "https://cloud.r-project.org"
  base_url <- paste0(mirror, "/src/contrib")
  default_url <- paste0(base_url, "/", filename)
  archive_url <- paste0(base_url, "/00Archive/", package, "/", filename)

  destfile <- file.path(destdir, filename)
  if (download_file(default_url, destfile) == 0) {
    default_url
  } else if (download_file(archive_url, destfile) == 0) {
    archive_url
  } else {
    NA
  }
}

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 2) {
  stop("Usage: <destination> <file1>")
}

local_cran <- args[1]

if (!dir.exists(local_cran)) dir.create(local_cran, recursive=TRUE)

packages_file <- args[2]

if (packages_file == "-") packages_file <- "stdin"

packages <- read.table(file(packages_file), header=FALSE)
packages <- strsplit(readLines(file(packages_file)), " ")

res <- mclapply(
  packages,
  function(x) download_package(local_cran, x[1], x[2]),
  mc.cores=4
)

res <- unlist(res)

tools::write_PACKAGES(local_cran, type="source", verbose=T)

missing_packages_lgl <- is.na(res)

if (any(missing_packages_lgl)) {
  cat("Missing packages: \n")
  cat(
    patse0(packages[missing_packages_lgl], "_", versions[missing_packages_lgl]),
    sep="\n"
  )
}

writeLines(res[!missing_packages_lgl], "CRAN-packages-urls.txt")
