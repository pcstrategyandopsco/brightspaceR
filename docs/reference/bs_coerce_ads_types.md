# Coerce ADS column types and normalise column names

ADS CSVs may arrive with all-character columns. This function coerces
known numeric columns to integer, parses date columns, and maps ADS
column name variants (e.g., `number_of_logins_to_the_system`) to the
short names the analytics functions expect (e.g., `login_count`).

## Usage

``` r
bs_coerce_ads_types(df)
```

## Arguments

- df:

  A tibble from an ADS export.

## Value

The tibble with corrected types and aliased columns.
