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
