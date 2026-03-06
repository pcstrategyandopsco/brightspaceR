# Interactive browser-based OAuth2 flow

Builds the authorization URL, opens the browser, prompts for the
redirect URL, and exchanges the code for a token.

## Usage

``` r
bs_auth_interactive(
  client_id,
  client_secret,
  instance_url,
  redirect_uri,
  scope
)
```
