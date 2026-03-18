# Join enrollments with grade results

Left joins an enrollments tibble with a grade results tibble on
`org_unit_id` and `user_id`.

## Usage

``` r
bs_join_enrollments_grades(enrollments, grade_results)
```

## Arguments

- enrollments:

  A tibble from the User Enrollments dataset.

- grade_results:

  A tibble from the Grade Results dataset.

## Value

A joined tibble.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
enrollments <- bs_get_dataset("User Enrollments")
grades <- bs_get_dataset("Grade Results")
bs_join_enrollments_grades(enrollments, grades)
}
# }
```
