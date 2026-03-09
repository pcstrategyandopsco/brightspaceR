## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)

## -----------------------------------------------------------------------------
# bs_check_scopes()
# #> i Testing API access with current token...
# #> v All 4 scope checks passed.

## -----------------------------------------------------------------------------
# bs_config_set(
#   client_id = "your-client-id",
#   client_secret = "your-client-secret",
#   instance_url = "https://myschool.brightspace.com"
# )

## -----------------------------------------------------------------------------
# # Open .Renviron for editing
# usethis::edit_r_environ()

## -----------------------------------------------------------------------------
# library(brightspaceR)
# 
# # Uses environment variables automatically
# bs_auth()

## -----------------------------------------------------------------------------
# bs_deauth()
# bs_auth()

## -----------------------------------------------------------------------------
# bs_auth_refresh(
#   refresh_token = Sys.getenv("BRIGHTSPACE_REFRESH_TOKEN")
# )

## -----------------------------------------------------------------------------
# # Check authentication status
# bs_has_token()
# #> [1] TRUE
# 
# # Verify API scopes are configured correctly
# bs_check_scopes()
# #> i Testing API access with current token...
# #> v All 4 scope checks passed.
# 
# # List available BDS datasets
# datasets <- bs_list_datasets()
# datasets
# #> # A tibble: 67 x 5
# #>    schema_id plugin_id name               description             created_date
# #>    <chr>     <chr>     <chr>              <chr>                   <chr>
# #>  1 abc123    def456    Users              User demographics ...   2024-01-01...
# #>  2 ghi789    jkl012    User Enrollments   Enrollment records ...  2024-01-01...
# #> ...
# 
# # If you have Tier 2 (ADS) scopes, also verify ADS access
# ads <- bs_list_ads()
# ads
# #> # A tibble: 12 x 4
# #>    dataset_id   name             description          category
# #>    <chr>        <chr>            <chr>                 <chr>
# #>  1 abc-def-...  Learner Usage    Activity metrics ...  Engagement
# #> ...

## -----------------------------------------------------------------------------
# Sys.getenv("BRIGHTSPACE_CLIENT_ID")

## -----------------------------------------------------------------------------
# bs_deauth()
# bs_auth()

