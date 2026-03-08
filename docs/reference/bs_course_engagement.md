# Calculate per-user per-course engagement metrics

Computes engagement metrics from Learner Usage ADS data including
progress percentage, days since last visit, and passes through all raw
activity counts. No composite score is computed here — use
[`bs_engagement_score()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_engagement_score.md)
to add one.

## Usage

``` r
bs_course_engagement(learner_usage, tz = NULL)
```

## Arguments

- learner_usage:

  A tibble from the Learner Usage ADS.

- tz:

  Timezone for date conversion. Defaults to
  [`bs_get_timezone()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_timezone.md).

## Value

A tibble with all learner_usage identity columns plus computed metrics:
`progress_pct`, `days_since_visit`.

## Examples

``` r
if (FALSE) { # \dontrun{
usage <- bs_get_ads("Learner Usage")
engagement <- bs_course_engagement(usage)
} # }
```
