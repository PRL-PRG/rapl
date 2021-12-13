#' @importFrom callr r
#' @return The paths to `packages`. This might be a subset of
#' the requested packages, if some packages failed to install.
#'
#' @export
install_cran_packages <- function(packages, lib_dir = NULL, r_home = R.home(),
                                  dest_dir = NULL, mirror = "https://cloud.r-project.org/", force = FALSE,
                                  dependencies = TRUE,
                                  install_opts = c("--example", "--install-tests", "--with-keep.source", "--no-multiarch"),
                                  n_cpus = floor(.9 * parallel::detectCores())) {
  options(repos = mirror)

  requested <- if (is.null(packages)) {
    available.packages()[, 1]
  } else {
    unique(trimws(packages, "both"))
  }

  if (force) {
    missing <- packages
  } else {
    installed <- installed.packages(lib.loc = lib_dir)
    missing <- setdiff(requested, installed[, 1])
  }

  if (length(missing) > 0) {
    message("Installing ", length(missing), " packages")
    message("- mirror: ", mirror)
    message("- library dir: ", lib_dir)
    message("- dest dir: ", dest_dir)
    message("- R home: ", r_home)

    if (!is.null(dest_dir) && !dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE)
    if (!is.null(lib_dir) && !dir.exists(lib_dir)) dir.create(lib_dir, recursive = TRUE)

    r_envir <- c(
      "_R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_" = Sys.getenv("_R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_", "5000")
    )

    callr::r(
      function(pkgs, lib_dir, dest_dir, dependencies, install_opts, n_cpus) {
        install.packages(
          pkgs,
          lib = lib_dir,
          destdir = dest_dir,
          dependencies = dependencies,
          INSTALL_opts = install_opts,
          Ncpus = n_cpus
        )
      },
      list(missing, lib_dir, dest_dir, dependencies, install_opts, n_cpus),
      arch = file.path(r_home, "bin", "R"),
      show = TRUE,
      libpath = lib_dir,
      env = r_envir
    )

    installed <- installed.packages(lib.loc = lib_dir)
  }

  info <- installed[installed[, "Package"] %in% packages, drop=FALSE, ]

  tibble(
    package = info[, "Package"],
    version = info[, "Version"],
    dir = file.path(info[, "LibPath"], info[, "Package"])
  )
}
