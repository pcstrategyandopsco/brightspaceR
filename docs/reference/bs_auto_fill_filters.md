# Auto-fill required ADS filters

Queries the dataset's filter definitions and fills in sensible defaults
for any required filter not already provided by the user.

## Usage

``` r
bs_auto_fill_filters(dataset_id, user_filters)
```

## Arguments

- dataset_id:

  The ADS dataset GUID.

- user_filters:

  Filters already supplied by the user (list of `list(Name, Value)`
  objects).

## Value

A complete filter list with required filters filled in.
