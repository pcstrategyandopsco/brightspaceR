# Check ADS export job status

Check ADS export job status

## Usage

``` r
bs_ads_job_status(job_id)
```

## Arguments

- job_id:

  Export job ID returned by
  [`bs_create_ads_job()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_create_ads_job.md).

## Value

A list with `export_job_id`, `name`, `status` (integer), `status_text`
(character), and `submit_date`.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
status <- bs_ads_job_status("abc-123")
status$status_text
}
# }
```
