# Smart join two BDS tibbles

Automatically detects shared key columns between two tibbles based on
the schema registry and performs a join. Falls back to joining on common
column names if schemas are not available.

## Usage

``` r
bs_join(df1, df2, type = c("left", "inner", "right", "full"))
```

## Arguments

- df1:

  First tibble.

- df2:

  Second tibble.

- type:

  Join type: `"left"` (default), `"inner"`, `"right"`, `"full"`.

## Value

A joined tibble.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
users <- bs_get_dataset("Users")
enrollments <- bs_get_dataset("User Enrollments")
bs_join(users, enrollments)
}
# }
```
