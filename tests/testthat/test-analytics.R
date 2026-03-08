# ---- Timezone ----------------------------------------------------------------

test_that("bs_set_timezone sets and bs_get_timezone retrieves timezone", {
  withr::local_options(list(brightspaceR.timezone = NULL))
  expect_equal(bs_get_timezone(), "UTC")

  bs_set_timezone("Pacific/Auckland")
  expect_equal(bs_get_timezone(), "Pacific/Auckland")
})

test_that("bs_set_timezone rejects invalid timezone", {
  expect_error(bs_set_timezone("Not/A/Timezone"), "Invalid timezone")
})

# ---- Filter Test Users -------------------------------------------------------

test_that("bs_filter_test_users filters by ID length", {
  df <- tibble::tibble(
    org_defined_id = c("short", paste0(rep("a", 30), collapse = ""),
                       paste0(rep("b", 35), collapse = "")),
    name = c("Test", "Real1", "Real2")
  )
  result <- bs_filter_test_users(df, min_id_length = 30)
  expect_equal(nrow(result), 2)
})

test_that("bs_filter_test_users applies exclusion list", {
  long_id1 <- paste0(rep("a", 30), collapse = "")
  long_id2 <- paste0(rep("b", 30), collapse = "")
  df <- tibble::tibble(
    org_defined_id = c(long_id1, long_id2),
    name = c("User1", "User2")
  )
  result <- bs_filter_test_users(df, min_id_length = 30,
                                 exclusion_list = long_id1)
  expect_equal(nrow(result), 1)
  expect_equal(result$name, "User2")
})

test_that("bs_filter_test_users errors on missing column", {
  df <- tibble::tibble(user_id = 1:3)
  expect_error(bs_filter_test_users(df), "not found")
})

# ---- Enrich Enrollments -----------------------------------------------------

test_that("bs_enrich_enrollments produces correct columns and filters", {
  withr::local_options(list(brightspaceR.timezone = "UTC"))
  enrollments <- tibble::tibble(
    user_id = c(1L, 2L),
    org_unit_id = c(100L, 100L),
    action = c("Enroll", "Enroll"),
    enrollment_date = as.POSIXct(c("2024-01-01", "2024-01-02"), tz = "UTC")
  )
  org_units <- tibble::tibble(
    org_unit_id = 100L,
    name = "Course 101",
    type = "Course Offering",
    code = "C101"
  )
  users <- tibble::tibble(
    user_id = c(1L, 2L),
    first_name = c("Alice", "Bob")
  )

  result <- bs_enrich_enrollments(enrollments, org_units, users)
  expect_true("event_type" %in% names(result))
  expect_true("org_unit_name" %in% names(result))
  expect_true("org_unit_code" %in% names(result))
  expect_true("first_name" %in% names(result))
  expect_equal(nrow(result), 2)
})

test_that("bs_enrich_enrollments with course_type = NULL keeps all", {
  withr::local_options(list(brightspaceR.timezone = "UTC"))
  enrollments <- tibble::tibble(
    user_id = c(1L, 2L),
    org_unit_id = c(100L, 200L),
    action = c("Enroll", "Enroll"),
    enrollment_date = as.POSIXct(c("2024-01-01", "2024-01-02"), tz = "UTC")
  )
  org_units <- tibble::tibble(
    org_unit_id = c(100L, 200L),
    name = c("Course 101", "Dept A"),
    type = c("Course Offering", "Department"),
    code = c("C101", "DA")
  )
  users <- tibble::tibble(
    user_id = c(1L, 2L),
    first_name = c("Alice", "Bob")
  )

  result <- bs_enrich_enrollments(enrollments, org_units, users,
                                  course_type = NULL)
  expect_equal(nrow(result), 2)
})

# ---- Summarize Enrollments ---------------------------------------------------

test_that("bs_summarize_enrollments produces one row per user per course", {
  withr::local_options(list(brightspaceR.timezone = "UTC"))
  enriched <- tibble::tibble(
    user_id = c(1L, 1L, 2L),
    org_unit_id = c(100L, 100L, 100L),
    org_unit_name = c("C1", "C1", "C1"),
    org_defined_id = c("u1", "u1", "u2"),
    event_type = c("Enroll", "Enroll", "Enroll"),
    enrollment_date = as.POSIXct(c("2024-01-01", "2024-06-01", "2024-01-15"),
                                 tz = "UTC")
  )
  result <- bs_summarize_enrollments(enriched)
  expect_equal(nrow(result), 2)
  # User 1 should have the later date
  u1 <- dplyr::filter(result, .data$user_id == 1L)
  expect_equal(as.Date(u1$enrollment_date), as.Date("2024-06-01"))
})

