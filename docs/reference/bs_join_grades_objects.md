# Join grade results with grade objects

Left joins a grade results tibble with a grade objects tibble on
`grade_object_id` and `org_unit_id`.

## Usage

``` r
bs_join_grades_objects(grade_results, grade_objects)
```

## Arguments

- grade_results:

  A tibble from the Grade Results dataset.

- grade_objects:

  A tibble from the Grade Objects dataset.

## Value

A joined tibble.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
grades <- bs_get_dataset("Grade Results")
objects <- bs_get_dataset("Grade Objects")
bs_join_grades_objects(grades, objects)
}
# }
```
