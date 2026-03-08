# Shiny App Example: LMS Explorer

This article provides a complete Shiny application that uses
brightspaceR to build an interactive LMS analytics dashboard. The app
lets users explore enrollments, grades, and course activity through
point-and-click filters.

## Prerequisites

``` r

install.packages(c("shiny", "bslib", "DT"))
# brightspaceR must be installed and authenticated:
# bs_auth()
```

## The complete app

Save the code below as `app.R` and run with
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

``` r

library(shiny)
library(bslib)
library(DT)
library(dplyr)
library(ggplot2)
library(lubridate)
library(brightspaceR)

# ── Data loading ──────────────────────────────────────────────────────────────
# Load once at startup. In production, wrap in a reactive timer to refresh
# periodically.
message("Loading Brightspace data...")
users        <- bs_get_dataset("Users")
enrollments  <- bs_get_dataset("User Enrollments")
org_units    <- bs_get_dataset("Org Units")
roles        <- bs_get_dataset("Role Details")
grades       <- bs_get_dataset("Grade Results")
grade_objects <- bs_get_dataset("Grade Objects")

# Pre-join common combinations
enrollment_detail <- enrollments |>
  bs_join_enrollments_roles(roles) |>
  bs_join_enrollments_orgunits(org_units)

grade_detail <- grades |>
  bs_join_grades_objects(grade_objects)

message("Data loaded.")

# ── UI ────────────────────────────────────────────────────────────────────────
ui <- page_sidebar(
  title = "brightspaceR LMS Explorer",
  theme = bs_theme(
    preset = "shiny",
    primary = "#f59e0b",
    "navbar-bg" = "#1a1a2e"
  ),

  sidebar = sidebar(
    width = 280,
    title = "Filters",
    selectInput("role_filter", "Role",
      choices = c("All", sort(unique(enrollment_detail$role_name))),
      selected = "All"
    ),
    selectInput("course_filter", "Course",
      choices = c("All", sort(unique(
        org_units$name[org_units$type == "Course Offering"]
      ))),
      selected = "All"
    ),
    dateRangeInput("date_range", "Enrollment Date",
      start = Sys.Date() - 365,
      end = Sys.Date()
    ),
    hr(),
    actionButton("refresh", "Refresh Data", class = "btn-outline-primary btn-sm")
  ),

  # KPI cards
  layout_columns(
    col_widths = c(3, 3, 3, 3),
    value_box(
      title = "Total Users", value = textOutput("kpi_users"),
      showcase = icon("users"), theme = "primary"
    ),
    value_box(
      title = "Enrollments", value = textOutput("kpi_enrollments"),
      showcase = icon("graduation-cap"), theme = "info"
    ),
    value_box(
      title = "Courses", value = textOutput("kpi_courses"),
      showcase = icon("book"), theme = "success"
    ),
    value_box(
      title = "Avg Grade", value = textOutput("kpi_grade"),
      showcase = icon("chart-line"), theme = "warning"
    )
  ),

  # Charts row
  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header("Enrollments by Role"),
      plotOutput("role_chart", height = "300px")
    ),
    card(
      card_header("Monthly Enrollment Trend"),
      plotOutput("trend_chart", height = "300px")
    )
  ),

  # Second charts row
  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header("Grade Distribution"),
      plotOutput("grade_chart", height = "300px")
    ),
    card(
      card_header("Top 10 Courses"),
      plotOutput("course_chart", height = "300px")
    )
  ),

  # Data table
  card(
    card_header("Enrollment Detail"),
    DTOutput("enrollment_table")
  )
)

# ── Server ────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {

  # Filtered enrollment data
  filtered_enrollments <- reactive({
    df <- enrollment_detail

    if (input$role_filter != "All") {
      df <- df |> filter(role_name == input$role_filter)
    }
    if (input$course_filter != "All") {
      df <- df |> filter(name == input$course_filter)
    }
    if (!is.null(input$date_range)) {
      df <- df |> filter(
        as.Date(enrollment_date) >= input$date_range[1],
        as.Date(enrollment_date) <= input$date_range[2]
      )
    }
    df
  })

  # Filtered grades
  filtered_grades <- reactive({
    df <- grade_detail |>
      filter(!is.na(points_numerator), points_numerator >= 0)

    if (input$course_filter != "All") {
      course_ids <- org_units |>
        filter(name == input$course_filter) |>
        pull(org_unit_id)
      df <- df |> filter(org_unit_id %in% course_ids)
    }
    df
  })

  # ── KPIs ──
  output$kpi_users <- renderText({
    format(nrow(users), big.mark = ",")
  })

  output$kpi_enrollments <- renderText({
    format(nrow(filtered_enrollments()), big.mark = ",")
  })

  output$kpi_courses <- renderText({
    n <- filtered_enrollments() |>
      filter(type == "Course Offering") |>
      distinct(org_unit_id) |>
      nrow()
    format(n, big.mark = ",")
  })

  output$kpi_grade <- renderText({
    g <- filtered_grades()
    if (nrow(g) == 0) return("--")
    paste0(round(mean(g$points_numerator, na.rm = TRUE), 1), "%")
  })

  # ── Charts ──
  chart_theme <- theme_minimal(base_size = 13) +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.grid.minor = element_blank()
    )

  output$role_chart <- renderPlot({
    filtered_enrollments() |>
      count(role_name, sort = TRUE) |>
      head(8) |>
      ggplot(aes(x = reorder(role_name, n), y = n, fill = role_name)) +
      geom_col(show.legend = FALSE) +
      coord_flip() +
      scale_fill_brewer(palette = "Set2") +
      labs(x = NULL, y = "Count") +
      chart_theme
  })

  output$trend_chart <- renderPlot({
    filtered_enrollments() |>
      mutate(month = floor_date(as.Date(enrollment_date), "month")) |>
      count(month) |>
      ggplot(aes(x = month, y = n)) +
      geom_line(colour = "#818cf8", linewidth = 1) +
      geom_point(colour = "#818cf8", size = 2) +
      scale_x_date(date_labels = "%b %Y") +
      labs(x = NULL, y = "New Enrollments") +
      chart_theme
  })

  output$grade_chart <- renderPlot({
    filtered_grades() |>
      ggplot(aes(x = points_numerator)) +
      geom_histogram(binwidth = 5, fill = "#38bdf8", colour = "white") +
      labs(x = "Grade (%)", y = "Count") +
      chart_theme
  })

  output$course_chart <- renderPlot({
    filtered_enrollments() |>
      filter(type == "Course Offering") |>
      count(name, sort = TRUE) |>
      head(10) |>
      ggplot(aes(x = reorder(name, n), y = n)) +
      geom_col(fill = "#f59e0b") +
      coord_flip() +
      labs(x = NULL, y = "Enrollments") +
      chart_theme
  })

  # ── Data table ──
  output$enrollment_table <- renderDT({
    filtered_enrollments() |>
      select(any_of(c(
        "user_id", "role_name", "name", "type",
        "enrollment_date"
      ))) |>
      head(500)
  }, options = list(pageLength = 15, scrollX = TRUE))

  # ── Refresh button ──
  observeEvent(input$refresh, {
    showNotification("Refreshing data...", type = "message")
    # In production, re-fetch from Brightspace here
  })
}

shinyApp(ui, server)
```

