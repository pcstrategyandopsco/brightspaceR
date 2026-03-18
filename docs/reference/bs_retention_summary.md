# Summarize retention and dropout rates

Calculates retention metrics by course or department, including start
rates, completion rates, and dropout rates.

## Usage

``` r
bs_retention_summary(learner_usage, by = c("course", "department"))
```

## Arguments

- learner_usage:

  A tibble from the Learner Usage ADS.

- by:

  Grouping dimension: `"course"` or `"department"`.

## Value

A summarised tibble sorted by `completion_rate`.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
usage <- bs_get_ads("Learner Usage")
bs_retention_summary(usage, by = "course")
}
# }
```
