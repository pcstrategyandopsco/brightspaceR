#' Authenticate with Brightspace
#'
#' Initiates an OAuth2 Authorization Code flow to authenticate with the
#' Brightspace Data Sets API. Because Brightspace requires an HTTPS redirect
#' URI and httr2's local server only supports HTTP, this function uses a
#' manual copy-paste flow: it opens a browser for authorization, then prompts
#' you to paste the redirect URL containing the authorization code.
#'
#' The resulting token is cached to disk for reuse across sessions.
#'
#' @param client_id OAuth2 client ID. Resolved in order: this argument,
#'   `config.yml` (if present), `BRIGHTSPACE_CLIENT_ID` env var.
#' @param client_secret OAuth2 client secret. Resolved in order: this argument,
#'   `config.yml` (if present), `BRIGHTSPACE_CLIENT_SECRET` env var.
#' @param instance_url Your Brightspace instance URL (e.g.,
#'   `"https://myschool.brightspace.com"`). Resolved in order: this argument,
#'   `config.yml` (if present), `BRIGHTSPACE_INSTANCE_URL` env var.
#' @param redirect_uri The registered HTTPS redirect URI. Resolved in order:
#'   this argument, `config.yml` (if present), `BRIGHTSPACE_REDIRECT_URI`
#'   env var, or `"https://localhost:1410/"`. Must match the URI registered in
#'   your Brightspace OAuth2 app exactly.
#' @param scope OAuth2 scope. Defaults to `"datahub:dataexports:*"`.
#'   Use `"datahub:dataexports:* datahub:adhocdataexports:*"` to also
#'   access Advanced Data Sets.
#'
#' @return Invisibly returns `TRUE` on success.
#' @export
#'
#' @examples
#' \dontrun{
#' bs_auth()
#' bs_auth(
#'   client_id = "my-client-id",
#'   client_secret = "my-secret",
#'   instance_url = "https://myschool.brightspace.com"
#' )
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
    fallback = "datahub:dataexports:*"
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
#' Builds the authorization URL, opens the browser, prompts for the redirect
#' URL, and exchanges the code for a token.
#'
#' @keywords internal
bs_auth_interactive <- function(client_id, client_secret, instance_url,
                                redirect_uri, scope) {
  # Generate PKCE code verifier and challenge
  code_verifier <- bs_random_string(128)
  code_challenge <- bs_pkce_challenge(code_verifier)

  state <- bs_random_string(32)

  # Build authorization URL
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

  # Open browser and prompt user
  cli_alert_info("Opening browser for Brightspace authorization...")
  cli_alert_info(
    "If the browser doesn't open, visit this URL:\n{.url {auth_url_str}}"
  )
  utils::browseURL(auth_url_str)

  cli_alert_info(paste0(
    "After authorizing, your browser will redirect to a URL starting with\n",
    "{.url {redirect_uri}}\n",
    "The page may show a connection error -- that's expected.\n",
    "Copy the ENTIRE URL from your browser's address bar and paste it below."
  ))
  redirect_response <- readline("Paste the redirect URL here: ")

  if (redirect_response == "") {
    abort("No redirect URL provided. Authentication cancelled.")
  }

  # Extract authorization code from redirect URL
  parsed <- httr2::url_parse(redirect_response)
  returned_state <- parsed$query$state
  code <- parsed$query$code
  error <- parsed$query$error

  if (!is.null(error)) {
    abort(c(
      "Authorization failed.",
      x = "Error: {error}",
      i = parsed$query$error_description %||% ""
    ))
  }

  if (is.null(code)) {
    abort(c(
      "No authorization code found in the redirect URL.",
      i = "Make sure you copied the entire URL from your browser."
    ))
  }

  if (!is.null(returned_state) && returned_state != state) {
    abort("State parameter mismatch. Possible CSRF attack. Please try again.")
  }

  # Exchange authorization code for token
  token_resp <- httr2::request("https://auth.brightspace.com/core/connect/token") |>
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

  token <- httr2::resp_body_json(token_resp)

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
#' @param scope OAuth2 scope. Defaults to `"datahub:dataexports:*"`.
#'
#' @return Invisibly returns `TRUE` on success.
#' @export
#'
#' @examples
#' \dontrun{
#' bs_auth_refresh(refresh_token = "my-refresh-token")
#' }
bs_auth_refresh <- function(refresh_token,
                            client_id = Sys.getenv("BRIGHTSPACE_CLIENT_ID"),
                            client_secret = Sys.getenv("BRIGHTSPACE_CLIENT_SECRET"),
                            instance_url = Sys.getenv("BRIGHTSPACE_INSTANCE_URL"),
                            scope = "datahub:dataexports:*") {
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
#' \dontrun{
#' bs_deauth()
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
          .bs_env$scope %||% "datahub:dataexports:*"
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

  resp <- httr2::request("https://auth.brightspace.com/core/connect/token") |>
    httr2::req_body_form(
      grant_type = "refresh_token",
      refresh_token = token$refresh_token,
      client_id = client_id,
      client_secret = client_secret,
      scope = scope
    ) |>
    httr2::req_error(body = bs_error_body) |>
    httr2::req_perform()

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
