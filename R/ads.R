#' Build an ADS (Advanced Data Sets) API path
#'
#' @param ... Path components to append after the versioned dataExport prefix.
#'
#' @return Character string of the full API path.
#' @keywords internal
bs_ads_path <- function(...) {
  version <- bs_api_version()
  parts <- c("d2l", "api", "lp", version, "dataExport", ...)
  paste(parts, collapse = "/")
}

#' ADS job status codes
#'
#' @keywords internal
ads_status_text <- c(
  "Queued",
  "Processing",

  "Complete",
  "Error",
  "Deleted"
)

#' List available Advanced Data Sets
#'
#' Retrieves all available ADS datasets from the Brightspace instance.
#'
#' @return A tibble with columns: `dataset_id`, `name`, `description`,
#'   `category`.
#' @export
#'
#' @examples
#' \dontrun{
#' ads <- bs_list_ads()
#' ads
#' }
bs_list_ads <- function() {
  path <- bs_ads_path("list")
  items <- tryCatch(
    bs_get(path),
    error = function(e) {
      if (grepl("403", e$message)) {
        cli_alert_warning(paste0(
          "ADS access denied (403 Forbidden). ",
          "Your OAuth2 app may not have the required {.val reporting:*} scopes."
        ))
        cli_alert_info(paste0(
          "Required scopes: {.val reporting:dataset:list}, ",
          "{.val reporting:job:create}, {.val reporting:job:download}. ",
          "See {.fun bs_check_scopes} to diagnose."
        ))
        return(NULL)
      }
      stop(e)
    }
  )

  if (is.null(items)) {
    return(tibble::tibble(
      dataset_id = character(),
      name = character(),
      description = character(),
      category = character()
    ))
  }

  if (length(items) == 0) {
    cli_alert_warning("No ADS datasets found.")
    return(tibble::tibble(
      dataset_id = character(),
      name = character(),
      description = character(),
      category = character()
    ))
  }

  tibble::tibble(
    dataset_id = purrr::map_chr(items, "DataSetId", .default = NA_character_),
    name = purrr::map_chr(items, "Name", .default = NA_character_),
    description = purrr::map_chr(items, "Description",
                                 .default = NA_character_),
    category = purrr::map_chr(items, "Category", .default = NA_character_)
  )
}

#' Build an ADS export filter
#'
#' Constructs a filter list for use with [bs_create_ads_job()] and
#' [bs_get_ads()]. Produces the `[{Name, Value}]` array format that the
#' Brightspace dataExport create endpoint expects.
#'
#' @param start_date Start date (Date, POSIXct, or character in
#'   "YYYY-MM-DD" format). Optional.
#' @param end_date End date (Date, POSIXct, or character in
#'   "YYYY-MM-DD" format). Optional.
#' @param parent_org_unit_id Integer org unit ID to filter by. Optional.
#' @param roles Integer vector of role IDs to filter by. Optional.
#'
#' @return A list of `list(Name = ..., Value = ...)` filter objects.
#' @export
#'
#' @examples
#' bs_ads_filter(start_date = "2024-01-01", end_date = "2024-12-31")
#' bs_ads_filter(parent_org_unit_id = 6606)
#' bs_ads_filter(roles = c(110, 120))
bs_ads_filter <- function(start_date = NULL, end_date = NULL,
                          parent_org_unit_id = NULL, roles = NULL) {
  filters <- list()

  if (!is.null(start_date)) {
    filters <- c(filters, list(list(
      Name = "startDate", Value = format_iso8601(start_date)
    )))
  }
  if (!is.null(end_date)) {
    filters <- c(filters, list(list(
      Name = "endDate", Value = format_iso8601(end_date)
    )))
  }
  if (!is.null(parent_org_unit_id)) {
    filters <- c(filters, list(list(
      Name = "parentOrgUnitId", Value = as.character(parent_org_unit_id)
    )))
  }
  if (!is.null(roles)) {
    # Roles are comma-separated in a single filter value
    filters <- c(filters, list(list(
      Name = "roles", Value = paste(as.integer(roles), collapse = ",")
    )))
  }

  filters
}

