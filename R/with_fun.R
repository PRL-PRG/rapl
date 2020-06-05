#' @importFrom injectr inject_code
with_capturing_calls <- function(funs, code) {
  if (is.function(funs)) {
    funs <- list(funs)
  }

  old_bodies <- lapply(funs, body)

  inject_code <- substitute({
    if (isTRUE(getOption(".tracing"))) {
      options(.tracing=FALSE)
      (function(call) {
        call <- as.list(call)
        fun <- as.character(call[[1]])
        args <- call[-1]
        retval <- returnValue()

        st <- sys.calls()
        st_start <- which(sapply(st, function(x) x[[1]] == "with_capturing_calls"))
        # +1 for with_capturing_calls
        # +1 for tryCatch
        # +1 for tryCatchList
        # +1 for force - FIXME do we need it?
        st_start <- st_start+4
        st_end <- length(st)
        # -1 for the actual eval
        # -1 for this function
        st_end <- length(st)-2
        # just in case
        if (st_start > st_end || st_end < st_start) {
          st_start <- 1
          st_end <- length(st)
        }
        st <- st[st_start:st_end]
        st <- rev(st)

        # TODO: this should be passed in as an argument
        resolve_parse <- function(call) {
          if (call$fun %in% c("eval", "evalq")) {
            expr <- call$args$expr
            if (is.call(expr)
                && identical(expr[[1]], as.name("parse"))) {
              tryCatch({
                call$args$expr <- eval.parent(expr, 3)
                call$parsed_call <- expr
              }, error=function(e) {
                call$parsed_call <- NULL
              })
            }
          }
          call
        }
       
        value <- list(
          fun=fun,
          args=args,
          retval=retval,
          st=st
        )

        value <- resolve_parse(value)
       
        capture <- getOption(".capture")
        n <- length(capture)
        assign(as.character(n+1), value, envir=capture)
      })(match.call())
      options(.tracing=TRUE)
    }
  })

  withr::local_options(list(.capture=new.env(parent=emptyenv())))

  for (f in funs) {
    injectr::inject_code(inject_code, f, "onexit")
  }

  tryCatch({
    options(.tracing=TRUE)
    force(code)
  }, finally={
    options(.tracing=FALSE)
    for (idx in seq_along(funs)) {
      injectr:::reassign_function_body(funs[[idx]], old_bodies[[idx]])
    }
  })

  ret <- as.list(getOption(".capture"))
  names(ret) <- NULL
  ret
}

#' @export
with_capturing_calls_to_file <- function(funs, file, code) {
  calls <- with_capturing_calls(funs, code)
  if (!is.null(calls) && length(calls) > 0) {
    saveRDS(calls, file)
  }
}
