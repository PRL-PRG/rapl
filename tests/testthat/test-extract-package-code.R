test_that("testthat is properly handled", {
  wrapper <- function(package, file, type, body) {
    str_glue(
      "# {package} :: {type} :: {basename(file)}",
      "{body}",
      .sep="\n"
    )
  }

  test_pkg_dir <- "data/pkg.testthat1"
  out_dir <- tempfile()

  files <- extract_package_code(
    "pkg.testthat1", test_pkg_dir,
    types="tests", out_dir, wrap=wrapper,
    compute_sloc=TRUE, quiet=FALSE
  )

  expect_equal(
    files$file,
    file.path("tests", c("testthat-drv-test1.R", "testthat-drv-test2.R"))
  )

  # the line count is before the wrapping
  expect_equal(files$code, c(6, 6))

  # the drive files are not wrapped
  expect_equal(purrr::map_int(files$file, ~length(readLines(file.path(out_dir, .)))), c(3, 3))

  # the testthat files are wrapped
  tt_tests <- file.path(dirname(files$file), "testthat" ,c("test-test1.R", "test-test2.R"))
  expect_equal(
    purrr::map_chr(tt_tests, ~readLines(file.path(out_dir, .))[1]),
    c(
      "# pkg.testthat1 :: tests :: test-test1.R",
      "# pkg.testthat1 :: tests :: test-test2.R"
    )
  )
})
