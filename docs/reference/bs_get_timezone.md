# Get the current Brightspace analytics timezone

Returns the timezone set by
[`bs_set_timezone()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_set_timezone.md),
defaulting to `"UTC"`.

## Usage

``` r
bs_get_timezone()
```

## Value

Character string of the timezone.

## Examples

``` r
bs_get_timezone()
#> [1] "UTC"
```
