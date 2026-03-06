
# brightspaceR <img src="man/figures/logo.svg" align="right" height="139" alt="brightspaceR logo" />

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

brightspaceR connects R to the [D2L Brightspace Data Sets (BDS) API](https://docs.valence.desire2learn.com/). Authenticate via OAuth2, download datasets as tidy data frames with proper column types, and join them using convenience functions that know the foreign key relationships.

It also ships an **MCP server** that lets AI assistants (Claude Desktop, Claude Code) query your Brightspace data conversationally -- writing R code, running aggregations, and generating interactive charts without you touching code.

## Documentation

**Full documentation and articles: <https://pcstrategyandopsco.github.io/brightspaceR/>**

## Installation

```r
# Install from GitHub
# install.packages("pak")
pak::pak("pcstrategyandopsco/brightspaceR")
```

## Quick start

```r
library(brightspaceR)

# Authenticate (opens browser for OAuth2 flow)
bs_auth()

# List available datasets
bs_list_datasets()

# Download a dataset as a tibble
users <- bs_get_dataset("Users")
enrollments <- bs_get_dataset("User Enrollments")

# Join related datasets (foreign keys handled automatically)
bs_join(users, enrollments)

# Or use named convenience joins
enrollments |>
  bs_join_enrollments_roles(bs_get_dataset("Role Details")) |>
  dplyr::count(role_name, sort = TRUE)
```

## Features

- **OAuth2 authentication** with automatic token caching and refresh
- **Dataset discovery** -- list, search, and describe all available BDS datasets
- **Typed downloads** -- columns are parsed to proper R types (dates, numerics, logicals) via built-in schemas
- **Smart joins** -- `bs_join()` automatically detects shared key columns; seven named join functions cover the most common combinations
- **MCP server** -- lets Claude Desktop or Claude Code query your LMS data conversationally

## Articles

| Topic | Description |
|-------|-------------|
| [Setup & Configuration](https://pcstrategyandopsco.github.io/brightspaceR/articles/setup.html) | OAuth2 setup, config.yml, environment variables |
| [Getting Started](https://pcstrategyandopsco.github.io/brightspaceR/articles/getting-started.html) | First steps with datasets and joins |
| [Convenience Functions](https://pcstrategyandopsco.github.io/brightspaceR/articles/convenience-functions.html) | All join functions, schemas, and common patterns |
| [Interactive Dashboard](https://pcstrategyandopsco.github.io/brightspaceR/articles/interactive-dashboard.html) | Build a self-contained HTML dashboard with R Markdown and Chart.js |
| [Shiny App](https://pcstrategyandopsco.github.io/brightspaceR/articles/shiny-app.html) | Full Shiny app with filters, KPIs, and charts |
| [MCP Server Design](https://pcstrategyandopsco.github.io/brightspaceR/articles/mcp-server-design.html) | Architecture and tool reference for the MCP server |

## MCP server

The MCP server gives AI assistants direct access to your Brightspace data. Claude discovers datasets, writes R code to aggregate and join them, and returns compact results -- text summaries and interactive Chart.js visualisations.

```json
{
  "mcpServers": {
    "brightspaceR": {
      "command": "Rscript",
      "args": ["<path-to>/brightspaceR/inst/mcp/server.R"],
      "cwd": "<path-to>/brightspaceR"
    }
  }
}
```

See the [MCP Server Design](https://pcstrategyandopsco.github.io/brightspaceR/articles/mcp-server-design.html) article for the full tool reference and architecture details.

## License

MIT
