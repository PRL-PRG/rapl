test_that("test running basic test", {
  out_file <- tempfile()
  on.exit(out_file)

  ret <- run_one("data/basictest/primitives.R", out_file)

  expect_equal(ret$exitval, 0L)
  expect_true(ret$time > 0)
  expect_true(file.size(out_file) > 0L)
})

test_that("run_all can run all files", {
  test_dir <- file.path(getwd(), "data/stringr")
  withr::with_tempdir({
    df <- run_all(test_dir)
    expect_equal(basename(df$file), c("case.Rd.R", "str_c.Rd.R", "testthat.R", "stringr.R"))
    expect_equal(df$exitval, c(0,0,1,0))
    expect_equal(df$error, c(NA, NA, NA, NA))
    for (f in df$out_file) expect_true(file.size(f) > 0)
  })
}) 

test_that("run_all can wrap running code", {
  withr::with_tempdir({
    writeLines("stop('Help!')", "test.R")
    df <- run_all(".")
    expect_equal(df$exitval, 1)

    wrap_fun <- function(body) str_c("try({", body, "})", sep="\n")
    df <- run_all(".", wrap_code_fun=wrap_fun)
    expect_equal(df$exitval, 0)
  })
})
