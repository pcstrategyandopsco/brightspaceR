# Filter test users from a dataset

Removes test/system accounts using a two-layer filter: ID string length
and an optional exclusion list. This eliminates the repeated boilerplate
of removing test users before analysis.

## Usage

``` r
bs_filter_test_users(
  df,
  min_id_length = 30,
  exclusion_list = NULL,
  id_col = "org_defined_id"
)
```

## Arguments

- df:

  A tibble containing user data.

- min_id_length:

  Minimum character length of a real user ID (default 30). IDs shorter
  than this are assumed to be test accounts.

- exclusion_list:

  Optional character vector of specific IDs to exclude.

- id_col:

  Name of the column containing user IDs (default `"org_defined_id"`).

## Value

A filtered tibble with test users removed.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
users <- bs_get_dataset("Users")
real_users <- bs_filter_test_users(users)
real_users <- bs_filter_test_users(users, exclusion_list = c("testuser01"))
}
# }
```
