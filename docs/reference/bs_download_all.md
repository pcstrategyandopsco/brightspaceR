# Download all available datasets

Downloads all available datasets and returns them as a named list of
tibbles. Names are snake_case versions of the dataset names.

## Usage

``` r
bs_download_all(extract_type = c("full", "diff"))
```

## Arguments

- extract_type:

  Type of extract: `"full"` or `"diff"`. Default `"full"`.

## Value

A named list of tibbles.

## Examples

``` r
if (FALSE) { # \dontrun{
all_data <- bs_download_all()
all_data$users
all_data$org_units
} # }
```
