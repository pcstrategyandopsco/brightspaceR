#' List available Brightspace Data Sets
#'
#' Retrieves all available BDS datasets from the Brightspace instance.
#'
#' @return A tibble with columns: `schema_id`, `plugin_id`, `name`,
#'   `description`, `full_download_link`, `diff_download_link`,
#'   `created_date`.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' datasets <- bs_list_datasets()
#' datasets
#' }
#' }
bs_list_datasets <- function() {
  path <- bs_bds_path()
  items <- bs_paginate(path, items_field = "Objects")

  if (length(items) == 0) {
    cli_alert_warning("No datasets found.")
    return(tibble::tibble(
      schema_id = character(),
      plugin_id = character(),
      name = character(),
      description = character(),
      created_date = character()
    ))
  }

  tibble::tibble(
    schema_id = purrr::map_chr(items, "SchemaId", .default = NA_character_),
    plugin_id = purrr::map_chr(items, c("Full", "PluginId"),
                               .default = NA_character_),
    diff_plugin_id = purrr::map_chr(items, c("Differential", "PluginId"),
                                    .default = NA_character_),
    name = purrr::map_chr(items, c("Full", "Name"),
                          .default = NA_character_),
    description = purrr::map_chr(items, c("Full", "Description"),
                                 .default = NA_character_),
    created_date = purrr::map_chr(items, c("Full", "CreatedDate"),
                                  .default = NA_character_)
  )
}

#' List available extracts for a dataset
#'
#' Retrieves available full and differential extracts for a specific dataset.
#'
#' @param schema_id Schema ID of the dataset.
#' @param plugin_id Plugin ID of the dataset.
#'
#' @return A tibble with columns: `extract_id`, `extract_type`, `bds_type`,
#'   `created_date`, `download_link`, `download_size`.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' datasets <- bs_list_datasets()
#' extracts <- bs_list_extracts(datasets$schema_id[1], datasets$plugin_id[1])
#' }
#' }
bs_list_extracts <- function(schema_id, plugin_id) {
  path <- bs_bds_path(schema_id, "plugins", plugin_id, "extracts")
  items <- bs_paginate(path, items_field = "Objects")

  if (length(items) == 0) {
    cli_alert_warning("No extracts found for this dataset.")
    return(tibble::tibble(
      extract_id = character(),
      extract_type = character(),
      bds_type = character(),
      created_date = character(),
      download_link = character(),
      download_size = numeric()
    ))
  }

  tibble::tibble(
    schema_id = purrr::map_chr(items, "SchemaId", .default = NA_character_),
    plugin_id = purrr::map_chr(items, "PluginId", .default = NA_character_),
    extract_type = purrr::map_chr(items, "BdsType", .default = NA_character_),
    created_date = purrr::map_chr(items, "CreatedDate", .default = NA_character_),
    download_link = purrr::map_chr(items, "DownloadLink", .default = NA_character_),
    download_size = purrr::map_dbl(items, "DownloadSize", .default = NA_real_),
    version = purrr::map_chr(items, "Version", .default = NA_character_)
  )
}

