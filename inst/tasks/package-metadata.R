#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(runr))
suppressPackageStartupMessages(library(stringr))

METADATA_FILE <- "metadata.csv"
SLOC_FILE <- "sloc.csv"
REVDEPS_FILE <- "revdeps.csv"
FUNCTIONS_FILE <- "functions.csv"
S3_CLASSES_FILE <- "s3-classes.csv"

cmd_metadata <- function(path) {
  package_name <- basename(path)
  pkg <- packageDescription(package_name)
  loadable <- tryCatch({
    require(package_name, quietly=TRUE, warn.conflicts=FALSE, character.only=TRUE)
  }, error=function(e) {
    FALSE
  })

  tryCatch({
    size <- system2("du", c("-sb", path), stdout = TRUE)
    size <- stringr::str_replace(size, "(\\d+).*", "\\1")
    size <- as.double(size)

    df <- data.frame(
      name=package_name,
      version=pkg$Version,
      title=pkg$Title,
      size,
      loadable
    )

    write.csv(df, METADATA_FILE, row.names=FALSE)
  }, error=function(e) {
    message("Unable to get package size: ", e$message)
  })
}

cmd_sloc <- function(path) {
  paths <- file.path(path, c("R", "src", "inst", "tests", "vignettes"))
  paths <- paths[dir.exists(paths)]

  df_list <- lapply(paths, cloc)
  df <- do.call(rbind, df_list)
  df$path <- basename(df$path)

  write.csv(df, SLOC_FILE, row.names=FALSE)
}

cmd_revdeps <- function(path) {
  package <- basename(path)

  mirror <- Sys.getenv(
    "CRAN_MIRROR_LOCAL_URL",
    Sys.getenv("CRAN_MIRROR_URL", "https://cran.r-project.org")
  )
  options(repos=mirror)

  revdeps <- unlist(
    tools::package_dependencies(
      package,
      which=c("Depends", "Imports"),
      reverse=TRUE,
      recursive=FALSE
    ),
    use.names=FALSE
  )

  revdeps <- unique(revdeps)

  df <- data.frame(revdep=revdeps)

  write.csv(df, REVDEPS_FILE, row.names=FALSE)
}

is_s3 <- function(fun) {
  globals <- codetools::findGlobals(fun, merge = FALSE)$functions
  any(globals == "UseMethod" | globals == "NextMethod")
}

cmd_functions <- function(path) {
  package <- basename(path)

  args <- commandArgs(trailingOnly=TRUE)
  if (length(args) != 1) {
    stop("Missing a path to the package source")
  }

  package <- basename(args[1])

  ns <- getNamespace(package)
  exports <- getNamespaceExports(package)
  bindings <- ls(env=ns, all.names=TRUE)

  function_bindings <- sapply(bindings, USE.NAMES=FALSE, function(x) {
    f <- get0(x, envir=ns)
    if (!is.function(f)) NA else x
  })
  function_bindings <- na.omit(function_bindings)
  functions <- lapply(function_bindings, get0, envir=ns)

  params <- lapply(functions, function(x) names(formals(x)))

  s3_methods <- NULL
  if (exists(".__NAMESPACE__.", envir=ns)) {
    s3_methods <- ns$.__NAMESPACE__.$S3methods[,3]
  }

  if (is.null(s3_methods)) {
    s3_methods <- character(0)
  }

  is_s3_dispatch <- sapply(functions, USE.NAMES=FALSE, is_s3_dispatch_method)
  is_s3_method <- function_bindings %in% s3_methods

  params <- sapply(params, USE.NAMES=FALSE, paste0, collapse=";")
  exported <- function_bindings %in% exports

  df <- data.frame(
    fun=function_bindings,
    exported,
    is_s3_dispatch,
    is_s3_method,
    params
  )

  write.csv(df, FUNCTIONS_FILE, row.names=FALSE)
}

cmd_s3_classes <- function(path) {
  package <- basename(path)
  ns <- getNamespace(package)

  classes <-  if (exists(".S3MethodsClasses", envir=ns)) {
    cs <- ns$.S3MethodsClasses
    ls(envir=cs, all.names=T)
  } else {
    character(0)
  }

  df <- data.frame(class=classes)

  write.csv(df, S3_CLASSES_FILE, row.names=FALSE)
}

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Usage: package-metadata.R <path to package source>")
}

package_path <- args[1]

cmds <- list(
  cmd_metadata,
  cmd_sloc,
  cmd_revdeps,
  cmd_functions,
  cmd_s3_classes
)

for (cmd in cmds) {
  cmd(package_path)
}
