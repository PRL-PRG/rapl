test_that("load_log_file loads parallel log", {
  path <- "data/10/parallel.log"
  log <- read_parallel_log(path)

  expect_equal(nrow(log), 10)
  expect_named(log, c("seq", "host", "starttime", "jobruntime", "send", "receive", "exitval", "signal", "command"))
  expect_s3_class(log$starttime, "POSIXct")
  expect_s4_class(log$jobruntime, "Period")
})