## Running the app

``` r

# From the directory containing app.R:
shiny::runApp()

# Or run from anywhere:
shiny::runApp("/path/to/app.R")
```

## How it works

### Data loading

The app loads six BDS datasets at startup and pre-joins them into two
working tables:

- **`enrollment_detail`**: enrollments joined with roles and org units –
  gives each enrollment row a human-readable role name and course name.
- **`grade_detail`**: grade results joined with grade objects – adds
  grade item names and max points to each score.

This front-loads the expensive I/O so the reactive filters are fast.

### Filtering

Three filters (role, course, date range) drive all charts and the data
table through a single `filtered_enrollments()` reactive. Changing any
filter instantly updates the full dashboard.

### Chart rendering

The app uses ggplot2 for charts. For a production deployment with
heavier interactivity needs (tooltips, zoom, click events), swap
`plotOutput` for `plotly::plotlyOutput` and wrap ggplots in
`plotly::ggplotly()`:

``` r

# In UI:
plotly::plotlyOutput("role_chart", height = "300px")

# In server:
output$role_chart <- plotly::renderPlotly({
  p <- ggplot(...) + geom_col(...)
  plotly::ggplotly(p)
})
```

## Extending the app

### Adding authentication

For multi-user deployments, wrap the data loading in a reactive that
authenticates per session:

``` r

# In server:
bs_data <- reactive({
  # Each user needs their own token
  bs_auth_token(session$userData$token)
  list(
    users = bs_get_dataset("Users"),
    enrollments = bs_get_dataset("User Enrollments")
  )
})
```

### Adding a download button

Let users export the filtered data as CSV:

``` r

# In UI, inside the enrollment_table card:
downloadButton("download_csv", "Export CSV")

# In server:
output$download_csv <- downloadHandler(
  filename = function() {
    paste0("enrollments_", Sys.Date(), ".csv")
  },
  content = function(file) {
    readr::write_csv(filtered_enrollments(), file)
  }
)
```

### Scheduled data refresh

For always-fresh data, use
[`reactiveTimer()`](https://rdrr.io/pkg/shiny/man/reactiveTimer.html) to
periodically re-fetch:

``` r

# Re-fetch every 30 minutes
auto_refresh <- reactiveTimer(30 * 60 * 1000)

live_enrollments <- reactive({
  auto_refresh()
  bs_get_dataset("User Enrollments")
})
```

### Deploying to Posit Connect / shinyapps.io

1.  Store credentials as environment variables on the server
2.  Use
    [`bs_auth_refresh()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth_refresh.md)
    with a long-lived refresh token instead of the interactive browser
    flow
3.  Pin datasets with the `pins` package for faster startup:

``` r

# Write once:
board <- pins::board_connect()
pins::pin_write(board, bs_get_dataset("Users"), "brightspace_users")

# Read in app:
users <- pins::pin_read(board, "brightspace_users")
```
