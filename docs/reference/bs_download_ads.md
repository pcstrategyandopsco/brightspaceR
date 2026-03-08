# Download a completed ADS export

Downloads the result of a completed ADS export job, unzips it, and
returns a tidy tibble with proper types and snake_case names.

## Usage

``` r
bs_download_ads(job_id, dataset_name = NULL)
```

## Arguments

- job_id:

  Export job ID.

- dataset_name:

  Optional dataset name (used for schema lookup).

## Value

A tibble of the dataset contents.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- bs_download_ads("abc-123", "Learner Usage")
} # }
```