#' Download a dataset extract
#'
#' Downloads a specific dataset extract as a ZIP file, unzips it, reads the
#' CSV, and returns a tidy tibble with proper types.
#'
#' @param schema_id Schema ID of the dataset.
#' @param plugin_id Plugin ID of the dataset.
#' @param extract_type Type of extract: `"full"` or `"diff"`. Default `"full"`.
#' @param extract_id Specific extract ID. If `NULL`, downloads the latest.
#' @param dataset_name Optional name of the dataset (used for schema lookup).
#'
#' @return A tibble of the dataset contents.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' datasets <- bs_list_datasets()
#' users <- bs_download_dataset(
#'   datasets$schema_id[1],
#'   datasets$plugin_id[1]
#' )
#' }
#' }
bs_download_dataset <- function(schema_id, plugin_id,
                                extract_type = c("full", "diff"),
                                extract_id = NULL,
                                dataset_name = NULL) {
  extract_type <- match.arg(extract_type)

  if (is.null(extract_id)) {
    # Get the latest extract using schema-level extracts endpoint
    extracts <- bs_list_extracts(schema_id, plugin_id)
    extracts <- extracts[tolower(extracts$extract_type) == extract_type, ]
    if (nrow(extracts) == 0 && extract_type == "diff") {
      # plugin_id might be for Full only; try schema-level extracts
      path <- bs_bds_path(schema_id, "extracts")
      items <- bs_paginate(path, items_field = "Objects")
      if (length(items) > 0) {
        all_extracts <- tibble::tibble(
          schema_id = purrr::map_chr(items, "SchemaId",
                                     .default = NA_character_),
          plugin_id = purrr::map_chr(items, "PluginId",
                                     .default = NA_character_),
          extract_type = purrr::map_chr(items, "BdsType",
                                        .default = NA_character_),
          created_date = purrr::map_chr(items, "CreatedDate",
                                        .default = NA_character_),
          download_link = purrr::map_chr(items, "DownloadLink",
                                         .default = NA_character_),
          download_size = purrr::map_dbl(items, "DownloadSize",
                                         .default = NA_real_)
        )
        extracts <- all_extracts[
          tolower(all_extracts$extract_type) == "differential", ]
      }
    }

    if (nrow(extracts) == 0) {
      abort(c(
        "No {extract_type} extracts available for this dataset.",
        i = "Try a different extract type."
      ))
    }

    # Use the most recent extract (first one returned)
    extract <- extracts[1, ]
    download_url <- extract$download_link
  } else {
    # Get specific extract
    path <- bs_bds_path(schema_id, "plugins", plugin_id, "extracts", extract_id)
    extract <- bs_get(path)
    download_url <- extract$DownloadLink
  }

  if (is.na(download_url) || is.null(download_url) || download_url == "") {
    abort("No download link available for this extract.")
  }

  # Get download size if available from extracts tibble
  dl_size <- NULL
  if (exists("extract") && is.data.frame(extract) &&
      "download_size" %in% names(extract)) {
    dl_size <- extract$download_size
  }

  cli_alert_info("Downloading {extract_type} extract{?s} for {.val {dataset_name %||% schema_id}}...")

  # Download the ZIP file
  zip_path <- tempfile(fileext = ".zip")
  bs_download(download_url, zip_path, download_size = dl_size)

  # Extract and parse
  tmp_dir <- bs_unzip(zip_path)
  csv_files <- list.files(tmp_dir, pattern = "\\.csv$", full.names = TRUE,
                          recursive = TRUE)

  if (length(csv_files) == 0) {
    abort("No CSV files found in the downloaded extract.")
  }

  # Read the first (usually only) CSV file
  result <- bs_parse_csv(csv_files[[1]], dataset_name = dataset_name)

  # Clean up
  unlink(zip_path)
  unlink(tmp_dir, recursive = TRUE)

  cli_alert_success(
    "Downloaded {.val {dataset_name %||% schema_id}}: {nrow(result)} rows x {ncol(result)} cols"
  )


  result
}

