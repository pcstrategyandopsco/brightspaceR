# Test Brightspace API scope access

Verifies which API capabilities are available with the current token by
making lightweight test calls to each endpoint group. Checks are grouped
into **Tier 1 (BDS)** and **Tier 2 (ADS)** so you can see at a glance
which tier is working. Useful for diagnosing 403 errors.

## Usage

``` r
bs_check_scopes()
```

## Value

A tibble with columns `tier`, `scope`, `endpoint`, `status` ("OK" or
error message), printed as a summary table.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
bs_auth()
bs_check_scopes()
}
# }
```
