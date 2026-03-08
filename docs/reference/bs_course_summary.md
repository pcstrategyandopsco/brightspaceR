# Summarize course effectiveness

Creates a per-course dashboard view with engagement, progress, and
optionally award-based completion metrics. `completion_rate_progress`
uses content progress (available from Learner Usage alone);
`completion_rate_awards` uses certificate issuance (more authoritative
but requires Awards Issued dataset).

## Usage

``` r
bs_course_summary(learner_usage, awards = NULL)
```

## Arguments

- learner_usage:

  A tibble from the Learner Usage ADS.

- awards:

  Optional tibble from the Awards Issued ADS. When provided, adds
  award-based completion rate.

## Value

A summarised tibble with one row per course, sorted by `n_learners`
descending.

## Examples

``` r
if (FALSE) { # \dontrun{
usage <- bs_get_ads("Learner Usage")
bs_course_summary(usage)

awards <- bs_get_ads("Awards Issued")
bs_course_summary(usage, awards = awards)
} # }
```
