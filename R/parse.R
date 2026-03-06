#' Parse a BDS CSV file into a tidy tibble
#'
#' Reads a CSV file with proper type handling. For known datasets (those with
#' schemas in the registry), explicit column types are used. For unknown
#' datasets, columns are read as character and then coerced intelligently.
#'
#' @param file_path Path to the CSV file.
#' @param dataset_name Optional name of the dataset (used for schema lookup).
#'
#' @return A tibble with clean snake_case column names and proper types.
#' @keywords internal
bs_parse_csv <- function(file_path, dataset_name = NULL) {
  schema <- NULL
  if (!is.null(dataset_name)) {
    schema_key <- normalize_dataset_name(dataset_name)
    schema <- bs_schemas[[schema_key]]
  }

  na_values <- c("", "NA", "null", "NULL", "None")

  if (!is.null(schema)) {
    # Known dataset: use explicit col_types
    if (!is.null(schema$na_values)) {
      na_values <- schema$na_values
    }
    df <- readr::read_csv(
      file_path,
      col_types = schema$col_types,
      na = na_values,
      show_col_types = FALSE
    )
  } else {
    # Unknown dataset: read as character then coerce
    df <- readr::read_csv(
      file_path,
      col_types = readr::cols(.default = readr::col_character()),
      na = na_values,
      show_col_types = FALSE
    )
    df <- bs_coerce_types(df)
  }

  # Clean column names to snake_case
  names(df) <- to_snake_case(names(df))

  # Post-processing for known schemas
  if (!is.null(schema)) {
    df <- bs_apply_schema_transforms(df, schema)
  }

  df
}

#' Apply schema-defined type transformations
#'
#' Converts date and boolean columns based on schema definitions.
#'
#' @param df A tibble.
#' @param schema A schema definition list.
#'
#' @return A transformed tibble.
#' @keywords internal
bs_apply_schema_transforms <- function(df, schema) {
  # Convert date columns
  if (!is.null(schema$date_cols)) {
    date_cols_snake <- to_snake_case(schema$date_cols)
    for (col in date_cols_snake) {
      if (col %in% names(df) && is.character(df[[col]])) {
        df[[col]] <- readr::parse_datetime(df[[col]],
          format = "",
          na = c("", "NA", "null")
        )
      }
    }
  }

  # Convert boolean columns
  if (!is.null(schema$bool_cols)) {
    bool_cols_snake <- to_snake_case(schema$bool_cols)
    for (col in bool_cols_snake) {
      if (col %in% names(df) && is.character(df[[col]])) {
        df[[col]] <- bs_parse_bool(df[[col]])
      }
    }
  }

  df
}

#' Coerce character columns to appropriate types
#'
#' For unknown datasets, attempts to convert character columns to numeric,
#' logical, or datetime types.
#'
#' @param df A tibble with all-character columns.
#'
#' @return A tibble with coerced types.
#' @keywords internal
bs_coerce_types <- function(df) {
  for (col in names(df)) {
    vals <- df[[col]][!is.na(df[[col]])]
    if (length(vals) == 0) next

    # Try logical
    if (all(tolower(vals) %in% c("true", "false", "0", "1"))) {
      df[[col]] <- bs_parse_bool(df[[col]])
      next
    }

    # Try integer
    if (all(grepl("^-?\\d+$", vals))) {
      parsed <- suppressWarnings(as.integer(vals))
      if (!any(is.na(parsed))) {
        df[[col]] <- as.integer(df[[col]])
        next
      }
    }

    # Try double
    if (all(grepl("^-?\\d*\\.?\\d+([eE][+-]?\\d+)?$", vals))) {
      parsed <- suppressWarnings(as.double(vals))
      if (!any(is.na(parsed))) {
        df[[col]] <- as.double(df[[col]])
        next
      }
    }

    # Try datetime (ISO 8601)
    if (all(grepl("^\\d{4}-\\d{2}-\\d{2}[T ]", vals))) {
      parsed <- suppressWarnings(readr::parse_datetime(vals))
      if (!all(is.na(parsed))) {
        df[[col]] <- readr::parse_datetime(df[[col]])
        next
      }
    }
  }

  df
}

#' Parse boolean values
#'
#' Handles Brightspace conventions: "True"/"False", "0"/"1".
#'
#' @param x Character vector.
#'
#' @return Logical vector.
#' @keywords internal
bs_parse_bool <- function(x) {
  dplyr::case_when(
    tolower(x) == "true" ~ TRUE,
    tolower(x) == "false" ~ FALSE,
    x == "1" ~ TRUE,
    x == "0" ~ FALSE,
    TRUE ~ NA
  )
}

#' Convert column names from PascalCase to snake_case
#'
#' @param df A data frame.
#'
#' @return A data frame with snake_case column names.
#' @export
#'
#' @examples
#' df <- data.frame(UserId = 1, FirstName = "A")
#' bs_clean_names(df)
bs_clean_names <- function(df) {
  names(df) <- to_snake_case(names(df))
  df
}
