# Download a dataset extract

Downloads a specific dataset extract as a ZIP file, unzips it, reads the
CSV, and returns a tidy tibble with proper types.

## Usage

``` r
bs_download_dataset(
  schema_id,
  plugin_id,
  extract_type = c("full", "diff"),
  extract_id = NULL,
  dataset_name = NULL
)
```

## Arguments

- schema_id:

  Schema ID of the dataset.

- plugin_id:

  Plugin ID of the dataset.

- extract_type:

  Type of extract: `"full"` or `"diff"`. Default `"full"`.

- extract_id:

  Specific extract ID. If `NULL`, downloads the latest.

- dataset_name:

  Optional name of the dataset (used for schema lookup).

## Value

A tibble of the dataset contents.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
datasets <- bs_list_datasets()
users <- bs_download_dataset(
  datasets$schema_id[1],
  datasets$plugin_id[1]
)
}
# }
```
