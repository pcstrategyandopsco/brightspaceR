# Coerce columns in y to match types in x

For each shared column, if types differ, attempts to cast the column in
`y` to match `x`. This prevents
[`rows_upsert()`](https://dplyr.tidyverse.org/reference/rows.html)
failures when diff extracts have character columns that should be
datetime, logical, etc.

## Usage

``` r
align_col_types(y, x)
```

## Arguments

- y:

  The tibble to coerce (diff extract).

- x:

  The reference tibble (full extract).

## Value

`y` with column types aligned to `x`.
