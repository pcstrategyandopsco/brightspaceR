# Test Brightspace API scope access

Verifies which API capabilities are available with the current token by
making lightweight test calls to each endpoint group. Useful for
diagnosing 403 errors.

## Usage

``` r
bs_check_scopes()
```

## Value

A tibble with columns `scope`, `endpoint`, `status` ("OK" or error
message), printed as a summary table.

## Examples

``` r
if (FALSE) { # \dontrun{
bs_auth()
bs_check_scopes()
} # }
```
