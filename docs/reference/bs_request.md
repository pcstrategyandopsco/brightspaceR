# Create a base Brightspace API request

Builds an httr2 request with the correct base URL, OAuth2 token,
user-agent, and retry logic. Brightspace uses a token-bucket credit
scheme for rate limiting (not a fixed rate), so no client-side throttle
is applied. If the credit bucket is exhausted, the server returns 429
with a `Retry-After` header, which httr2 honours automatically.

## Usage

``` r
bs_request(path)
```

## Arguments

- path:

  API path (e.g., `/d2l/api/lp/1.49/datasets/bds`).

## Value

An httr2 request object.
