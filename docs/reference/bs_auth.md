# Authenticate with Brightspace

Initiates an OAuth2 Authorization Code flow with PKCE to authenticate
with the Brightspace Data Hub API. The resulting token is cached to disk
for reuse across sessions and automatically refreshed when expired.

## Usage

``` r
bs_auth(
  client_id = "",
  client_secret = "",
  instance_url = "",
  redirect_uri = "",
  scope = ""
)
```

## Arguments

- client_id:

  OAuth2 client ID. Resolved in order: this argument, `config.yml` (if
  present), `BRIGHTSPACE_CLIENT_ID` env var.

- client_secret:

  OAuth2 client secret. Resolved in order: this argument, `config.yml`
  (if present), `BRIGHTSPACE_CLIENT_SECRET` env var.

- instance_url:

  Your Brightspace instance URL (e.g.,
  `"https://myschool.brightspace.com"`). Resolved in order: this
  argument, `config.yml` (if present), `BRIGHTSPACE_INSTANCE_URL` env
  var.

- redirect_uri:

  The registered redirect URI. Must match the URI registered in your
  Brightspace OAuth2 app exactly. Supports both `http://localhost`
  (automatic capture via local server) and `https://localhost`
  (browser-based with URL paste).

- scope:

  OAuth2 scope string (space-separated). Resolved from config.yml or
  defaults to BDS + ADS scopes.

## Value

Invisibly returns `TRUE` on success.

## Details

The first authentication requires an interactive R session
(browser-based login). After that, cached credentials are used
automatically — including in non-interactive scripts run via `Rscript`.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
bs_auth()
bs_auth(
  client_id = "my-client-id",
  client_secret = "my-secret",
  instance_url = "https://myschool.brightspace.com"
)
}
# }
```
