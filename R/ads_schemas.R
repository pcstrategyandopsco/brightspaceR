#' ADS (Advanced Data Sets) Schema Registry
#'
#' Internal list of column type specifications for known Advanced Data Set
#' datasets. Column names must match the actual CSV headers from Brightspace
#' (lowercase with spaces). After parsing, `to_snake_case()` converts them
#' to snake_case.
#'
#' @keywords internal
bs_ads_schemas <- list(

  # 1. Learner Usage
  learner_usage = list(
    col_types = readr::cols(
      `course offering id` = readr::col_integer(),
      `course offering code` = readr::col_character(),
      `course offering name` = readr::col_character(),
      `parent department name` = readr::col_character(),
      `parent department code` = readr::col_character(),
      `user id` = readr::col_integer(),
      `username` = readr::col_character(),
      `org defined id` = readr::col_character(),
      `first name` = readr::col_character(),
      `last name` = readr::col_character(),
      `is active` = readr::col_character(),
      `role id` = readr::col_integer(),
      `role name` = readr::col_character(),
      `content completed` = readr::col_integer(),
      `content required` = readr::col_integer(),
      `checklist completed` = readr::col_integer(),
      `quiz completed` = readr::col_integer(),
      `total quiz attempts` = readr::col_integer(),
      `discussion post created` = readr::col_integer(),
      `discussion post replies` = readr::col_integer(),
      `discussion post read` = readr::col_integer(),
      `number of assignment submissions` = readr::col_integer(),
      `number of logins to the system` = readr::col_integer(),
      `last visited date` = readr::col_character(),
      `last system login` = readr::col_character(),
      `last discussion post date` = readr::col_character(),
      `last assignment submission date` = readr::col_character(),
      `total time spent in content` = readr::col_character(),
      `last quiz attempt date` = readr::col_character(),
      `last scorm completion date` = readr::col_character(),
      `last scorm visit date` = readr::col_character(),
      .default = readr::col_character()
    ),
    date_cols = c("last visited date", "last system login",
                  "last discussion post date", "last assignment submission date",
                  "last quiz attempt date", "last scorm completion date",
                  "last scorm visit date"),
    bool_cols = c("is active"),
    key_cols = c("course offering id", "user id")
  )
)

#' Get the schema for an ADS dataset
#'
#' @param dataset_name Name of the dataset (will be normalized to snake_case).
#'
#' @return A schema list, or `NULL` if no schema is registered.
#' @export
#'
#' @examples
#' bs_get_ads_schema("Learner Usage")
bs_get_ads_schema <- function(dataset_name) {
  key <- normalize_dataset_name(dataset_name)
  bs_ads_schemas[[key]]
}

#' List all registered ADS dataset schemas
#'
#' @return A character vector of registered dataset names (snake_case).
#' @export
#'
#' @examples
#' bs_list_ads_schemas()
bs_list_ads_schemas <- function() {
  names(bs_ads_schemas)
}
