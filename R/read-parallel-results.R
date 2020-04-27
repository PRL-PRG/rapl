#' @importFrom dplyr left_join bind_cols
#' @importFrom fs dir_ls path
#' @importFrom purrr map_dfr
#' @importFrom stringr str_c
#' @importFrom tibble tibble as_tibble
#' @export
#'
read_parallel_results <- function(path, stdout=TRUE, stderr=TRUE) {
  log <- read_parallel_log(path)
  seq <- read_parallel_seq(path)
  # It is important that the seq with log and not the other way around.
  # The reason is that log could have some duplication due to
  # multiple run of the same job. Each job gets a unique seq ID stored
  # in the log, but since we use the job name as a directory name, running
  # the same job will have two different seqs, but only one will be kept
  # in the output directory
  df <- left_join(seq, log, by="seq")

  read_extras <- function(name) {
    process_row <- function(x) {
      if (is.character(x) && length(x) == 0) {
        x <- as.character(NA)
      }

      row <- if (inherits(x, "error")) {
        list(as.character(NA), x[[3]])
      } else if (inherits(x, "condition")) {
        list(as.character(NA), x$message)
      } else {
        list(str_c(x, collapse="\n"), as.character(NA))
      }

      names(row) <- c(name, str_c(name, "_error"))
      as_tibble(row)
    }

    files <- path(df$path, name)
    content <- read_files(df$job, files)
    map_dfr(content, process_row)
  }

  extras <- c("stdout", "stderr")
  extras <- extras[c(stdout, stderr)]
  for (e in extras) df <- bind_cols(df, read_extras(e))
  df
}

#' @importFrom purrr map2 discard keep
#' @importFrom readr read_lines
#' @importFrom stringr str_glue
#' @importFrom progress progress_bar
#' @export
#'
read_files <- function(jobs, files,
                       readf=read_lines,
                       mapf=function(job, x) x,
                       mapf_error=function(...) structure(list(...), class="error"),
                       reducef=identity,
                       quiet=TRUE) {

  stopifnot(length(jobs) == length(files))

  pb <- progress::progress_bar$new(
    format="reading :file [:bar] :current/:total :percent, :eta",
    total=length(jobs),
    clear=FALSE,
    width=80
  )

  read_one <- function(job, file) {
    tryCatch({
      mapf(job, readf(file))
    }, error=function(e) {
      msg <- str_glue("[{job}] unable to read: {file}: {e$message}")

      if (!quiet) message(msg)

      mapf_error(job, file, e$message)
    }, finally={
      if (is.na(file)) file <- "NA"
      else if (is.null(file)) file <- "NULL"
      else file <- basename(file)
      pb$tick(tokens=list(file=file))
    })
  }

  results <- map2(jobs, files, read_one)
  names(results) <- files
  reducef(results)
}

#' @importFrom dplyr bind_rows
#' @importFrom fs dir_ls
#' @importFrom purrr map2_dfr keep
#' @export
#'
read_parallel_seq <- function(path, quiet=TRUE) {
  files <- dir_ls(path, regex="/seq$", recurse=1)
  jobs <- basename(dirname(files))

  read_files(
    jobs,
    files,
    mapf=function(job, x) tibble(job, path=file.path(path, job), seq=as.integer(x)),
    mapf_error=function(...) NULL,
    reducef=bind_rows,
    quiet=quiet
  )
}
