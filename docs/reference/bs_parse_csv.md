# Parse a BDS CSV file into a tidy tibble

Reads a CSV file with proper type handling. For known datasets (those
with schemas in the registry), explicit column types are used. For
unknown datasets, columns are read as character and then coerced
intelligently.

## Usage

``` r
bs_parse_csv(file_path, dataset_name = NULL)
```

## Arguments

- file_path:

  Path to the CSV file.

- dataset_name:

  Optional name of the dataset (used for schema lookup).

## Value

A tibble with clean snake_case column names and proper types.
