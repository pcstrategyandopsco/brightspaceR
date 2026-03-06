# Join users with enrollments

Left joins a users tibble with an enrollments tibble on `user_id`.

## Usage

``` r
bs_join_users_enrollments(users, enrollments)
```

## Arguments

- users:

  A tibble from the Users dataset.

- enrollments:

  A tibble from the User Enrollments dataset.

## Value

A joined tibble.

## Examples

``` r
if (FALSE) { # \dontrun{
users <- bs_get_dataset("Users")
enrollments <- bs_get_dataset("User Enrollments")
bs_join_users_enrollments(users, enrollments)
} # }
```
