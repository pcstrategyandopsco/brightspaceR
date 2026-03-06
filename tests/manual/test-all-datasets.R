# ============================================================================
# Download every available dataset and check typing
#
# Run interactively:
#   source("tests/manual/test-all-datasets.R")
#
# Produces a summary report of:
#   - Which datasets downloaded successfully
#   - Which columns are still character but look like dates/integers/booleans
#   - Schema warnings (mismatched column names)
# ============================================================================

library(brightspaceR)

cat("== Downloading all datasets and checking types ==\n\n")

bs_auth()
datasets <- bs_list_datasets()
cat(sprintf("Found %d datasets.\n\n", nrow(datasets)))

results <- list()
issues <- list()

for (i in seq_len(nrow(datasets))) {
  ds_name <- datasets$name[i]
  cat(sprintf("[%d/%d] %s ... ", i, nrow(datasets), ds_name))

  tryCatch({
    # Capture warnings during download
    warns <- character()
    df <- withCallingHandlers(
      bs_get_dataset(ds_name),
      warning = function(w) {
        warns <<- c(warns, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )

    results[[ds_name]] <- df
    cat(sprintf("OK (%d rows x %d cols)\n", nrow(df), ncol(df)))

    # Check for typing issues
    ds_issues <- list()

    if (length(warns) > 0) {
      ds_issues$schema_warnings <- warns
    }

    # Find character columns that look like they should be typed
    for (col in names(df)) {
      vals <- df[[col]][!is.na(df[[col]])]
      if (length(vals) == 0 || !is.character(vals)) next

      sample_vals <- head(vals, 100)

      # Looks like datetime?
      if (all(grepl("^\\d{4}-\\d{2}-\\d{2}[T ]", sample_vals))) {
        ds_issues[[col]] <- "character but looks like datetime"
      }
      # Looks like boolean?
      else if (all(tolower(sample_vals) %in%
                   c("true", "false", "0", "1"))) {
        ds_issues[[col]] <- "character but looks like boolean"
      }
      # Looks like integer?
      else if (all(grepl("^-?\\d+$", sample_vals)) &&
               max(nchar(sample_vals)) <= 10) {
        ds_issues[[col]] <- "character but looks like integer"
      }
    }

    if (length(ds_issues) > 0) {
      issues[[ds_name]] <- ds_issues
    }
  }, error = function(e) {
    cat(sprintf("FAILED: %s\n", e$message))
    issues[[ds_name]] <<- list(error = e$message)
  })
}

# ---- Summary Report --------------------------------------------------------

cat("\n\n== SUMMARY ==\n\n")
cat(sprintf("Downloaded: %d / %d datasets\n",
            length(results), nrow(datasets)))
cat(sprintf("Datasets with issues: %d\n\n", length(issues)))

if (length(issues) > 0) {
  for (ds_name in names(issues)) {
    cat(sprintf("--- %s ---\n", ds_name))
    for (field in names(issues[[ds_name]])) {
      cat(sprintf("  %-30s  %s\n", field, issues[[ds_name]][[field]]))
    }
    cat("\n")
  }
}

# Save results for inspection
saveRDS(results, "all_datasets.rds")
saveRDS(issues, "all_datasets_issues.rds")
cat("Results saved to all_datasets.rds and all_datasets_issues.rds\n")
