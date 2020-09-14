context("impute_srcref")

expect_srcref <- function(x, ref) {
  x_ref <- attr(x, "srcref")

  if (is.null(ref)) {
    expect_null(x_ref)
  } else {
    x_ref_str <- if (is.list(x_ref)) {
      sapply(x_ref, as.character)
    } else {
      as.character(x_ref)
    }

    expect_equal(x_ref_str, ref)
  }
}

## test_that("match.arg", {
##   f <- function(x=c("a", "b")) {
##     match.arg(x)
##   }

##   d <- do_trace_eval(f("a"))
##   browser()
##   1
## })

## test_that("impute_fun_srcref", {
##   f <- function() if (TRUE) eval(1) else 2
##   expect_srcref(body(f), NULL)

##   g <- impute_fun_srcref(f)
##   expect_srcref(body(g), list(character(0), "TRUE", "eval(1)", "2"))
##   expect_srcref(body(g)[[3]], "eval(1)")

##   d <- do_trace_eval(g())
##   expect_false(is.na(d$caller_srcref))
## })

test_that("trace_eval works with imputed srcref", {
  g <- function(xs, f1) {
    for (x in xs) f1(x)
  }
  
  f <- function(n, expr) {
    g(integer(n), eval.parent(substitute(function(...) expr)))
  }

  d <- do_trace_eval(f(1, 1))

  browser()
  expect_true(is.na(d$caller_srcref))

#  g <- impute_fun_srcref(f)

})
