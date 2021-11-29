#!/usr/bin/env Rscript

install_cran_packages <- function(from, libdir, destdir, mirror, force) {
  options(repos=mirror)

  if (!is.null(destdir)) {
    if (!dir.exists(destdir)) {
      dir.create(destdir, recursive=TRUE)
    }
  }

  requested <- if (is.null(from)) {
    available.packages()[, 1]
  } else {
    packages
  }

  if (force) {
    missing <- packages
  } else {
    installed <- installed.packages(lib.loc=libdir)[, 1]
    missing <- setdiff(requested, installed)
  }

  message("Installing ", length(missing), " packages from ", mirror, " into ", libdir, " sources ", destdir)

  if (length(missing) > 0) {
    if (!is.null(destdir) && !dir.exists(destdir)) dir.create(destdir, recursive=TRUE)
    if (!is.null(libdir) && !dir.exists(libdir)) dir.create(libdir, recursive=TRUE)
  }

  # set package installation timeout
  Sys.setenv(
    `_R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_`=Sys.getenv("_R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_", "5000")
  )

  res <- install.packages(
    missing,
    lib=libdir,
    destdir=destdir,
    dependencies=TRUE,
    INSTALL_opts=c("--example", "--install-tests", "--with-keep.source", "--no-multiarch"),
    Ncpus=floor(.9*parallel::detectCores())
  )

  invisible(res)
}

args <- commandArgs(trailingOnly=TRUE)
libdir <- NULL
destdir <- NULL
packages <- character()
mirror <- "http://cran.r-project.org"
force <- FALSE

shift <- function(n) {
  if (n > 0) {
    idx <- -1 * seq(n)
    args <<- args[idx]
  }
}

print_help <- function() {
  cat(
    "Usage: install-cran-packages.R [-m URL] [-l DIR] [-d DIR] [<packages>]",
    "",
    "options:",
    "  -m URL \t CRAN mirror to use",
    "  -l DIR \t where to install (defaults to R_LIBS)",
    "  -d DIR \t where to download sources (defaults to none)",
    "  -f     \t force installation",
    "",
    "packages:",
    "  - either a file with one package per line",
    "  - space separated package names",
    "  - nothing meaning installing all available packages",
    sep="\n"
  )
}

while (length(args) > 0) {
  if (args[1] == "-l") {
    stopifnot(length(args) >= 2)
    libdir <- args[2]
    shift(2)
  } else if (args[1] == "-d") {
    stopifnot(length(args) >= 2)
    destdir <- normalizePath(args[2], mustWork = TRUE)
    shift(2)
  } else if (args[1] == "-m") {
    stopifnot(length(args) >= 2)
    mirror <- args[2]
    shift(2)
  } else if (args[1] == "-f") {
    force <- TRUE
    shift(1)
  } else if (args[1] == "--help") {
    print_help()
    q(save = "no", status=1)
  } else {
    packages <- append(packages, args[1])
    shift(1)
  }
}

if (length(packages) == 1 && file.exists(packages)) {
  packages <- trimws(readLines(packages), "both")
  packages <- packages[nchar(packages) > 0]
}

install_cran_packages(from=packages, libdir=libdir, destdir=destdir, mirror=mirror, force=force)
