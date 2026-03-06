# Get key columns for a dataset

Returns the primary/foreign key column names for a known dataset.

## Usage

``` r
bs_key_cols(dataset_name)
```

## Arguments

- dataset_name:

  Name of the dataset.

## Value

Character vector of key column names (snake_case), or `NULL`.
