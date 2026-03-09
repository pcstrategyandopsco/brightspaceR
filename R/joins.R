#' Join users with enrollments
#'
#' Left joins a users tibble with an enrollments tibble on `user_id`.
#'
#' @param users A tibble from the Users dataset.
#' @param enrollments A tibble from the User Enrollments dataset.
#'
#' @return A joined tibble.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' users <- bs_get_dataset("Users")
#' enrollments <- bs_get_dataset("User Enrollments")
#' bs_join_users_enrollments(users, enrollments)
#' }
#' }
bs_join_users_enrollments <- function(users, enrollments) {
  dplyr::left_join(users, enrollments, by = "user_id")
}

#' Join enrollments with grade results
#'
#' Left joins an enrollments tibble with a grade results tibble on
#' `org_unit_id` and `user_id`.
#'
#' @param enrollments A tibble from the User Enrollments dataset.
#' @param grade_results A tibble from the Grade Results dataset.
#'
#' @return A joined tibble.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' enrollments <- bs_get_dataset("User Enrollments")
#' grades <- bs_get_dataset("Grade Results")
#' bs_join_enrollments_grades(enrollments, grades)
#' }
#' }
bs_join_enrollments_grades <- function(enrollments, grade_results) {
  dplyr::left_join(enrollments, grade_results,
                   by = c("org_unit_id", "user_id"))
}

#' Join grade results with grade objects
#'
#' Left joins a grade results tibble with a grade objects tibble on
#' `grade_object_id` and `org_unit_id`.
#'
#' @param grade_results A tibble from the Grade Results dataset.
#' @param grade_objects A tibble from the Grade Objects dataset.
#'
#' @return A joined tibble.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' grades <- bs_get_dataset("Grade Results")
#' objects <- bs_get_dataset("Grade Objects")
#' bs_join_grades_objects(grades, objects)
#' }
#' }
bs_join_grades_objects <- function(grade_results, grade_objects) {
  dplyr::left_join(grade_results, grade_objects,
                   by = c("grade_object_id", "org_unit_id"))
}

#' Join content objects with user progress
#'
#' Left joins a content objects tibble with a content user progress tibble
#' on `content_object_id` and `org_unit_id`.
#'
#' @param content_objects A tibble from the Content Objects dataset.
#' @param content_progress A tibble from the Content User Progress dataset.
#'
#' @return A joined tibble.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' content <- bs_get_dataset("Content Objects")
#' progress <- bs_get_dataset("Content User Progress")
#' bs_join_content_progress(content, progress)
#' }
#' }
bs_join_content_progress <- function(content_objects, content_progress) {
  dplyr::left_join(content_objects, content_progress,
                   by = c("content_object_id", "org_unit_id"))
}

#' Join enrollments with role details
#'
#' Left joins an enrollments tibble with a role details tibble on `role_id`.
#'
#' @param enrollments A tibble from the User Enrollments dataset.
#' @param role_details A tibble from the Role Details dataset.
#'
#' @return A joined tibble.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' enrollments <- bs_get_dataset("User Enrollments")
#' roles <- bs_get_dataset("Role Details")
#' bs_join_enrollments_roles(enrollments, roles)
#' }
#' }
bs_join_enrollments_roles <- function(enrollments, role_details) {
  dplyr::left_join(enrollments, role_details, by = "role_id")
}

#' Join enrollments with org units
#'
#' Left joins an enrollments tibble with an org units tibble on `org_unit_id`.
#'
#' @param enrollments A tibble from the User Enrollments dataset.
#' @param org_units A tibble from the Org Units dataset.
#'
#' @return A joined tibble.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' enrollments <- bs_get_dataset("User Enrollments")
#' org_units <- bs_get_dataset("Org Units")
#' bs_join_enrollments_orgunits(enrollments, org_units)
#' }
#' }
bs_join_enrollments_orgunits <- function(enrollments, org_units) {
  dplyr::left_join(enrollments, org_units, by = "org_unit_id")
}

#' Smart join two BDS tibbles
#'
#' Automatically detects shared key columns between two tibbles based on the
#' schema registry and performs a join. Falls back to joining on common column
#' names if schemas are not available.
#'
#' @param df1 First tibble.
#' @param df2 Second tibble.
#' @param type Join type: `"left"` (default), `"inner"`, `"right"`, `"full"`.
#'
#' @return A joined tibble.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' users <- bs_get_dataset("Users")
#' enrollments <- bs_get_dataset("User Enrollments")
#' bs_join(users, enrollments)
#' }
#' }
bs_join <- function(df1, df2, type = c("left", "inner", "right", "full")) {
  type <- match.arg(type)

  # Find common columns
  common <- intersect(names(df1), names(df2))

  # Filter to likely key columns (ending in _id or known key patterns)
  key_cols <- common[grepl("_id$", common)]

  if (length(key_cols) == 0) {
    # Fall back to all common columns
    key_cols <- common
  }

  if (length(key_cols) == 0) {
    abort(c(
      "No common columns found between the two data frames.",
      i = "Specify join columns manually with {.fun dplyr::left_join}."
    ))
  }

  join_fn <- switch(type,
    left = dplyr::left_join,
    inner = dplyr::inner_join,
    right = dplyr::right_join,
    full = dplyr::full_join
  )

  cli_alert_info("Joining on: {.val {key_cols}}")
  join_fn(df1, df2, by = key_cols)
}