#' Format a date as ISO 8601 UTC string
#'
#' @param x Date, POSIXct, or character date.
#' @return Character string in ISO 8601 UTC format.
#' @keywords internal
format_iso8601 <- function(x) {
  if (is.character(x)) {
    x <- as.POSIXct(x, tz = "UTC")
  } else if (inherits(x, "Date")) {
    x <- as.POSIXct(x, tz = "UTC")
  }
  format(x, "%Y-%m-%dT%H:%M:%S.000Z", tz = "UTC")
}

#' Create an ADS export job
#'
#' Submits a new export job for the named ADS dataset. Use
#' [bs_ads_job_status()] to poll for completion, then
#' [bs_download_ads()] to retrieve the result.
#'
#' @param name Dataset name (case-insensitive). For example,
#'   `"Learner Usage"`.
#' @param filters Optional filter list from [bs_ads_filter()].
#'
#' @return A tibble with one row containing `export_job_id`, `dataset_id`,
#'   `name`, `status`, `status_text`, `submit_date`.
#' @export
#'
#' @examples
#' \dontrun{
#' job <- bs_create_ads_job("Learner Usage")
#' job$export_job_id
#' }
bs_create_ads_job <- function(name, filters = list()) {
  # Look up dataset ID by name
  datasets <- bs_list_ads()
  idx <- which(tolower(datasets$name) == tolower(name))

  if (length(idx) == 0) {
    idx <- grep(name, datasets$name, ignore.case = TRUE)
  }

  if (length(idx) == 0) {
    abort(c(
      "ADS dataset {.val {name}} not found.",
      i = "Use {.fun bs_list_ads} to see available datasets."
    ))
  }

  if (length(idx) > 1) {
    matches <- datasets$name[idx]
    cli_alert_warning(
      "Multiple matches found: {.val {matches}}. Using the first match."
    )
    idx <- idx[1]
  }

  ds <- datasets[idx, ]

  # Auto-fill required filters with sensible defaults
  filters <- bs_auto_fill_filters(ds$dataset_id, filters)

  cli_alert_info("Creating ADS export job for {.val {ds$name}}...")

  body <- list(DataSetId = ds$dataset_id, Filters = filters)
  path <- bs_ads_path("create")
  resp <- bs_post(path, body)

  status_code <- resp$Status %||% 0L
  status_label <- ads_status_text[status_code + 1L] %||% "Unknown"

  cli_alert_success("Job created (status: {status_label})")

  tibble::tibble(
    export_job_id = resp$ExportJobId %||% NA_character_,
    dataset_id = ds$dataset_id,
    name = ds$name,
    status = status_code,
    status_text = status_label,
    submit_date = resp$SubmitDate %||% NA_character_
  )
}

#' Check ADS export job status
#'
#' @param job_id Export job ID returned by [bs_create_ads_job()].
#'
#' @return A list with `export_job_id`, `name`, `status` (integer),
#'   `status_text` (character), and `submit_date`.
#' @export
#'
#' @examples
#' \dontrun{
#' status <- bs_ads_job_status("abc-123")
#' status$status_text
#' }
bs_ads_job_status <- function(job_id) {
  path <- bs_ads_path("jobs", job_id)
  resp <- bs_get(path)

  status_code <- resp$Status %||% 0L
  status_label <- ads_status_text[status_code + 1L] %||% "Unknown"

  list(
    export_job_id = resp$ExportJobId %||% job_id,
    name = resp$Name %||% NA_character_,
    status = status_code,
    status_text = status_label,
    submit_date = resp$SubmitDate %||% NA_character_
  )
}