# ---- Course Engagement -------------------------------------------------------

test_that("bs_course_engagement calculates progress_pct correctly", {
  df <- tibble::tibble(
    user_id = c(1L, 2L, 3L),
    org_unit_id = c(100L, 100L, 100L),
    content_completed = c(5, 10, 0),
    content_required = c(10, 10, 0),
    login_count = c(5L, 10L, 0L),
    last_visited_date = as.POSIXct(c("2024-01-01", "2024-06-01", NA),
                                   tz = "UTC")
  )
  result <- bs_course_engagement(df)
  expect_equal(result$progress_pct, c(50.0, 100.0, NA))
})

test_that("bs_course_engagement calculates days_since_visit", {
  df <- tibble::tibble(
    user_id = 1L,
    org_unit_id = 100L,
    content_completed = 5,
    content_required = 10,
    login_count = 5L,
    last_visited_date = Sys.time() - as.difftime(7, units = "days")
  )
  result <- bs_course_engagement(df)
  expect_true(abs(result$days_since_visit - 7) < 0.1)
})

# ---- Engagement Summary ------------------------------------------------------

test_that("bs_engagement_summary groups by course", {
  df <- tibble::tibble(
    user_id = c(1L, 2L),
    org_unit_id = c(100L, 100L),
    course_offering_name = c("Course A", "Course A"),
    content_completed = c(5, 10),
    content_required = c(10, 10),
    login_count = c(3L, 7L),
    quiz_completed = c(1L, 2L),
    assignment_completed = c(1L, 1L),
    discussion_posts_created = c(2L, 3L),
    last_visited_date = as.POSIXct(c("2024-01-01", "2024-06-01"), tz = "UTC")
  )
  result <- bs_engagement_summary(df, by = "course")
  expect_equal(nrow(result), 1)
  expect_true("n_users" %in% names(result))
  expect_equal(result$n_users, 2L)
})

test_that("bs_engagement_summary groups by user", {
  df <- tibble::tibble(
    user_id = c(1L, 1L),
    org_defined_id = c("u1", "u1"),
    first_name = c("Alice", "Alice"),
    last_name = c("Smith", "Smith"),
    org_unit_id = c(100L, 200L),
    content_completed = c(5, 10),
    content_required = c(10, 10),
    login_count = c(3L, 7L),
    quiz_completed = c(1L, 2L),
    assignment_completed = c(1L, 1L),
    discussion_posts_created = c(2L, 3L),
    last_visited_date = as.POSIXct(c("2024-01-01", "2024-06-01"), tz = "UTC")
  )
  result <- bs_engagement_summary(df, by = "user")
  expect_equal(nrow(result), 1)
  expect_true("n_courses" %in% names(result))
  expect_equal(result$n_courses, 2L)
})

# ---- Grade Summary -----------------------------------------------------------

test_that("bs_grade_summary calculates percentages", {
  grades <- tibble::tibble(
    grade_object_id = c(10L, 20L),
    org_unit_id = c(100L, 100L),
    user_id = c(1L, 1L),
    points_numerator = c(85, 0),
    points_denominator = c(100, 0),
    is_deleted = c(FALSE, FALSE)
  )
  objects <- tibble::tibble(
    grade_object_id = c(10L, 20L),
    org_unit_id = c(100L, 100L),
    name = c("Midterm", "Final"),
    type_name = c("Numeric", "Numeric"),
    max_points = c(100, 100)
  )
  result <- bs_grade_summary(grades, objects)
  expect_equal(result$grade_pct[1], 85.0)
  expect_true(is.na(result$grade_pct[2]))
  expect_equal(result$grade_label[1], "85%")
})

