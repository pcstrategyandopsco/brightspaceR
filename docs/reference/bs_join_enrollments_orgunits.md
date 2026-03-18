# Join enrollments with org units

Left joins an enrollments tibble with an org units tibble on
`org_unit_id`.

## Usage

``` r
bs_join_enrollments_orgunits(enrollments, org_units)
```

## Arguments

- enrollments:

  A tibble from the User Enrollments dataset.

- org_units:

  A tibble from the Org Units dataset.

## Value

A joined tibble.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
enrollments <- bs_get_dataset("User Enrollments")
org_units <- bs_get_dataset("Org Units")
bs_join_enrollments_orgunits(enrollments, org_units)
}
# }
```
