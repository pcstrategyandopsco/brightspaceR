# ── Person-referencing ID columns per dataset ─────────────────────────────
# These get HMAC-hashed so that pseudonyms replace raw integer IDs.
# Structural IDs (OrgUnitId, GradeObjectId, etc.) are left untouched.
# Internal — not exported.
PERSON_ID_COLUMNS <- list(
  "Users"                        = c("UserId"),
  "User Enrollments"             = c("UserId"),
  "Grade Results"                = c("UserId", "LastModifiedBy"),
  "Assignment Submissions"       = c("SubmitterId", "FeedbackUserId"),
  "Quiz User Answers"            = c("LastModifiedBy"),
  "Content User Progress"        = c("UserId"),
  "Quiz Attempts"                = c("UserId"),
  "Discussion Posts"             = c("UserId"),
  "Discussion Topics"            = c("LastPostUserId", "DeletedByUserId"),
  "Content Objects"              = c("CreatedBy", "LastModifiedBy", "DeletedBy"),
  "Grade Objects"                = c("DeletedByUserId"),
  "Enrollments and Withdrawals"  = c("UserId", "ModifiedByUserId"),
  "Final Grades"                 = c("UserId"),
  "Attendance Records"           = c("UserId")
)

#' Pseudonymise a vector of IDs
#'
#' Replaces each value with an HMAC-SHA256 pseudonym of the form `usr_a3f2b1c8`.
#' The same value + key always produces the same pseudonym, so joins and
#' grouping work correctly within a session.
#'
#' @param values A vector of IDs (integer, numeric, or character). `NA` values
#'   are preserved.
#' @param key A raw vector used as the HMAC key. Generate one per session with
#'   `openssl::rand_bytes(32)`. Required — there is no default, to force
#'   deliberate key management.
#'
#' @return A character vector the same length as `values`, with non-`NA`
#'   entries replaced by `usr_` plus 8 hex characters.
#' @export
#'
#' @examples
#' key <- openssl::rand_bytes(32)
#' bs_pseudonymise_id(c(1, 2, NA, 3), key = key)
bs_pseudonymise_id <- function(values, key) {
  result <- rep(NA_character_, length(values))
  non_na <- !is.na(values)
  if (any(non_na)) {
    hashes <- vapply(as.character(values[non_na]), function(v) {
      raw_hash <- openssl::sha256(charToRaw(v), key = key)
      paste0("usr_", substr(as.character(raw_hash), 1, 8))
    }, character(1), USE.NAMES = FALSE)
    result[non_na] <- hashes
  }
  result
}

#' Pseudonymise person-referencing ID columns in a data frame
#'
#' Applies [bs_pseudonymise_id()] to the person-referencing columns for a
#' known Brightspace Data Set. Structural IDs (OrgUnitId, GradeObjectId, etc.)
#' are left untouched.
#'
#' @param df A data frame (typically from [bs_get_dataset()]).
#' @param dataset_name Character string identifying the BDS dataset (e.g.
#'   `"Users"`, `"Grade Results"`). Used to look up which columns contain
#'   person-referencing IDs.
#' @param key A raw vector used as the HMAC key (passed to
#'   [bs_pseudonymise_id()]).
#' @param columns Character vector of column names to pseudonymise. If `NULL`
#'   (the default), the built-in registry is used based on `dataset_name`. If
#'   `dataset_name` is not in the registry and `columns` is `NULL`, the data
#'   frame is returned unchanged.
#'
#' @return The input data frame with person-referencing columns replaced by
#'   pseudonyms.
#' @export
#'
#' @examples
#' key <- openssl::rand_bytes(32)
#' df <- data.frame(UserId = c(1L, 2L), OrgUnitId = c(10L, 20L))
#' bs_pseudonymise_df(df, "Users", key = key)
bs_pseudonymise_df <- function(df, dataset_name, key, columns = NULL) {
  cols <- columns %||% PERSON_ID_COLUMNS[[dataset_name]]
  if (is.null(cols)) return(df)
  for (col in cols) {
    if (col %in% names(df)) {
      df[[col]] <- bs_pseudonymise_id(df[[col]], key = key)
    }
  }
  df
}

#' Apply a PII field policy to a data frame
#'
#' Filters or redacts columns based on a YAML-driven field policy. This is the
#' same logic the MCP server uses to strip PII before data reaches the AI
#' model.
#'
#' @param df A data frame (typically from [bs_get_dataset()]).
#' @param dataset_name Character string identifying the BDS dataset.
#' @param policy A named list representing the field policy (as returned by
#'   [yaml::read_yaml()]). If `NULL` (the default), loads the bundled
#'   `field_policy.yml` shipped with the package.
#'
#' @details
#' The policy supports three modes per dataset:
#' \describe{
#'   \item{`allow`}{Only the listed fields are kept; all others are dropped.}
#'   \item{`redact`}{The listed fields have their values replaced with
#'     `"[REDACTED]"`; all other fields pass through.}
#'   \item{`all`}{All columns pass through unchanged.}
#' }
#'
#' If `dataset_name` is not found in the policy, the data frame is returned
#' unchanged.
#'
#' @return The input data frame with the field policy applied.
#' @export
#'
#' @examples
#' df <- data.frame(
#'   UserId = 1L, FirstName = "Jane", Organization = "Org1",
#'   stringsAsFactors = FALSE
#' )
#' bs_apply_field_policy(df, "Users")
bs_apply_field_policy <- function(df, dataset_name, policy = NULL) {
  if (is.null(policy)) {
    policy_path <- system.file("mcp", "field_policy.yml", package = "brightspaceR")
    if (policy_path == "") return(df)
    policy <- yaml::read_yaml(policy_path)
  }

  ds_policy <- policy[[dataset_name]]
  if (is.null(ds_policy)) return(df)

  mode <- ds_policy$mode
  if (is.null(mode) || mode == "all") return(df)

  if (mode == "allow") {
    allowed <- ds_policy$fields
    if (is.null(allowed)) return(df)
    keep <- intersect(allowed, names(df))
    return(df[, keep, drop = FALSE])
  }

  if (mode == "redact") {
    redact_cols <- ds_policy$fields
    if (!is.null(redact_cols)) {
      for (col in redact_cols) {
        if (col %in% names(df)) {
          df[[col]] <- "[REDACTED]"
        }
      }
    }
    return(df)
  }

  # Unknown mode — pass through
  df
}
