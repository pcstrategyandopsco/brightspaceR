#' Authenticate with Brightspace
#'
#' Initiates an OAuth2 Authorization Code flow with PKCE to authenticate with
#' the Brightspace Data Hub API. The resulting token is cached to disk for
#' reuse across sessions and automatically refreshed when expired.
#'
#' The first authentication requires an interactive R session (browser-based
#' login). After that, cached credentials are used automatically — including
#' in non-interactive scripts run via `Rscript`.
#'
#' @param client_id OAuth2 client ID. Resolved in order: this argument,
#'   `config.yml` (if present), `BRIGHTSPACE_CLIENT_ID` env var.
#' @param client_secret OAuth2 client secret. Resolved in order: this argument,
#'   `config.yml` (if present), `BRIGHTSPACE_CLIENT_SECRET` env var.
#' @param instance_url Your Brightspace instance URL (e.g.,
#'   `"https://myschool.brightspace.com"`). Resolved in order: this argument,
#'   `config.yml` (if present), `BRIGHTSPACE_INSTANCE_URL` env var.
#' @param redirect_uri The registered redirect URI. Must match the URI
#'   registered in your Brightspace OAuth2 app exactly. Supports both
#'   `http://localhost` (automatic capture via local server) and
#'   `https://localhost` (browser-based with URL paste).
#' @param scope OAuth2 scope string (space-separated). Resolved from config.yml
#'   or defaults to BDS + ADS scopes.
#'
#' @return Invisibly returns `TRUE` on success.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' bs_auth()
#' bs_auth(
#'   client_id = "my-client-id",
#'   client_secret = "my-secret",
#'   instance_url = "https://myschool.brightspace.com"
#' )
#' }
#' }
bs_auth <- function(client_id = "",
                    client_secret = "",
                    instance_url = "",
                    redirect_uri = "",
                    scope = "") {
  # Resolve credentials: explicit arg > config.yml > env var
  cfg <- bs_config()

  client_id <- bs_resolve_cred(
    client_id, cfg$client_id, "BRIGHTSPACE_CLIENT_ID"
  )
  client_secret <- bs_resolve_cred(
    client_secret, cfg$client_secret, "BRIGHTSPACE_CLIENT_SECRET"
  )
  instance_url <- bs_resolve_cred(
    instance_url, cfg$instance_url, "BRIGHTSPACE_INSTANCE_URL"
  )
  redirect_uri <- bs_resolve_cred(
    redirect_uri, cfg$redirect_uri, "BRIGHTSPACE_REDIRECT_URI",
    fallback = "https://localhost:1410/"
  )
  scope <- bs_resolve_cred(
    scope, cfg$scope, "",
    fallback = paste(
      "datasets:bds:read",
      "datahub:dataexports:read",
      "datahub:dataexports:download",
      "reporting:dataset:list",
      "reporting:dataset:fetch",
      "reporting:job:create",
      "reporting:job:list",
      "reporting:job:fetch",
      "reporting:job:download",
      "users:profile:read"
    )
  )

  if (client_id == "") {
    abort(c(
      "No client ID found.",
      i = "Pass {.arg client_id}, add it to {.file config.yml}, or set {.envvar BRIGHTSPACE_CLIENT_ID}."
    ))
  }
  if (client_secret == "") {
    abort(c(
      "No client secret found.",
      i = "Pass {.arg client_secret}, add it to {.file config.yml}, or set {.envvar BRIGHTSPACE_CLIENT_SECRET}."
    ))
  }
  if (instance_url == "") {
    abort(c(
      "No instance URL found.",
      i = "Pass {.arg instance_url}, add it to {.file config.yml}, or set {.envvar BRIGHTSPACE_INSTANCE_URL}."
    ))
  }

  # Normalize instance URL (remove trailing slash)
  instance_url <- sub("/+$", "", instance_url)

  # Check for cached token first
  cache_path <- bs_token_cache_path(client_id)
  if (file.exists(cache_path)) {
    cached <- readRDS(cache_path)
    if (!is.null(cached$access_token)) {
      .bs_env$token <- cached
      .bs_env$client_id <- client_id
      .bs_env$client_secret <- client_secret
      .bs_env$instance_url <- instance_url
      .bs_env$redirect_uri <- redirect_uri
      .bs_env$scope <- scope

      # Try to refresh if token looks expired
      if (bs_token_needs_refresh(cached)) {
        tryCatch(
          {
            refreshed <- bs_refresh_token(
              cached, client_id, client_secret, scope
            )
            .bs_env$token <- refreshed
            saveRDS(refreshed, cache_path)
            cli_alert_success(
              "Refreshed token for Brightspace at {.url {instance_url}}"
            )
          },
          error = function(e) {
            cli_alert_warning(
              "Token refresh failed, re-authenticating: {e$message}"
            )
            bs_auth_interactive(
              client_id, client_secret, instance_url, redirect_uri, scope
            )
          }
        )
      } else {
        cli_alert_success(
          "Using cached token for Brightspace at {.url {instance_url}}"
        )
      }
      return(invisible(TRUE))
    }
  }

  bs_auth_interactive(client_id, client_secret, instance_url, redirect_uri,
                      scope)
}

