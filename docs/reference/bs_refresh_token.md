# Refresh an OAuth2 token

Refresh an OAuth2 token

## Usage

``` r
bs_refresh_token(token, client_id, client_secret, scope)
```

## Arguments

- token:

  A token list with a `refresh_token` field.

- client_id:

  OAuth2 client ID.

- client_secret:

  OAuth2 client secret.

- scope:

  OAuth2 scope.

## Value

A new token list.
