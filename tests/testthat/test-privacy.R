test_that("bs_pseudonymise_df pseudonymises snake_case columns from bs_get_dataset", {
  key <- openssl::rand_bytes(32)
  # bs_get_dataset() / bs_parse_csv() return snake_case columns, while the
  # registry lists PascalCase (e.g. "UserId"). The two must still line up.
  df <- tibble::tibble(user_id = c(1L, 2L, NA), org_unit_id = c(10L, 20L, 30L))
  out <- bs_pseudonymise_df(df, "Users", key = key)
  expect_true(all(grepl("^usr_", out$user_id[!is.na(df$user_id)])))
  expect_true(is.na(out$user_id[3]))
  # Structural IDs are left untouched.
  expect_identical(out$org_unit_id, df$org_unit_id)
})

test_that("bs_pseudonymise_df still works on PascalCase input", {
  key <- openssl::rand_bytes(32)
  df <- tibble::tibble(UserId = c(1L, 2L))
  out <- bs_pseudonymise_df(df, "Users", key = key)
  expect_true(all(grepl("^usr_", out$UserId)))
})

test_that("bs_pseudonymise_df is deterministic and preserves joinability", {
  key <- openssl::rand_bytes(32)
  a <- bs_pseudonymise_df(tibble::tibble(user_id = 1L), "Users", key = key)
  b <- bs_pseudonymise_df(tibble::tibble(user_id = 1L), "Users", key = key)
  expect_identical(a$user_id, b$user_id)
})

test_that("bs_pseudonymise_df covers Course Access (UserId keyed on day)", {
  key <- openssl::rand_bytes(32)
  df <- tibble::tibble(
    org_unit_id = c(100L, 100L),
    user_id = c(5L, 5L),
    day_accessed = as.POSIXct(c("2025-01-01", "2025-01-02"), tz = "UTC")
  )
  out <- bs_pseudonymise_df(df, "Course Access", key = key)
  expect_true(all(grepl("^usr_", out$user_id)))
  expect_identical(out$org_unit_id, df$org_unit_id)
  expect_identical(out$day_accessed, df$day_accessed)
})

test_that("bs_apply_field_policy allow-mode keeps snake_case columns", {
  policy <- list(Users = list(mode = "allow", fields = c("UserId", "Organization")))
  df <- tibble::tibble(
    user_id = 1L, user_name = "jsmith",
    organization = "OrgA", external_email = "j@x.com"
  )
  out <- bs_apply_field_policy(df, "Users", policy = policy)
  expect_setequal(names(out), c("user_id", "organization"))
})

test_that("bs_apply_field_policy redact-mode redacts snake_case columns", {
  policy <- list(Users = list(mode = "redact", fields = c("ExternalEmail")))
  df <- tibble::tibble(user_id = 1L, external_email = "j@x.com")
  out <- bs_apply_field_policy(df, "Users", policy = policy)
  expect_equal(out$external_email, "[REDACTED]")
  expect_equal(out$user_id, 1L)
})

test_that("bs_apply_field_policy passes through unknown datasets and 'all' mode", {
  df <- tibble::tibble(user_id = 1L, x = 2L)
  expect_identical(bs_apply_field_policy(df, "Not A Dataset", policy = list()), df)
  expect_identical(
    bs_apply_field_policy(df, "Foo", policy = list(Foo = list(mode = "all"))),
    df
  )
})
