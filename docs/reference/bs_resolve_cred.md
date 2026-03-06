# Resolve a credential from multiple sources

Checks, in order: explicit argument, config file value, environment
variable, and an optional hardcoded fallback.

## Usage

``` r
bs_resolve_cred(arg, config_val = NULL, envvar = "", fallback = "")
```

## Arguments

- arg:

  The explicitly passed argument value (empty string if not set).

- config_val:

  The value from config.yml (may be NULL).

- envvar:

  Name of the environment variable to check.

- fallback:

  Default value if all other sources are empty.

## Value

Character string.