test_that("bs_grade_summary filters deleted records", {
  grades <- tibble::tibble(
    grade_object_id = c(10L, 20L),
    org_unit_id = c(100L, 100L),
    user_id = c(1L, 1L),
    points_numerator = c(85, 90),
    points_denominator = c(100, 100),
    is_deleted = c(FALSE, TRUE)
  )
  objects <- tibble::tibble(
    grade_object_id = c(10L, 20L),
    org_unit_id = c(100L, 100L),
    name = c("Midterm", "Final"),
    type_name = c("Numeric", "Numeric"),
    max_points = c(100, 100)
  )
  result <- bs_grade_summary(grades, objects)
  expect_equal(nrow(result), 1)
})

# ---- Assessment Performance --------------------------------------------------

test_that("bs_assessment_performance aggregates attempts correctly", {
  attempts <- tibble::tibble(
    user_id = c(1L, 1L, 2L),
    quiz_id = c(10L, 10L, 10L),
    org_unit_id = c(100L, 100L, 100L),
    score = c(70, 85, 90),
    possible_score = c(100, 100, 100),
    is_graded = c(TRUE, TRUE, TRUE),
    is_deleted = c(FALSE, FALSE, FALSE),
    time_started = as.POSIXct(c("2024-01-01", "2024-01-15", "2024-01-10"),
                              tz = "UTC"),
    time_completed = as.POSIXct(c("2024-01-01", "2024-01-15", "2024-01-10"),
                                tz = "UTC")
  )
  result <- bs_assessment_performance(attempts)
  expect_equal(nrow(result), 2)
  u1 <- dplyr::filter(result, .data$user_id == 1L)
  expect_equal(u1$n_attempts, 2L)
  expect_equal(u1$best_score, 85)
  expect_equal(u1$best_pct, 85.0)
})

# ---- Assignment Completion ---------------------------------------------------

test_that("bs_assignment_completion calculates grading rate", {
  submissions <- tibble::tibble(
    dropbox_id = c(1L, 1L, 1L),
    org_unit_id = c(100L, 100L, 100L),
    user_id = c(1L, 2L, 3L),
    is_graded = c(TRUE, TRUE, FALSE),
    is_deleted = c(FALSE, FALSE, FALSE),
    score = c(80, 90, NA),
    last_submission_date = as.POSIXct(
      c("2024-01-01", "2024-01-02", "2024-01-03"), tz = "UTC"
    )
  )
  result <- bs_assignment_completion(submissions)
  expect_equal(nrow(result), 1)
  expect_equal(result$n_submitted, 3L)
  expect_equal(result$n_graded, 2L)
  expect_equal(result$grading_rate, 2 / 3)
})

# ---- Identify At-Risk -------------------------------------------------------

test_that("bs_identify_at_risk flags correctly", {
  df <- tibble::tibble(
    user_id = c(1L, 2L, 3L, 4L),
    org_unit_id = c(100L, 100L, 100L, 100L),
    content_completed = c(0, 2, 10, 10),
    content_required = c(10, 10, 10, 10),
    login_count = c(0L, 1L, 5L, 20L),
    last_visited_date = c(
      as.POSIXct(NA_character_, tz = "UTC"),
      as.POSIXct("2024-01-01", tz = "UTC"),
      Sys.time() - as.difftime(1, units = "days"),
      Sys.time()
    )
  )
  result <- bs_identify_at_risk(df, thresholds = list(progress = 25))

  # User 1: never_accessed=T, low_progress=T, inactive=T, low_logins=T -> 4

  u1 <- dplyr::filter(result, .data$user_id == 1L)
  expect_true(u1$never_accessed)
  expect_equal(u1$risk_score, 4L)
  expect_equal(as.character(u1$risk_level), "Critical")

  # User 4: all good -> 0
  u4 <- dplyr::filter(result, .data$user_id == 4L)
  expect_equal(u4$risk_score, 0L)
  expect_equal(as.character(u4$risk_level), "Low")
})

test_that("bs_identify_at_risk risk_level is ordered factor", {
  df <- tibble::tibble(
    user_id = 1L,
    org_unit_id = 100L,
    content_completed = 10,
    content_required = 10,
    login_count = 20L,
    last_visited_date = as.POSIXct(as.character(Sys.Date()), tz = "UTC")
  )
  result <- bs_identify_at_risk(df)
  expect_true(is.ordered(result$risk_level))
})

# ---- Retention Summary -------------------------------------------------------

