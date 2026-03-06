# Coerce character columns to appropriate types

For unknown datasets, attempts to convert character columns to numeric,
logical, or datetime types.

## Usage

``` r
bs_coerce_types(df)
```

## Arguments

- df:

  A tibble with all-character columns.

## Value

A tibble with coerced types.
