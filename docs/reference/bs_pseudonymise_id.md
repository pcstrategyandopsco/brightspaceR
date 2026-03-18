# Pseudonymise a vector of IDs

Replaces each value with an HMAC-SHA256 pseudonym of the form
`usr_a3f2b1c8`. The same value + key always produces the same pseudonym,
so joins and grouping work correctly within a session.

## Usage

``` r
bs_pseudonymise_id(values, key)
```

## Arguments

- values:

  A vector of IDs (integer, numeric, or character). `NA` values are
  preserved.

- key:

  A raw vector used as the HMAC key. Generate one per session with
  `openssl::rand_bytes(32)`. Required — there is no default, to force
  deliberate key management.

## Value

A character vector the same length as `values`, with non-`NA` entries
replaced by `usr_` plus 8 hex characters.

## Examples

``` r
key <- openssl::rand_bytes(32)
bs_pseudonymise_id(c(1, 2, NA, 3), key = key)
#> Error in bs_pseudonymise_id(c(1, 2, NA, 3), key = key): could not find function "bs_pseudonymise_id"
```
