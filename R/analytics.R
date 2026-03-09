# ---- Data Preparation (Tier 1) -----------------------------------------------

#' Filter test users from a dataset
#'
#' Removes test/system accounts using a two-layer filter: ID string length and
#' an optional exclusion list. This eliminates the repeated boilerplate of
#' removing test users before analysis.
#'
#' @param df A tibble containing user data.
#' @param min_id_length Minimum character length of a real user ID (default 30).
#'   IDs shorter than this are assumed to be test accounts.
#' @param exclusion_list Optional character vector of specific IDs to exclude.
#' @param id_col Name of the column containing user IDs (default
#'   `"org_defined_id"`).
#'
#' @return A filtered tibble with test users removed.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' users <- bs_get_dataset("Users")
#' real_users <- bs_filter_test_users(users)
#' real_users <- bs_filter_test_users(users, exclusion_list = c("testuser01"))
#' }
#' }
bs_filter_test_users <- function(df, min_id_length = 30, exclusion_list = NULL,
                                 id_col = "org_defined_id") {
  if (!id_col %in% names(df)) {
    abort(c(
      paste0("Column `", id_col, "` not found in data frame."),
      i = "Specify the correct column with `id_col`."
    ))
  }

  n_before <- nrow(df)

  # Layer 1: filter by ID string length
  result <- dplyr::filter(df, stringr::str_length(.data[[id_col]]) >= min_id_length)

  # Layer 2: exclude specific IDs

if (!is.null(exclusion_list)) {
    result <- dplyr::filter(result, !.data[[id_col]] %in% exclusion_list)
  }

  n_removed <- n_before - nrow(result)
  cli_alert_info("Removed {n_removed} test user{?s} ({nrow(result)} remaining)")

  result
}

#' Enrich enrollments with org unit and user details
#'
#' Builds the enriched enrollment table by joining enrollments with org units
#' and users, adding analysis-friendly column aliases. Original column names are
#' preserved for compatibility; friendly aliases are added for readability.
#'
#' @param enrollments A tibble from the Enrollments and Withdrawals dataset.
#' @param org_units A tibble from the Org Units dataset.
#' @param users A tibble from the Users dataset.
#' @param course_type Org unit type to filter to (default `"Course Offering"`).
#'   Set to `NULL` to keep all org unit types.
#'
#' @return A tibble with both original and friendly column names, filtered to
#'   the specified course type.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' enroll <- bs_get_dataset("Enrollments and Withdrawals")
#' org_units <- bs_get_dataset("Org Units")
#' users <- bs_get_dataset("Users")
#' enriched <- bs_enrich_enrollments(enroll, org_units, users)
#' }
#' }
bs_enrich_enrollments <- function(enrollments, org_units, users,
                                  course_type = "Course Offering") {
  tz <- bs_get_timezone()

  # Add event_type alias for action (action is ambiguous — event_type clarifies

# it holds "Enroll"/"Withdraw" values)
  result <- dplyr::mutate(enrollments, event_type = .data$action)

  # Join org_units — use suffix to handle name conflicts
  result <- dplyr::left_join(result, org_units, by = "org_unit_id",
                             suffix = c("", "_org"))

  # Add friendly org unit column aliases
  if ("name_org" %in% names(result)) {
    result <- dplyr::mutate(result, org_unit_name = .data$name_org)
  } else if ("name" %in% names(result)) {
    result <- dplyr::mutate(result, org_unit_name = .data$name)
  }
  if ("type" %in% names(result)) {
    result <- dplyr::mutate(result, org_unit_type = .data$type)
  }
  if ("code" %in% names(result)) {
    result <- dplyr::mutate(result, org_unit_code = .data$code)
  }

  # Join users
  result <- dplyr::left_join(result, users, by = "user_id",
                             suffix = c("", "_user"))

  # Filter to course type
  if (!is.null(course_type) && "org_unit_type" %in% names(result)) {
    result <- dplyr::filter(result, .data$org_unit_type == course_type)
  }

  # Convert date columns to configured timezone
  date_cols <- names(result)[grepl("date", names(result), ignore.case = TRUE)]
  for (col in date_cols) {
    if (inherits(result[[col]], "POSIXct")) {
      n_na_before <- sum(is.na(result[[col]]))
      result[[col]] <- lubridate::with_tz(result[[col]], tzone = tz)
      n_na_after <- sum(is.na(result[[col]]))
      if (n_na_after > n_na_before) {
        warn(paste0(
          "Timezone conversion introduced ", n_na_after - n_na_before,
          " NA(s) in column `", col, "`."
        ))
      }
    }
  }

  result
}