#' Interactive browser-based OAuth2 flow
#'
#' Handles two redirect URI schemes:
#' - `http://localhost`: httr2 starts a local server to capture the code
#'   automatically (zero user interaction after browser login).
#' - `https://localhost`: Opens browser, then prompts user to paste the
#'   redirect URL back (browser will show "can't connect" after auth — the
#'   code is in the address bar).
#'
#' Requires an interactive R session. Non-interactive scripts should rely on
#' cached tokens (from a prior interactive auth) or [bs_auth_refresh()].
#'
#' @keywords internal
bs_auth_interactive <- function(client_id, client_secret, instance_url,
                                redirect_uri, scope) {
  if (!interactive()) {
    abort(c(
      "Browser-based authentication requires an interactive R session.",
      i = "Run {.fun bs_auth} once in an interactive R console or RStudio to cache credentials.",
      i = "Cached tokens are reused and refreshed automatically in non-interactive scripts.",
      i = "Alternatively, use {.fun bs_auth_refresh} with a refresh token."
    ))
  }

  # Build an httr2 OAuth client
  client <- httr2::oauth_client(
    id = client_id,
    secret = client_secret,
    token_url = "https://auth.brightspace.com/core/connect/token",
    name = "brightspaceR"
  )

  parsed_uri <- httr2::url_parse(redirect_uri)
  is_localhost_http <- identical(parsed_uri$scheme, "http") &&
    parsed_uri$hostname %in% c("localhost", "127.0.0.1")

  if (is_localhost_http) {
    # Automatic flow: httr2 starts a local HTTP server to capture the code
    port <- parsed_uri$port
    if (is.null(port) || is.na(port)) port <- 1410L

    cli_alert_info(
      "Opening browser for Brightspace authorization (local server on port {port})..."
    )

    token <- httr2::oauth_flow_auth_code(
      client = client,
      auth_url = "https://auth.brightspace.com/oauth2/auth",
      scope = scope,
      redirect_uri = redirect_uri,
      pkce = TRUE,
      port = as.integer(port)
    )
  } else {
    # HTTPS redirect URI flow: browser-based with URL paste-back
    token <- bs_auth_https_flow(
      client_id, client_secret, redirect_uri, scope
    )
  }

  # Add metadata for refresh tracking
  token$created_at <- as.numeric(Sys.time())

  # Store in environment
  .bs_env$token <- token
  .bs_env$client_id <- client_id
  .bs_env$client_secret <- client_secret
  .bs_env$instance_url <- instance_url
  .bs_env$redirect_uri <- redirect_uri
  .bs_env$scope <- scope

  # Cache to disk
  cache_path <- bs_token_cache_path(client_id)
  dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(token, cache_path)

  cli_alert_success("Authenticated with Brightspace at {.url {instance_url}}")
  invisible(TRUE)
}

