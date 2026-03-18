# Merge full and differential BDS extracts

Applies one or more differential extracts on top of a full extract using
upsert logic keyed by the dataset's primary key columns.

## Usage

``` r
bs_apply_diffs(full, diffs, dataset_name = NULL, keep_deleted = FALSE)
```

## Arguments

- full:

  A tibble from the full extract.

- diffs:

  A list of tibbles from differential extracts, in chronological order.

- dataset_name:

  Optional dataset name used to look up key columns via
  [`bs_key_cols()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_key_cols.md).

- keep_deleted:

  If `FALSE` (default), rows where `is_deleted` is `TRUE` are removed
  from the final result.

## Value

A tibble with diffs applied.
