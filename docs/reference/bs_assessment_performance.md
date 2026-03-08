# Summarize assessment performance per user per quiz

Aggregates quiz attempt data into per-user per-quiz performance
summaries including best, average, and latest scores.

## Usage

``` r
bs_assessment_performance(quiz_attempts)
```

## Arguments

- quiz_attempts:

  A tibble from the Quiz Attempts dataset.

## Value

A summarised tibble with one row per user per quiz per org unit.

## Examples

``` r
if (FALSE) { # \dontrun{
attempts <- bs_get_dataset("Quiz Attempts")
bs_assessment_performance(attempts)
} # }
```