#' List all submitted ADS export jobs
#'
#' @return A tibble of all submitted export jobs with columns:
#'   `export_job_id`, `name`, `dataset_id`, `status`, `status_text`,
#'   `submit_date`.
#' @export
#'
#' @examples
#' \dontrun{
#' bs_list_ads_jobs()
#' }
bs_list_ads_jobs <- function() {
  path <- bs_ads_path("jobs")
  items <- bs_get(path)

  if (length(items) == 0) {
    cli_alert_warning("No ADS export jobs found.")
    return(tibble::tibble(
      export_job_id = character(),
      name = character(),
      dataset_id = character(),
      status = integer(),
      status_text = character(),
      submit_date = character()
    ))
  }

  tibble::tibble(
    export_job_id = purrr::map_chr(items, "ExportJobId",
                                   .default = NA_character_),
    name = purrr::map_chr(items, "Name", .default = NA_character_),
    dataset_id = purrr::map_chr(items, "DataSetId",
                                .default = NA_character_),
    status = purrr::map_int(items, "Status", .default = NA_integer_),
    status_text = purrr::map_chr(
      items,
      function(x) {
        s <- x$Status %||% 0L
        ads_status_text[s + 1L] %||% "Unknown"
      }
    ),
    submit_date = purrr::map_chr(items, "SubmitDate",
                                 .default = NA_character_)
  )
}

#' Download a completed ADS export
#'
#' Downloads the result of a completed ADS export job, unzips it,
#' and returns a tidy tibble with proper types and snake_case names.
#'
#' @param job_id Export job ID.
#' @param dataset_name Optional dataset name (used for schema lookup).
#'
#' @return A tibble of the dataset contents.
#' @export
#'
#' @examples
#' \dontrun{
#' result <- bs_download_ads("abc-123", "Learner Usage")
#' }
bs_download_ads <- function(job_id, dataset_name = NULL) {
  # Build the download URL
  download_url <- paste0(
    bs_instance_url(), "/",
    bs_ads_path("download", job_id)
  )

  cli_alert_info("Export ready. Downloading...")

  zip_path <- tempfile(fileext = ".zip")
  bs_download(download_url, zip_path)

  # Extract and parse
  tmp_dir <- bs_unzip(zip_path)
  csv_files <- list.files(tmp_dir, pattern = "\\.csv$", full.names = TRUE,
                          recursive = TRUE)

  if (length(csv_files) == 0) {
    abort("No CSV files found in the downloaded ADS export.")
  }

  result <- bs_parse_csv(csv_files[[1]], dataset_name = dataset_name)

  # Clean up
  unlink(zip_path)
  unlink(tmp_dir, recursive = TRUE)

  cli_alert_success(
    "Downloaded {.val {dataset_name %||% job_id}}: {nrow(result)} rows x {ncol(result)} cols"
  )

  result
}

#' Get an ADS dataset by name (convenience wrapper)
#'
#' High-level function that finds the dataset by name, creates an export job,
#' polls until complete, downloads the result, and returns a tidy tibble.
#' Intended for interactive use.
#'
#' @param name Dataset name (case-insensitive). For example,
#'   `"Learner Usage"`.
#' @param filters Optional filter list from [bs_ads_filter()].
#' @param poll_interval Seconds between status checks. Default 5.
#' @param timeout Maximum seconds to wait for completion. Default 300.
#'
#' @return A tibble of the dataset contents.
#' @export
#'
#' @examples
#' \dontrun{
#' usage <- bs_get_ads("Learner Usage")
#' usage <- bs_get_ads("Learner Usage",
#'   filters = bs_ads_filter(start_date = "2024-01-01"))
#' }
bs_get_ads <- function(name, filters = list(), poll_interval = 5,
                       timeout = 300) {
  # Create the job — returns NULL if ADS access is denied
  job <- tryCatch(
    bs_create_ads_job(name, filters = filters),
    error = function(e) {
      if (grepl("403", e$message)) {
        cli_alert_warning(paste0(
          "Cannot create ADS export for {.val {name}}: access denied (403). ",
          "Your OAuth2 app needs {.val reporting:*} scopes for ADS access."
        ))
        cli_alert_info("Run {.fun bs_check_scopes} to diagnose scope issues.")
        return(NULL)
      }
      stop(e)
    }
  )

  if (is.null(job)) return(invisible(NULL))
  job_id <- job$export_job_id

  # Poll until complete
  elapsed <- 0
  cli_alert_info("Waiting for export... [{job$status_text}]")


  while (job$status %in% c(0L, 1L)) {
    if (elapsed >= timeout) {
      abort("Timed out after {timeout}s waiting for ADS export job.")
    }
    Sys.sleep(poll_interval)
    elapsed <- elapsed + poll_interval

    status <- bs_ads_job_status(job_id)
    job$status <- status$status
    job$status_text <- status$status_text

    cli_alert_info(
      "Waiting for export... [{status$status_text}] ({elapsed}s)"
    )
  }

  # Check for error

  if (job$status == 3L) {
    abort("ADS export job failed (status: Error).")
  }
  if (job$status == 4L) {
    abort("ADS export job was deleted.")
  }

  # Download
  bs_download_ads(job_id, dataset_name = name)
}

