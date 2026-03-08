# HTTPS redirect URI OAuth2 flow

Handles the auth code flow when the redirect URI uses HTTPS. Opens the
browser for Brightspace login, then prompts the user to paste back the
redirect URL (which the browser can't load since no local HTTPS server
is running — the authorization code is in the address bar).

## Usage

``` r
bs_auth_https_flow(client_id, client_secret, redirect_uri, scope)
```

## Arguments

- client_id:

  OAuth2 client ID.

- client_secret:

  OAuth2 client secret.

- redirect_uri:

  The HTTPS redirect URI.

- scope:

  OAuth2 scope string.

## Value

A token list.
