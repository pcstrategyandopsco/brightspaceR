# Get the schema for a dataset

Get the schema for a dataset

## Usage

``` r
bs_get_schema(dataset_name)
```

## Arguments

- dataset_name:

  Name of the dataset (will be normalized to snake_case).

## Value

A schema list, or `NULL` if no schema is registered.

## Examples

``` r
bs_get_schema("Users")
#> $col_types
#> $cols
#> $cols$UserId
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$UserName
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$OrgDefinedId
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$FirstName
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$MiddleName
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$LastName
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$IsActive
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$Organization
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$ExternalEmail
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$SignupDate
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$FirstLoginDate
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$Version
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$OrgRoleId
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$LastAccessed
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
#> [1] "SignupDate"     "FirstLoginDate" "LastAccessed"  
#> 
#> $bool_cols
#> [1] "IsActive"
#> 
#> $key_cols
#> [1] "UserId"
#> 
bs_get_schema("Grade Results")
#> $col_types
#> $cols
#> $cols$GradeObjectId
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$OrgUnitId
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$UserId
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$PointsNumerator
#> list()
#> attr(,"class")
#> [1] "collector_double" "collector"       
#> 
#> $cols$PointsDenominator
#> list()
#> attr(,"class")
#> [1] "collector_double" "collector"       
#> 
#> $cols$WeightedNumerator
#> list()
#> attr(,"class")
#> [1] "collector_double" "collector"       
#> 
#> $cols$WeightedDenominator
#> list()
#> attr(,"class")
#> [1] "collector_double" "collector"       
#> 
#> $cols$GradeText
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$IsReleased
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$IsDropped
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$LastModified
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$LastModifiedBy
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$Comments
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$PrivateComments
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$GradeReleasedDate
#> list()
#> attr(,"class")
#> [1] "collector_character" "collector"          
#> 
#> $cols$Version
#> list()
#> attr(,"class")
#> [1] "collector_integer" "collector"        
#> 
#> $cols$IsDeleted
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
#> [1] "LastModified"      "GradeReleasedDate"
#> 
#> $bool_cols
#> [1] "IsReleased" "IsDropped"  "IsDeleted" 
#> 
#> $key_cols
#> [1] "GradeObjectId" "OrgUnitId"     "UserId"       
#> 
```
