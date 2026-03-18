# Summarize assignment submission completion

Aggregates assignment submission data per assignment per org unit,
including grading rates and score statistics.

## Usage

``` r
bs_assignment_completion(assignment_submissions)
```

## Arguments

- assignment_submissions:

  A tibble from the Assignment Submissions dataset.

## Value

A summarised tibble with one row per assignment per org unit.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
submissions <- bs_get_dataset("Assignment Submissions")
bs_assignment_completion(submissions)
}
# }
```
