# Getting Started with brightspaceR

## Overview

brightspaceR connects to the D2L Brightspace Data Sets (BDS) API via
OAuth2, downloads all available datasets as tidy data frames with proper
types, and provides convenience functions for joining them.

## Prerequisites

Before using this package you must register an OAuth2 application in
your Brightspace instance. See
[`vignette("setup")`](https://pcstrategyandopsco.github.io/brightspaceR/articles/setup.md)
for detailed step-by-step instructions covering app registration,
scopes, redirect URIs, and troubleshooting.

Once configured, authenticate:

``` r

library(brightspaceR)
bs_auth()
```

## Discovering Datasets

List all available datasets:

``` r

datasets <- bs_list_datasets()
datasets
```

See available extracts (full and differential) for a specific dataset:

``` r

extracts <- bs_list_extracts(
  schema_id = datasets$schema_id[1],
  plugin_id = datasets$plugin_id[1]
)
extracts
```

## Downloading Datasets

Download a single dataset by name:

``` r

users <- bs_get_dataset("Users")
users
```

Download all datasets at once:

``` r

all_data <- bs_download_all()
names(all_data)

# Access individual datasets
all_data$users
all_data$org_units
```

## Joining Datasets

Use the convenience join functions to combine related datasets:

``` r

users <- bs_get_dataset("Users")
enrollments <- bs_get_dataset("User Enrollments")
grades <- bs_get_dataset("Grade Results")
grade_objects <- bs_get_dataset("Grade Objects")

# Join users with their enrollments
user_enrollments <- bs_join_users_enrollments(users, enrollments)

# Chain joins to build a complete grade report
grade_report <- enrollments |>
  bs_join_enrollments_grades(grades) |>
  bs_join_grades_objects(grade_objects)

grade_report
```

Or use the smart join that auto-detects key columns:

``` r

result <- bs_join(users, enrollments)
```

## Column Types and Schemas

brightspaceR knows the column types for ~20 common BDS datasets. Column
names are automatically converted from BDS PascalCase to snake_case:

``` r

# See which datasets have registered schemas
bs_list_schemas()

# View a specific schema
bs_get_schema("Users")
```

For unknown datasets, columns are read as character and then
intelligently coerced to numeric, logical, or datetime types.

## Advanced Data Sets (ADS)

ADS datasets like Learner Usage provide engagement metrics not available
in BDS. They require additional `reporting:*` OAuth2 scopes (Tier 2 –
see
[`vignette("setup")`](https://pcstrategyandopsco.github.io/brightspaceR/articles/setup.md)).

``` r

# Download Learner Usage (ADS)
usage <- bs_get_ads("Learner Usage")

# Per-user engagement metrics
engagement <- bs_course_engagement(usage)

# Identify at-risk students
at_risk <- bs_identify_at_risk(usage)

# Course-level dashboard
dashboard <- bs_course_summary(usage)
```

If ADS scopes are not configured,
[`bs_get_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_ads.md)
returns `NULL` with a warning – BDS functions are unaffected.

## Configuration

Set the API version (default is `1.49`):

``` r

bs_api_version("1.50")
```

Set the timezone for date conversions in analytics functions:

``` r

bs_set_timezone("Pacific/Auckland")
```

## Cleaning Up

Clear your cached credentials:

``` r

bs_deauth()
```
