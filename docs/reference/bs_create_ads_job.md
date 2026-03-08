# Create an ADS export job

Submits a new export job for the named ADS dataset. Use
[`bs_ads_job_status()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_ads_job_status.md)
to poll for completion, then
[`bs_download_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_download_ads.md)
to retrieve the result.

## Usage

``` r
bs_create_ads_job(name, filters = list())
```

## Arguments

- name:

  Dataset name (case-insensitive). For example, `"Learner Usage"`.

- filters:

  Optional filter list from
  [`bs_ads_filter()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_ads_filter.md).

## Value

A tibble with one row containing `export_job_id`, `dataset_id`, `name`,
`status`, `status_text`, `submit_date`.

## Examples

``` r
if (FALSE) { # \dontrun{
job <- bs_create_ads_job("Learner Usage")
job$export_job_id
} # }
```
