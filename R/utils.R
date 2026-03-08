#' Set the timezone for Brightspace analytics
#'
#' All analytics functions use this timezone for converting date columns.
#'
#' @param tz A valid timezone string from [OlsonNames()].
#'
#' @return Invisibly returns the timezone string.
#' @export
#'
#' @examples
#' bs_set_timezone("Pacific/Auckland")
#' bs_set_timezone("America/New_York")
bs_set_timezone <- function(tz) {
  if (!tz %in% OlsonNames()) {
    abort(c(
      paste0("Invalid timezone: ", tz),
      i = "Use `OlsonNames()` to see valid timezone strings."
    ))
  }
  options(brightspaceR.timezone = tz)
  cli_alert_success("Timezone set to {.val {tz}}")
  invisible(tz)
}

#' Get the current Brightspace analytics timezone
#'
#' Returns the timezone set by [bs_set_timezone()], defaulting to `"UTC"`.
#'
#' @return Character string of the timezone.
#' @export
#'
#' @examples
#' bs_get_timezone()
bs_get_timezone <- function() {
  getOption("brightspaceR.timezone", "UTC")
}

#' Get or set the Brightspace API version
#'
#' @param version If provided, sets the API version. If `NULL`, returns the
#'   current version.
#'
#' @return Character string of the API version.
#' @export
#'
#' @examples
#' bs_api_version()
#' bs_api_version("1.49")
bs_api_version <- function(version = NULL) {
  if (!is.null(version)) {
    options(brightspaceR.api_version = version)
    invisible(version)
  } else {
    getOption("brightspaceR.api_version", "1.49")
  }
}

#' Build a BDS API path
#'
#' @param ... Path components to append after the versioned API prefix.
#'
#' @return Character string of the full API path.
#' @keywords internal
bs_bds_path <- function(...) {
  version <- bs_api_version()
  parts <- c("d2l", "api", "lp", version, "datasets", "bds", ...)
  paste(parts, collapse = "/")
}

#' Paginate through Brightspace API results
#'
#' Handles the Brightspace `ObjectListPage` pagination pattern (bookmark-based).
#'
#' @param path API path.
#' @param query Base query parameters.
#' @param items_field Name of the field containing the items list.
#'
#' @return A list of all items across pages.
#' @keywords internal
bs_paginate <- function(path, query = list(), items_field = "BdsType") {
  all_items <- list()
  bookmark <- NULL

  repeat {
    q <- query
    if (!is.null(bookmark)) {
      q$bookmark <- bookmark
    }

    resp <- bs_get(path, query = q)

    items <- resp[[items_field]]
    if (is.null(items) || length(items) == 0) {
      break
    }

    all_items <- c(all_items, items)

    # Check for next page
    paging <- resp$PagingInfo %||% resp$Paging
    if (!is.null(paging) && !is.null(paging$Bookmark) && paging$HasMoreItems) {
      bookmark <- paging$Bookmark
    } else if (!is.null(resp$Next)) {
      # Some endpoints use a "Next" URL for pagination
      bookmark <- httr2::url_parse(resp$Next)$query$bookmark
      if (is.null(bookmark)) break
    } else {
      break
    }
  }

  all_items
}

#' Extract a ZIP file to a temporary directory
#'
#' @param zip_path Path to the ZIP file.
#'
#' @return Path to the temporary directory containing extracted files.
#' @keywords internal
bs_unzip <- function(zip_path) {
  tmp_dir <- tempfile("brightspaceR_")
  dir.create(tmp_dir, recursive = TRUE)
  utils::unzip(zip_path, exdir = tmp_dir)
  tmp_dir
}

#' Convert PascalCase or mixed-case names to snake_case
#'
#' @param x Character vector of names.
#'
#' @return Character vector of snake_case names.
#' @keywords internal
to_snake_case <- function(x) {
  # Replace spaces with underscores (handles ADS column names like
  # "Course Offering Id")
  x <- gsub("\\s+", "_", x)
  # Insert underscore before uppercase letters that follow lowercase letters
  x <- gsub("([a-z])([A-Z])", "\\1_\\2", x)
  # Insert underscore before uppercase letters that are followed by lowercase
  # (handles sequences like "HTTPRequest" -> "HTTP_Request")
  x <- gsub("([A-Z]+)([A-Z][a-z])", "\\1_\\2", x)
  # Convert to lowercase
  x <- tolower(x)
  # Replace multiple underscores with single
  x <- gsub("_+", "_", x)
  # Remove leading/trailing underscores
  x <- gsub("^_|_$", "", x)
  x
}

#' Normalize a dataset name to a clean identifier
#'
#' Converts a dataset name like "Users" or "User Enrollments" to a snake_case
#' key like "users" or "user_enrollments".
#'
#' @param name Dataset name.
#'
#' @return Character string.
#' @keywords internal
normalize_dataset_name <- function(name) {
  name <- gsub("[^A-Za-z0-9 ]", "", name)
  name <- trimws(name)
  name <- gsub("\\s+", "_", name)
  tolower(name)
}
