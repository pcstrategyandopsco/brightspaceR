# Apply a PII field policy to a data frame

Filters or redacts columns based on a YAML-driven field policy. This is
the same logic the MCP server uses to strip PII before data reaches the
AI model.

## Usage

``` r
bs_apply_field_policy(df, dataset_name, policy = NULL)
```

## Arguments

- df:

  A data frame (typically from
  [`bs_get_dataset()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_dataset.md)).

- dataset_name:

  Character string identifying the BDS dataset.

- policy:

  A named list representing the field policy (as returned by
  [`yaml::read_yaml()`](https://yaml.r-lib.org/reference/read_yaml.html)).
  If `NULL` (the default), loads the bundled `field_policy.yml` shipped
  with the package.

## Value

The input data frame with the field policy applied.

## Details

The policy supports three modes per dataset:

- `allow`:

  Only the listed fields are kept; all others are dropped.

- `redact`:

  The listed fields have their values replaced with `"[REDACTED]"`; all
  other fields pass through.

- `all`:

  All columns pass through unchanged.

If `dataset_name` is not found in the policy, the data frame is returned
unchanged.

## Examples

``` r
df <- data.frame(
  UserId = 1L, FirstName = "Jane", Organization = "Org1",
  stringsAsFactors = FALSE
)
bs_apply_field_policy(df, "Users")
#> Error in bs_apply_field_policy(df, "Users"): could not find function "bs_apply_field_policy"
```
