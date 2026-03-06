# Convenience Functions: Joins, Schemas, and Data Wrangling

brightspaceR ships with convenience functions that handle the repetitive
work of joining Brightspace Data Sets (BDS) and parsing column types.
This article walks through each one.

## Fetching datasets

### Single dataset by name

[`bs_get_dataset()`](https://peeyooshchandra.github.io/brightspaceR/reference/bs_get_dataset.md)
is the workhorse. It looks up a dataset by name, downloads the latest
full extract, parses the CSV with the correct column types, and returns
a tidy tibble with snake_case column names:

``` r

library(brightspaceR)

users <- bs_get_dataset("Users")
users
#> # A tibble: 12,430 x 14
#>    user_id first_name last_name  org_defined_id  ...
#>      <dbl> <chr>      <chr>      <chr>           ...
```

### Discovery

If you don’t know the exact dataset name, use
[`bs_list_datasets()`](https://peeyooshchandra.github.io/brightspaceR/reference/bs_list_datasets.md)
to browse everything available, or `bs_search_datasets()` to filter by
keyword:

``` r

# All datasets
bs_list_datasets()

# Find grade-related datasets
bs_list_datasets() |>
  dplyr::filter(grepl("grade", name, ignore.case = TRUE))
```

### Bulk download

Download everything at once as a named list. Useful for building a local
data warehouse or for pipelines that need multiple datasets:

``` r

all_data <- bs_download_all()
names(all_data)
#> [1] "users"              "user_enrollments"   "org_units"
#> [4] "grade_results"      "grade_objects"       ...
```

## Joining datasets

BDS datasets are normalized – users, enrollments, grades, and org units
live in separate tables linked by ID columns. brightspaceR provides two
ways to join them.

### Smart join: `bs_join()`

[`bs_join()`](https://peeyooshchandra.github.io/brightspaceR/reference/bs_join.md)
examines both data frames, finds columns ending in `_id` that appear in
both, and performs a left join on those columns:

``` r

users <- bs_get_dataset("Users")
enrollments <- bs_get_dataset("User Enrollments")

# Automatically joins on user_id
combined <- bs_join(users, enrollments)
```

This works well for most pairs of datasets. Under the hood it uses the
schema registry to identify key columns.

### Named join functions

For explicit, self-documenting code, use the named join functions. Each
specifies exactly which key columns are used:

``` r

# Users + Enrollments (by user_id)
bs_join_users_enrollments(users, enrollments)

# Enrollments + Grades (by org_unit_id and user_id)
grades <- bs_get_dataset("Grade Results")
bs_join_enrollments_grades(enrollments, grades)

# Grades + Grade Objects (by grade_object_id and org_unit_id)
grade_objects <- bs_get_dataset("Grade Objects")
bs_join_grades_objects(grades, grade_objects)

# Enrollments + Org Units (by org_unit_id)
org_units <- bs_get_dataset("Org Units")
bs_join_enrollments_orgunits(enrollments, org_units)

# Enrollments + Roles (by role_id)
roles <- bs_get_dataset("Role Details")
bs_join_enrollments_roles(enrollments, roles)

# Content Objects + User Progress (by content_object_id and org_unit_id)
content <- bs_get_dataset("Content Objects")
progress <- bs_get_dataset("Content User Progress")
bs_join_content_progress(content, progress)
```

All join functions use
[`dplyr::left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html),
so the first argument determines which rows are preserved.

### Chaining joins

Build a complete grade report by chaining joins with the pipe:

``` r

grade_report <- bs_get_dataset("User Enrollments") |>
  bs_join_enrollments_grades(bs_get_dataset("Grade Results")) |>
  bs_join_grades_objects(bs_get_dataset("Grade Objects"))

grade_report
#> # A tibble: 523,041 x 28
#>    user_id org_unit_id role_id grade_object_id points_numerator ...
```

## Schemas and column types

### Why schemas matter

BDS exports everything as CSV with PascalCase column names and string
values. Without schema information, dates come through as character,
booleans as “True”/“False” strings, and IDs as text. brightspaceR’s
schema registry fixes this automatically.

### Registered schemas

The package knows the column types for ~20 common BDS datasets:

``` r

bs_list_schemas()
#>  [1] "users"                          "user_enrollments"
#>  [3] "org_units"                      "org_unit_types"
#>  [5] "grade_objects"                  "grade_results"
#>  [7] "content_objects"                "content_user_progress"
#>  [9] "quiz_attempts"                  "quiz_user_answers"
#> [11] "discussion_posts"               "discussion_topics"
#> [13] "assignment_submissions"         "attendance_registers"
#> [15] "attendance_records"             "role_details"
#> [17] "course_offerings"               "final_grades"
#> [19] "enrollments_and_withdrawals"    "organizational_unit_ancestors"
```

### Inspecting a schema

Each schema defines column types, date columns, boolean columns, and key
columns (used for joining):

``` r

schema <- bs_get_schema("grade_results")
schema$key_cols
#> [1] "GradeObjectId" "OrgUnitId" "UserId"

schema$date_cols
#> [1] "LastModified"

schema$bool_cols
#> [1] "IsReleased" "IsDropped"
```

### Unknown datasets

For datasets without a registered schema, brightspaceR applies
intelligent type coercion:

- Columns that look numeric are parsed as `double`
- Columns containing “True”/“False” or “0”/“1” become `logical`
- Columns matching ISO 8601 date patterns become `POSIXct`
- Everything else stays `character`

This means
[`bs_get_dataset()`](https://peeyooshchandra.github.io/brightspaceR/reference/bs_get_dataset.md)
returns usable tibbles even for datasets the package doesn’t know about.

### Column name conversion

All BDS PascalCase names are automatically converted to snake_case:

``` r

bs_clean_names(c("UserId", "OrgUnitId", "FirstName", "LastAccessedDate"))
#> [1] "user_id"            "org_unit_id"        "first_name"
#> [4] "last_accessed_date"
```

## Common patterns

### Enrollment counts by role

``` r

library(dplyr)

bs_get_dataset("User Enrollments") |>
  bs_join_enrollments_roles(bs_get_dataset("Role Details")) |>
  count(role_name, sort = TRUE)
#> # A tibble: 8 x 2
#>   role_name       n
#>   <chr>       <int>
#> 1 Student    108330
#> 2 Instructor   5753
#> 3 ...
```

### Grade summary for a course

``` r

org_units <- bs_get_dataset("Org Units")
grades <- bs_get_dataset("Grade Results")
grade_objs <- bs_get_dataset("Grade Objects")

# Find the course
course <- org_units |> filter(grepl("STAT101", name))

# Build grade report
grades |>
  filter(org_unit_id %in% course$org_unit_id) |>
  bs_join_grades_objects(grade_objs) |>
  group_by(name) |>
  summarise(
    n_students = n_distinct(user_id),
    mean_score = mean(points_numerator, na.rm = TRUE),
    .groups = "drop"
  )
```

### Active users in the last 90 days

``` r

bs_get_dataset("Users") |>
  filter(
    is_active == TRUE,
    last_accessed >= Sys.time() - as.difftime(90, units = "days")
  ) |>
  nrow()
```

### Content completion rates

``` r

content <- bs_get_dataset("Content Objects")
progress <- bs_get_dataset("Content User Progress")

bs_join_content_progress(content, progress) |>
  group_by(title) |>
  summarise(
    n_users = n_distinct(user_id),
    n_completed = sum(!is.na(completed_date)),
    completion_rate = n_completed / n_users,
    .groups = "drop"
  ) |>
  arrange(desc(n_users))
```
