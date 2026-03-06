# List all registered dataset schemas

List all registered dataset schemas

## Usage

``` r
bs_list_schemas()
```

## Value

A character vector of registered dataset names (snake_case).

## Examples

``` r
bs_list_schemas()
#>  [1] "users"                         "user_enrollments"             
#>  [3] "org_units"                     "org_unit_types"               
#>  [5] "organizational_unit_ancestors" "enrollments_and_withdrawals"  
#>  [7] "grade_objects"                 "grade_results"                
#>  [9] "content_objects"               "content_user_progress"        
#> [11] "quiz_attempts"                 "quiz_user_answers"            
#> [13] "discussion_posts"              "discussion_topics"            
#> [15] "assignment_submissions"        "attendance_registers"         
#> [17] "attendance_records"            "role_details"                 
#> [19] "course_offerings"              "final_grades"                 
```
