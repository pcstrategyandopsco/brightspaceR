# Summarize grades with percentages

Joins grade results with grade object definitions and calculates grade
percentages.

## Usage

``` r
bs_grade_summary(grade_results, grade_objects)
```

## Arguments

- grade_results:

  A tibble from the Grade Results dataset.

- grade_objects:

  A tibble from the Grade Objects dataset.

## Value

A joined tibble with grade object name, type, max points, and calculated
`grade_pct` and `grade_label`.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
grades <- bs_get_dataset("Grade Results")
objects <- bs_get_dataset("Grade Objects")
bs_grade_summary(grades, objects)
}
# }
```
