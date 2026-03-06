#' Create a base Brightspace API request
#'
#' Builds an httr2 request with the correct base URL, OAuth2 token,
#' user-agent, rate limiting, and retry logic.
#'
#' @param path API path (e.g., `/d2l/api/lp/1.49/datasets/bds`).
#'
#' @return An httr2 request object.
#' @keywords internal
bs_request <- function(path) {
  base_url <- bs_instance_url()

  httr2::request(base_url) |>
    httr2::req_url_path_append(path) |>
    httr2::req_auth_bearer_token(bs_token()$access_token) |>
    httr2::req_user_agent("brightspaceR (https://github.com/peeyooshchandra/brightspaceR)") |>
    httr2::req_throttle(rate = 10 / 60) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = bs_is_transient,
      after = bs_retry_after
    ) |>
    httr2::req_error(body = bs_error_body)
}

#' Determine if an HTTP error is transient
#'
#' @param resp An httr2 response.
#' @return Logical.
#' @keywords internal
bs_is_transient <- function(resp) {
  httr2::resp_status(resp) %in% c(429L, 503L)
}

#' Extract retry-after delay from response
#'
#' @param resp An httr2 response.
#' @return Numeric seconds to wait.
#' @keywords internal
bs_retry_after <- function(resp) {
  after <- httr2::resp_header(resp, "Retry-After")
  if (!is.null(after)) {
    as.numeric(after)
  } else {
    5
  }
}

#' Extract error message from Brightspace API response body
#'
#' @param resp An httr2 response.
#' @return Character string with error details.
#' @keywords internal
bs_error_body <- function(resp) {
  body <- tryCatch(
    httr2::resp_body_json(resp),
    error = function(e) NULL
  )

  if (!is.null(body)) {
    msg <- body$Message %||% body$message %||% body$error_description %||%
      body$error %||% "Unknown API error"
    paste0("Brightspace API error: ", msg)
  } else {
    "Brightspace API error (no details available)"
  }
}

#' Perform a GET request and return parsed JSON
#'
#' @param path API path.
#' @param query Named list of query parameters.
#'
#' @return Parsed JSON response as a list.
#' @keywords internal
bs_get <- function(path, query = list()) {
  req <- bs_request(path)

  if (length(query) > 0) {
    req <- httr2::req_url_query(req, !!!query)
  }

  resp <- httr2::req_perform(req)
  httr2::resp_body_json(resp)
}

#' Download a file from a URL
#'
#' @param url Full URL to download.
#' @param dest_path Destination file path.
#'
#' @return The destination path (invisibly).
#' @keywords internal
bs_download <- function(url, dest_path, download_size = NULL) {
  token <- bs_token()$access_token

  # Use curl directly for reliable progress display
  h <- curl::new_handle()
  curl::handle_setheaders(h,
    Authorization = paste("Bearer", token),
    `User-Agent` = "brightspaceR (https://github.com/peeyooshchandra/brightspaceR)"
  )

  if (!is.null(download_size) && download_size > 0) {
    size_mb <- round(download_size / 1024 / 1024, 1)
    cli_alert_info("Downloading {size_mb} MB...")
  }

  curl::curl_download(url, dest_path, handle = h, quiet = FALSE)

  invisible(dest_path)
}
