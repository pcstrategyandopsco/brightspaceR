# Building an Interactive Dashboard

This article shows how to build a self-contained HTML dashboard from
Brightspace data using R Markdown and Chart.js. The result is a single
HTML file you can open in any browser, share with colleagues, or host on
a web server – no R or Shiny required to view it.

## Strategy

R Markdown is ideal for this: R chunks compute and aggregate data, then
knitr’s inline R expressions inject the results directly into Chart.js
JavaScript blocks. knitr knits the whole thing into a single
self-contained HTML file.

## Step 1: Create the Rmd template

Create a file called `dashboard.Rmd` with this YAML front matter. The
`params` block lets you render the same template for different date
ranges.

``` yaml
---
title: "Brightspace LMS Dashboard"
output:
  html_document:
    self_contained: true
    theme: null
params:
  from_date: !r Sys.Date() - 365
  to_date: !r Sys.Date()
---
```

## Step 2: Data preparation chunk

Add a hidden R chunk that loads and aggregates data. This chunk runs but
produces no visible output (`include=FALSE`).

``` r

# This chunk uses include=FALSE in the actual Rmd
library(brightspaceR)
library(dplyr)
library(lubridate)
library(jsonlite)

# Helpers: convert R vectors to JS array literals
js_labels <- function(x) toJSON(as.character(x), auto_unbox = FALSE)
js_values <- function(x) toJSON(as.numeric(x), auto_unbox = FALSE)

# Fetch datasets
enrollments <- bs_get_dataset("User Enrollments")
roles       <- bs_get_dataset("Role Details")
grades      <- bs_get_dataset("Grade Results")
org_units   <- bs_get_dataset("Org Units")
users       <- bs_get_dataset("Users")

# Apply date filter from params
enrollments <- enrollments |>
  filter(
    as.Date(enrollment_date) >= params$from_date,
    as.Date(enrollment_date) <= params$to_date
  )

# KPIs
total_users <- format(nrow(users), big.mark = ",")
total_enrol <- format(nrow(enrollments), big.mark = ",")
n_courses   <- format(
  n_distinct(org_units$org_unit_id[org_units$type == "Course Offering"]),
  big.mark = ","
)
avg_grade <- grades |>
  filter(!is.na(points_numerator), points_numerator >= 0) |>
  summarise(m = round(mean(points_numerator, na.rm = TRUE), 1)) |>
  pull(m)

# Chart data
role_counts <- enrollments |>
  bs_join_enrollments_roles(roles) |>
  count(role_name, sort = TRUE) |>
  head(8)

monthly_trend <- enrollments |>
  mutate(month = floor_date(as.Date(enrollment_date), "month")) |>
  count(month) |>
  arrange(month)

grade_dist <- grades |>
  filter(!is.na(points_numerator), points_numerator >= 0) |>
  mutate(bracket = cut(points_numerator,
    breaks = seq(0, 100, 10), include.lowest = TRUE, right = FALSE
  )) |>
  count(bracket) |>
  filter(!is.na(bracket))

top_courses <- enrollments |>
  bs_join_enrollments_orgunits(org_units) |>
  filter(type == "Course Offering") |>
  count(name, sort = TRUE) |>
  head(10)
```

## Step 3: HTML layout with inline R

Below the data chunk, add raw HTML for the dashboard layout. knitr
evaluates inline R expressions everywhere in the document – including
inside HTML tags and `<script>` blocks. The syntax is a backtick, the
letter `r`, a space, an R expression, and a closing backtick.

The KPI cards use inline R to inject computed values. For example,
writing the inline R syntax in the HTML outputs the formatted number:

``` html
<div class="kpis">
  <div class="kpi">
    <div class="value" style="color:#818cf8">INLINE_R: total_users</div>
    <div class="label">Total Users</div>
  </div>
  <div class="kpi">
    <div class="value" style="color:#38bdf8">INLINE_R: total_enrol</div>
    <div class="label">Enrollments</div>
  </div>
  <!-- ... same pattern for n_courses, avg_grade -->
</div>
```

Where `INLINE_R: total_users` represents knitr’s inline R syntax: a
backtick, the letter r, a space, the expression, and a closing backtick.
knitr replaces these with the evaluated value at render time.

The chart grid contains `<canvas>` elements for Chart.js:

``` html
<div class="grid">
  <div class="card">
    <h2>Enrollments by Role</h2>
    <canvas id="roleChart"></canvas>
  </div>
  <div class="card">
    <h2>Monthly Enrollment Trend</h2>
    <canvas id="trendChart"></canvas>
  </div>
  <div class="card">
    <h2>Grade Distribution</h2>
    <canvas id="gradeChart"></canvas>
  </div>
  <div class="card">
    <h2>Top 10 Courses</h2>
    <canvas id="courseChart"></canvas>
  </div>
</div>
```

