# Inspect the extract manifest from a merged BDS dataset

Returns a tibble showing each extract (full + diffs + merged total) with
its creation date, row count, and download status. Use this to verify
that all differential extracts were successfully downloaded and merged.

## Usage

``` r
bs_diff_manifest(data)
```

## Arguments

- data:

  A tibble returned by
  [`bs_get_dataset_current()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_dataset_current.md).

## Value

A tibble with columns `extract`, `created_date`, `rows`, `status`, or
`NULL` if the data has no manifest attribute.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
users <- bs_get_dataset_current("Users")
bs_diff_manifest(users)
}
# }
```
