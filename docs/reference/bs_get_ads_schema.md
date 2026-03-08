# Get the schema for an ADS dataset

Get the schema for an ADS dataset

## Usage

``` r
bs_get_ads_schema(dataset_name)
```

## Arguments

- dataset_name:

  Name of the dataset (will be normalized to snake_case).

## Value

A schema list, or `NULL` if no schema is registered.

## Examples

``` r
bs_get_ads_schema("Learner Usage")
#> $col_types
#> $cols
#> $cols$`course offering id`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`course offering code`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`course offering name`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`parent department name`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`parent department code`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`user id`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$username
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`org defined id`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`first name`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`last name`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`is active`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`role id`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`role name`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`content completed`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`content required`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`checklist completed`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`quiz completed`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`total quiz attempts`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`discussion post created`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`discussion post replies`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`discussion post read`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`number of assignment submissions`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`number of logins to the system`
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$`last visited date`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`last system login`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`last discussion post date`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`last assignment submission date`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`total time spent in content`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`last quiz attempt date`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`last scorm completion date`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$`last scorm visit date`
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> 
#> $default
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $delim
#> NULL
#> 
#> attr(,"class")
#> [1] "col_spec"
#> 
#> $date_cols
#> [1] "last visited date"               "last system login"              
#> [3] "last discussion post date"       "last assignment submission date"
#> [5] "last quiz attempt date"          "last scorm completion date"     
#> [7] "last scorm visit date"          
#> 
#> $bool_cols
#> [1] "is active"
#> 
#> $key_cols
#> [1] "course offering id" "user id"           
#> 
```
