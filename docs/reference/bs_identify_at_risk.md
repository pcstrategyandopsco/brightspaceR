# Identify at-risk students

Flags at-risk students from Learner Usage data based on configurable
thresholds. Adds boolean risk flags and a composite risk score.

## Usage

``` r
bs_identify_at_risk(learner_usage, thresholds = list())
```

## Arguments

- learner_usage:

  A tibble from the Learner Usage ADS.

- thresholds:

  A named list of thresholds to override defaults. Available thresholds:
  `progress` (default 25), `inactive_days` (default 14), `login_min`
  (default 2).

## Value

A tibble with all original columns plus risk flags (`never_accessed`,
`low_progress`, `inactive`, `low_logins`), `risk_score` (0-4), and
`risk_level` (ordered factor: Low, Medium, High, Critical), sorted by
risk_score descending.

## Examples

``` r
if (FALSE) { # \dontrun{
usage <- bs_get_ads("Learner Usage")
at_risk <- bs_identify_at_risk(usage)
at_risk <- bs_identify_at_risk(usage, thresholds = list(progress = 30))
} # }
```
