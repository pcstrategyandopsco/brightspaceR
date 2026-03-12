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

test_that("bs_get_dataset_current errors when not authenticated", {
  withr::defer(brightspaceR:::bs_deauth())
  brightspaceR:::bs_deauth()
  expect_error(bs_get_dataset_current("Users"), "No instance URL")
})

# --- bs_apply_diffs tests ---

test_that("bs_apply_diffs inserts new rows from diff", {
  full <- tibble::tibble(user_id = 1:3, name = c("A", "B", "C"))
  diff <- tibble::tibble(user_id = 4L, name = "D")
  result <- bs_apply_diffs(full, list(diff))
  expect_equal(nrow(result), 4)
  expect_true(4L %in% result$user_id)
})

test_that("bs_apply_diffs updates existing rows", {
  full <- tibble::tibble(user_id = 1:3, name = c("A", "B", "C"))
  diff <- tibble::tibble(user_id = 2L, name = "B_updated")
  result <- bs_apply_diffs(full, list(diff))
  expect_equal(nrow(result), 3)
  expect_equal(result$name[result$user_id == 2L], "B_updated")
})

test_that("bs_apply_diffs removes deleted rows when keep_deleted = FALSE", {
  full <- tibble::tibble(
    user_id = 1:3, name = c("A", "B", "C"),
    is_deleted = c(FALSE, FALSE, FALSE)
  )
  diff <- tibble::tibble(user_id = 2L, name = "B", is_deleted = TRUE)
  result <- bs_apply_diffs(full, list(diff), keep_deleted = FALSE)
  expect_false(2L %in% result$user_id)
  expect_equal(nrow(result), 2)
})

test_that("bs_apply_diffs keeps deleted rows when keep_deleted = TRUE", {
  full <- tibble::tibble(
    user_id = 1:3, name = c("A", "B", "C"),
    is_deleted = c(FALSE, FALSE, FALSE)
  )
  diff <- tibble::tibble(user_id = 2L, name = "B", is_deleted = TRUE)
  result <- bs_apply_diffs(full, list(diff), keep_deleted = TRUE)
  expect_equal(nrow(result), 3)
  expect_true(result$is_deleted[result$user_id == 2L])
})

test_that("bs_apply_diffs auto-detects _id columns when no dataset_name", {
  full <- tibble::tibble(org_unit_id = 1:2, title = c("X", "Y"))
  diff <- tibble::tibble(org_unit_id = 1L, title = "X_updated")
  result <- bs_apply_diffs(full, list(diff))
  expect_equal(result$title[result$org_unit_id == 1L], "X_updated")
})

test_that("bs_apply_diffs returns full unchanged with empty diffs", {
  full <- tibble::tibble(user_id = 1:3, name = c("A", "B", "C"))
  result <- bs_apply_diffs(full, list())
  expect_identical(result, full)
})

test_that("bs_apply_diffs handles type mismatches between full and diff", {
  full <- tibble::tibble(
    org_unit_id = 1:2,
    start_date = as.POSIXct(c("2025-01-01", "2025-06-01"), tz = "UTC"),
    is_active = c(TRUE, FALSE)
  )
  diff <- tibble::tibble(
    org_unit_id = 1L,
    start_date = "2025-03-01T00:00:00.000Z",
    is_active = "True"
  )
  result <- bs_apply_diffs(full, list(diff))
  expect_s3_class(result$start_date, "POSIXct")
  expect_type(result$is_active, "logical")
  expect_equal(nrow(result), 2)
})

test_that("bs_apply_diffs applies multiple diffs in order", {
  full <- tibble::tibble(user_id = 1:2, name = c("A", "B"))
  diff1 <- tibble::tibble(user_id = 1L, name = "A_v2")
  diff2 <- tibble::tibble(user_id = 1L, name = "A_v3")
  result <- bs_apply_diffs(full, list(diff1, diff2))
  expect_equal(result$name[result$user_id == 1L], "A_v3")
})
