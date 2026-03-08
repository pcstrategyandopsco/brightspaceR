# ADS (Advanced Data Sets) Schema Registry

Internal list of column type specifications for known Advanced Data Set
datasets. Column names must match the actual CSV headers from
Brightspace (lowercase with spaces). After parsing,
[`to_snake_case()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/to_snake_case.md)
converts them to snake_case.

## Usage

``` r
bs_ads_schemas
```

## Format

An object of class `list` of length 1.
