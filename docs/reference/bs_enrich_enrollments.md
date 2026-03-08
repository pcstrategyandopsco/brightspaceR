# Enrich enrollments with org unit and user details

Builds the enriched enrollment table by joining enrollments with org
units and users, adding analysis-friendly column aliases. Original
column names are preserved for compatibility; friendly aliases are added
for readability.

## Usage

``` r
bs_enrich_enrollments(
  enrollments,
  org_units,
  users,
  course_type = "Course Offering"
)
```

## Arguments

- enrollments:

  A tibble from the Enrollments and Withdrawals dataset.

- org_units:

  A tibble from the Org Units dataset.

- users:

  A tibble from the Users dataset.

- course_type:

  Org unit type to filter to (default `"Course Offering"`). Set to
  `NULL` to keep all org unit types.

## Value

A tibble with both original and friendly column names, filtered to the
specified course type.

## Examples

``` r
if (FALSE) { # \dontrun{
enroll <- bs_get_dataset("Enrollments and Withdrawals")
org_units <- bs_get_dataset("Org Units")
users <- bs_get_dataset("Users")
enriched <- bs_enrich_enrollments(enroll, org_units, users)
} # }
```
