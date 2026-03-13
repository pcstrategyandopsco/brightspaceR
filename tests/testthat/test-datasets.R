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

test_that("bs_apply_diffs inserts new rows from multiple diffs (no silent drops)", {
  # Regression: bs_get_dataset_current previously downloaded the same
  # (latest) diff extract every iteration instead of each specific diff,
  # silently dropping earlier differential records.
  full <- tibble::tibble(
    attempt_id = 1:3L,
    quiz_id = rep(100L, 3),
    user_id = 101:103L,
    score = c(80, 85, 90),
    time_completed = as.POSIXct(
      c("2025-01-05", "2025-01-06", "2025-01-07"), tz = "UTC"
    )
  )
  # Diff 1: new attempt from March 10
  diff1 <- tibble::tibble(
    attempt_id = 4L, quiz_id = 100L, user_id = 104L,
    score = 75,
    time_completed = as.POSIXct("2025-03-10", tz = "UTC")
  )
  # Diff 2: new attempt from March 11
  diff2 <- tibble::tibble(
    attempt_id = 5L, quiz_id = 100L, user_id = 105L,
    score = 92,
    time_completed = as.POSIXct("2025-03-11", tz = "UTC")
  )
  result <- bs_apply_diffs(full, list(diff1, diff2))
  expect_equal(nrow(result), 5)
  expect_true(4L %in% result$attempt_id)
  expect_true(5L %in% result$attempt_id)
  # Verify the March data is actually present
  march_rows <- result[result$time_completed >= as.POSIXct("2025-03-01", tz = "UTC"), ]
  expect_equal(nrow(march_rows), 2)
})

test_that("bs_apply_diffs handles composite keys correctly", {
  full <- tibble::tibble(
    attempt_id = c(1L, 2L),
    quiz_id = c(100L, 100L),
    org_unit_id = c(10L, 10L),
    user_id = c(1L, 2L),
    score = c(80, 85)
  )
  # Diff updates one existing and inserts one new
  diff <- tibble::tibble(
    attempt_id = c(2L, 3L),
    quiz_id = c(100L, 100L),
    org_unit_id = c(10L, 10L),
    user_id = c(2L, 3L),
    score = c(90, 70)
  )
  result <- bs_apply_diffs(full, list(diff),
                            dataset_name = "Quiz Attempts")
  expect_equal(nrow(result), 3)
  expect_equal(result$score[result$attempt_id == 2L], 90)
  expect_equal(result$score[result$attempt_id == 3L], 70)
})

test_that("bs_apply_diffs deduplicates within a single diff", {
  full <- tibble::tibble(user_id = 1:2L, name = c("A", "B"))
  # Diff has duplicate keys — last occurrence should win
  diff <- tibble::tibble(
    user_id = c(1L, 1L),
    name = c("A_old", "A_newest")
  )
  result <- bs_apply_diffs(full, list(diff))
  expect_equal(nrow(result), 2)
  expect_equal(result$name[result$user_id == 1L], "A_newest")
})

# --- bs_diff_manifest tests ---

test_that("bs_diff_manifest returns manifest from attributed tibble", {
  data <- tibble::tibble(user_id = 1:3, name = c("A", "B", "C"))
  manifest <- tibble::tibble(
    extract = c("Full", "Diff 1"),
    created_date = c("2025-01-01", "2025-03-10"),
    rows = c(2L, 1L),
    status = c("ok", "ok")
  )
  attr(data, "bds_manifest") <- manifest
  result <- bs_diff_manifest(data)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$extract, c("Full", "Diff 1"))
  expect_equal(result$rows, c(2L, 1L))
})

test_that("bs_diff_manifest returns NULL for plain tibble", {
  data <- tibble::tibble(user_id = 1:3)
  expect_null(bs_diff_manifest(data))
})

test_that("bs_diff_manifest shows failed diffs", {
  data <- tibble::tibble(user_id = 1:2)
  manifest <- tibble::tibble(
    extract = c("Full", "Diff 1", "Diff 2"),
    created_date = c("2025-01-01", "2025-03-10", "2025-03-11"),
    rows = c(2L, NA_integer_, 1L),
    status = c("ok", "failed", "ok")
  )
  attr(data, "bds_manifest") <- manifest
  result <- bs_diff_manifest(data)
  expect_equal(result$status[result$extract == "Diff 1"], "failed")
  expect_true(is.na(result$rows[result$extract == "Diff 1"]))
})

# --- Quiz Attempts realistic merge tests ---

