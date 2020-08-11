#!/usr/bin/env Rscript

install_cran_packages <- function(mirror,
                                  lib=NULL,
                                  destdir=NULL,
                                  from=NULL) {
  options(repos=mirror)

  requested <- if (is.null(from)) {
    available.packages()[,1]
  } else {
    unique(trimws(readLines(from), "both"))
  }

  installed <- installed.packages(lib.loc=lib)[,1]
  missing <- setdiff(requested, installed)

  message("Installing ", length(missing), " packages from $mirror into $libs")

  if (length(missing) > 0) {
    if (!dir.exists(destdir)) dir.create(destdir, recursive=TRUE)
    if (!dir.exists(lib)) dir.create(lib, recursive=TRUE)
  }

  res <- install.packages(
    missing,
    lib=lib,
    destdir=destdir,
    dependencies=TRUE,
    INSTALL_opts=c("--example", "--install-tests", "--with-keep.source", "--no-multiarch"),
    Ncpus=parallel::detectCores()
  )

  output_file <- file.path(lib, "packages-installed.csv")

  write.csv(
    as.data.frame(res, make.names=FALSE),
    output_file,
    row.names=FALSE,
    append=file.exists(output_file)
  )
}

show_help <- function() {
  cat(
    "Usage: install-cran-packages.R [-d PATH] [-f FILE] [-l PATH] [-m HOST]",
    "",
    "where:",
    "",
    "  -d PATH      where to keep downloaded sources (optional)",
    "  -f FILE      list of packages (defaults to all avalable packages)",
    "  -l PATH      where to install the packages (defaults to $def_lib)",
    "  -m HOST      mirror to use (defaults to $def_mirror)",
    sep="\n"
  )
}

