# List available extracts for a dataset

Retrieves available full and differential extracts for a specific
dataset.

## Usage

``` r
bs_list_extracts(schema_id, plugin_id)
```

## Arguments

- schema_id:

  Schema ID of the dataset.

- plugin_id:

  Plugin ID of the dataset.

## Value

A tibble with columns: `extract_id`, `extract_type`, `bds_type`,
`created_date`, `download_link`, `download_size`.

## Examples

``` r
if (FALSE) { # \dontrun{
datasets <- bs_list_datasets()
extracts <- bs_list_extracts(datasets$schema_id[1], datasets$plugin_id[1])
} # }
```
