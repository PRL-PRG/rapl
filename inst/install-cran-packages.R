#!/usr/bin/env Rscript

install_cran_packages <- function(mirror,
                                  lib=NULL,
                                  destdir=NULL,
                                  from=NULL) {
  options(repos=mirror)

  output_file <- file.path(lib, "packages-installed.csv")
  if (file.exists(output_file)) {
    unlink(output_file)
  }

  requested <- if (is.null(from)) {
    available.packages()[,1]
  } else {
    unique(trimws(readLines(from), "both"))
  }

  installed <- installed.packages(lib.loc=lib)[,1]
  missing <- setdiff(requested, installed)

  message("Installing ", length(missing), " packages from ", mirror, " into ", lib)

  if (length(missing) > 0) {
    if (!is.null(destdir) && !dir.exists(destdir)) dir.create(destdir, recursive=TRUE)
    if (!is.null(lib) && !dir.exists(lib)) dir.create(lib, recursive=TRUE)
  }

  # set package installation timeout
  Sys.setenv(
    _R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_=Sys.getenv("_R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_", "5000")
  )

  res <- install.packages(
    missing,
    lib=lib,
    destdir=destdir,
    dependencies=TRUE,
    INSTALL_opts=c("--example", "--install-tests", "--with-keep.source", "--no-multiarch"),
    Ncpus=floor(.5*parallel::detectCores())
  )


  write.csv(
    as.data.frame(res, make.names=FALSE),
    output_file,
    row.names=FALSE,
    append=file.exists(output_file)
  )
}