test_that("bs_retention_summary calculates rates correctly", {
  df <- tibble::tibble(
    user_id = c(1L, 2L, 3L, 4L),
    org_unit_id = c(100L, 100L, 100L, 100L),
    course_offering_name = rep("Course A", 4),
    content_completed = c(10, 5, 0, 0),
    content_required = c(10, 10, 10, 10),
    login_count = c(10L, 5L, 0L, 0L),
    last_visited_date = as.POSIXct(
      c("2024-06-01", "2024-06-01", NA, NA), tz = "UTC"
    )
  )
  result <- bs_retention_summary(df, by = "course")
  expect_equal(nrow(result), 1)
  expect_equal(result$n_enrolled, 4L)
  expect_equal(result$n_started, 2L)
  expect_equal(result$n_completed, 1L)
  expect_equal(result$start_rate, 0.5)
  expect_equal(result$completion_rate, 0.25)
  expect_equal(result$dropout_rate, 0.5)
})

# ---- Engagement Score --------------------------------------------------------

test_that("bs_engagement_score adds weighted score", {
  df <- tibble::tibble(
    user_id = c(1L, 2L),
    login_count = c(10L, 5L),
    quiz_completed = c(2L, 1L),
    assignment_completed = c(1L, 0L),
    discussion_posts_created = c(3L, 2L)
  )
  result <- bs_engagement_score(df)
  # 10*1 + 2*3 + 1*5 + 3*2 = 10+6+5+6 = 27
  expect_equal(result$engagement_score[1], 27)
  # 5*1 + 1*3 + 0*5 + 2*2 = 5+3+0+4 = 12
  expect_equal(result$engagement_score[2], 12)
})

test_that("bs_engagement_score warns on missing columns", {
  df <- tibble::tibble(login_count = c(10L, 5L))
  expect_warning(bs_engagement_score(df), "not found")
})

test_that("bs_engagement_score accepts custom weights", {
  df <- tibble::tibble(
    login_count = c(10L),
    quiz_completed = c(2L),
    assignment_completed = c(1L),
    discussion_posts_created = c(3L)
  )
  result <- bs_engagement_score(df, weights = list(login_count = 10))
  # 10*10 + 2*3 + 1*5 + 3*2 = 100+6+5+6 = 117
  expect_equal(result$engagement_score[1], 117)
})

# ---- Course Summary ----------------------------------------------------------

test_that("bs_course_summary aggregates correctly", {
  df <- tibble::tibble(
    user_id = c(1L, 2L, 3L),
    org_unit_id = c(100L, 100L, 100L),
    course_offering_name = rep("Course A", 3),
    content_completed = c(10, 5, 0),
    content_required = c(10, 10, 10),
    login_count = c(10L, 5L, 1L),
    quiz_completed = c(2L, 1L, 0L),
    assignment_completed = c(1L, 1L, 0L),
    discussion_posts_created = c(3L, 2L, 0L),
    last_visited_date = as.POSIXct(
      c("2024-06-01", "2024-05-01", "2024-04-01"), tz = "UTC"
    )
  )
  result <- bs_course_summary(df)
  expect_equal(nrow(result), 1)
  expect_equal(result$n_learners, 3L)
  # 1 out of 3 has 100% progress
  expect_equal(result$completion_rate_progress, 1 / 3)
  expect_true(is.na(result$completion_rate_awards))
})

test_that("bs_course_summary includes award completion when awards provided", {
  df <- tibble::tibble(
    user_id = c(1L, 2L),
    org_unit_id = c(100L, 100L),
    course_offering_name = rep("Course A", 2),
    content_completed = c(10, 5),
    content_required = c(10, 10),
    login_count = c(10L, 5L),
    quiz_completed = c(2L, 1L),
    assignment_completed = c(1L, 1L),
    discussion_posts_created = c(3L, 2L),
    last_visited_date = as.POSIXct(c("2024-06-01", "2024-05-01"), tz = "UTC")
  )
  awards <- tibble::tibble(
    user_id = 1L,
    org_unit_id = 100L,
    issue_date = as.POSIXct("2024-06-15", tz = "UTC")
  )
  result <- bs_course_summary(df, awards = awards)
  expect_equal(result$completion_rate_awards, 0.5)
})