#' Set Brightspace authentication token directly
#'
#' Sets authentication credentials without going through the browser-based
#' OAuth2 flow. Useful for non-interactive environments or when you already
#' have a valid token.
#'
#' @param token A token list with at least an `access_token` field.
#'   Can also include `refresh_token`, `expires_in`, etc.
#' @param instance_url Your Brightspace instance URL.
#' @param client_id OAuth2 client ID.
#' @param client_secret OAuth2 client secret.
#'
#' @return Invisibly returns `TRUE`.
#' @export
bs_auth_token <- function(token, instance_url,
                          client_id = Sys.getenv("BRIGHTSPACE_CLIENT_ID"),
                          client_secret = Sys.getenv("BRIGHTSPACE_CLIENT_SECRET")) {
  instance_url <- sub("/+$", "", instance_url)

  .bs_env$token <- token
  .bs_env$client_id <- client_id
  .bs_env$client_secret <- client_secret
  .bs_env$instance_url <- instance_url

  cli_alert_success("Token set for Brightspace at {.url {instance_url}}")
  invisible(TRUE)
}

#' Authenticate with a refresh token
#'
#' Authenticates using an existing refresh token, without requiring browser
#' interaction. Ideal for non-interactive scripts and scheduled jobs.
#'
#' @param refresh_token The OAuth2 refresh token string.
#' @param client_id OAuth2 client ID. Defaults to `BRIGHTSPACE_CLIENT_ID`
#'   environment variable.
#' @param client_secret OAuth2 client secret. Defaults to
#'   `BRIGHTSPACE_CLIENT_SECRET` environment variable.
#' @param instance_url Your Brightspace instance URL. Defaults to
#'   `BRIGHTSPACE_INSTANCE_URL` environment variable.
#' @param scope OAuth2 scope.
#'
#' @return Invisibly returns `TRUE` on success.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' bs_auth_refresh(refresh_token = "my-refresh-token")
#' }
#' }
bs_auth_refresh <- function(refresh_token,
                            client_id = Sys.getenv("BRIGHTSPACE_CLIENT_ID"),
                            client_secret = Sys.getenv("BRIGHTSPACE_CLIENT_SECRET"),
                            instance_url = Sys.getenv("BRIGHTSPACE_INSTANCE_URL"),
                            scope = "") {
  cfg <- bs_config()
  if (client_id == "") client_id <- cfg$client_id %||% ""
  if (client_secret == "") client_secret <- cfg$client_secret %||% ""
  if (instance_url == "") instance_url <- cfg$instance_url %||% ""
  if (!nzchar(scope)) {
    scope <- cfg$scope %||% paste(
      "datasets:bds:read",
      "datahub:dataexports:read",
      "datahub:dataexports:download",
      "reporting:dataset:list",
      "reporting:dataset:fetch",
      "reporting:job:create",
      "reporting:job:list",
      "reporting:job:fetch",
      "reporting:job:download",
      "users:profile:read"
    )
  }

  if (client_id == "") {
    abort(c(
      "No client ID found.",
      i = "Set {.envvar BRIGHTSPACE_CLIENT_ID} or pass {.arg client_id}."
    ))
  }
  if (client_secret == "") {
    abort(c(
      "No client secret found.",
      i = "Set {.envvar BRIGHTSPACE_CLIENT_SECRET} or pass {.arg client_secret}."
    ))
  }
  if (instance_url == "") {
    abort(c(
      "No instance URL found.",
      i = "Set {.envvar BRIGHTSPACE_INSTANCE_URL} or pass {.arg instance_url}."
    ))
  }

  instance_url <- sub("/+$", "", instance_url)

  token <- bs_refresh_token(
    list(refresh_token = refresh_token),
    client_id, client_secret, scope
  )

  .bs_env$token <- token
  .bs_env$client_id <- client_id
  .bs_env$client_secret <- client_secret
  .bs_env$instance_url <- instance_url
  .bs_env$scope <- scope

  # Cache to disk
  cache_path <- bs_token_cache_path(client_id)
  dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(token, cache_path)

  cli_alert_success("Authenticated with Brightspace at {.url {instance_url}}")
  invisible(TRUE)
}

