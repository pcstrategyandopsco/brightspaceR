# List available Advanced Data Sets

Retrieves all available ADS datasets from the Brightspace instance.

## Usage

``` r
bs_list_ads()
```

## Value

A tibble with columns: `dataset_id`, `name`, `description`, `category`.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
ads <- bs_list_ads()
ads
}
# }
```
