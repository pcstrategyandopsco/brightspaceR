# Get or set the Brightspace API version

Get or set the Brightspace API version

## Usage

``` r
bs_api_version(version = NULL)
```

## Arguments

- version:

  If provided, sets the API version. If `NULL`, returns the current
  version.

## Value

Character string of the API version.

## Examples

``` r
bs_api_version()
#> [1] "1.49"
bs_api_version("1.49")
```
