# Build an ADS export filter

Constructs a filter list for use with
[`bs_create_ads_job()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_create_ads_job.md)
and
[`bs_get_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_ads.md).
Produces the `[{Name, Value}]` array format that the Brightspace
dataExport create endpoint expects.

## Usage

``` r
bs_ads_filter(
  start_date = NULL,
  end_date = NULL,
  parent_org_unit_id = NULL,
  roles = NULL
)
```

## Arguments

- start_date:

  Start date (Date, POSIXct, or character in "YYYY-MM-DD" format).
  Optional.

- end_date:

  End date (Date, POSIXct, or character in "YYYY-MM-DD" format).
  Optional.

- parent_org_unit_id:

  Integer org unit ID to filter by. Optional.

- roles:

  Integer vector of role IDs to filter by. Optional.

## Value

A list of `list(Name = ..., Value = ...)` filter objects.

## Examples

``` r
bs_ads_filter(start_date = "2024-01-01", end_date = "2024-12-31")
#> [[1]]
#> [[1]]$Name
#> [1] "startDate"
#> 
#> [[1]]$Value
#> [1] "2024-01-01T00:00:00.000Z"
#> 
#> 
#> [[2]]
#> [[2]]$Name
#> [1] "endDate"
#> 
#> [[2]]$Value
#> [1] "2024-12-31T00:00:00.000Z"
#> 
#> 
bs_ads_filter(parent_org_unit_id = 6606)
#> [[1]]
#> [[1]]$Name
#> [1] "parentOrgUnitId"
#> 
#> [[1]]$Value
#> [1] "6606"
#> 
#> 
bs_ads_filter(roles = c(110, 120))
#> [[1]]
#> [[1]]$Name
#> [1] "roles"
#> 
#> [[1]]$Value
#> [1] "110,120"
#> 
#> 
```
