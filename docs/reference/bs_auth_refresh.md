# Authenticate with a refresh token

Authenticates using an existing refresh token, without requiring browser
interaction. Ideal for non-interactive scripts and scheduled jobs.

## Usage

``` r
bs_auth_refresh(
  refresh_token,
  client_id = Sys.getenv("BRIGHTSPACE_CLIENT_ID"),
  client_secret = Sys.getenv("BRIGHTSPACE_CLIENT_SECRET"),
  instance_url = Sys.getenv("BRIGHTSPACE_INSTANCE_URL"),
  scope = ""
)
```

## Arguments

- refresh_token:

  The OAuth2 refresh token string.

- client_id:

  OAuth2 client ID. Defaults to `BRIGHTSPACE_CLIENT_ID` environment
  variable.

- client_secret:

  OAuth2 client secret. Defaults to `BRIGHTSPACE_CLIENT_SECRET`
  environment variable.

- instance_url:

  Your Brightspace instance URL. Defaults to `BRIGHTSPACE_INSTANCE_URL`
  environment variable.

- scope:

  OAuth2 scope.

## Value

Invisibly returns `TRUE` on success.

## Examples

``` r
if (FALSE) { # \dontrun{
bs_auth_refresh(refresh_token = "my-refresh-token")
} # }
```