#' Summarize enrollments to one row per user per course
#'
#' Collapses enrollment records to keep only the latest enrollment date for
#' each user-course combination.
#'
#' @param enriched_enrollments An enriched enrollment tibble (from
#'   [bs_enrich_enrollments()]).
#' @param event_type The event type to filter to (default `"Enroll"`).
#'
#' @return A tibble with one row per user per course.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' enriched <- bs_enrich_enrollments(enroll, org_units, users)
#' summary <- bs_summarize_enrollments(enriched)
#' }
#' }
bs_summarize_enrollments <- function(enriched_enrollments,
                                     event_type = "Enroll") {
  result <- dplyr::filter(enriched_enrollments,
                          .data$event_type == .env$event_type)

  group_cols <- intersect(
    c("user_id", "org_unit_id", "org_unit_name", "org_defined_id"),
    names(result)
  )

  result |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
    dplyr::summarize(
      enrollment_date = max(.data$enrollment_date, na.rm = TRUE),
      .groups = "drop"
    )
}

# ---- Engagement Analysis -----------------------------------------------------

#' Calculate per-user per-course engagement metrics
#'
#' Computes engagement metrics from Learner Usage ADS data including progress
#' percentage, days since last visit, and passes through all raw activity counts.
#' No composite score is computed here — use [bs_engagement_score()] to add one.
#'
#' @param learner_usage A tibble from the Learner Usage ADS.
#' @param tz Timezone for date conversion. Defaults to [bs_get_timezone()].
#'
#' @return A tibble with all learner_usage identity columns plus computed
#'   metrics: `progress_pct`, `days_since_visit`.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' usage <- bs_get_ads("Learner Usage")
#' engagement <- bs_course_engagement(usage)
#' }
#' }
bs_course_engagement <- function(learner_usage, tz = NULL) {
  tz <- tz %||% bs_get_timezone()

  result <- bs_coerce_ads_types(learner_usage)

  # Calculate progress percentage (NA when content_required == 0)
  if (all(c("content_completed", "content_required") %in% names(result))) {
    result <- dplyr::mutate(
      result,
      progress_pct = dplyr::if_else(
        .data$content_required == 0 | is.na(.data$content_required),
        NA_real_,
        round(.data$content_completed / .data$content_required * 100, 1)
      )
    )
  }

  # Convert last_visited_date to timezone and calculate days since visit
  if ("last_visited_date" %in% names(result)) {
    if (inherits(result$last_visited_date, "POSIXct")) {
      n_na_before <- sum(is.na(result$last_visited_date))
      result$last_visited_date <- lubridate::with_tz(
        result$last_visited_date, tzone = tz
      )
      n_na_after <- sum(is.na(result$last_visited_date))
      if (n_na_after > n_na_before) {
        warn(paste0(
          "Timezone conversion introduced ", n_na_after - n_na_before,
          " NA(s) in `last_visited_date`."
        ))
      }
    }
    now <- lubridate::now(tzone = tz)
    result <- dplyr::mutate(
      result,
      days_since_visit = as.numeric(
        lubridate::interval(.data$last_visited_date, now),
        "days"
      )
    )
  }

  result
}