#' Clear Brightspace authentication
#'
#' Removes cached credentials from the current session and optionally from
#' disk.
#'
#' @param clear_cache If `TRUE` (default), also removes the cached token from
#'   disk.
#'
#' @return Invisibly returns `TRUE`.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' bs_deauth()
#' }
#' }
bs_deauth <- function(clear_cache = TRUE) {
  if (clear_cache && !is.null(.bs_env$client_id)) {
    cache_path <- bs_token_cache_path(.bs_env$client_id)
    if (file.exists(cache_path)) {
      unlink(cache_path)
    }
  }
  rm(list = ls(.bs_env), envir = .bs_env)
  cli_alert_info("Brightspace credentials cleared.")
  invisible(TRUE)
}

#' Check if authenticated with Brightspace
#'
#' @return Logical; `TRUE` if a token is available.
#' @export
#'
#' @examples
#' bs_has_token()
bs_has_token <- function() {
  !is.null(.bs_env$token)
}

#' Test Brightspace API scope access
#'
#' Verifies which API capabilities are available with the current token by
#' making lightweight test calls to each endpoint group. Useful for diagnosing
#' 403 errors.
#'
#' @return A tibble with columns `scope`, `endpoint`, `status` ("OK" or error
#'   message), printed as a summary table.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' bs_auth()
#' bs_check_scopes()
#' }
#' }
bs_check_scopes <- function() {
  if (!bs_has_token()) {
    abort(c(
      "Not authenticated.",
      i = "Run {.fun bs_auth} first."
    ))
  }

  cli_alert_info("Testing API access with current token...")

  checks <- list(
    list(
      scope = "datasets:bds:read",
      label = "BDS dataset list",
      fn = function() bs_get(bs_bds_path())
    ),
    list(
      scope = "datahub:dataexports:download,read",
      label = "BDS full/diff extracts",
      fn = function() bs_get(bs_bds_path())
    ),
    list(
      scope = "reporting:dataset:list",
      label = "ADS dataset list",
      fn = function() bs_get(bs_ads_path("list"))
    ),
    list(
      scope = "users:profile:read",
      label = "User profile (whoami)",
      fn = function() bs_get("d2l/api/lp/1.49/users/whoami")
    )
  )

  results <- purrr::map(checks, function(chk) {
    status <- tryCatch(
      {
        chk$fn()
        "OK"
      },
      error = function(e) {
        msg <- e$message
        if (grepl("403", msg)) {
          "403 Forbidden"
        } else if (grepl("404", msg)) {
          "404 Not Found"
        } else {
          paste0("Error: ", substr(msg, 1, 80))
        }
      }
    )
    tibble::tibble(
      scope = chk$scope,
      endpoint = chk$label,
      status = status
    )
  })

  result <- dplyr::bind_rows(results)

  n_ok <- sum(result$status == "OK")
  n_fail <- nrow(result) - n_ok

  if (n_fail == 0) {
    cli_alert_success("All {n_ok} scope checks passed.")
  } else {
    cli_alert_warning("{n_ok}/{nrow(result)} passed, {n_fail} failed:")
    failed <- result[result$status != "OK", ]
    for (i in seq_len(nrow(failed))) {
      cli_alert_danger("{failed$endpoint[i]}: {failed$status[i]} (scope: {.val {failed$scope[i]}})")
    }
  }

  invisible(result)
}

#' Get the current Brightspace OAuth token
#'
#' Returns the current access token, refreshing it if expired.
#'
#' @return A token list with `access_token` and related fields.
#' @keywords internal
bs_token <- function() {
  if (!bs_has_token()) {
    abort(c(
      "Not authenticated with Brightspace.",
      i = "Run {.fun bs_auth} first."
    ))
  }

  token <- .bs_env$token

  # Auto-refresh if expired
  if (bs_token_needs_refresh(token) && !is.null(token$refresh_token)) {
    tryCatch(
      {
        token <- bs_refresh_token(
          token,
          .bs_env$client_id,
          .bs_env$client_secret,
          .bs_env$scope %||% ""
        )
        .bs_env$token <- token
        # Update cache
        if (!is.null(.bs_env$client_id)) {
          cache_path <- bs_token_cache_path(.bs_env$client_id)
          saveRDS(token, cache_path)
        }
      },
      error = function(e) {
        cli_alert_warning("Token refresh failed: {e$message}")
      }
    )
  }

  .bs_env$token
}

