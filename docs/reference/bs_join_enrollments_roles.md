# Join enrollments with role details

Left joins an enrollments tibble with a role details tibble on
`role_id`.

## Usage

``` r
bs_join_enrollments_roles(enrollments, role_details)
```

## Arguments

- enrollments:

  A tibble from the User Enrollments dataset.

- role_details:

  A tibble from the Role Details dataset.

## Value

A joined tibble.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
enrollments <- bs_get_dataset("User Enrollments")
roles <- bs_get_dataset("Role Details")
bs_join_enrollments_roles(enrollments, roles)
}
# }
```
