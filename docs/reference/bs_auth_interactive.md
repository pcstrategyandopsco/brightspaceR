# Interactive browser-based OAuth2 flow

Handles two redirect URI schemes:

- `http://localhost`: httr2 starts a local server to capture the code
  automatically (zero user interaction after browser login).

- `https://localhost`: Opens browser, then prompts user to paste the
  redirect URL back (browser will show "can't connect" after auth — the
  code is in the address bar).

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

## Details

Requires an interactive R session. Non-interactive scripts should rely
on cached tokens (from a prior interactive auth) or
[`bs_auth_refresh()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth_refresh.md).
