#' @importFrom dplyr group_by top_n ungroup
#' @importFrom fs dir_ls
#' @importFrom purrr map_dfr
#' @importFrom magrittr %>%
normalize_parallel_files <- function(dir, file, read_f, write_f) {
  logs <- dir_ls(dir, regexp=paste0(file, ".*"))

  if (length(logs) == 0) {
    return(NULL)
  }

  df <- suppressWarnings(map_dfr(logs, read_f))

  new <- group_by(df, Command) %>% top_n(1, Starttime) %>% ungroup()
  write_f(new, file)
}

#' @importFrom readr read_tsv write_tsv
#' @export
normalize_parallel_logs <- function(dir, file) {
  normalize_parallel_files(dir, file, readr::read_tsv, readr::write_tsv)
}

#' @importFrom readr read_csv write_csv
#' @export
normalize_parallel_results <- function(dir, file) {
  normalize_parallel_files(dir, file, readr::read_csv, readr::write_csv)
}
