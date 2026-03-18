# Get an ADS dataset by name (convenience wrapper)

High-level function that finds the dataset by name, creates an export
job, polls until complete, downloads the result, and returns a tidy
tibble. Intended for interactive use.

## Usage

``` r
bs_get_ads(name, filters = list(), poll_interval = 5, timeout = 300)
```

## Arguments

- name:

  Dataset name (case-insensitive). For example, `"Learner Usage"`.

- filters:

  Optional filter list from
  [`bs_ads_filter()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_ads_filter.md).

- poll_interval:

  Seconds between status checks. Default 5.

- timeout:

  Maximum seconds to wait for completion. Default 300.

## Value

A tibble of the dataset contents.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
usage <- bs_get_ads("Learner Usage")
usage <- bs_get_ads("Learner Usage",
  filters = bs_ads_filter(start_date = "2024-01-01"))
}
# }
```
