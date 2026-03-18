# Summarize enrollments to one row per user per course

Collapses enrollment records to keep only the latest enrollment date for
each user-course combination.

## Usage

``` r
bs_summarize_enrollments(enriched_enrollments, event_type = "Enroll")
```

## Arguments

- enriched_enrollments:

  An enriched enrollment tibble (from
  [`bs_enrich_enrollments()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_enrich_enrollments.md)).

- event_type:

  The event type to filter to (default `"Enroll"`).

## Value

A tibble with one row per user per course.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
enriched <- bs_enrich_enrollments(enroll, org_units, users)
summary <- bs_summarize_enrollments(enriched)
}
# }
```
