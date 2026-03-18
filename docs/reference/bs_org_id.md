# Get the root organisation ID

Calls `/d2l/api/lp/(version)/organization/info` and returns the org
identifier.

## Usage

``` r
bs_org_id()
```

## Value

Character string of the root org unit ID.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
bs_org_id()
}
# }
```