#' Download all available datasets
#'
#' Downloads all available datasets and returns them as a named list of
#' tibbles. Names are snake_case versions of the dataset names.
#'
#' @param extract_type Type of extract: `"full"` or `"diff"`. Default `"full"`.
#'
#' @return A named list of tibbles.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' all_data <- bs_download_all()
#' all_data$users
#' all_data$org_units
#' }
#' }
bs_download_all <- function(extract_type = c("full", "diff")) {
  extract_type <- match.arg(extract_type)

  datasets <- bs_list_datasets()

  if (nrow(datasets) == 0) {
    cli_alert_warning("No datasets available.")
    return(list())
  }

  cli_alert_info("Downloading {nrow(datasets)} datasets...")
  id <- cli_progress_bar(
    "Downloading {ds$name} ({i}/{nrow(datasets)})",
    total = nrow(datasets)
  )

  results <- list()

  for (i in seq_len(nrow(datasets))) {
    ds <- datasets[i, ]
    ds_name <- normalize_dataset_name(ds$name)

    cli_progress_update(id = id)

    result <- tryCatch(
      bs_download_dataset(
        schema_id = ds$schema_id,
        plugin_id = ds$plugin_id,
        extract_type = extract_type,
        dataset_name = ds$name
      ),
      error = function(e) {
        cli_alert_warning("Failed to download {.val {ds$name}}: {e$message}")
        NULL
      }
    )

    if (!is.null(result)) {
      results[[ds_name]] <- result
    }
  }

  cli_progress_done(id = id)
  cli_alert_success("Downloaded {length(results)}/{nrow(datasets)} datasets.")

  results
}