## Step 4: Chart.js with inline R data

Load Chart.js from CDN, then initialise each chart. The key technique:
inline R expressions inside `<script>` tags inject R data as JavaScript
arrays.

``` r

# In the Rmd, this is raw HTML (not an R chunk).
# Inline R expressions like `r js_labels(...)` are replaced by knitr
# with the evaluated JSON output before the HTML is finalised.
#
# Example Chart.js initialisation:
#
# <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
# <script>
# new Chart("roleChart", {
#   type: "doughnut",
#   data: {
#     labels: `r js_labels(role_counts$role_name)`,
#     datasets: [{
#       data: `r js_values(role_counts$n)`,
#       backgroundColor: ["#38bdf8","#818cf8","#f59e0b","#34d399"]
#     }]
#   }
# });
# </script>
```

When knitr processes the Rmd, the inline R expressions are replaced with
their evaluated results:

    Before knitr:
      labels: INLINE_R: js_labels(role_counts$role_name)

    After knitr:
      labels: ["Student","Instructor","TA","Observer"]

The `js_labels()` and `js_values()` helpers use
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
to produce valid JavaScript array literals. This is safer than manual
[`paste0()`](https://rdrr.io/r/base/paste.html) because
[`toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
handles quoting, escaping, and edge cases automatically.

The same pattern applies to each chart: line charts for trends, bar
charts for distributions, horizontal bars for top courses. Each
`new Chart()` call references a `<canvas>` id and uses inline R to
inject labels and data arrays.

## Step 5: CSS styling

Add a `<style>` block at the top of the HTML section for the dashboard
layout:

``` css
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: system-ui, sans-serif; background: #f0f2f5; }
  .header { background: linear-gradient(135deg, #1a1a2e, #16213e);
            color: white; padding: 2rem; }
  .kpis { display: grid; grid-template-columns: repeat(4, 1fr);
          gap: 1rem; padding: 1.5rem; max-width: 1200px; margin: 0 auto; }
  .kpi { background: white; border-radius: 12px; padding: 1.2rem;
         text-align: center; }
  .kpi .value { font-size: 2rem; font-weight: 700; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(480px, 1fr));
          gap: 1.5rem; padding: 0 1.5rem 1.5rem; max-width: 1200px; margin: 0 auto; }
  .card { background: white; border-radius: 12px; padding: 1.5rem; }
  .card h2 { font-size: 1rem; color: #475569; margin-bottom: 1rem; }
</style>
```

## Rendering

``` r

# Default: last 12 months
rmarkdown::render("dashboard.Rmd",
  output_file = "brightspaceR_output/dashboard.html")
browseURL("brightspaceR_output/dashboard.html")
```

## Parameterised reports

Render different versions from the same template without editing the
Rmd:

``` r

# This semester
rmarkdown::render("dashboard.Rmd",
  params = list(from_date = as.Date("2026-01-01"), to_date = Sys.Date()),
  output_file = "brightspaceR_output/dashboard_s1_2026.html"
)

# Last year
rmarkdown::render("dashboard.Rmd",
  params = list(from_date = as.Date("2025-01-01"), to_date = as.Date("2025-12-31")),
  output_file = "brightspaceR_output/dashboard_2025.html"
)
```

This makes it straightforward to generate quarterly or per-semester
reports from a single template.

## Using with the MCP server

The MCP server’s `execute_r` tool can use either approach:

1.  **Rmd rendering** (recommended for complex dashboards): Write the
    Rmd file from `execute_r`, then call
    [`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html).
    This produces the cleanest output and supports params.
2.  **HTML string** (faster, simpler): Build HTML with
    [`paste0()`](https://rdrr.io/r/base/paste.html) and
    [`writeLines()`](https://rdrr.io/r/base/writeLines.html). No Rmd
    dependency, but harder to maintain for complex layouts.

Both write to the output directory and can be opened with
[`browseURL()`](https://rdrr.io/r/utils/browseURL.html).

## Why Chart.js instead of plotly?

|  | Chart.js | plotly |
|----|----|----|
| **Dependencies** | None (CDN) | `plotly` R package + htmlwidgets |
| **File size** | ~80KB (CDN-loaded) | 3-5MB per file (self-contained) |
| **Sharing** | Single HTML, opens anywhere | Single HTML, but large |
| **R Markdown** | Works via inline R in `<script>` | Works via `plotly::ggplotly()` |
| **MCP compatible** | Yes (plain HTML string) | No (`htmlwidgets` needs R session) |
| **Chart types** | Bar, line, doughnut, scatter, radar | Everything, including 3D |

For most LMS analytics – bar charts, line trends, doughnut breakdowns –
Chart.js covers the use cases with zero R-side dependencies.
