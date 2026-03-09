## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)

## ----eval=FALSE---------------------------------------------------------------
# # This chunk uses include=FALSE in the actual Rmd
# library(brightspaceR)
# library(dplyr)
# library(lubridate)
# library(jsonlite)
# 
# # Helpers: convert R vectors to JS array literals
# js_labels <- function(x) toJSON(as.character(x), auto_unbox = FALSE)
# js_values <- function(x) toJSON(as.numeric(x), auto_unbox = FALSE)
# 
# # Fetch datasets
# enrollments <- bs_get_dataset("User Enrollments")
# roles       <- bs_get_dataset("Role Details")
# grades      <- bs_get_dataset("Grade Results")
# org_units   <- bs_get_dataset("Org Units")
# users       <- bs_get_dataset("Users")
# 
# # Apply date filter from params
# enrollments <- enrollments |>
#   filter(
#     as.Date(enrollment_date) >= params$from_date,
#     as.Date(enrollment_date) <= params$to_date
#   )
# 
# # KPIs
# total_users <- format(nrow(users), big.mark = ",")
# total_enrol <- format(nrow(enrollments), big.mark = ",")
# n_courses   <- format(
#   n_distinct(org_units$org_unit_id[org_units$type == "Course Offering"]),
#   big.mark = ","
# )
# avg_grade <- grades |>
#   filter(!is.na(points_numerator), points_numerator >= 0) |>
#   summarise(m = round(mean(points_numerator, na.rm = TRUE), 1)) |>
#   pull(m)
# 
# # Chart data
# role_counts <- enrollments |>
#   bs_join_enrollments_roles(roles) |>
#   count(role_name, sort = TRUE) |>
#   head(8)
# 
# monthly_trend <- enrollments |>
#   mutate(month = floor_date(as.Date(enrollment_date), "month")) |>
#   count(month) |>
#   arrange(month)
# 
# grade_dist <- grades |>
#   filter(!is.na(points_numerator), points_numerator >= 0) |>
#   mutate(bracket = cut(points_numerator,
#     breaks = seq(0, 100, 10), include.lowest = TRUE, right = FALSE
#   )) |>
#   count(bracket) |>
#   filter(!is.na(bracket))
# 
# top_courses <- enrollments |>
#   bs_join_enrollments_orgunits(org_units) |>
#   filter(type == "Course Offering") |>
#   count(name, sort = TRUE) |>
#   head(10)

## ----eval=FALSE---------------------------------------------------------------
# # In the Rmd, this is raw HTML (not an R chunk).
# # Inline R expressions like `r js_labels(...)` are replaced by knitr
# # with the evaluated JSON output before the HTML is finalised.
# #
# # Example Chart.js initialisation:
# #
# # <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
# # <script>
# # new Chart("roleChart", {
# #   type: "doughnut",
# #   data: {
# #     labels: `r js_labels(role_counts$role_name)`,
# #     datasets: [{
# #       data: `r js_values(role_counts$n)`,
# #       backgroundColor: ["#38bdf8","#818cf8","#f59e0b","#34d399"]
# #     }]
# #   }
# # });
# # </script>

## -----------------------------------------------------------------------------
# # Default: last 12 months
# rmarkdown::render("dashboard.Rmd",
#   output_file = "brightspaceR_output/dashboard.html")
# browseURL("brightspaceR_output/dashboard.html")

## -----------------------------------------------------------------------------
# # This semester
# rmarkdown::render("dashboard.Rmd",
#   params = list(from_date = as.Date("2026-01-01"), to_date = Sys.Date()),
#   output_file = "brightspaceR_output/dashboard_s1_2026.html"
# )
# 
# # Last year
# rmarkdown::render("dashboard.Rmd",
#   params = list(from_date = as.Date("2025-01-01"), to_date = as.Date("2025-12-31")),
#   output_file = "brightspaceR_output/dashboard_2025.html"
# )

