# List available Brightspace Data Sets

Retrieves all available BDS datasets from the Brightspace instance.

## Usage

``` r
bs_list_datasets()
```

## Value

A tibble with columns: `schema_id`, `plugin_id`, `name`, `description`,
`full_download_link`, `diff_download_link`, `created_date`.

## Examples

``` r
if (FALSE) { # \dontrun{
datasets <- bs_list_datasets()
datasets
} # }
```
