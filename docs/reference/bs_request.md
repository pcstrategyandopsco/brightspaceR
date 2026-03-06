# Create a base Brightspace API request

Builds an httr2 request with the correct base URL, OAuth2 token,
user-agent, rate limiting, and retry logic.

## Usage

``` r
bs_request(path)
```

## Arguments

- path:

  API path (e.g., `/d2l/api/lp/1.49/datasets/bds`).

## Value

An httr2 request object.
