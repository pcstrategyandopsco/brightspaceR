# Read Brightspace credentials from a config file

Reads Brightspace OAuth2 credentials from a YAML configuration file
using the config package. The function looks for a `brightspace` key in
the config file and returns the credentials as a named list.

## Usage

``` r
bs_config(
  file = "config.yml",
  profile = Sys.getenv("R_CONFIG_ACTIVE", "default")
)
```

## Arguments

- file:

  Path to the YAML config file. Defaults to `"config.yml"` in the
  working directory.

- profile:

  Configuration profile to use. Defaults to the `R_CONFIG_ACTIVE`
  environment variable, or `"default"` if unset.

## Value

A named list with elements `client_id`, `client_secret`, `instance_url`,
`redirect_uri`, and `scope`, or `NULL` if the file does not exist or the
`brightspace` key is missing.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
# Read from default config.yml
cfg <- bs_config()
cfg$client_id

# Read from a custom file and profile
cfg <- bs_config(file = "my-config.yml", profile = "production")
}
# }
```
