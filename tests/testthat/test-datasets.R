test_that("bs_api_version returns default version", {
  withr::local_options(brightspaceR.api_version = NULL)
  expect_equal(bs_api_version(), "1.49")
})

test_that("bs_api_version can be set", {
  withr::local_options(brightspaceR.api_version = NULL)
  bs_api_version("1.50")
  expect_equal(bs_api_version(), "1.50")
})

test_that("bs_bds_path builds correct paths", {
  withr::local_options(brightspaceR.api_version = "1.49")
  expect_equal(
    brightspaceR:::bs_bds_path(),
    "d2l/api/lp/1.49/datasets/bds"
  )
  expect_equal(
    brightspaceR:::bs_bds_path("schema1", "plugin1", "extracts"),
    "d2l/api/lp/1.49/datasets/bds/schema1/plugin1/extracts"
  )
})

test_that("bs_unzip extracts files to temp directory", {
  # Create a temporary ZIP with a CSV inside
  tmp_dir <- tempfile("test_zip_")
  dir.create(tmp_dir)
  withr::defer(unlink(tmp_dir, recursive = TRUE))

  csv_path <- file.path(tmp_dir, "test.csv")
  writeLines(c("a,b", "1,2"), csv_path)

  zip_path <- tempfile(fileext = ".zip")
  withr::defer(unlink(zip_path))

  withr::with_dir(tmp_dir, {
    utils::zip(zip_path, "test.csv")
  })

  result_dir <- brightspaceR:::bs_unzip(zip_path)
  withr::defer(unlink(result_dir, recursive = TRUE))

  extracted_files <- list.files(result_dir, recursive = TRUE)
  expect_true("test.csv" %in% extracted_files)
})

test_that("bs_list_datasets errors when not authenticated", {
  withr::defer(brightspaceR:::bs_deauth())
  brightspaceR:::bs_deauth()
  expect_error(bs_list_datasets(), "No instance URL")
})

test_that("bs_get_dataset errors when not authenticated", {
  withr::defer(brightspaceR:::bs_deauth())
  brightspaceR:::bs_deauth()
  expect_error(bs_get_dataset("Users"), "No instance URL")
})
