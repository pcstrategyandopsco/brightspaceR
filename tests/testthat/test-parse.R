test_that("to_snake_case converts PascalCase correctly", {
  expect_equal(brightspaceR:::to_snake_case("UserId"), "user_id")
  expect_equal(brightspaceR:::to_snake_case("OrgUnitId"), "org_unit_id")
  expect_equal(brightspaceR:::to_snake_case("FirstName"), "first_name")
  expect_equal(brightspaceR:::to_snake_case("IsActive"), "is_active")
  expect_equal(brightspaceR:::to_snake_case("LastAccessedDate"), "last_accessed_date")
  expect_equal(brightspaceR:::to_snake_case("HTTPRequest"), "http_request")
  expect_equal(brightspaceR:::to_snake_case("already_snake"), "already_snake")
})

test_that("normalize_dataset_name works correctly", {
  expect_equal(brightspaceR:::normalize_dataset_name("Users"), "users")
  expect_equal(brightspaceR:::normalize_dataset_name("User Enrollments"), "user_enrollments")
  expect_equal(brightspaceR:::normalize_dataset_name("Grade Results"), "grade_results")
  expect_equal(brightspaceR:::normalize_dataset_name("Org Units"), "org_units")
  expect_equal(
    brightspaceR:::normalize_dataset_name("Content User Progress"),
    "content_user_progress"
  )
})

test_that("bs_parse_bool handles various boolean formats", {
  expect_equal(
    brightspaceR:::bs_parse_bool(c("True", "False", "1", "0", NA)),
    c(TRUE, FALSE, TRUE, FALSE, NA)
  )
  expect_equal(
    brightspaceR:::bs_parse_bool(c("true", "false", "TRUE", "FALSE")),
    c(TRUE, FALSE, TRUE, FALSE)
  )
})

test_that("bs_clean_names converts column names", {
  df <- data.frame(UserId = 1, FirstName = "A", LastAccessedDate = "2024-01-01")
  result <- bs_clean_names(df)
  expect_equal(names(result), c("user_id", "first_name", "last_accessed_date"))
})

test_that("bs_parse_csv reads a known dataset with schema", {
  # Create a temporary CSV that mimics a Users BDS extract
  tmp <- tempfile(fileext = ".csv")
  withr::defer(unlink(tmp))

  writeLines(
    c(
      "UserId,UserName,OrgDefinedId,FirstName,MiddleName,LastName,IsActive,Organization,ExternalEmail,SignupDate,LastAccessedDate",
      '100,"jdoe","EMP001","John","M","Doe","True","Org1","john@example.com","2024-01-15T10:30:00.000Z","2024-06-01T08:00:00.000Z"',
      '200,"asmith","EMP002","Alice","","Smith","False","Org1","alice@example.com","2023-06-01T12:00:00.000Z",""'
    ),
    tmp
  )

  result <- brightspaceR:::bs_parse_csv(tmp, dataset_name = "Users")

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$user_id, c(100L, 200L))
  expect_equal(result$first_name, c("John", "Alice"))
  expect_equal(result$is_active, c(TRUE, FALSE))
  expect_s3_class(result$signup_date, "POSIXct")
})

test_that("bs_parse_csv handles unknown dataset with type coercion", {
  tmp <- tempfile(fileext = ".csv")
  withr::defer(unlink(tmp))

  writeLines(
    c(
      "Id,Value,IsEnabled,CreatedAt",
      '1,99.5,True,2024-01-15T10:30:00.000Z',
      '2,88.0,False,2024-02-20T14:00:00.000Z'
    ),
    tmp
  )

  result <- brightspaceR:::bs_parse_csv(tmp, dataset_name = NULL)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_type(result$id, "integer")
  expect_type(result$value, "double")
  expect_type(result$is_enabled, "logical")
  expect_s3_class(result$created_at, "POSIXct")
})

test_that("bs_parse_csv handles NA values correctly", {
  tmp <- tempfile(fileext = ".csv")
  withr::defer(unlink(tmp))

  writeLines(
    c(
      "UserId,UserName,OrgDefinedId,FirstName,MiddleName,LastName,IsActive,Organization,ExternalEmail,SignupDate,LastAccessedDate",
      '1,"user1","","John","null","Doe","True","Org","email@test.com","2024-01-01T00:00:00.000Z",""',
      '2,"user2","NULL","Jane","","Smith","False","Org","","2024-01-01T00:00:00.000Z","null"'
    ),
    tmp
  )

  result <- brightspaceR:::bs_parse_csv(tmp, dataset_name = "Users")

  expect_true(is.na(result$org_defined_id[1]))
  expect_true(is.na(result$middle_name[1]))
  expect_true(is.na(result$org_defined_id[2]))
  expect_true(is.na(result$external_email[2]))
})
