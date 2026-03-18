# Clear Brightspace authentication

Removes cached credentials from the current session and optionally from
disk.

## Usage

``` r
bs_deauth(clear_cache = TRUE)
```

## Arguments

- clear_cache:

  If `TRUE` (default), also removes the cached token from disk.

## Value

Invisibly returns `TRUE`.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
bs_deauth()
}
# }
```
