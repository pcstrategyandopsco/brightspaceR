test_that("bs_ads_path builds correct paths", {
  withr::local_options(brightspaceR.api_version = "1.49")
  expect_equal(
    brightspaceR:::bs_ads_path(),
    "d2l/api/lp/1.49/dataExport"
  )
  expect_equal(
    brightspaceR:::bs_ads_path("list"),
    "d2l/api/lp/1.49/dataExport/list"
  )
  expect_equal(
    brightspaceR:::bs_ads_path("jobs", "abc-123"),
    "d2l/api/lp/1.49/dataExport/jobs/abc-123"
  )
  expect_equal(
    brightspaceR:::bs_ads_path("download", "abc-123"),
    "d2l/api/lp/1.49/dataExport/download/abc-123"
  )
  expect_equal(
    brightspaceR:::bs_ads_path("create"),
    "d2l/api/lp/1.49/dataExport/create"
  )
})

test_that("bs_list_ads errors when not authenticated", {
  withr::defer(brightspaceR:::bs_deauth())
  brightspaceR:::bs_deauth()
  expect_error(bs_list_ads(), "No instance URL")
})

test_that("bs_get_ads errors when not authenticated", {
  withr::defer(brightspaceR:::bs_deauth())
  brightspaceR:::bs_deauth()
  expect_error(bs_get_ads("Learner Usage"), "No instance URL")
})

test_that("bs_ads_filter builds correct filter with dates", {
  f <- bs_ads_filter(start_date = "2024-01-01", end_date = "2024-12-31")
  filter_names <- vapply(f, function(x) x$Name, character(1))
  expect_true("startDate" %in% filter_names)
  expect_true("endDate" %in% filter_names)
  expect_false("parentOrgUnitId" %in% filter_names)
  expect_false("roles" %in% filter_names)
})

test_that("bs_ads_filter formats dates as ISO 8601 UTC", {
  f <- bs_ads_filter(start_date = "2024-06-15")
  start_filter <- f[[1]]
  expect_equal(start_filter$Name, "startDate")
  expect_equal(start_filter$Value, "2024-06-15T00:00:00.000Z")
})

test_that("bs_ads_filter builds correct filter with org unit", {
  f <- bs_ads_filter(parent_org_unit_id = 6606)
  expect_equal(f[[1]]$Name, "parentOrgUnitId")
  expect_equal(f[[1]]$Value, "6606")
})

test_that("bs_ads_filter builds correct filter with roles", {
  f <- bs_ads_filter(roles = c(110, 120))
  expect_equal(f[[1]]$Name, "roles")
  expect_equal(f[[1]]$Value, "110,120")
})

test_that("bs_ads_filter returns empty list when no args", {
  f <- bs_ads_filter()
  expect_equal(length(f), 0)
  expect_type(f, "list")
})

test_that("bs_get_ads_schema returns schema for known dataset", {
  schema <- bs_get_ads_schema("Learner Usage")
  expect_false(is.null(schema))
  expect_true("col_types" %in% names(schema))
  expect_true("date_cols" %in% names(schema))
  expect_true("bool_cols" %in% names(schema))
  expect_true("key_cols" %in% names(schema))
})

test_that("bs_get_ads_schema returns NULL for unknown dataset", {
  schema <- bs_get_ads_schema("Nonexistent Dataset")
  expect_null(schema)
})

test_that("bs_list_ads_schemas includes learner_usage", {
  schemas <- bs_list_ads_schemas()
  expect_true("learner_usage" %in% schemas)
})

test_that("ads_status_text has correct mapping", {
  st <- brightspaceR:::ads_status_text
  expect_equal(st[1], "Queued")
  expect_equal(st[2], "Processing")
  expect_equal(st[3], "Complete")
  expect_equal(st[4], "Error")
  expect_equal(st[5], "Deleted")
})
