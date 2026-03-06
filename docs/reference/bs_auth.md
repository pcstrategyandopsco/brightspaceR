# Authenticate with Brightspace

Initiates an OAuth2 Authorization Code flow to authenticate with the
Brightspace Data Sets API. Because Brightspace requires an HTTPS
redirect URI and httr2's local server only supports HTTP, this function
uses a manual copy-paste flow: it opens a browser for authorization,
then prompts you to paste the redirect URL containing the authorization
code.

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

  The registered HTTPS redirect URI. Resolved in order: this argument,
  `config.yml` (if present), `BRIGHTSPACE_REDIRECT_URI` env var, or
  `"https://localhost:1410/"`. Must match the URI registered in your
  Brightspace OAuth2 app exactly.

- scope:

  OAuth2 scope. Defaults to `"datahub:dataexports:*"`. Use
  `"datahub:dataexports:* datahub:adhocdataexports:*"` to also access
  Advanced Data Sets.

## Value

Invisibly returns `TRUE` on success.

## Details

The resulting token is cached to disk for reuse across sessions.

## Examples

``` r
if (FALSE) { # \dontrun{
bs_auth()
bs_auth(
  client_id = "my-client-id",
  client_secret = "my-secret",
  instance_url = "https://myschool.brightspace.com"
)
} # }
```
