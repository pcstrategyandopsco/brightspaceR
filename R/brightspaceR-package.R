#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang .data .env %||% abort inform warn
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_warning
#'   cli_alert_danger cli_progress_bar cli_progress_update cli_progress_done
## usethis namespace: end
NULL

# Package-level environment for storing auth state
.bs_env <- new.env(parent = emptyenv())
