#!/usr/bin/env Rscript

library(optparse)
library(runr)
library(stringr)

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

cmd_revdeps <- function(path, cran_mirror) {
  package <- basename(path)

  options(repos=cran_mirror)

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

cmd_s3 <- function(path) {
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

TYPES <- c("metadata", "sloc", "revdeps", "functions", "s3")

option_list <- list(
  make_option(
    c("--cran-mirror"), default="https://cran.r-project.org",
    help="Which mirror to use [default: %default]",
    dest="cran_mirror", metavar="URL"
  ),
  make_option(
    c("--types"), default=paste0(TYPES, collapse=","),
    help="Which metadata to generate [default: %default]",
    dest="types", metavar="TYPE"
  )
)

opt_parser <- OptionParser(option_list=option_list)
opts <- parse_args(opt_parser, positional_arguments=1)

package_path <- opts$args[1]

types <- str_split(opts$options$types, ",")[[1]]
types <- match.arg(types, choices=TYPES, several.ok=TRUE)

if ("metadata" %in% types) {
  cmd_metadata(package_path)
}

if ("sloc" %in% types) {
  cmd_sloc(package_path)
}

if ("revdeps" %in% types) {
  cmd_revdeps(package_path, opts$options$cran_mirror)
}

if ("functions" %in% types) {
  cmd_functions(package_path)
}

if ("s3" %in% types) {
  cmd_s3(package_path)
}
