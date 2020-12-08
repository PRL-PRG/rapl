context("impute_srcref")

## test_that("nested function calls", {
##   f <- function() {
##     tryCatch(g())
##   }

##   r <- impute_fun_srcref(f)
##   expect_srcref(body(r)[[2]], "tryCatch(g())")
##   expect_srcref(body(r)[[2]][[2]], "g()")
## })

test_that("for", {
  f <- function() {
    for (x in y()) {
      g()
    }
  }

  r <- impute_fun_srcref(f)
  expect_srcref(body(r)[[2]][[3]], "y()")
  expect_srcref(body(r)[[2]][[4]][[2]], "g()")
})

test_that("while", {
  f <- function() {
    while ((x())) {
      g()
    }
  }

  r <- impute_fun_srcref(f)
  expect_srcref(body(r)[[2]][[2]][[2]], "x()")
  expect_srcref(body(r)[[2]][[3]][[2]], "g()")
})

test_that("assignments", {
  f <- function() {
    x <- g()
    h() -> y
    z = i()
  }

  r <- impute_fun_srcref(f)
  expect_srcref(body(r)[[2]][[3]], "g()")
  expect_srcref(body(r)[[3]][[3]], "h()")
  expect_srcref(body(r)[[4]][[3]], "i()")
})
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

## test_that("trace_eval works with imputed srcref", {
##   g <- function(xs, f1) {
##     for (x in xs) f1(x)
##   }
  
##   f <- function(n, expr) {
##     g(integer(n), eval.parent(substitute(function(...) expr)))
##   }

##   d <- do_trace_eval(f(1, 1))

##   browser()
##   expect_true(is.na(d$caller_srcref))

## #  g <- impute_fun_srcref(f)

## })
