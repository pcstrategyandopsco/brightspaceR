test_that("bs_join_users_enrollments joins on user_id", {
  users <- tibble::tibble(
    user_id = c(1L, 2L, 3L),
    first_name = c("Alice", "Bob", "Charlie")
  )
  enrollments <- tibble::tibble(
    user_id = c(1L, 1L, 2L),
    org_unit_id = c(100L, 200L, 100L),
    role_id = c(1L, 1L, 2L)
  )

  result <- bs_join_users_enrollments(users, enrollments)
  expect_equal(nrow(result), 4)
  expect_true("first_name" %in% names(result))
  expect_true("org_unit_id" %in% names(result))
})

test_that("bs_join_enrollments_grades joins on org_unit_id and user_id", {
  enrollments <- tibble::tibble(
    user_id = c(1L, 2L),
    org_unit_id = c(100L, 100L),
    role_id = c(1L, 2L)
  )
  grades <- tibble::tibble(
    user_id = c(1L, 1L, 2L),
    org_unit_id = c(100L, 100L, 100L),
    grade_object_id = c(10L, 20L, 10L),
    points_numerator = c(90, 85, 78)
  )

  result <- bs_join_enrollments_grades(enrollments, grades)
  expect_equal(nrow(result), 3)
  expect_true("role_id" %in% names(result))
  expect_true("points_numerator" %in% names(result))
})

test_that("bs_join_grades_objects joins on grade_object_id and org_unit_id", {
  grades <- tibble::tibble(
    grade_object_id = c(10L, 20L),
    org_unit_id = c(100L, 100L),
    user_id = c(1L, 1L),
    points_numerator = c(90, 85)
  )
  objects <- tibble::tibble(
    grade_object_id = c(10L, 20L),
    org_unit_id = c(100L, 100L),
    name = c("Midterm", "Final"),
    max_points = c(100, 100)
  )

  result <- bs_join_grades_objects(grades, objects)
  expect_equal(nrow(result), 2)
  expect_true("name" %in% names(result))
  expect_true("max_points" %in% names(result))
})

test_that("bs_join_content_progress joins on content_object_id and org_unit_id", {
  content <- tibble::tibble(
    content_object_id = c(1L, 2L),
    org_unit_id = c(100L, 100L),
    title = c("Module 1", "Module 2")
  )
  progress <- tibble::tibble(
    content_object_id = c(1L, 1L, 2L),
    org_unit_id = c(100L, 100L, 100L),
    user_id = c(10L, 20L, 10L),
    is_completed = c(TRUE, FALSE, TRUE)
  )

  result <- bs_join_content_progress(content, progress)
  expect_equal(nrow(result), 3)
  expect_true("title" %in% names(result))
  expect_true("is_completed" %in% names(result))
})

test_that("bs_join auto-detects key columns", {
  df1 <- tibble::tibble(
    user_id = c(1L, 2L),
    name = c("Alice", "Bob")
  )
  df2 <- tibble::tibble(
    user_id = c(1L, 2L),
    score = c(95, 88)
  )

  result <- bs_join(df1, df2)
  expect_equal(nrow(result), 2)
  expect_true("name" %in% names(result))
  expect_true("score" %in% names(result))
})

test_that("bs_join supports different join types", {
  df1 <- tibble::tibble(user_id = c(1L, 2L, 3L), name = c("A", "B", "C"))
  df2 <- tibble::tibble(user_id = c(1L, 2L, 4L), score = c(95, 88, 72))

  left <- bs_join(df1, df2, type = "left")
  expect_equal(nrow(left), 3)

  inner <- bs_join(df1, df2, type = "inner")
  expect_equal(nrow(inner), 2)

  full <- bs_join(df1, df2, type = "full")
  expect_equal(nrow(full), 4)
})

test_that("bs_join errors with no common columns", {
  df1 <- tibble::tibble(a = 1)
  df2 <- tibble::tibble(b = 2)
  expect_error(bs_join(df1, df2), "No common columns")
})