#' Get a dataset by name
#'
#' Convenience wrapper that finds a dataset by name, downloads the latest
#' full extract, and returns a tidy tibble.
#'
#' @param name Dataset name (case-insensitive partial match). For example,
#'   `"Users"`, `"Grade Results"`, `"Org Units"`.
#' @param extract_type Type of extract: `"full"` or `"diff"`. Default `"full"`.
#'
#' @return A tibble of the dataset contents.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' users <- bs_get_dataset("Users")
#' grades <- bs_get_dataset("Grade Results")
#' }
#' }
bs_get_dataset <- function(name, extract_type = c("full", "diff")) {
  extract_type <- match.arg(extract_type)

  datasets <- bs_list_datasets()

  # Try exact match first, then case-insensitive partial match

  idx <- which(tolower(datasets$name) == tolower(name))

  if (length(idx) == 0) {
    idx <- grep(name, datasets$name, ignore.case = TRUE)
  }

  if (length(idx) == 0) {
    abort(c(
      "Dataset {.val {name}} not found.",
      i = "Use {.fun bs_list_datasets} to see available datasets."
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

  # Use the differential plugin_id when requesting diff extracts
  pid <- if (extract_type == "diff" && !is.na(ds$diff_plugin_id)) {
    ds$diff_plugin_id
  } else {
    ds$plugin_id
  }

  bs_download_dataset(
    schema_id = ds$schema_id,
    plugin_id = pid,
    extract_type = extract_type,
    dataset_name = ds$name
  )
}

#' Merge full and differential BDS extracts
#'
#' Applies one or more differential extracts on top of a full extract using
#' upsert logic keyed by the dataset's primary key columns.
#'
#' @param full A tibble from the full extract.
#' @param diffs A list of tibbles from differential extracts, in chronological
#'   order.
#' @param dataset_name Optional dataset name used to look up key columns via
#'   [bs_key_cols()].
#' @param keep_deleted If `FALSE` (default), rows where `is_deleted` is `TRUE`
#'   are removed from the final result.
#'
#' @return A tibble with diffs applied.
#' @keywords internal
#' @export
bs_apply_diffs <- function(full, diffs, dataset_name = NULL, keep_deleted = FALSE) {
  if (length(diffs) == 0) return(full)

  # Determine key columns
  key_cols <- NULL
  if (!is.null(dataset_name)) {
    key_cols <- bs_key_cols(dataset_name)
  }
  if (is.null(key_cols)) {
    # Auto-detect: columns ending in _id
    key_cols <- grep("_id$", names(full), value = TRUE)
    key_cols <- setdiff(key_cols, "is_deleted")
  }
  if (length(key_cols) == 0) {
    abort("Cannot determine key columns for merging. Provide `dataset_name`.")
  }

  result <- full
  for (diff in diffs) {
    # Only use key columns that exist in both datasets
    common_keys <- intersect(key_cols, intersect(names(result), names(diff)))
    if (length(common_keys) == 0) next
    result <- dplyr::rows_upsert(result, diff, by = common_keys)
  }

  if (!keep_deleted && "is_deleted" %in% names(result)) {
    result <- result[!result$is_deleted | is.na(result$is_deleted), ]
  }

  result
}

#' Get current dataset by merging full and differential extracts
#'
#' Downloads the latest full extract and all subsequent differential extracts
#' for a dataset, then merges them to produce a current-as-of-today tibble.
#'
#' @param name Dataset name (case-insensitive partial match). For example,
#'   `"Users"`, `"Grade Results"`, `"Org Units"`.
#' @param keep_deleted If `FALSE` (default), rows marked as deleted in
#'   differential extracts are removed from the final result.
#'
#' @return A tibble of the merged dataset contents.
#' @export
#'
#' @examples
#' \donttest{
#' if (bs_has_token()) {
#' users <- bs_get_dataset_current("Users")
#' }
#' }
bs_get_dataset_current <- function(name, keep_deleted = FALSE) {
  datasets <- bs_list_datasets()

  # Name matching (same logic as bs_get_dataset)
  idx <- which(tolower(datasets$name) == tolower(name))
  if (length(idx) == 0) {
    idx <- grep(name, datasets$name, ignore.case = TRUE)
  }
  if (length(idx) == 0) {
    abort(c(
      "Dataset {.val {name}} not found.",
      i = "Use {.fun bs_list_datasets} to see available datasets."
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

  # 1. Download the latest full extract
  cli_alert_info("Downloading latest full extract for {.val {ds$name}}...")
  full <- bs_download_dataset(
    schema_id = ds$schema_id,
    plugin_id = ds$plugin_id,
    extract_type = "full",
    dataset_name = ds$name
  )

  # Get full extract metadata to find its created_date

  full_extracts <- bs_list_extracts(ds$schema_id, ds$plugin_id)
  full_extracts <- full_extracts[tolower(full_extracts$extract_type) == "full", ]
  if (nrow(full_extracts) == 0) return(full)
  full_created <- full_extracts$created_date[1]

  # 2. Get differential extracts created after the full extract
  if (is.na(ds$diff_plugin_id)) {
    cli_alert_info("No differential plugin available. Returning full extract.")
    return(full)
  }

  diff_extracts <- bs_list_extracts(ds$schema_id, ds$diff_plugin_id)
  diff_extracts <- diff_extracts[
    tolower(diff_extracts$extract_type) == "differential", ]

  # Filter to diffs created after the full extract
  diff_extracts <- diff_extracts[diff_extracts$created_date > full_created, ]

  if (nrow(diff_extracts) == 0) {
    cli_alert_info("No differential extracts newer than the full extract.")
    return(full)
  }

  # Sort chronologically (oldest first)
  diff_extracts <- diff_extracts[order(diff_extracts$created_date), ]

  cli_alert_info(
    "Downloading {nrow(diff_extracts)} differential extract{?s}..."
  )

  # 3. Download each diff
  diffs <- list()
  for (i in seq_len(nrow(diff_extracts))) {
    d <- diff_extracts[i, ]
    diff_data <- tryCatch(
      bs_download_dataset(
        schema_id = d$schema_id,
        plugin_id = d$plugin_id,
        extract_type = "diff",
        dataset_name = ds$name
      ),
      error = function(e) {
        cli_alert_warning(
          "Failed to download diff extract {i}: {e$message}"
        )
        NULL
      }
    )
    if (!is.null(diff_data)) {
      diffs <- c(diffs, list(diff_data))
    }
  }

  # 4. Merge
  result <- bs_apply_diffs(full, diffs, dataset_name = ds$name,
                           keep_deleted = keep_deleted)

  cli_alert_success(
    "Merged {.val {ds$name}}: {nrow(result)} rows x {ncol(result)} cols (full + {length(diffs)} diff{?s})"
  )

  result
}
