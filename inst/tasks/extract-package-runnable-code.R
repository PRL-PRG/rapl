#!/usr/bin/env Rscript

options(error = function() { traceback(3); q(status=1) })

library(glue)
library(purrr)
library(rapr)
library(readr)
library(tibble)

OUTPUT_FILE <- "runnable-code.csv"
METADATA_FILE <- "runnable-code-metadata.csv"
CODE_FILE <- "run-all.R"

# TODO: use fs and put to rapr
extract_package_code <- function(pkg, pkg_dir=find.package(pkg),
                                 types=c("examples", "tests", "vignettes", "all"),
                                 output_dir,
                                 filter=NULL) {
  
  stopifnot(is.character(pkg) && length(pkg) == 1)
  stopifnot(dir.exists(pkg_dir))
  stopifnot(is.null(filter) || is.character(filter))
  
  if ("all" %in% types) {
    types <- c("examples", "tests", "vignettes")
  }
  
  types <- match.arg(types, c("examples", "tests", "vignettes"), several.ok=TRUE)
  
  # so the output list is named
  names(types) <- types
  
  lapply(types, function(type) {
    fun <- switch(
      type,
      examples=extract_package_examples,
      tests=extract_package_tests,
      vignettes=extract_package_vignettes
    )
    
    # each type has its own folder not to clash with one another
    output <- file.path(output_dir, type)
    stopifnot(dir.exists(output) || dir.create(output, recursive=TRUE))
    
    files <- fun(pkg, pkg_dir, output_dir=output)
    
    if (!is.null(filter)) {
      files <- files[grepl(filter, tools::file_path_sans_ext(files))]
    }
    
    names(files) <- NULL
    files
  })
}

extract_package_examples <- function(pkg, pkg_dir, output_dir) {
  db <- tryCatch({
    tools::Rd_db(basename(pkg_dir), dir=dirname(pkg_dir))
  }, error=function(e) {
    c()
  })
  
  if (!length(db)) {
    return(character())
  }
  
  files <- names(db)
  
  examples <- sapply(files, function(x) {
    f <- file.path(output_dir, paste0(basename(x), ".R"))
    tools::Rd2ex(db[[x]], f, defines=NULL)
    
    if (!file.exists(f)) {
      message("Rd file `", x, "' does not contain any code to be run")
      NA
    } else {
      # prepend the file with library call
      txt <- c(
        paste0("library(", pkg, ")"),
        "",
        "",
        readLines(f)
      )
      writeLines(txt, f)
      f
    }
  })
  
  na.omit(examples)
}

extract_package_tests <- function(pkg, pkg_dir, output_dir) {
  test_dir <- file.path(pkg_dir, "tests")
  
  if (!dir.exists(test_dir)) {
    return(character())
  }
  
  files <- Sys.glob(file.path(test_dir, "*"))
  file.copy(files, output_dir, recursive=TRUE)
  
  tests <- file.path(output_dir, basename(files))
  tests <- tests[!dir.exists(tests)]
  tests <- tests[grepl("\\.R$", tests)]
  
  tests
}

extract_package_vignettes <- function(pkg, pkg_dir, output_dir) {
  vinfo <- tools::pkgVignettes(pkg, source=T)
  if (length(vinfo$docs) == 0) {
    return(character())
  }
  
  if (length(vinfo$sources) == 0) {
    # so far no sources. The following should generate them if there are any
    # sources in the R code. It might actually run the vignettes as well.
    # That is a pity, but there is no way to tell it not to (the tangle is
    # needed to it extracts the R code)
    tools::checkVignettes(pkg, pkg_dir, tangle=TRUE, weave=FALSE, workdir="src")
  }
  
  # check if there are some sources
  vinfo <- tools::pkgVignettes(pkg, source=T)
  files <- as.character(unlist(vinfo$sources))
  if (length(files) == 0) {
    return(character())
  }
  
  file.copy(files, to=output_dir)
  vignettes <- file.path(output_dir, basename(files))
  
  vignettes
}

args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1) {
  stop("Missing a path to the package source")
}

package_path <- args[1]
package <- basename(package_path)

files <- extract_package_code(package, package_path, types="all", output_dir=".")
df <- imap_dfr(files, ~tibble(path=.x, type=.y))

write_csv(df, OUTPUT_FILE)

df_sloc <- map_dfr(c("examples", "tests", "vignettes"), ~cloc(.))
write_csv(df_sloc, METADATA_FILE)

