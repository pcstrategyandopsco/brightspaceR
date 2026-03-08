# Read the auth redirect URL from the user

Uses the best available input method: RStudio dialog if available,
otherwise [`readline()`](https://rdrr.io/r/base/readline.html).

## Usage

``` r
bs_read_auth_response()
```

## Value

Character string with the pasted URL.
