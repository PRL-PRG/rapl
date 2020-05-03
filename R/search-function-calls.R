#' @param expr is the expression in which run the search
#' @param functions is a string vector in the form of package:::function_name
#' @importFrom stringr str_replace str_c
#' @export
#'
search_function_calls <- function(expr, functions, srcref=NULL) {
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

  loop <- function(node, srcref=NULL) {
    if (is.atomic(node) || is.name(node)) {
      NULL
    } else {
      nested_srcref <- attr(node, "srcref")
      if (length(nested_srcref) != length(node)) {
        nested_srcref <- map(seq(length(node)), ~NULL)
      }

      calls <- unlist(map2(node, nested_srcref, loop))

      if (is.call(node) && is_interesting_call(node)) {
        attr(node, "srcref") <- srcref
        calls <- append(calls, node)
      }
      calls
    }
  }

  loop(expr, srcref)
}
