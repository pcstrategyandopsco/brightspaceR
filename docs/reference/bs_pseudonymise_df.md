# Pseudonymise person-referencing ID columns in a data frame

Applies
[`bs_pseudonymise_id()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_pseudonymise_id.md)
to the person-referencing columns for a known Brightspace Data Set.
Structural IDs (OrgUnitId, GradeObjectId, etc.) are left untouched.

## Usage

``` r
bs_pseudonymise_df(df, dataset_name, key, columns = NULL)
```

## Arguments

- df:

  A data frame (typically from
  [`bs_get_dataset()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_dataset.md)).

- dataset_name:

  Character string identifying the BDS dataset (e.g. `"Users"`,
  `"Grade Results"`). Used to look up which columns contain
  person-referencing IDs.

- key:

  A raw vector used as the HMAC key (passed to
  [`bs_pseudonymise_id()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_pseudonymise_id.md)).

- columns:

  Character vector of column names to pseudonymise. If `NULL` (the
  default), the built-in registry is used based on `dataset_name`. If
  `dataset_name` is not in the registry and `columns` is `NULL`, the
  data frame is returned unchanged.

## Value

The input data frame with person-referencing columns replaced by
pseudonyms.

## Examples

``` r
key <- openssl::rand_bytes(32)
df <- data.frame(UserId = c(1L, 2L), OrgUnitId = c(10L, 20L))
bs_pseudonymise_df(df, "Users", key = key)
#> Error in bs_pseudonymise_df(df, "Users", key = key): could not find function "bs_pseudonymise_df"
```
