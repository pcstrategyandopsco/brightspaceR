# Set Brightspace authentication token directly

Sets authentication credentials without going through the browser-based
OAuth2 flow. Useful for non-interactive environments or when you already
have a valid token.

## Usage

``` r
bs_auth_token(
  token,
  instance_url,
  client_id = Sys.getenv("BRIGHTSPACE_CLIENT_ID"),
  client_secret = Sys.getenv("BRIGHTSPACE_CLIENT_SECRET")
)
```

## Arguments

- token:

  A token list with at least an `access_token` field. Can also include
  `refresh_token`, `expires_in`, etc.

- instance_url:

  Your Brightspace instance URL.

- client_id:

  OAuth2 client ID.

- client_secret:

  OAuth2 client secret.

## Value

Invisibly returns `TRUE`.
