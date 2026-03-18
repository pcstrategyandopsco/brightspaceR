# Join content objects with user progress

Left joins a content objects tibble with a content user progress tibble
on `content_object_id` and `org_unit_id`.

## Usage

``` r
bs_join_content_progress(content_objects, content_progress)
```

## Arguments

- content_objects:

  A tibble from the Content Objects dataset.

- content_progress:

  A tibble from the Content User Progress dataset.

## Value

A joined tibble.

## Examples

``` r
# \donttest{
if (bs_has_token()) {
content <- bs_get_dataset("Content Objects")
progress <- bs_get_dataset("Content User Progress")
bs_join_content_progress(content, progress)
}
# }
```
