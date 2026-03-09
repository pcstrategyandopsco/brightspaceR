## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)

## -----------------------------------------------------------------------------
# library(brightspaceR)
# bs_auth()

## -----------------------------------------------------------------------------
# datasets <- bs_list_datasets()
# datasets

## -----------------------------------------------------------------------------
# extracts <- bs_list_extracts(
#   schema_id = datasets$schema_id[1],
#   plugin_id = datasets$plugin_id[1]
# )
# extracts

## -----------------------------------------------------------------------------
# users <- bs_get_dataset("Users")
# users

## -----------------------------------------------------------------------------
# all_data <- bs_download_all()
# names(all_data)
# 
# # Access individual datasets
# all_data$users
# all_data$org_units

## -----------------------------------------------------------------------------
# users <- bs_get_dataset("Users")
# enrollments <- bs_get_dataset("User Enrollments")
# grades <- bs_get_dataset("Grade Results")
# grade_objects <- bs_get_dataset("Grade Objects")
# 
# # Join users with their enrollments
# user_enrollments <- bs_join_users_enrollments(users, enrollments)
# 
# # Chain joins to build a complete grade report
# grade_report <- enrollments |>
#   bs_join_enrollments_grades(grades) |>
#   bs_join_grades_objects(grade_objects)
# 
# grade_report

## -----------------------------------------------------------------------------
# result <- bs_join(users, enrollments)

## -----------------------------------------------------------------------------
# # See which datasets have registered schemas
# bs_list_schemas()
# 
# # View a specific schema
# bs_get_schema("Users")

## -----------------------------------------------------------------------------
# # Download Learner Usage (ADS)
# usage <- bs_get_ads("Learner Usage")
# 
# # Per-user engagement metrics
# engagement <- bs_course_engagement(usage)
# 
# # Identify at-risk students
# at_risk <- bs_identify_at_risk(usage)
# 
# # Course-level dashboard
# dashboard <- bs_course_summary(usage)

## -----------------------------------------------------------------------------
# bs_api_version("1.50")

## -----------------------------------------------------------------------------
# bs_set_timezone("Pacific/Auckland")

## -----------------------------------------------------------------------------
# bs_deauth()

