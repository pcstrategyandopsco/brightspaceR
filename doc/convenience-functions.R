## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)

## -----------------------------------------------------------------------------
# library(brightspaceR)
# 
# users <- bs_get_dataset("Users")
# users
# #> # A tibble: 12,430 x 14
# #>    user_id first_name last_name  org_defined_id  ...
# #>      <dbl> <chr>      <chr>      <chr>           ...

## -----------------------------------------------------------------------------
# # All datasets
# bs_list_datasets()
# 
# # Find grade-related datasets
# bs_list_datasets() |>
#   dplyr::filter(grepl("grade", name, ignore.case = TRUE))

## -----------------------------------------------------------------------------
# all_data <- bs_download_all()
# names(all_data)
# #> [1] "users"              "user_enrollments"   "org_units"
# #> [4] "grade_results"      "grade_objects"       ...

## -----------------------------------------------------------------------------
# users <- bs_get_dataset("Users")
# enrollments <- bs_get_dataset("User Enrollments")
# 
# # Automatically joins on user_id
# combined <- bs_join(users, enrollments)

## -----------------------------------------------------------------------------
# # Users + Enrollments (by user_id)
# bs_join_users_enrollments(users, enrollments)
# 
# # Enrollments + Grades (by org_unit_id and user_id)
# grades <- bs_get_dataset("Grade Results")
# bs_join_enrollments_grades(enrollments, grades)
# 
# # Grades + Grade Objects (by grade_object_id and org_unit_id)
# grade_objects <- bs_get_dataset("Grade Objects")
# bs_join_grades_objects(grades, grade_objects)
# 
# # Enrollments + Org Units (by org_unit_id)
# org_units <- bs_get_dataset("Org Units")
# bs_join_enrollments_orgunits(enrollments, org_units)
# 
# # Enrollments + Roles (by role_id)
# roles <- bs_get_dataset("Role Details")
# bs_join_enrollments_roles(enrollments, roles)
# 
# # Content Objects + User Progress (by content_object_id and org_unit_id)
# content <- bs_get_dataset("Content Objects")
# progress <- bs_get_dataset("Content User Progress")
# bs_join_content_progress(content, progress)

## -----------------------------------------------------------------------------
# grade_report <- bs_get_dataset("User Enrollments") |>
#   bs_join_enrollments_grades(bs_get_dataset("Grade Results")) |>
#   bs_join_grades_objects(bs_get_dataset("Grade Objects"))
# 
# grade_report
# #> # A tibble: 523,041 x 28
# #>    user_id org_unit_id role_id grade_object_id points_numerator ...

## -----------------------------------------------------------------------------
# bs_list_schemas()
# #>  [1] "users"                          "user_enrollments"
# #>  [3] "org_units"                      "org_unit_types"
# #>  [5] "grade_objects"                  "grade_results"
# #>  [7] "content_objects"                "content_user_progress"
# #>  [9] "quiz_attempts"                  "quiz_user_answers"
# #> [11] "discussion_posts"               "discussion_topics"
# #> [13] "assignment_submissions"         "attendance_registers"
# #> [15] "attendance_records"             "role_details"
# #> [17] "course_offerings"               "final_grades"
# #> [19] "enrollments_and_withdrawals"    "organizational_unit_ancestors"

## -----------------------------------------------------------------------------
# schema <- bs_get_schema("grade_results")
# schema$key_cols
# #> [1] "GradeObjectId" "OrgUnitId" "UserId"
# 
# schema$date_cols
# #> [1] "LastModified"
# 
# schema$bool_cols
# #> [1] "IsReleased" "IsDropped"

## -----------------------------------------------------------------------------
# bs_clean_names(c("UserId", "OrgUnitId", "FirstName", "LastAccessedDate"))
# #> [1] "user_id"            "org_unit_id"        "first_name"
# #> [4] "last_accessed_date"

## -----------------------------------------------------------------------------
# library(dplyr)
# 
# bs_get_dataset("User Enrollments") |>
#   bs_join_enrollments_roles(bs_get_dataset("Role Details")) |>
#   count(role_name, sort = TRUE)
# #> # A tibble: 8 x 2
# #>   role_name       n
# #>   <chr>       <int>
# #> 1 Student    108330
# #> 2 Instructor   5753
# #> 3 ...

## -----------------------------------------------------------------------------
# org_units <- bs_get_dataset("Org Units")
# grades <- bs_get_dataset("Grade Results")
# grade_objs <- bs_get_dataset("Grade Objects")
# 
# # Find the course
# course <- org_units |> filter(grepl("STAT101", name))
# 
# # Build grade report
# grades |>
#   filter(org_unit_id %in% course$org_unit_id) |>
#   bs_join_grades_objects(grade_objs) |>
#   group_by(name) |>
#   summarise(
#     n_students = n_distinct(user_id),
#     mean_score = mean(points_numerator, na.rm = TRUE),
#     .groups = "drop"
#   )

## -----------------------------------------------------------------------------
# bs_get_dataset("Users") |>
#   filter(
#     is_active == TRUE,
#     last_accessed >= Sys.time() - as.difftime(90, units = "days")
#   ) |>
#   nrow()

## -----------------------------------------------------------------------------
# content <- bs_get_dataset("Content Objects")
# progress <- bs_get_dataset("Content User Progress")
# 
# bs_join_content_progress(content, progress) |>
#   group_by(title) |>
#   summarise(
#     n_users = n_distinct(user_id),
#     n_completed = sum(!is.na(completed_date)),
#     completion_rate = n_completed / n_users,
#     .groups = "drop"
#   ) |>
#   arrange(desc(n_users))

