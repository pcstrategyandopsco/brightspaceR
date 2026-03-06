# Convert column names from PascalCase to snake_case

Convert column names from PascalCase to snake_case

## Usage

``` r
bs_clean_names(df)
```

## Arguments

- df:

  A data frame.

## Value

A data frame with snake_case column names.

## Examples

``` r
df <- data.frame(UserId = 1, FirstName = "A")
bs_clean_names(df)
#>   user_id first_name
#> 1       1          A
```
