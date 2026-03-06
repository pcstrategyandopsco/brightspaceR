# Paginate through Brightspace API results

Handles the Brightspace `ObjectListPage` pagination pattern
(bookmark-based).

## Usage

``` r
bs_paginate(path, query = list(), items_field = "BdsType")
```

## Arguments

- path:

  API path.

- query:

  Base query parameters.

- items_field:

  Name of the field containing the items list.

## Value

A list of all items across pages.
