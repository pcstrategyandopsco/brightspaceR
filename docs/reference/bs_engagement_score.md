# Add a composite engagement score

Adds a weighted composite `engagement_score` column to any tibble that
has raw activity count columns. Default weights reflect relative
effort/depth (login is passive, assignment is active). Users should
override for their context.

## Usage

``` r
bs_engagement_score(df, weights = list())
```

## Arguments

- df:

  A tibble with activity count columns.

- weights:

  A named list of column-weight pairs to override defaults. Defaults:
  `login_count = 1`, `quiz_completed = 3`, `assignment_completed = 5`,
  `discussion_posts_created = 2`.

## Value

The input tibble with an `engagement_score` column appended.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
usage <- bs_get_ads("Learner Usage")
scored <- bs_engagement_score(usage)
scored <- bs_engagement_score(usage, weights = list(login_count = 2))
}
# }
```