#' Get the Brightspace instance URL
#'
#' @return Character string of the instance URL.
#' @keywords internal
bs_instance_url <- function() {
  if (is.null(.bs_env$instance_url)) {
    abort(c(
      "No instance URL set.",
      i = "Run {.fun bs_auth} first."
    ))
  }
  .bs_env$instance_url
}

# ---- Internal helpers --------------------------------------------------------

#' HTTPS redirect URI OAuth2 flow
#'
#' Handles the auth code flow when the redirect URI uses HTTPS. Opens the
#' browser for Brightspace login, then prompts the user to paste back the
#' redirect URL (which the browser can't load since no local HTTPS server is
#' running — the authorization code is in the address bar).
#'
#' @param client_id OAuth2 client ID.
#' @param client_secret OAuth2 client secret.
#' @param redirect_uri The HTTPS redirect URI.
#' @param scope OAuth2 scope string.
#'
#' @return A token list.
#' @keywords internal
bs_auth_https_flow <- function(client_id, client_secret, redirect_uri, scope) {
  code_verifier <- bs_random_string(128)
  code_challenge <- bs_pkce_challenge(code_verifier)
  state <- bs_random_string(32)

  auth_url <- httr2::url_parse("https://auth.brightspace.com/oauth2/auth")
  auth_url$query <- list(
    response_type = "code",
    client_id = client_id,
    redirect_uri = redirect_uri,
    scope = scope,
    state = state,
    code_challenge = code_challenge,
    code_challenge_method = "S256"
  )
  auth_url_str <- httr2::url_build(auth_url)

  cli_alert_info("Opening browser for Brightspace authorization...")
  utils::browseURL(auth_url_str)

  cli_alert_info(paste0(
    "After authorizing, your browser will redirect to {.url {redirect_uri}}. ",
    "The page won't load \u2014 this is expected."
  ))
  cli_alert_info(
    "Copy the {.strong entire URL} from your browser's address bar and paste it below."
  )

  redirect_response <- bs_read_auth_response()

  parsed <- httr2::url_parse(redirect_response)
  returned_state <- parsed$query$state
  code <- parsed$query$code
  error <- parsed$query$error

  if (!is.null(error)) {
    abort(c(
      "Authorization failed.",
      x = paste0("Error: ", error),
      i = parsed$query$error_description %||% ""
    ))
  }
  if (is.null(code)) {
    abort(c(
      "No authorization code found in the redirect URL.",
      i = "Make sure you copied the entire URL from your browser's address bar."
    ))
  }
  if (!is.null(returned_state) && returned_state != state) {
    abort("State parameter mismatch. Please try again.")
  }

  token_resp <- httr2::request(
    "https://auth.brightspace.com/core/connect/token"
  ) |>
    httr2::req_body_form(
      grant_type = "authorization_code",
      code = code,
      redirect_uri = redirect_uri,
      client_id = client_id,
      client_secret = client_secret,
      code_verifier = code_verifier
    ) |>
    httr2::req_error(body = bs_error_body) |>
    httr2::req_perform()

  httr2::resp_body_json(token_resp)
}

#' Read the auth redirect URL from the user
#'
#' Uses the best available input method: RStudio dialog if available,
#' otherwise `readline()`.
#'
#' @return Character string with the pasted URL.
#' @keywords internal
bs_read_auth_response <- function() {
  # Prefer RStudio dialog when available — provides a proper GUI input
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    resp <- rstudioapi::showPrompt(
      title = "Brightspace Authorization",
      message = "Paste the redirect URL from your browser:",
      default = ""
    )
    if (is.null(resp)) {
      abort("Authentication cancelled.")
    }
    resp <- trimws(resp)
    if (!nzchar(resp)) {
      abort("No redirect URL provided. Authentication cancelled.")
    }
    return(resp)
  }

  # Fallback to readline for interactive R console
  resp <- readline("Paste the redirect URL here: ")
  resp <- trimws(resp)
  if (!nzchar(resp)) {
    abort("No redirect URL provided. Authentication cancelled.")
  }
  resp
}

