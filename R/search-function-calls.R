#' @param expr is the expression in which run the search
#' @param functions is a string vector in the form of package:::function_name
#' @importFrom stringr str_replace str_c
#' @export
#'
search_function_calls <- function(expr, functions) {
  functions_names <- str_replace(functions, "^.*:::", "")

  is_interesting_call <- function(call) {
    if (is.call(call)) {
      fun <- call[[1L]]

      if (is.call(fun)) {
        if (length(fun) == 3L && (as.character(fun[[1L]]) %in% c("::", ":::"))) {
          fqn <- str_c(as.character(fun[-1L]), collapse=":::")
          fqn %in% functions
        } else {
          is_interesting_call(fun[[1L]])
        }
      } else {
        is_interesting_call(fun)
      }
    } else {
      as.character(call) %in% functions_names
    }
  }

  loop <- function(node) {
    if (is.atomic(node) || is.name(node)) {
      NULL
    } else {
      calls <- unlist(lapply(node, loop))

      if (is.call(node) && is_interesting_call(node)) {
        calls <- append(calls, node)
      }
      calls
    }
  }

  loop(expr)
}
