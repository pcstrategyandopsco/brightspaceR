# Get a dataset by name

Convenience wrapper that finds a dataset by name, downloads the latest
full extract, and returns a tidy tibble.

## Usage

``` r
bs_get_dataset(name, extract_type = c("full", "diff"))
```

## Arguments

- name:

  Dataset name (case-insensitive partial match). For example, `"Users"`,
  `"Grade Results"`, `"Org Units"`.

- extract_type:

  Type of extract: `"full"` or `"diff"`. Default `"full"`.

## Value

A tibble of the dataset contents.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
users <- bs_get_dataset("Users")
grades <- bs_get_dataset("Grade Results")
}
# }
```