test_that("Quiz Attempts: multiple diffs insert new attempts across dates", {
  # Full extract: 5 attempts from January
  full <- tibble::tibble(
    attempt_id = 1:5L,
    quiz_id = rep(1538L, 5),
    org_unit_id = rep(6606L, 5),
    user_id = 201:205L,
    score = c(80, 85, 72, 90, 65),
    is_deleted = rep(FALSE, 5),
    time_completed = as.POSIXct(
      paste0("2025-01-0", 1:5, " 10:00:00"), tz = "UTC"
    )
  )
  # Diff 1: Feb — two new attempts
  diff1 <- tibble::tibble(
    attempt_id = 6:7L,
    quiz_id = rep(1538L, 2),
    org_unit_id = rep(6606L, 2),
    user_id = 206:207L,
    score = c(88, 91),
    is_deleted = rep(FALSE, 2),
    time_completed = as.POSIXct(
      c("2025-02-10 09:00:00", "2025-02-11 14:30:00"), tz = "UTC"
    )
  )
  # Diff 2: March 10-11 — the differential that was being silently dropped
  diff2 <- tibble::tibble(
    attempt_id = 8:9L,
    quiz_id = rep(1538L, 2),
    org_unit_id = rep(6606L, 2),
    user_id = 208:209L,
    score = c(75, 82),
    is_deleted = rep(FALSE, 2),
    time_completed = as.POSIXct(
      c("2025-03-10 11:00:00", "2025-03-11 16:00:00"), tz = "UTC"
    )
  )

  result <- bs_apply_diffs(full, list(diff1, diff2),
                            dataset_name = "Quiz Attempts")
  expect_equal(nrow(result), 9)
  # All attempt IDs present
  expect_equal(sort(result$attempt_id), 1:9L)
  # March records specifically present (the ones that were being dropped)
  march <- result[result$time_completed >= as.POSIXct("2025-03-01", tz = "UTC"), ]
  expect_equal(nrow(march), 2)
  expect_true(all(c(208L, 209L) %in% march$user_id))
})

test_that("Quiz Attempts: diff updates score on existing attempt", {
  full <- tibble::tibble(
    attempt_id = c(1L, 2L),
    quiz_id = c(1538L, 1539L),
    org_unit_id = c(6606L, 6606L),
    user_id = c(201L, 202L),
    score = c(80, 60),
    is_deleted = c(FALSE, FALSE),
    time_completed = as.POSIXct(
      c("2025-01-05 10:00:00", "2025-01-06 11:00:00"), tz = "UTC"
    )
  )
  # Diff: user 202's attempt is regraded
  diff <- tibble::tibble(
    attempt_id = 2L,
    quiz_id = 1539L,
    org_unit_id = 6606L,
    user_id = 202L,
    score = 75,
    is_deleted = FALSE,
    time_completed = as.POSIXct("2025-01-06 11:00:00", tz = "UTC")
  )

  result <- bs_apply_diffs(full, list(diff),
                            dataset_name = "Quiz Attempts")
  expect_equal(nrow(result), 2)
  expect_equal(result$score[result$attempt_id == 2L], 75)
  # Untouched row preserved
  expect_equal(result$score[result$attempt_id == 1L], 80)
})

test_that("Quiz Attempts: diff deletes an attempt", {
  full <- tibble::tibble(
    attempt_id = 1:3L,
    quiz_id = rep(1538L, 3),
    org_unit_id = rep(6606L, 3),
    user_id = 201:203L,
    score = c(80, 85, 90),
    is_deleted = c(FALSE, FALSE, FALSE),
    time_completed = as.POSIXct(
      c("2025-01-01", "2025-01-02", "2025-01-03"), tz = "UTC"
    )
  )
  # Diff marks attempt 2 as deleted
  diff <- tibble::tibble(
    attempt_id = 2L,
    quiz_id = 1538L,
    org_unit_id = 6606L,
    user_id = 202L,
    score = 85,
    is_deleted = TRUE,
    time_completed = as.POSIXct("2025-01-02", tz = "UTC")
  )

  result <- bs_apply_diffs(full, list(diff),
                            dataset_name = "Quiz Attempts",
                            keep_deleted = FALSE)
  expect_equal(nrow(result), 2)
  expect_false(2L %in% result$attempt_id)

  # With keep_deleted = TRUE, row stays
  result2 <- bs_apply_diffs(full, list(diff),
                             dataset_name = "Quiz Attempts",
                             keep_deleted = TRUE)
  expect_equal(nrow(result2), 3)
  expect_true(result2$is_deleted[result2$attempt_id == 2L])
})

