# ============================================================================
# Manual OAuth2 test via config.yml
#
# Run interactively:
#   source("tests/manual/test-oauth.R")
#
# Prerequisites:
#   1. OAuth2 app registered in Brightspace (Authorization Code Grant)
#   2. You will be prompted for client_id, client_secret, and instance_url
# ============================================================================

library(brightspaceR)

cat("== brightspaceR OAuth2 Test ==\n\n")

# --- Step 1: Create config.yml from user input ------------------------------

cat("Enter your Brightspace OAuth2 credentials:\n\n")

client_id     <- readline("Client ID: ")
client_secret <- readline("Client Secret: ")
instance_url  <- readline("Instance URL (e.g. https://myschool.brightspace.com): ")

cat("\nWriting config.yml...\n")
bs_config_set(
  client_id     = client_id,
  client_secret = client_secret,
  instance_url  = instance_url
)

# --- Step 2: Verify config.yml is readable ----------------------------------

cat("\nReading back config.yml...\n")
cfg <- bs_config()

stopifnot(
  "config read failed"        = !is.null(cfg),
  "client_id mismatch"        = cfg$client_id == client_id,
  "client_secret mismatch"    = cfg$client_secret == client_secret,
  "instance_url mismatch"     = cfg$instance_url == instance_url
)
cat("  client_id:    ", cfg$client_id, "\n")
cat("  instance_url: ", cfg$instance_url, "\n")
cat("  redirect_uri: ", cfg$redirect_uri, "\n")
cat("  Config file OK!\n")

# --- Step 3: Authenticate (browser flow) ------------------------------------

cat("\n-- Starting OAuth2 flow --\n")
cat("A browser window will open. Authorize the app, then copy the redirect URL.\n\n")

bs_auth()

# --- Step 4: Verify token ---------------------------------------------------

stopifnot("Token not set after auth" = bs_has_token())
cat("\nToken acquired successfully!\n")

# --- Step 5: Test an API call -----------------------------------------------

cat("\nFetching dataset list...\n")
datasets <- bs_list_datasets()
cat(sprintf("  Retrieved %d datasets.\n", nrow(datasets)))

if (nrow(datasets) > 0) {
  cat("\n  First 5 datasets:\n")
  print(head(datasets[, c("Name")], 5))
}

cat("\n== All checks passed! OAuth2 is working. ==\n")
