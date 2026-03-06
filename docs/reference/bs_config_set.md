# Create or update a Brightspace config file

Interactively creates or updates a `config.yml` file with Brightspace
OAuth2 credentials. If the file already exists, the `brightspace`
section is updated while preserving other settings.

## Usage

``` r
bs_config_set(
  client_id,
  client_secret,
  instance_url,
  redirect_uri = "https://localhost:1410/",
  scope = "datahub:dataexports:*",
  file = "config.yml",
  profile = "default"
)
```

## Arguments

- client_id:

  OAuth2 client ID.

- client_secret:

  OAuth2 client secret.

- instance_url:

  Your Brightspace instance URL (e.g.,
  `"https://myschool.brightspace.com"`).

- redirect_uri:

  Redirect URI. Defaults to `"https://localhost:1410/"`.

- scope:

  OAuth2 scope. Defaults to `"datahub:dataexports:*"`.

- file:

  Path for the config file. Defaults to `"config.yml"`.

- profile:

  Configuration profile to write to. Defaults to `"default"`.

## Value

Invisibly returns the file path.

## Examples

``` r
if (FALSE) { # \dontrun{
bs_config_set(
  client_id = "my-client-id",
  client_secret = "my-secret",
  instance_url = "https://myschool.brightspace.com"
)
} # }
```
