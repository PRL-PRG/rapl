library(lightr)

#' @importFrom injectr inject_code
with_capturing_calls <- function(funs, code) {

    call_exit_callback <- function(context, application, package, func, call) {
        call_expression <- get_expression(call)
        fun_name <- get_name(func)
        parameters <- get_parameters(call)
        expressions <- list()
        values <- list()
        for(parameter in parameters) {
            arguments <- get_arguments(parameter)
            argument <- arguments[[1]]
            expressions[[get_name(parameter)]] <- get_expression(argument)
        }

        call_stack <- get_call_stack(application)

        print(call_stack)

        return_value <- if(is_successful(call)) get_result(call) else NULL

        ## resolve parse
        if (fun_name %in% c("eval", "evalq")) {
            expr_arg <- get_arguments(get_parameters(call)[[1]])[[1]]
            eval_expr <- get_expression(expr_arg)

            parse_value <- if (is.call(eval_expr) &&
                               identical(eval_expr[[1]], as.name("parse"))) {
                tryCatch({
                    eval.parent(eval_expr, 3)
                }, error=function(e) {
                    NULL
                })
            }
        }

        st <- sys.calls()
        st_start <- which(sapply(st, function(x) identical(x[[1]], as.name("with_capturing_calls"))))
        # +1 for with_capturing_calls
        # +1 for tryCatch
        # +1 for tryCatchList
                                        # +1 for force - FIXME do we need it?
        st_start <- st_start+3
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

        value <- list(
            fun=fun_name,
            args=expressions,
            retval=return_value,
            st=st,
            parse_value = parse_value
        )

        env <- get_data(context)
        n <- length(env)
        assign(as.character(n+1), value, envir=env)
    }

    context <- create_context(call_exit_callback=call_exit_callback, functions=funs)

    set_data(context, new.env(parent=emptyenv()))

    trace_code(code, context, envir=environment())

    captures <- as.list(get_data(context))
    names(captures) <- NULL
    captures
}


#' @export
with_capturing_calls_to_file <- function(funs, file, code) {
  calls <- with_capturing_calls(funs, code)
  if (!is.null(calls) && length(calls) > 0) {
    saveRDS(calls, file)
  }
}

