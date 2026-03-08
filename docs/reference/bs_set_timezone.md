# Set the timezone for Brightspace analytics

All analytics functions use this timezone for converting date columns.

## Usage

``` r
bs_set_timezone(tz)
```

## Arguments

- tz:

  A valid timezone string from
  [`OlsonNames()`](https://rdrr.io/r/base/timezones.html).

## Value

Invisibly returns the timezone string.

## Examples

``` r
bs_set_timezone("Pacific/Auckland")
#> ✔ Timezone set to "Pacific/Auckland"
bs_set_timezone("America/New_York")
#> ✔ Timezone set to "America/New_York"
```
