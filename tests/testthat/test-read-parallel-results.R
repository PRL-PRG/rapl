test_that("read_parallel_results reads seq", {
  results <- read_parallel_results("data/10")

  expect_equal(nrow(results), 10)
  expect_equal(sort(results$seq), 1:10)
  expect_true(all(c("path", "stdout", "stderr", "stdout_error", "stderr_error") %in% colnames(results)))
})

