test_that("test search_function_calls", {
  code <- "
    function(x) {
      if (x) {
        stopifnot(x > 1)
      } else if (x < 0) {
        base::stopifnot(x < 0)
      } else {
        base:::stopifnot(x < 0)
      }
    }
  "

  ast <- parse(text=code)

  funs <- search_function_calls(ast, "base:::stopifnot")
  expect_equal(length(funs), 3)
})

test_that("call to result of an eval", {
  code <- "
     glmfit <- glm(Inew ~ -1 +as.factor(period) + (lIminus) + offset(lSminus),
                   family=eval(parse(text=family))(link=link))
  "
  ast <- parse(text=code)
  funs <- search_function_calls(ast, "base:::eval")
  expect_equal(length(funs), 1)
})