#' Get the root organisation ID
#'
#' Calls `/d2l/api/lp/(version)/organization/info` and returns the org
#' identifier.
#'
#' @return Character string of the root org unit ID.
#' @export
#'
#' @examples
#' \dontrun{
#' bs_org_id()
#' }
bs_org_id <- function() {
  path <- paste("d2l/api/lp", bs_api_version(), "organization/info", sep = "/")
  info <- bs_get(path)
  info$Identifier %||% abort("Could not determine organisation ID.")
}

#' Auto-fill required ADS filters
#'
#' Queries the dataset's filter definitions and fills in sensible defaults for
#' any required filter not already provided by the user.
#'
#' @param dataset_id The ADS dataset GUID.
#' @param user_filters Filters already supplied by the user (list of
#'   `list(Name, Value)` objects).
#'
#' @return A complete filter list with required filters filled in.
#' @keywords internal
bs_auto_fill_filters <- function(dataset_id, user_filters) {
  # Fetch dataset definition to discover required filters
  path <- bs_ads_path("list", dataset_id)
  ds_def <- bs_get(path)

  required <- ds_def$Filters %||% list()
  if (length(required) == 0) return(user_filters)

  # Names the user already provided
  user_names <- tolower(purrr::map_chr(
    user_filters, ~ .x$Name %||% "", .default = ""
  ))

  for (f in required) {
    fname <- f$Name %||% ""
    if (tolower(fname) %in% user_names) next
    if (nzchar(f$DefaultValue %||% "")) next

    # Supply sensible defaults for known filter types
    val <- switch(
      tolower(fname),
      "parentorgunitid" = {
        org_id <- bs_org_id()
        cli_alert_info(
          "Auto-filling filter {.val {fname}} with org ID {.val {org_id}}"
        )
        org_id
      },
      "startdate" = {
        # Default to 3 years ago
        d <- format_iso8601(Sys.Date() - 365 * 3)
        cli_alert_info(
          "Auto-filling filter {.val {fname}} with {.val {d}}"
        )
        d
      },
      "enddate" = {
        d <- format_iso8601(Sys.Date())
        cli_alert_info(
          "Auto-filling filter {.val {fname}} with {.val {d}}"
        )
        d
      },
      "roles" = {
        # Look up the most common role from enrollment data
        role_id <- tryCatch(
          {
            enroll <- bs_get_dataset("Enrolments and Withdrawals")
            tbl <- table(enroll$role_id)
            most_common <- names(which.max(tbl))
            cli_alert_info(
              "Auto-filling filter {.val {fname}} with most common role ({most_common})"
            )
            most_common
          },
          error = function(e) {
            abort(c(
              "Required filter {.val roles} could not be auto-detected.",
              i = "Supply it via {.fun bs_ads_filter}: e.g., {.code bs_ads_filter(roles = 126)}"
            ))
          }
        )
        role_id
      },
      {
        abort(c(
          "Required filter {.val {fname}} has no default.",
          i = "Supply it via {.fun bs_ads_filter}."
        ))
      }
    )

    user_filters <- c(user_filters, list(list(Name = fname, Value = val)))
  }

  user_filters
}