test_that("Quiz Attempts: mixed inserts, updates, deletes across 3 diffs", {
  full <- tibble::tibble(
    attempt_id = 1:4L,
    quiz_id = rep(1538L, 4),
    org_unit_id = rep(6606L, 4),
    user_id = 201:204L,
    score = c(80, 85, 72, 90),
    is_deleted = rep(FALSE, 4)
  )
  # Diff 1: insert attempt 5, update attempt 1 score
  diff1 <- tibble::tibble(
    attempt_id = c(5L, 1L),
    quiz_id = c(1538L, 1538L),
    org_unit_id = c(6606L, 6606L),
    user_id = c(205L, 201L),
    score = c(88, 95),
    is_deleted = c(FALSE, FALSE)
  )
  # Diff 2: delete attempt 3
  diff2 <- tibble::tibble(
    attempt_id = 3L,
    quiz_id = 1538L,
    org_unit_id = 6606L,
    user_id = 203L,
    score = 72,
    is_deleted = TRUE
  )
  # Diff 3: insert attempt 6
  diff3 <- tibble::tibble(
    attempt_id = 6L,
    quiz_id = 1538L,
    org_unit_id = 6606L,
    user_id = 206L,
    score = 77,
    is_deleted = FALSE
  )

  result <- bs_apply_diffs(full, list(diff1, diff2, diff3),
                            dataset_name = "Quiz Attempts",
                            keep_deleted = FALSE)
  # 4 original + 2 inserted - 1 deleted = 5
  expect_equal(nrow(result), 5)
  expect_equal(result$score[result$attempt_id == 1L], 95)   # updated
  expect_false(3L %in% result$attempt_id)                    # deleted
  expect_true(5L %in% result$attempt_id)                     # inserted
  expect_true(6L %in% result$attempt_id)                     # inserted
})

# --- Quiz User Answers realistic merge tests ---

test_that("Quiz User Answers: diffs insert new answers from later dates", {
  full <- tibble::tibble(
    attempt_id = c(1L, 1L, 2L, 2L),
    question_id = c(101L, 102L, 101L, 102L),
    score = c(5, 8, 7, 6),
    is_deleted = rep(FALSE, 4),
    time_completed = as.POSIXct(
      rep("2025-01-10 10:00:00", 4), tz = "UTC"
    )
  )
  # Diff: new attempt 3 answers
  diff <- tibble::tibble(
    attempt_id = c(3L, 3L),
    question_id = c(101L, 102L),
    score = c(9, 10),
    is_deleted = c(FALSE, FALSE),
    time_completed = as.POSIXct(
      rep("2025-03-11 14:00:00", 2), tz = "UTC"
    )
  )

  result <- bs_apply_diffs(full, list(diff),
                            dataset_name = "Quiz User Answers")
  expect_equal(nrow(result), 6)
  # March answers present
  march <- result[result$time_completed >= as.POSIXct("2025-03-01", tz = "UTC"), ]
  expect_equal(nrow(march), 2)
  expect_equal(sort(march$score), c(9, 10))
})

test_that("Quiz User Answers: diff updates score on existing answer", {
  full <- tibble::tibble(
    attempt_id = c(1L, 1L),
    question_id = c(101L, 102L),
    score = c(5, 3),
    is_deleted = c(FALSE, FALSE)
  )
  # Regraded question 102
  diff <- tibble::tibble(
    attempt_id = 1L,
    question_id = 102L,
    score = 7,
    is_deleted = FALSE
  )

  result <- bs_apply_diffs(full, list(diff),
                            dataset_name = "Quiz User Answers")
  expect_equal(nrow(result), 2)
  expect_equal(result$score[result$question_id == 102L], 7)
  expect_equal(result$score[result$question_id == 101L], 5)  # unchanged
})

test_that("Quiz User Answers: 3 diffs with mixed operations", {
  full <- tibble::tibble(
    attempt_id = c(1L, 1L, 1L),
    question_id = c(101L, 102L, 103L),
    score = c(5, 8, 3),
    is_deleted = rep(FALSE, 3)
  )
  # Diff 1: update q102 score
  diff1 <- tibble::tibble(
    attempt_id = 1L, question_id = 102L, score = 10, is_deleted = FALSE
  )
  # Diff 2: new attempt 2 answers
  diff2 <- tibble::tibble(
    attempt_id = c(2L, 2L, 2L),
    question_id = c(101L, 102L, 103L),
    score = c(9, 7, 8),
    is_deleted = rep(FALSE, 3)
  )
  # Diff 3: delete q103 from attempt 1
  diff3 <- tibble::tibble(
    attempt_id = 1L, question_id = 103L, score = 3, is_deleted = TRUE
  )

  result <- bs_apply_diffs(full, list(diff1, diff2, diff3),
                            dataset_name = "Quiz User Answers",
                            keep_deleted = FALSE)
  # 3 original + 3 new - 1 deleted = 5
  expect_equal(nrow(result), 5)
  # attempt 1, q102 was updated
  expect_equal(
    result$score[result$attempt_id == 1L & result$question_id == 102L], 10
  )
  # attempt 1, q103 was deleted
  expect_false(
    any(result$attempt_id == 1L & result$question_id == 103L)
  )
  # attempt 2 fully present
  expect_equal(sum(result$attempt_id == 2L), 3)
})
