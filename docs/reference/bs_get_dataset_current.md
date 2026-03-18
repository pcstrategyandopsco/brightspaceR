# Get current dataset by merging full and differential extracts

Downloads the latest full extract and all subsequent differential
extracts for a dataset, then merges them to produce a
current-as-of-today tibble.

## Usage

``` r
bs_get_dataset_current(name, keep_deleted = FALSE)
```

## Arguments

- name:

  Dataset name (case-insensitive partial match). For example, `"Users"`,
  `"Grade Results"`, `"Org Units"`.

- keep_deleted:

  If `FALSE` (default), rows marked as deleted in differential extracts
  are removed from the final result.

## Value

A tibble of the merged dataset contents. The tibble carries a
`"bds_manifest"` attribute with the extract breakdown (full, each diff,
and merged total with row counts and download status). Retrieve it with
[`bs_diff_manifest()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_diff_manifest.md).

## Examples

``` r
# \donttest{
if (bs_has_token()) {
users <- bs_get_dataset_current("Users")
bs_diff_manifest(users)
}
# }
```
