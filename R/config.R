#' Read Brightspace credentials from a config file
#'
#' Reads Brightspace OAuth2 credentials from a YAML configuration file using
#' the \pkg{config} package. The function looks for a `brightspace` key in the
#' config file and returns the credentials as a named list.
#'
#' @param file Path to the YAML config file. Defaults to `"config.yml"` in the
#'   working directory.
#' @param profile Configuration profile to use. Defaults to the
#'   `R_CONFIG_ACTIVE` environment variable, or `"default"` if unset.
#'
#' @return A named list with elements `client_id`, `client_secret`,
#'   `instance_url`, `redirect_uri`, and `scope`, or `NULL` if the file does
#'   not exist or the `brightspace` key is missing.
#' @export
#'
#' @examples
#' \dontrun{
#' # Read from default config.yml
#' cfg <- bs_config()
#' cfg$client_id
#'
#' # Read from a custom file and profile
#' cfg <- bs_config(file = "my-config.yml", profile = "production")
#' }
bs_config <- function(file = "config.yml",
                      profile = Sys.getenv("R_CONFIG_ACTIVE", "default")) {
  if (!file.exists(file)) {
    return(NULL)
  }

  cfg <- tryCatch(
    config::get(config = profile, file = file),
    error = function(e) NULL
  )

  if (is.null(cfg) || is.null(cfg$brightspace)) {
    return(NULL)
  }

  cfg$brightspace
}

#' Create or update a Brightspace config file
#'
#' Interactively creates or updates a `config.yml` file with Brightspace
#' OAuth2 credentials. If the file already exists, the `brightspace` section
#' is updated while preserving other settings.
#'
#' @param client_id OAuth2 client ID.
#' @param client_secret OAuth2 client secret.
#' @param instance_url Your Brightspace instance URL (e.g.,
#'   `"https://myschool.brightspace.com"`).
#' @param redirect_uri Redirect URI. Defaults to `"https://localhost:1410/"`.
#' @param scope OAuth2 scope. Defaults to `"datahub:dataexports:*"`.
#' @param file Path for the config file. Defaults to `"config.yml"`.
#' @param profile Configuration profile to write to. Defaults to `"default"`.
#'
#' @return Invisibly returns the file path.
#' @export
#'
#' @examples
#' \dontrun{
#' bs_config_set(
#'   client_id = "my-client-id",
#'   client_secret = "my-secret",
#'   instance_url = "https://myschool.brightspace.com"
#' )
#' }
bs_config_set <- function(client_id,
                          client_secret,
                          instance_url,
                          redirect_uri = "https://localhost:1410/",
                          scope = "datahub:dataexports:*",
                          file = "config.yml",
                          profile = "default") {
  # Build the brightspace config
  bs_cfg <- list(
    client_id = client_id,
    client_secret = client_secret,
    instance_url = instance_url,
    redirect_uri = redirect_uri,
    scope = scope
  )

  # Read existing config or start fresh
  if (file.exists(file)) {
    existing <- yaml::read_yaml(file)
  } else {
    existing <- list()
  }

  # Update the profile's brightspace section
  if (is.null(existing[[profile]])) {
    existing[[profile]] <- list()
  }
  existing[[profile]]$brightspace <- bs_cfg

  yaml::write_yaml(existing, file)
  cli_alert_success("Brightspace credentials written to {.file {file}}")

  # Warn if config.yml is not in .gitignore
  gitignore_path <- file.path(dirname(file), ".gitignore")
  if (file.exists(gitignore_path)) {
    gitignore <- readLines(gitignore_path, warn = FALSE)
    if (!any(grepl("^config\\.yml$", trimws(gitignore)))) {
      cli_alert_warning(
        "{.file config.yml} is not in {.file .gitignore}. Add it to avoid committing secrets."
      )
    }
  } else {
    cli_alert_warning(
      "No {.file .gitignore} found. Create one and add {.file config.yml} to avoid committing secrets."
    )
  }

  invisible(file)
}
