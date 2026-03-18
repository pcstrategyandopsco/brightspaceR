# Summarize engagement by grouping dimension

Aggregates engagement metrics from Learner Usage data by course,
department, or user.

## Usage

``` r
bs_engagement_summary(learner_usage, by = c("course", "department", "user"))
```

## Arguments

- learner_usage:

  A tibble from the Learner Usage ADS.

- by:

  Grouping dimension: `"course"`, `"department"`, or `"user"`.

## Value

A summarised tibble sorted by `mean_progress` descending (or
`last_activity` for user grouping).

## Examples

``` r
# \donttest{
if (bs_has_token()) {
usage <- bs_get_ads("Learner Usage")
bs_engagement_summary(usage, by = "course")
bs_engagement_summary(usage, by = "department")
bs_engagement_summary(usage, by = "user")
}
# }
```