#' Summarize engagement by grouping dimension
#'
#' Aggregates engagement metrics from Learner Usage data by course, department,
#' or user.
#'
#' @param learner_usage A tibble from the Learner Usage ADS.
#' @param by Grouping dimension: `"course"`, `"department"`, or `"user"`.
#'
#' @return A summarised tibble sorted by `mean_progress` descending (or
#'   `last_activity` for user grouping).
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' usage <- bs_get_ads("Learner Usage")
#' bs_engagement_summary(usage, by = "course")
#' bs_engagement_summary(usage, by = "department")
#' bs_engagement_summary(usage, by = "user")
#' }
#' }
bs_engagement_summary <- function(learner_usage,
                                  by = c("course", "department", "user")) {
  by <- match.arg(by)
  engaged <- bs_course_engagement(learner_usage)

  if (by == "course") {
    group_cols <- intersect(c("org_unit_id", "course_offering_name"),
                            names(engaged))
    result <- engaged |>
      dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
      dplyr::summarize(
        n_users = dplyr::n(),
        mean_progress = mean(.data$progress_pct, na.rm = TRUE),
        median_progress = stats::median(.data$progress_pct, na.rm = TRUE),
        mean_logins = mean(.data$login_count, na.rm = TRUE),
        total_quiz_completed = sum(.data$quiz_completed, na.rm = TRUE),
        total_assignments_completed = sum(.data$assignment_completed,
                                          na.rm = TRUE),
        total_discussion_posts = sum(.data$discussion_posts_created,
                                     na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::arrange(dplyr::desc(.data$mean_progress))
  } else if (by == "department") {
    group_cols <- intersect(c("parent_department_name"), names(engaged))
    result <- engaged |>
      dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
      dplyr::summarize(
        n_users = dplyr::n(),
        mean_progress = mean(.data$progress_pct, na.rm = TRUE),
        median_progress = stats::median(.data$progress_pct, na.rm = TRUE),
        mean_logins = mean(.data$login_count, na.rm = TRUE),
        total_quiz_completed = sum(.data$quiz_completed, na.rm = TRUE),
        total_assignments_completed = sum(.data$assignment_completed,
                                          na.rm = TRUE),
        total_discussion_posts = sum(.data$discussion_posts_created,
                                     na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::arrange(dplyr::desc(.data$mean_progress))
  } else {
    # by == "user"
    group_cols <- intersect(
      c("user_id", "org_defined_id", "first_name", "last_name"),
      names(engaged)
    )
    result <- engaged |>
      dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
      dplyr::summarize(
        n_courses = dplyr::n(),
        mean_progress = mean(.data$progress_pct, na.rm = TRUE),
        total_logins = sum(.data$login_count, na.rm = TRUE),
        last_activity = max(.data$last_visited_date, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::arrange(dplyr::desc(.data$mean_progress))
  }

  result
}

# ---- Performance Analysis ----------------------------------------------------

#' Summarize grades with percentages
#'
#' Joins grade results with grade object definitions and calculates grade
#' percentages.
#'
#' @param grade_results A tibble from the Grade Results dataset.
#' @param grade_objects A tibble from the Grade Objects dataset.
#'
#' @return A joined tibble with grade object name, type, max points, and
#'   calculated `grade_pct` and `grade_label`.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' grades <- bs_get_dataset("Grade Results")
#' objects <- bs_get_dataset("Grade Objects")
#' bs_grade_summary(grades, objects)
#' }
#' }
bs_grade_summary <- function(grade_results, grade_objects) {
  # Join grades with grade object definitions
  result <- bs_join_grades_objects(grade_results, grade_objects)

  # Filter out deleted records
  if ("is_deleted" %in% names(result)) {
    result <- dplyr::filter(result, !.data$is_deleted)
  }

  # Calculate percentage and label
  result <- dplyr::mutate(
    result,
    grade_pct = dplyr::if_else(
      is.na(.data$points_denominator) | .data$points_denominator == 0,
      NA_real_,
      round(.data$points_numerator / .data$points_denominator * 100, 1)
    ),
    grade_label = dplyr::if_else(
      is.na(.data$grade_pct),
      NA_character_,
      paste0(.data$grade_pct, "%")
    )
  )

  result
}

#' Summarize assessment performance per user per quiz
#'
#' Aggregates quiz attempt data into per-user per-quiz performance summaries
#' including best, average, and latest scores.
#'
#' @param quiz_attempts A tibble from the Quiz Attempts dataset.
#'
#' @return A summarised tibble with one row per user per quiz per org unit.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' attempts <- bs_get_dataset("Quiz Attempts")
#' bs_assessment_performance(attempts)
#' }
#' }
bs_assessment_performance <- function(quiz_attempts) {
  result <- quiz_attempts

  # Filter to graded, non-deleted attempts
  if ("is_graded" %in% names(result)) {
    result <- dplyr::filter(result, .data$is_graded == TRUE)
  }
  if ("is_deleted" %in% names(result)) {
    result <- dplyr::filter(result, !.data$is_deleted)
  }

  # Order by time_completed for latest score
  if ("time_completed" %in% names(result)) {
    result <- dplyr::arrange(result, .data$time_completed)
  }

  result |>
    dplyr::group_by(.data$user_id, .data$quiz_id, .data$org_unit_id) |>
    dplyr::summarize(
      n_attempts = dplyr::n(),
      best_score = max(.data$score, na.rm = TRUE),
      avg_score = mean(.data$score, na.rm = TRUE),
      latest_score = dplyr::last(.data$score),
      possible_score = max(.data$possible_score, na.rm = TRUE),
      best_pct = dplyr::if_else(
        max(.data$possible_score, na.rm = TRUE) == 0,
        NA_real_,
        round(max(.data$score, na.rm = TRUE) /
                max(.data$possible_score, na.rm = TRUE) * 100, 1)
      ),
      first_attempt = min(.data$time_started, na.rm = TRUE),
      last_attempt = max(.data$time_completed, na.rm = TRUE),
      .groups = "drop"
    )
}

#' Summarize assignment submission completion
#'
#' Aggregates assignment submission data per assignment per org unit, including
#' grading rates and score statistics.
#'
#' @param assignment_submissions A tibble from the Assignment Submissions
#'   dataset.
#'
#' @return A summarised tibble with one row per assignment per org unit.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' submissions <- bs_get_dataset("Assignment Submissions")
#' bs_assignment_completion(submissions)
#' }
#' }
bs_assignment_completion <- function(assignment_submissions) {
  result <- assignment_submissions

  # Filter out deleted
  if ("is_deleted" %in% names(result)) {
    result <- dplyr::filter(result, !.data$is_deleted)
  }

  result |>
    dplyr::group_by(.data$dropbox_id, .data$org_unit_id) |>
    dplyr::summarize(
      n_submitted = dplyr::n(),
      n_graded = sum(.data$is_graded, na.rm = TRUE),
      grading_rate = .data$n_graded / .data$n_submitted,
      mean_score = mean(.data$score, na.rm = TRUE),
      median_score = stats::median(.data$score, na.rm = TRUE),
      latest_submission = max(.data$last_submission_date, na.rm = TRUE),
      .groups = "drop"
    )
}

# ---- Retention & Risk --------------------------------------------------------

#' Identify at-risk students
#'
#' Flags at-risk students from Learner Usage data based on configurable
#' thresholds. Adds boolean risk flags and a composite risk score.
#'
#' @param learner_usage A tibble from the Learner Usage ADS.
#' @param thresholds A named list of thresholds to override defaults. Available
#'   thresholds: `progress` (default 25), `inactive_days` (default 14),
#'   `login_min` (default 2).
#'
#' @return A tibble with all original columns plus risk flags (`never_accessed`,
#'   `low_progress`, `inactive`, `low_logins`), `risk_score` (0-4), and
#'   `risk_level` (ordered factor: Low, Medium, High, Critical), sorted by
#'   risk_score descending.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' usage <- bs_get_ads("Learner Usage")
#' at_risk <- bs_identify_at_risk(usage)
#' at_risk <- bs_identify_at_risk(usage, thresholds = list(progress = 30))
#' }
#' }
bs_identify_at_risk <- function(learner_usage, thresholds = list()) {
  defaults <- list(progress = 25, inactive_days = 14, login_min = 2)
  thresholds <- utils::modifyList(defaults, thresholds)

  # Get engagement metrics
  result <- bs_course_engagement(learner_usage)

  # Add boolean risk flags
  result <- dplyr::mutate(
    result,
    never_accessed = is.na(.data$login_count) | .data$login_count == 0,
    low_progress = dplyr::if_else(
      is.na(.data$progress_pct), TRUE,
      .data$progress_pct < thresholds$progress
    ),
    inactive = dplyr::if_else(
      is.na(.data$days_since_visit), TRUE,
      .data$days_since_visit > thresholds$inactive_days
    ),
    low_logins = dplyr::if_else(
      is.na(.data$login_count), TRUE,
      .data$login_count < thresholds$login_min
    )
  )

  # Composite risk score (0-4)
  result <- dplyr::mutate(
    result,
    risk_score = as.integer(.data$never_accessed) +
      as.integer(.data$low_progress) +
      as.integer(.data$inactive) +
      as.integer(.data$low_logins),
    risk_level = factor(
      dplyr::case_when(
        .data$risk_score >= 3 ~ "Critical",
        .data$risk_score == 2 ~ "High",
        .data$risk_score == 1 ~ "Medium",
        TRUE ~ "Low"
      ),
      levels = c("Low", "Medium", "High", "Critical"),
      ordered = TRUE
    )
  )

  result <- dplyr::arrange(result, dplyr::desc(.data$risk_score))

  n_at_risk <- sum(result$risk_score >= 1, na.rm = TRUE)
  n_crit <- sum(result$risk_level == "Critical", na.rm = TRUE)
  n_high <- sum(result$risk_level == "High", na.rm = TRUE)
  cli_alert_info(
    "Identified {n_at_risk} at-risk learner{?s} ({n_crit} critical, {n_high} high)"
  )

  result
}

#' Summarize retention and dropout rates
#'
#' Calculates retention metrics by course or department, including start rates,
#' completion rates, and dropout rates.
#'
#' @param learner_usage A tibble from the Learner Usage ADS.
#' @param by Grouping dimension: `"course"` or `"department"`.
#'
#' @return A summarised tibble sorted by `completion_rate`.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' usage <- bs_get_ads("Learner Usage")
#' bs_retention_summary(usage, by = "course")
#' }
#' }
bs_retention_summary <- function(learner_usage,
                                 by = c("course", "department")) {
  by <- match.arg(by)
  engaged <- bs_course_engagement(learner_usage)

  # Classify each record
  engaged <- dplyr::mutate(
    engaged,
    started = !is.na(.data$login_count) & .data$login_count > 0,
    completed = !is.na(.data$progress_pct) & .data$progress_pct >= 100
  )

  if (by == "course") {
    group_cols <- intersect(c("org_unit_id", "course_offering_name"),
                            names(engaged))
  } else {
    group_cols <- intersect(c("parent_department_name"), names(engaged))
  }

  engaged |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
    dplyr::summarize(
      n_enrolled = dplyr::n(),
      n_started = sum(.data$started, na.rm = TRUE),
      n_completed = sum(.data$completed, na.rm = TRUE),
      start_rate = .data$n_started / .data$n_enrolled,
      completion_rate = .data$n_completed / .data$n_enrolled,
      dropout_rate = dplyr::if_else(
        .data$n_started == 0, NA_real_,
        (.data$n_started - .data$n_completed) / .data$n_started
      ),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$completion_rate))
}

# ---- Engagement Scoring Helpers ----------------------------------------------

#' Add a composite engagement score
#'
#' Adds a weighted composite `engagement_score` column to any tibble that has
#' raw activity count columns. Default weights reflect relative effort/depth
#' (login is passive, assignment is active). Users should override for their
#' context.
#'
#' @param df A tibble with activity count columns.
#' @param weights A named list of column-weight pairs to override defaults.
#'   Defaults: `login_count = 1`, `quiz_completed = 3`,
#'   `assignment_completed = 5`, `discussion_posts_created = 2`.
#'
#' @return The input tibble with an `engagement_score` column appended.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' usage <- bs_get_ads("Learner Usage")
#' scored <- bs_engagement_score(usage)
#' scored <- bs_engagement_score(usage, weights = list(login_count = 2))
#' }
#' }
bs_engagement_score <- function(df, weights = list()) {
  defaults <- list(
    login_count = 1,
    quiz_completed = 3,
    assignment_completed = 5,
    discussion_posts_created = 2
  )
  weights <- utils::modifyList(defaults, weights)

  # Only use columns that exist in the data
  present <- intersect(names(weights), names(df))
  missing <- setdiff(names(weights), names(df))

  if (length(missing) > 0) {
    warn(paste0(
      "Columns not found (skipped): ",
      paste(missing, collapse = ", ")
    ))
  }

  if (length(present) == 0) {
    abort("No weighted columns found in data frame.")
  }

  # Calculate weighted sum
  score <- rep(0, nrow(df))
  for (col in present) {
    vals <- df[[col]]
    vals[is.na(vals)] <- 0
    score <- score + vals * weights[[col]]
  }

  df$engagement_score <- score
  df
}

# ---- Course Effectiveness ----------------------------------------------------

#' Summarize course effectiveness
#'
#' Creates a per-course dashboard view with engagement, progress, and optionally
#' award-based completion metrics. `completion_rate_progress` uses content
#' progress (available from Learner Usage alone); `completion_rate_awards` uses
#' certificate issuance (more authoritative but requires Awards Issued dataset).
#'
#' @param learner_usage A tibble from the Learner Usage ADS.
#' @param awards Optional tibble from the Awards Issued ADS. When provided,
#'   adds award-based completion rate.
#'
#' @return A summarised tibble with one row per course, sorted by `n_learners`
#'   descending.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' usage <- bs_get_ads("Learner Usage")
#' bs_course_summary(usage)
#'
#' awards <- bs_get_ads("Awards Issued")
#' bs_course_summary(usage, awards = awards)
#' }
#' }
bs_course_summary <- function(learner_usage, awards = NULL) {
  engaged <- bs_course_engagement(learner_usage)

  # Join awards if provided
  if (!is.null(awards)) {
    join_cols <- intersect(c("user_id", "org_unit_id"), names(awards))
    engaged <- dplyr::left_join(engaged, awards, by = join_cols,
                                suffix = c("", "_award"))
    if ("issue_date" %in% names(engaged)) {
      engaged <- dplyr::mutate(
        engaged,
        completed_award = !is.na(.data$issue_date)
      )
    }
  }

  group_cols <- intersect(
    c("org_unit_id", "course_offering_name", "parent_department_name"),
    names(engaged)
  )

  result <- engaged |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
    dplyr::summarize(
      n_learners = dplyr::n_distinct(.data$user_id),
      mean_progress = mean(.data$progress_pct, na.rm = TRUE),
      median_progress = stats::median(.data$progress_pct, na.rm = TRUE),
      completion_rate_progress = mean(
        !is.na(.data$progress_pct) & .data$progress_pct >= 100,
        na.rm = TRUE
      ),
      mean_logins = mean(.data$login_count, na.rm = TRUE),
      median_logins = stats::median(.data$login_count, na.rm = TRUE),
      mean_quiz_completed = mean(.data$quiz_completed, na.rm = TRUE),
      mean_assignments_completed = mean(.data$assignment_completed,
                                        na.rm = TRUE),
      mean_discussion_posts = mean(.data$discussion_posts_created,
                                   na.rm = TRUE),
      .groups = "drop"
    )

  # Add award-based completion rate if awards were joined
  if ("completed_award" %in% names(engaged)) {
    award_rates <- engaged |>
      dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
      dplyr::summarize(
        completion_rate_awards = mean(.data$completed_award, na.rm = TRUE),
        .groups = "drop"
      )
    result <- dplyr::left_join(result, award_rates, by = group_cols)
  } else {
    result$completion_rate_awards <- NA_real_
  }

  dplyr::arrange(result, dplyr::desc(.data$n_learners))
}

# ---- Internal helpers --------------------------------------------------------

#' Coerce ADS column types and normalise column names
#'
#' ADS CSVs may arrive with all-character columns. This function coerces known
#' numeric columns to integer, parses date columns, and maps ADS column name
#' variants (e.g., `number_of_logins_to_the_system`) to the short names the
#' analytics functions expect (e.g., `login_count`).
#'
#' @param df A tibble from an ADS export.
#' @return The tibble with corrected types and aliased columns.
#' @keywords internal
bs_coerce_ads_types <- function(df) {
  # Coerce numeric columns that may be character
  numeric_cols <- c(
    "content_completed", "content_required", "login_count",
    "quiz_completed", "total_quiz_attempts", "discussion_posts_created",
    "discussion_posts_read", "assignment_completed", "assignment_submissions",
    "number_of_logins_to_the_system", "number_of_assignment_submissions",
    "discussion_post_created", "discussion_post_read",
    "discussion_post_replies", "checklist_completed",
    "course_offering_id", "user_id", "role_id"
  )
  for (col in intersect(numeric_cols, names(df))) {
    if (is.character(df[[col]])) {
      df[[col]] <- suppressWarnings(as.integer(df[[col]]))
    }
  }

  # Map ADS column name variants to the names analytics functions expect
  aliases <- c(
    login_count = "number_of_logins_to_the_system",
    assignment_completed = "number_of_assignment_submissions",
    discussion_posts_created = "discussion_post_created",
    discussion_posts_read = "discussion_post_read"
  )
  for (new_name in names(aliases)) {
    old_name <- aliases[[new_name]]
    if (old_name %in% names(df) && !new_name %in% names(df)) {
      df[[new_name]] <- df[[old_name]]
    }
  }

  # Parse date columns that may still be character
  date_cols <- c("last_visited_date", "last_system_login")
  for (col in intersect(date_cols, names(df))) {
    if (is.character(df[[col]])) {
      df[[col]] <- readr::parse_datetime(df[[col]],
        format = "", na = c("", "NA", "null")
      )
    }
  }

  df
}