#' Refresh an OAuth2 token
#'
#' @param token A token list with a `refresh_token` field.
#' @param client_id OAuth2 client ID.
#' @param client_secret OAuth2 client secret.
#' @param scope OAuth2 scope.
#'
#' @return A new token list.
#' @keywords internal
bs_refresh_token <- function(token, client_id, client_secret, scope) {
  if (is.null(token$refresh_token)) {
    abort("No refresh token available. Re-authenticate with {.fun bs_auth}.")
  }

  req <- httr2::request("https://auth.brightspace.com/core/connect/token") |>
    httr2::req_body_form(
      grant_type = "refresh_token",
      refresh_token = token$refresh_token,
      client_id = client_id,
      client_secret = client_secret
    ) |>
    httr2::req_error(body = bs_error_body)

  if (nzchar(scope)) {
    req <- httr2::req_body_form(req, scope = scope)
  }

  resp <- httr2::req_perform(req)

  new_token <- httr2::resp_body_json(resp)
  new_token$created_at <- as.numeric(Sys.time())

  # Preserve refresh token if the server didn't return a new one
  if (is.null(new_token$refresh_token)) {
    new_token$refresh_token <- token$refresh_token
  }

  new_token
}

#' Check if a token needs refreshing
#'
#' @param token A token list.
#' @return Logical.
#' @keywords internal
bs_token_needs_refresh <- function(token) {
  if (is.null(token$created_at) || is.null(token$expires_in)) {
    return(FALSE)
  }
  # Refresh 60 seconds before actual expiry
  expires_at <- token$created_at + token$expires_in - 60
  as.numeric(Sys.time()) >= expires_at
}

#' Get the token cache path
#'
#' @param client_id OAuth2 client ID (used to namespace cache files).
#' @return File path string.
#' @keywords internal
bs_token_cache_path <- function(client_id) {
  cache_dir <- tools::R_user_dir("brightspaceR", which = "cache")
  file.path(cache_dir, paste0("token_", substr(
    openssl::md5(client_id), 1, 8
  ), ".rds"))
}

#' Generate a random string
#'
#' @param n Number of characters.
#' @return Character string.
#' @keywords internal
bs_random_string <- function(n = 32) {
  paste0(
    sample(c(letters, LETTERS, 0:9, "-", ".", "_", "~"), n, replace = TRUE),
    collapse = ""
  )
}

#' Generate a PKCE S256 code challenge
#'
#' @param verifier The code verifier string.
#' @return Base64url-encoded SHA-256 hash.
#' @keywords internal
bs_pkce_challenge <- function(verifier) {
  hash <- openssl::sha256(charToRaw(verifier))
  # Base64url encoding (no padding)
  challenge <- openssl::base64_encode(hash)
  challenge <- gsub("\\+", "-", challenge)
  challenge <- gsub("/", "_", challenge)
  challenge <- gsub("=+$", "", challenge)
  challenge
}

#' Resolve a credential from multiple sources
#'
#' Checks, in order: explicit argument, config file value, environment variable,
#' and an optional hardcoded fallback.
#'
#' @param arg The explicitly passed argument value (empty string if not set).
#' @param config_val The value from config.yml (may be NULL).
#' @param envvar Name of the environment variable to check.
#' @param fallback Default value if all other sources are empty.
#'
#' @return Character string.
#' @keywords internal
bs_resolve_cred <- function(arg, config_val = NULL, envvar = "",
                            fallback = "") {
  if (nzchar(arg)) return(arg)
  if (!is.null(config_val) && nzchar(config_val)) return(config_val)
  if (nzchar(envvar)) {
    env_val <- Sys.getenv(envvar, "")
    if (nzchar(env_val)) return(env_val)
  }
  fallback
}
