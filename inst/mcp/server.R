#!/usr/bin/env Rscript

# ── brightspaceR MCP Server ─────────────────────────────────────────────────
# Model Context Protocol server for querying Brightspace LMS data.
# Communicates via JSON-RPC 2.0 over stdio (stdin/stdout).
# All diagnostic output goes to stderr; stdout is reserved for MCP protocol.
#
# Design: Claude writes R code, server executes it, returns compact multi-modal
# results (text summaries + inline plots as base64 PNG).
#
# Usage:
#   Rscript inst/mcp/server.R
#
# Claude Desktop config:
#   {
#     "mcpServers": {
#       "brightspaceR": {
#         "command": "Rscript",
#         "args": ["/path/to/brightspaceR/inst/mcp/server.R"],
#         "cwd": "/path/to/project/with/config.yml"
#       }
#     }
#   }

# ── 1. Preamble ─────────────────────────────────────────────────────────────

suppressPackageStartupMessages({
  library(jsonlite)
  library(stringr)
})

# Load brightspaceR: use pkgload::load_all() for dev mode, library() if installed
pkg_root <- Sys.getenv("BRIGHTSPACER_PKG_DIR", "")
if (nchar(pkg_root) == 0) {
  # Auto-detect: script lives at <pkg>/inst/mcp/server.R
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[1]), mustWork = FALSE)
    candidate <- normalizePath(file.path(dirname(script_path), "..", ".."),
                               mustWork = FALSE)
    if (file.exists(file.path(candidate, "DESCRIPTION"))) {
      pkg_root <- candidate
    }
  }
}

if (nchar(pkg_root) > 0 && file.exists(file.path(pkg_root, "DESCRIPTION"))) {
  suppressPackageStartupMessages(
    pkgload::load_all(pkg_root, export_all = FALSE, quiet = TRUE)
  )
} else {
  suppressPackageStartupMessages(library(brightspaceR))
}

# Redirect all cli output to stderr so it doesn't corrupt the MCP protocol
options(
  cli.default_handler = function(msg) {
    cat(conditionMessage(msg), file = stderr())
  }
)

mcp_log <- function(...) {
  cat(paste0("[brightspaceR] ", ..., "\n"), file = stderr())
}

# Helper: named list that serializes as {} not []
empty_obj <- function() structure(list(), names = character(0))

# ── 2. Server Instructions ───────────────────────────────────────────────────

# Output directory for plots and reports
MCP_OUTPUT_DIR <- Sys.getenv("BRIGHTSPACER_OUTPUT_DIR", "")
if (nchar(MCP_OUTPUT_DIR) == 0) {
  # Prefer pkg_root (known to exist), fall back to cwd, last resort home dir
  base_dir <- if (nchar(pkg_root) > 0 && dir.exists(pkg_root)) {
    pkg_root
  } else if (getwd() != "/") {
    getwd()
  } else {
    Sys.getenv("HOME", tempdir())
  }
  MCP_OUTPUT_DIR <- file.path(base_dir, "brightspaceR_output")
}
# Normalize to clean up double slashes or relative paths
MCP_OUTPUT_DIR <- normalizePath(MCP_OUTPUT_DIR, mustWork = FALSE)
if (!dir.exists(MCP_OUTPUT_DIR)) {
  ok <- dir.create(MCP_OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
  if (!ok) {
    mcp_log("WARNING: Could not create output dir: ", MCP_OUTPUT_DIR)
    # Fall back to temp directory as last resort
    MCP_OUTPUT_DIR <- file.path(tempdir(), "brightspaceR_output")
    dir.create(MCP_OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
    mcp_log("Using fallback output dir: ", MCP_OUTPUT_DIR)
  }
}
mcp_log("Output directory: ", MCP_OUTPUT_DIR)
mcp_log("Dir writable: ", file.access(MCP_OUTPUT_DIR, 2) == 0)

SERVER_INSTRUCTIONS <- paste0(
  "brightspaceR MCP server provides access to Brightspace LMS data.\n\n",
  "Output directory: ", MCP_OUTPUT_DIR, "\n\n",
  "Workflow:\n",
  "1. Use list_datasets or search_datasets to discover data\n",
  "2. Use describe_dataset to understand columns and distributions\n",
  "3. Use get_data_summary with filter_by/group_by for quick stats\n",
  "4. Use execute_r for custom analysis -- write dplyr pipelines, joins, visualizations\n\n",
  "In execute_r, you have access to:\n",
  "- bs_get_dataset(\"Name\") -- loads and caches a dataset as a tibble\n",
  "- bs_join(df1, df2) -- smart join on matching _id columns\n",
  "- dplyr, tidyr, ggplot2, lubridate, scales -- pre-loaded\n",
  "- Variables persist between calls\n\n",
  "IMPORTANT performance guidelines for execute_r:\n",
  "- ALWAYS call describe_dataset first to check row counts before loading data\n",
  "- For large datasets (>10K rows), filter early: bs_get_dataset('X') %>% filter(...)\n",
  "- Avoid loading multiple large datasets without filtering\n",
  "- Never return raw unfiltered data frames -- aggregate, summarise, or head() first\n",
  "- Execution is capped at 30 seconds\n\n",
  "## Visualizations\n\n",
  "ALWAYS prefer interactive Chart.js HTML charts. Fall back to static ggplot only\n",
  "if the user explicitly asks for a PNG/ggplot, or the chart type is unsupported by Chart.js.\n\n",
  "### Interactive charts (default)\n",
  "Use Chart.js injected into a self-contained HTML file. plotly is NOT installed.\n\n",
  "Pattern:\n",
  "1. Aggregate data in R to a small summary data frame (never pass raw datasets to the chart)\n",
  "2. Extract vectors: labels <- df$col_name, values <- df$count\n",
  "3. Build an HTML string using paste0() with Chart.js from CDN:\n",
  "   https://cdn.jsdelivr.net/npm/chart.js\n",
  "4. Write with write_chart(html, 'chart_name.html') -- saves to output dir safely\n",
  "5. Open with browseURL(file.path(output_dir, 'chart_name.html'))\n\n",
  "### Static charts (fallback)\n",
  "Use ggplot2 only when the user requests a PNG or a chart type Chart.js cannot handle.\n",
  "Return a ggplot object (do NOT use ggsave). The server saves PNG + HTML viewer.\n\n",
  "## Date axis gotcha\n",
  "When using ggplot2 geom_col() with POSIXct x-axis, width is in SECONDS.\n",
  "Convert to Date with as.Date(floor_date(...)) first -- then width = 28 means 28 days.\n\n",
  "## Available packages\n",
  "tidyverse (dplyr, ggplot2, lubridate, tidyr), scales.\n",
  "plotly is NOT available. Use Chart.js HTML for interactive output.\n\n",
  "## Safety Policy\n",
  "Code is inspected before execution. Blocked: direct API access (brightspaceR::,\n",
  "httr::, curl::), file I/O (readLines, writeLines, readRDS, etc.), shell commands\n",
  "(system, system2), network functions (download.file, url), and metaprogramming\n",
  "(eval, do.call, get). Use write_chart() for HTML output. Use bs_get_dataset() for data.\n\n",
  "Person-referencing IDs (UserId, SubmitterId, etc.) are pseudonymised — you will\n",
  "see values like usr_a3f2b1c8 instead of raw integers. These are consistent\n",
  "within a session, so joins and grouping work normally."
)

# ── 3. Tool Definitions ─────────────────────────────────────────────────────

mcp_tools <- list(
  list(
    name = "list_datasets",
    description = "List all available Brightspace Data Set (BDS) dataset names and descriptions.",
    inputSchema = list(
      type = "object",
      properties = empty_obj(),
      required = list()
    )
  ),
  list(
    name = "describe_dataset",
    description = paste0(
      "Get per-column summary statistics for a dataset. ",
      "Numeric columns: min, max, mean, n_missing. ",
      "Character columns: n_unique, top 3 values, n_missing. ",
      "Logical columns: n_true, n_false, n_missing. ",
      "Date columns: min, max, n_missing."
    ),
    inputSchema = list(
      type = "object",
      properties = list(
        name = list(type = "string", description = "Dataset name (e.g. 'Users', 'Grade Results')")
      ),
      required = list("name")
    )
  ),
  list(
    name = "search_datasets",
    description = "Search available datasets by keyword (case-insensitive, matches name and description).",
    inputSchema = list(
      type = "object",
      properties = list(
        keyword = list(type = "string", description = "Search keyword")
      ),
      required = list("keyword")
    )
  ),
  list(
    name = "execute_r",
    description = paste0(
      "Execute R code in a persistent workspace. ",
      "Available packages: dplyr, tidyr, ggplot2, lubridate, scales. ",
      "plotly is NOT available. ",
      "Use bs_get_dataset('Name') to load data. Variables persist between calls. ",
      "For charts: PREFER interactive Chart.js HTML (build HTML string with CDN script, ",
      "write_chart(html, 'name.html'), browseURL()). ",
      "Fall back to static ggplot only if user requests PNG or chart type is unsupported. ",
      "For ggplot: return the object (do NOT use ggsave) -- the server saves PNG + HTML."
    ),
    inputSchema = list(
      type = "object",
      properties = list(
        code = list(type = "string", description = "R code to execute")
      ),
      required = list("code")
    )
  ),
  list(
    name = "get_data_summary",
    description = paste0(
      "Get summary statistics for a dataset, optionally filtered and grouped. ",
      "Returns row/column counts and per-column stats. ",
      "Replaces get_dataset, student_summary, course_summary, join_datasets."
    ),
    inputSchema = list(
      type = "object",
      properties = list(
        dataset = list(type = "string", description = "Dataset name (e.g. 'Users', 'Grade Results')"),
        filter_by = list(
          type = "object",
          description = "Column-value pairs to filter by (e.g. {\"role_name\": \"Student\"})",
          additionalProperties = TRUE
        ),
        group_by = list(
          type = "array",
          items = list(type = "string"),
          description = "Column(s) to group by for aggregated stats"
        )
      ),
      required = list("dataset")
    )
  ),
  list(
    name = "auth_status",
    description = "Check whether the server is authenticated with Brightspace.",
    inputSchema = list(
      type = "object",
      properties = empty_obj(),
      required = list()
    )
  ),
  list(
    name = "list_schemas",
    description = "List registered dataset schemas and their key columns.",
    inputSchema = list(
      type = "object",
      properties = empty_obj(),
      required = list()
    )
  )
)

# ── 4. PII Field Policy ────────────────────────────────────────────────────

.field_policy_cache <- new.env(parent = emptyenv())
.field_policy_cache$policy <- NULL

load_field_policy <- function() {
  if (!is.null(.field_policy_cache$policy)) return(.field_policy_cache$policy)

  # Resolution order: env var -> cwd -> package bundled
  candidates <- c(
    Sys.getenv("BRIGHTSPACER_FIELD_POLICY", ""),
    file.path(getwd(), "field_policy.yml"),
    system.file("mcp", "field_policy.yml", package = "brightspaceR")
  )
  # In dev mode, also check relative to pkg_root
  if (nchar(pkg_root) > 0) {
    candidates <- c(candidates,
                    file.path(pkg_root, "inst", "mcp", "field_policy.yml"))
  }
  candidates <- candidates[nchar(candidates) > 0]

  for (path in candidates) {
    if (file.exists(path)) {
      mcp_log("Loading field policy from: ", path)
      policy <- yaml::read_yaml(path)
      .field_policy_cache$policy <- policy
      return(policy)
    }
  }

  mcp_log("WARNING: No field_policy.yml found, all fields pass through")
  .field_policy_cache$policy <- list()
  list()
}

apply_field_policy <- function(df, dataset_name) {
  policy <- load_field_policy()
  ds_policy <- policy[[dataset_name]]

  if (is.null(ds_policy)) {
    # Unknown dataset — pass through with warning
    mcp_log("Field policy: no entry for '", dataset_name, "', passing through")
    return(df)
  }

  mode <- ds_policy$mode
  if (is.null(mode) || mode == "all") {
    return(df)
  }

  if (mode == "allow") {
    allowed <- ds_policy$fields
    if (is.null(allowed)) return(df)
    keep <- intersect(allowed, names(df))
    return(df[, keep, drop = FALSE])
  }

  if (mode == "redact") {
    redact_cols <- ds_policy$fields
    if (!is.null(redact_cols)) {
      for (col in redact_cols) {
        if (col %in% names(df)) {
          df[[col]] <- "[REDACTED]"
        }
      }
    }
    return(df)
  }

  # Unknown mode — pass through
  mcp_log("Field policy: unknown mode '", mode, "' for '", dataset_name, "'")
  df
}

# ── 5. ID Pseudonymisation ─────────────────────────────────────────────────

# Person-referencing ID columns per dataset — these get HMAC-hashed so the
# AI model sees deterministic pseudonyms (usr_a3f2b1c8) instead of raw integers.
# Structural IDs (OrgUnitId, GradeObjectId, etc.) are left untouched.
PERSON_ID_COLUMNS <- list(
  "Users"                        = c("UserId"),
  "User Enrollments"             = c("UserId"),
  "Grade Results"                = c("UserId", "LastModifiedBy"),
  "Assignment Submissions"       = c("SubmitterId", "FeedbackUserId"),
  "Quiz User Answers"            = c("LastModifiedBy"),
  "Content User Progress"        = c("UserId"),
  "Quiz Attempts"                = c("UserId"),
  "Discussion Posts"             = c("UserId"),
  "Discussion Topics"            = c("LastPostUserId", "DeletedByUserId"),
  "Content Objects"              = c("CreatedBy", "LastModifiedBy", "DeletedBy"),
  "Grade Objects"                = c("DeletedByUserId"),
  "Enrollments and Withdrawals"  = c("UserId", "ModifiedByUserId"),
  "Final Grades"                 = c("UserId"),
  "Attendance Records"           = c("UserId")
)

# Session-scoped key — generated once at startup, dies with the process
.pseudonym_key <- openssl::rand_bytes(32)

pseudonymise_id <- function(values, key = .pseudonym_key) {
  result <- rep(NA_character_, length(values))
  non_na <- !is.na(values)
  if (any(non_na)) {
    hashes <- vapply(as.character(values[non_na]), function(v) {
      raw_hash <- openssl::sha256(charToRaw(v), key = key)
      paste0("usr_", substr(as.character(raw_hash), 1, 8))
    }, character(1), USE.NAMES = FALSE)
    result[non_na] <- hashes
  }
  result
}

pseudonymise_df <- function(df, dataset_name) {
  cols <- PERSON_ID_COLUMNS[[dataset_name]]
  if (is.null(cols)) return(df)
  for (col in cols) {
    if (col %in% names(df)) {
      df[[col]] <- pseudonymise_id(df[[col]])
    }
  }
  df
}

# ── 6. Dataset Cache ────────────────────────────────────────────────────────

.cache <- new.env(parent = emptyenv())
.cache$datasets <- new.env(parent = emptyenv())
.cache$listing <- NULL
.cache$listing_time <- NULL

LISTING_TTL <- 300  # 5 minutes

get_cached_listing <- function() {
  now <- as.numeric(Sys.time())
  if (!is.null(.cache$listing) &&
      !is.null(.cache$listing_time) &&
      (now - .cache$listing_time) < LISTING_TTL) {
    return(.cache$listing)
  }
  listing <- suppressMessages(bs_list_datasets())
  .cache$listing <- listing
  .cache$listing_time <- now
  listing
}

normalize_name <- function(name) {
  name <- str_replace_all(name, "[^A-Za-z0-9 ]", "")
  name <- str_trim(name)
  name <- str_replace_all(name, "\\s+", "_")
  str_to_lower(name)
}

get_cached_dataset <- function(name) {
  key <- normalize_name(name)
  if (exists(key, envir = .cache$datasets)) {
    return(get(key, envir = .cache$datasets))
  }
  ds <- suppressMessages(bs_get_dataset(name))
  # Apply PII field policy then pseudonymise person IDs before caching
  ds <- apply_field_policy(ds, name)
  ds <- pseudonymise_df(ds, name)
  assign(key, ds, envir = .cache$datasets)
  ds
}

# ── 7. JSON & Response Helpers ────────────────────────────────────────────────

to_json <- function(x) {
  jsonlite::toJSON(x, auto_unbox = TRUE, POSIXt = "ISO8601", null = "null",
                   na = "null", dataframe = "rows", pretty = FALSE)
}

MAX_RESULT_BYTES <- 800000L  # ~800KB safety limit for text content

# MCP content helpers with audience annotation support
mcp_text <- function(text, audience = NULL) {
  content <- list(type = "text", text = text)
  if (!is.null(audience)) {
    content$annotations <- list(audience = audience)
  }
  content
}

# Minimal HTML escaping (avoids htmltools dependency)
html_esc <- function(x) {
  x <- str_replace_all(x, fixed("&"), "&amp;")
  x <- str_replace_all(x, fixed("<"), "&lt;")
  x <- str_replace_all(x, fixed(">"), "&gt;")
  x <- str_replace_all(x, fixed("'"), "&#39;")
  x <- str_replace_all(x, fixed('"'), "&quot;")
  x
}

# Save a ggplot to the output directory and generate an HTML viewer
# Returns list(png_path, html_path)
save_plot <- function(plot_obj, title = NULL) {
  title <- title %||% plot_obj$labels$title %||% "plot"
  # Sanitize title for filename
  slug <- str_replace_all(title, "[^A-Za-z0-9]+", "_")
  slug <- str_replace_all(slug, "^_|_$", "")
  slug <- tolower(substr(slug, 1, 60))
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  base_name <- paste0(slug, "_", timestamp)

  png_path <- file.path(MCP_OUTPUT_DIR, paste0(base_name, ".png"))
  html_path <- file.path(MCP_OUTPUT_DIR, paste0(base_name, ".html"))

  # Render PNG at good quality for viewing
  if (requireNamespace("ragg", quietly = TRUE)) {
    ragg::agg_png(png_path, width = 900, height = 600, res = 150,
                  background = "white")
  } else {
    grDevices::png(png_path, width = 900, height = 600, res = 150,
                   bg = "white")
  }
  print(plot_obj)
  grDevices::dev.off()

  mcp_log("Plot saved: ", png_path, " (", file.info(png_path)$size, " bytes)")

  # Generate HTML viewer
  png_file <- basename(png_path)
  html_title <- if (!is.null(plot_obj$labels$title)) plot_obj$labels$title else title
  html_content <- paste0(
    "<!DOCTYPE html>\n<html>\n<head>\n",
    "  <meta charset='utf-8'>\n",
    "  <title>", html_esc(html_title), "</title>\n",
    "  <style>\n",
    "    body { font-family: system-ui, sans-serif; margin: 2rem; background: #fafafa; }\n",
    "    h1 { color: #333; font-size: 1.4rem; }\n",
    "    img { max-width: 100%; border: 1px solid #ddd; border-radius: 4px; }\n",
    "    .meta { color: #666; font-size: 0.85rem; margin-top: 1rem; }\n",
    "  </style>\n",
    "</head>\n<body>\n",
    "  <h1>", html_esc(html_title), "</h1>\n",
    "  <img src='", png_file, "' alt='", html_esc(html_title), "'>\n",
    "  <p class='meta'>Generated by brightspaceR MCP server at ",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "</p>\n",
    "</body>\n</html>"
  )
  writeLines(html_content, html_path)

  list(png_path = png_path, html_path = html_path)
}

mcp_result <- function(contents, is_error = FALSE) {
  if (!is.list(contents[[1]])) {
    contents <- list(contents)
  }
  result <- list(content = contents, isError = is_error)
  # Guard: check serialized size and truncate text if needed
  json_size <- nchar(as.character(to_json(result)), type = "bytes")
  if (json_size > MAX_RESULT_BYTES) {
    # Find text content items and truncate the largest one
    for (i in seq_along(result$content)) {
      if (result$content[[i]]$type == "text") {
        text <- result$content[[i]]$text
        keep_bytes <- MAX_RESULT_BYTES - 500L
        text <- substr(text, 1, keep_bytes)
        text <- paste0(
          text,
          "\n\n... [TRUNCATED: response exceeded size limit. ",
          "Use head()/filter() to narrow results in execute_r.]"
        )
        result$content[[i]]$text <- text
        break
      }
    }
  }
  result
}

# Legacy wrappers for unchanged handlers
make_text_content <- function(text) {
  list(mcp_text(text))
}

make_result <- function(content, is_error = FALSE) {
  mcp_result(content, is_error = is_error)
}

# ── 8. AST Code Inspection ───────────────────────────────────────────────────

BLOCKED_PACKAGES <- c("brightspaceR", "httr", "httr2", "curl", "jsonlite", "config")

BLOCKED_FUNCTIONS <- c(
  # Metaprogramming
  "eval", "evalq", "do.call", "get", "mget", "exists", "match.fun",
  "getExportedValue", "loadNamespace", "requireNamespace",
  # Environment
  "Sys.getenv", "Sys.setenv",
  # Shell
  "system", "system2", "shell",
  # File I/O
  "readLines", "scan", "file", "readRDS", "writeLines",
  "write.csv", "write.csv2", "saveRDS",
  # Network
  "download.file", "url", "socketConnection"
)

# Recursively walk an AST expression and collect blocked constructs
walk_ast <- function(expr, blocked = character(0)) {
  if (is.call(expr)) {
    fn <- expr[[1]]

    # Check for pkg::fn or pkg:::fn calls
    if (is.call(fn) && length(fn) == 3 &&
        (identical(fn[[1]], as.name("::")) || identical(fn[[1]], as.name(":::")))) {
      pkg_name <- as.character(fn[[2]])
      if (pkg_name %in% BLOCKED_PACKAGES) {
        blocked <- c(blocked, paste0(pkg_name, "::", as.character(fn[[3]])))
      }
    } else if (is.name(fn)) {
      fn_name <- as.character(fn)
      if (fn_name %in% BLOCKED_FUNCTIONS) {
        blocked <- c(blocked, fn_name)
      }
      # Also check compound names like Sys.getenv (parsed as single symbol)
    } else if (is.call(fn) && length(fn) == 3 && identical(fn[[1]], as.name("$"))) {
      # Handles Sys$getenv style (unlikely but defensive)
      compound <- paste0(as.character(fn[[2]]), "$", as.character(fn[[3]]))
      if (compound %in% BLOCKED_FUNCTIONS) {
        blocked <- c(blocked, compound)
      }
    }

    # Recurse into all arguments
    for (i in seq_along(expr)) {
      blocked <- walk_ast(expr[[i]], blocked)
    }
  } else if (is.pairlist(expr) || (is.recursive(expr) && !is.environment(expr))) {
    for (i in seq_along(expr)) {
      blocked <- walk_ast(expr[[i]], blocked)
    }
  }
  blocked
}

check_code_safety <- function(code) {
  parsed <- tryCatch(parse(text = code), error = function(e) NULL)
  # Syntax errors pass through — they'll fail at eval anyway
  if (is.null(parsed)) return(list(safe = TRUE))

  blocked <- character(0)
  for (i in seq_along(parsed)) {
    blocked <- walk_ast(parsed[[i]], blocked)
  }
  blocked <- unique(blocked)

  if (length(blocked) == 0) {
    list(safe = TRUE)
  } else {
    list(safe = FALSE, blocked = blocked)
  }
}

# ── 9. Persistent Workspace ──────────────────────────────────────────────────

.mcp_workspace <- new.env(parent = globalenv())

# Pre-load packages into workspace
local({
  suppressPackageStartupMessages({
    require(dplyr, quietly = TRUE)
    require(tidyr, quietly = TRUE)
    require(ggplot2, quietly = TRUE)
    require(lubridate, quietly = TRUE)
    require(scales, quietly = TRUE)
  })
}, envir = .mcp_workspace)

# Expose output directory so execute_r code can write Chart.js HTML there
.mcp_workspace$output_dir <- MCP_OUTPUT_DIR

# Safe Chart.js HTML writer — only writes .html to MCP_OUTPUT_DIR
.mcp_workspace$write_chart <- function(html_string, filename) {
  if (!is.character(filename) || length(filename) != 1 || !grepl("\\.html$", filename)) {
    stop("write_chart: filename must be a single string ending in .html")
  }
  # Strip any path components — only bare filename allowed
  filename <- basename(filename)
  path <- file.path(MCP_OUTPUT_DIR, filename)
  writeLines(html_string, path)
  message(paste0("[Chart written: ", path, "]"))
  invisible(path)
}

# Wire in bs_get_dataset with row-count reporting so Claude always sees data size
.mcp_workspace$bs_get_dataset <- function(name, ...) {
  ds <- get_cached_dataset(name)
  nr <- nrow(ds)
  nc <- ncol(ds)
  msg <- paste0("[", name, ": ", format(nr, big.mark = ","), " rows x ", nc, " cols]")
  if (nr > 50000) {
    msg <- paste0(msg, " WARNING: large dataset -- filter early to avoid slow operations")
  }
  message(msg)
  ds
}

.mcp_workspace$bs_join <- function(df1, df2, ...) {
  nr1 <- nrow(df1)
  nr2 <- nrow(df2)
  # Warn about potentially large joins
  if (nr1 > 50000 || nr2 > 50000) {
    message(paste0(
      "[Join warning: ", format(nr1, big.mark = ","), " x ",
      format(nr2, big.mark = ","),
      " rows -- consider filtering before joining]"
    ))
  }
  result <- suppressMessages(bs_join(df1, df2, ...))
  message(paste0("[Join result: ", format(nrow(result), big.mark = ","), " rows]"))
  result
}

# ── 10. Column Summary Helper ────────────────────────────────────────────────

summarize_column <- function(x, col_name) {
  n_missing <- sum(is.na(x))
  n_total <- length(x)
  info <- list(column = col_name, type = class(x)[1], n_missing = n_missing)

  if (is.numeric(x)) {
    vals <- x[!is.na(x)]
    if (length(vals) > 0) {
      info$min <- round(min(vals), 4)
      info$max <- round(max(vals), 4)
      info$mean <- round(mean(vals), 4)
    }
  } else if (is.character(x) || is.factor(x)) {
    vals <- as.character(x[!is.na(x)])
    info$n_unique <- length(unique(vals))
    if (length(vals) > 0) {
      tbl <- sort(table(vals), decreasing = TRUE)
      top_n <- min(3, length(tbl))
      top_vals <- utils::head(tbl, top_n)
      info$top_values <- paste(
        paste0(names(top_vals), " (", as.integer(top_vals), ")"),
        collapse = ", "
      )
    }
  } else if (is.logical(x)) {
    info$n_true <- sum(x, na.rm = TRUE)
    info$n_false <- sum(!x, na.rm = TRUE)
  } else if (inherits(x, "Date") || inherits(x, "POSIXt")) {
    vals <- x[!is.na(x)]
    if (length(vals) > 0) {
      info$min <- as.character(min(vals))
      info$max <- as.character(max(vals))
    }
  }

  info
}

# ── 11. Tool Handlers ───────────────────────────────────────────────────────

handle_list_datasets <- function(args) {
  listing <- get_cached_listing()
  summary_df <- listing[, c("name", "description"), drop = FALSE]
  text <- paste0(
    "Found ", nrow(summary_df), " datasets:\n\n",
    as.character(to_json(summary_df))
  )
  make_result(make_text_content(text))
}

handle_describe_dataset <- function(args) {
  name <- args$name
  if (is.null(name) || name == "") {
    return(make_result(
      make_text_content("Error: 'name' parameter is required."),
      is_error = TRUE
    ))
  }

  ds <- get_cached_dataset(name)

  # Per-column summary stats
  col_summaries <- lapply(names(ds), function(cn) {
    summarize_column(ds[[cn]], cn)
  })

  text <- paste0(
    "Dataset: ", name, "\n",
    "Rows: ", nrow(ds), "\n",
    "Columns: ", ncol(ds), "\n\n",
    "Column summaries:\n", as.character(to_json(col_summaries)),
    "\n\nUse execute_r to query this dataset with bs_get_dataset('", name, "')"
  )
  make_result(make_text_content(text))
}

handle_search_datasets <- function(args) {
  keyword <- args$keyword
  if (is.null(keyword) || keyword == "") {
    return(make_result(
      make_text_content("Error: 'keyword' parameter is required."),
      is_error = TRUE
    ))
  }

  listing <- get_cached_listing()
  pattern <- tolower(keyword)
  matches <- grepl(pattern, tolower(listing$name), fixed = TRUE) |
    grepl(pattern, tolower(listing$description), fixed = TRUE)
  results <- listing[matches, c("name", "description"), drop = FALSE]

  if (nrow(results) == 0) {
    text <- paste0("No datasets found matching '", keyword, "'.")
  } else {
    text <- paste0(
      "Found ", nrow(results), " datasets matching '", keyword, "':\n\n",
      as.character(to_json(results))
    )
  }
  make_result(make_text_content(text))
}

handle_execute_r <- function(args) {
  code <- args$code
  if (is.null(code) || code == "") {
    return(mcp_result(
      list(mcp_text("Error: 'code' parameter is required.")),
      is_error = TRUE
    ))
  }

  mcp_log("execute_r code: ", substr(code, 1, 200))

  # AST safety check — reject dangerous constructs before execution
  safety <- check_code_safety(code)
  if (!safety$safe) {
    mcp_log("BLOCKED code: ", paste(safety$blocked, collapse = ", "))
    return(mcp_result(
      list(mcp_text(paste0(
        "Code blocked by safety policy. The following constructs are not allowed:\n",
        paste0("- ", safety$blocked, collapse = "\n"),
        "\n\nUse the provided workspace functions (bs_get_dataset, write_chart, etc.) instead."
      ))),
      is_error = TRUE
    ))
  }

  # Use an environment to store results reliably across nested scopes
  .res <- new.env(parent = emptyenv())
  .res$val <- NULL
  .res$output <- character(0)
  .res$messages <- character(0)

  EXEC_TIMEOUT <- 30  # seconds

  eval_result <- tryCatch(
    withCallingHandlers(
      {
        setTimeLimit(elapsed = EXEC_TIMEOUT, transient = TRUE)
        on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)
        .res$output <- utils::capture.output({
          .res$val <- eval(parse(text = code), envir = .mcp_workspace)
        })
        "success"
      },
      message = function(m) {
        .res$messages <- c(.res$messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    ),
    error = function(e) {
      setTimeLimit(elapsed = Inf, transient = TRUE)
      msg <- conditionMessage(e)
      if (grepl("time limit|elapsed time", msg, ignore.case = TRUE)) {
        paste0("Execution timed out after ", EXEC_TIMEOUT,
               " seconds. Try filtering data earlier or breaking into smaller steps.")
      } else {
        msg
      }
    }
  )

  if (eval_result != "success") {
    return(mcp_result(
      list(mcp_text(paste0("Error executing R code:\n", eval_result))),
      is_error = TRUE
    ))
  }

  result_val <- .res$val
  output <- .res$output
  messages <- .res$messages

  mcp_log("result class: ", paste(class(result_val), collapse = ", "),
          " | is.null: ", is.null(result_val),
          " | output lines: ", length(output))

  # Smart result formatting
  contents <- list()

  # Check if result is a ggplot (belt-and-suspenders: check class attr too)
  is_ggplot <- inherits(result_val, "gg") || inherits(result_val, "ggplot") ||
    any(c("gg", "ggplot") %in% class(result_val))

  if (is_ggplot) {
    mcp_log("Detected ggplot object, calling save_plot")
    save_err <- NULL
    paths <- tryCatch(
      save_plot(result_val),
      error = function(e) {
        save_err <<- conditionMessage(e)
        mcp_log("save_plot error: ", conditionMessage(e))
        NULL
      }
    )
    if (!is.null(paths)) {
      plot_title <- result_val$labels$title %||% "Untitled plot"
      n_layers <- length(result_val$layers)
      summary_text <- paste0(
        "Plot saved: ", plot_title,
        " (", n_layers, " layer", if (n_layers != 1) "s", ")\n",
        "PNG: ", paths$png_path, "\n",
        "HTML viewer: ", paths$html_path, "\n\n",
        "Ask the user: \"Would you like me to open the chart in your browser?\" ",
        "If yes, call execute_r with: browseURL('", paths$html_path, "')"
      )
      contents <- list(mcp_text(summary_text))
    } else {
      err_detail <- if (!is.null(save_err)) paste0(": ", save_err) else ""
      contents <- list(mcp_text(paste0(
        "Plot rendering failed", err_detail, "\n",
        "Output dir: ", MCP_OUTPUT_DIR, "\n",
        "Dir exists: ", dir.exists(MCP_OUTPUT_DIR), "\n",
        "Dir writable: ", file.access(MCP_OUTPUT_DIR, 2) == 0
      )))
    }
  } else if (is.data.frame(result_val)) {
    nr <- nrow(result_val)
    if (nr <= 50) {
      tbl_text <- paste(utils::capture.output(print(result_val, n = nr)), collapse = "\n")
    } else {
      tbl_text <- paste(utils::capture.output(print(utils::head(result_val, 20))), collapse = "\n")
      tbl_text <- paste0(tbl_text, "\n... ", nr - 20, " more rows. Use head()/filter() to narrow.")
    }
    if (length(output) > 0 && any(nchar(output) > 0)) {
      tbl_text <- paste0(paste(output, collapse = "\n"), "\n", tbl_text)
    }
    contents <- list(mcp_text(tbl_text))
  } else if (is.character(result_val) && length(result_val) == 1 &&
             grepl("\\.(html|png|pdf|csv)$", result_val, ignore.case = TRUE)) {
    # File path result
    contents <- list(mcp_text(paste0("File saved: ", result_val)))
  } else {
    # General output
    mcp_log("Fallback branch: result class=", paste(class(result_val), collapse = ","),
            " is.null=", is.null(result_val))
    if (!is.null(result_val)) {
      val_output <- paste(utils::capture.output(print(result_val)), collapse = "\n")
    } else {
      val_output <- ""
    }
    # Combine captured stdout and value output
    all_output <- c(output, val_output)
    all_output <- all_output[nchar(all_output) > 0]
    if (length(all_output) == 0) {
      all_output <- "(no visible output)"
    }
    text <- paste(all_output, collapse = "\n")
    contents <- list(mcp_text(text))
  }

  # Prepend captured messages (row counts, join warnings) as assistant-facing context
  if (length(messages) > 0) {
    msg_text <- paste(trimws(messages), collapse = "\n")
    contents <- c(list(mcp_text(msg_text, audience = list("assistant"))), contents)
  }

  mcp_result(contents)
}

handle_get_data_summary <- function(args) {
  dataset_name <- args$dataset
  if (is.null(dataset_name) || dataset_name == "") {
    return(mcp_result(
      list(mcp_text("Error: 'dataset' parameter is required.")),
      is_error = TRUE
    ))
  }

  ds <- get_cached_dataset(dataset_name)

  # Apply filters
  filter_by <- args$filter_by
  if (!is.null(filter_by) && length(filter_by) > 0) {
    for (col_name in names(filter_by)) {
      if (col_name %in% names(ds)) {
        filter_val <- filter_by[[col_name]]
        ds <- ds[ds[[col_name]] == filter_val & !is.na(ds[[col_name]]), , drop = FALSE]
      }
    }
  }

  # Group by
  group_by_cols <- args$group_by
  if (!is.null(group_by_cols) && length(group_by_cols) > 0) {
    # Validate group_by columns exist
    valid_cols <- group_by_cols[group_by_cols %in% names(ds)]
    if (length(valid_cols) == 0) {
      return(mcp_result(
        list(mcp_text(paste0(
          "Error: None of the group_by columns found. Available: ",
          paste(names(ds), collapse = ", ")
        ))),
        is_error = TRUE
      ))
    }

    # Group counts
    group_formula <- stats::as.formula(paste("~", paste(valid_cols, collapse = " + ")))
    group_counts <- as.data.frame(stats::xtabs(group_formula, data = ds))
    names(group_counts)[ncol(group_counts)] <- "count"
    group_counts <- group_counts[group_counts$count > 0, , drop = FALSE]
    group_counts <- group_counts[order(-group_counts$count), , drop = FALSE]

    # Numeric column means per group
    numeric_cols <- names(ds)[vapply(ds, is.numeric, logical(1))]
    numeric_cols <- setdiff(numeric_cols, valid_cols)

    group_stats_text <- paste(utils::capture.output(print(
      utils::head(group_counts, 30)
    )), collapse = "\n")

    text <- paste0(
      "Dataset: ", dataset_name, "\n",
      "Rows after filtering: ", nrow(ds), "\n",
      "Groups (", paste(valid_cols, collapse = ", "), "): ",
      nrow(group_counts), " unique\n\n",
      "Group counts (top 30):\n", group_stats_text
    )

    if (length(numeric_cols) > 0) {
      # Compute means per group for numeric columns (up to 5)
      agg_cols <- utils::head(numeric_cols, 5)
      agg_text <- character(0)
      for (ac in agg_cols) {
        agg <- stats::aggregate(
          ds[[ac]],
          by = ds[valid_cols],
          FUN = function(v) round(mean(v, na.rm = TRUE), 2),
          na.action = NULL
        )
        names(agg)[ncol(agg)] <- paste0("mean_", ac)
        agg_text <- c(agg_text, paste0(
          "\nMean ", ac, " per group:\n",
          paste(utils::capture.output(print(utils::head(agg, 20))), collapse = "\n")
        ))
      }
      text <- paste0(text, paste(agg_text, collapse = "\n"))
    }
  } else {
    # No grouping — per-column summary stats
    col_summaries <- lapply(names(ds), function(cn) {
      summarize_column(ds[[cn]], cn)
    })

    text <- paste0(
      "Dataset: ", dataset_name, "\n",
      "Rows: ", nrow(ds), "\n",
      "Columns: ", ncol(ds), "\n\n",
      "Column summaries:\n", as.character(to_json(col_summaries))
    )
  }

  text <- paste0(
    text,
    "\n\nUse execute_r for custom analysis. Available: bs_get_dataset(), bs_join(), dplyr verbs."
  )
  mcp_result(list(mcp_text(text)))
}

handle_auth_status <- function(args) {
  has_token <- bs_has_token()
  info <- list(authenticated = has_token)
  if (has_token) {
    info$message <- "Authenticated with Brightspace."
  } else {
    info$message <- "Not authenticated. Run bs_auth() in an interactive R session first."
  }
  text <- as.character(to_json(info))
  make_result(make_text_content(text))
}

handle_list_schemas <- function(args) {
  schema_names <- bs_list_schemas()
  result <- lapply(schema_names, function(s) {
    schema <- bs_get_schema(s)
    list(
      name = s,
      key_cols = if (!is.null(schema$key_cols)) schema$key_cols else list()
    )
  })
  text <- paste0(
    "Registered schemas (", length(result), "):\n\n",
    as.character(to_json(result))
  )
  make_result(make_text_content(text))
}

# Tool handler dispatch
tool_handlers <- list(
  list_datasets = handle_list_datasets,
  describe_dataset = handle_describe_dataset,
  search_datasets = handle_search_datasets,
  execute_r = handle_execute_r,
  get_data_summary = handle_get_data_summary,
  auth_status = handle_auth_status,
  list_schemas = handle_list_schemas
)

# ── 12. Audit Logging ────────────────────────────────────────────────────────

AUDIT_LOG_PATH <- file.path(MCP_OUTPUT_DIR, "mcp_audit.jsonl")

audit_log <- function(tool, arguments = NULL, response_bytes = 0L,
                      code_blocked = FALSE, blocked_constructs = NULL,
                      is_error = FALSE) {
  entry <- list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
    tool = tool
  )

  if (!is.null(arguments)) {
    # Truncate code argument to 500 chars for log readability
    args_copy <- arguments
    if (!is.null(args_copy$code) && nchar(args_copy$code) > 500) {
      args_copy$code <- paste0(substr(args_copy$code, 1, 500), "...[truncated]")
    }
    entry$arguments <- args_copy
  }

  entry$response_bytes <- as.integer(response_bytes)
  entry$code_blocked <- code_blocked
  if (!is.null(blocked_constructs) && length(blocked_constructs) > 0) {
    entry$blocked_constructs <- as.list(blocked_constructs)
  }
  entry$is_error <- is_error

  line <- tryCatch(
    as.character(to_json(entry)),
    error = function(e) {
      # Fallback: minimal entry on serialization failure
      paste0('{"timestamp":"', entry$timestamp, '","tool":"', tool,
             '","error":"audit serialization failed"}')
    }
  )

  tryCatch(
    cat(line, "\n", sep = "", file = AUDIT_LOG_PATH, append = TRUE),
    error = function(e) {
      mcp_log("WARNING: Could not write audit log: ", conditionMessage(e))
    }
  )
}

# ── 13. JSON-RPC Dispatch ──────────────────────────────────────────────────

handle_request <- function(request) {
  method <- request$method
  id <- request$id
  params <- request$params

  if (method == "initialize") {
    return(list(
      jsonrpc = "2.0",
      id = id,
      result = list(
        protocolVersion = "2025-06-18",
        capabilities = list(
          tools = empty_obj()
        ),
        serverInfo = list(
          name = "brightspaceR",
          version = as.character(utils::packageVersion("brightspaceR"))
        ),
        instructions = SERVER_INSTRUCTIONS
      )
    ))
  }

  if (method == "notifications/initialized") {
    return(NULL)  # notification, no response
  }

  if (method == "tools/list") {
    return(list(
      jsonrpc = "2.0",
      id = id,
      result = list(tools = mcp_tools)
    ))
  }

  if (method == "tools/call") {
    tool_name <- params$name
    arguments <- if (!is.null(params$arguments)) params$arguments else list()

    handler <- tool_handlers[[tool_name]]
    if (is.null(handler)) {
      audit_log(tool_name %||% "unknown", arguments = arguments, is_error = TRUE)
      return(list(
        jsonrpc = "2.0",
        id = id,
        result = make_result(
          make_text_content(paste0("Unknown tool: ", tool_name)),
          is_error = TRUE
        )
      ))
    }

    result <- tryCatch(
      {
        handler(arguments)
      },
      error = function(e) {
        mcp_log("Error in tool '", tool_name, "': ", conditionMessage(e))
        make_result(
          make_text_content(paste0("Error: ", conditionMessage(e))),
          is_error = TRUE
        )
      }
    )

    # Audit log after handler returns
    result_json <- tryCatch(as.character(to_json(result)), error = function(e) "")
    is_blocked <- isTRUE(result$isError) && tool_name == "execute_r" &&
      any(grepl("Code blocked by safety policy", vapply(result$content, function(c) c$text %||% "", character(1))))
    blocked_items <- if (is_blocked) {
      safety <- check_code_safety(arguments$code %||% "")
      if (!safety$safe) safety$blocked else NULL
    } else NULL
    audit_log(
      tool = tool_name,
      arguments = arguments,
      response_bytes = nchar(result_json, type = "bytes"),
      code_blocked = is_blocked,
      blocked_constructs = blocked_items,
      is_error = isTRUE(result$isError)
    )

    return(list(
      jsonrpc = "2.0",
      id = id,
      result = result
    ))
  }

  # Unknown method
  list(
    jsonrpc = "2.0",
    id = id,
    error = list(
      code = -32601L,
      message = paste0("Method not found: ", method)
    )
  )
}

# ── 14. Auth on Startup ─────────────────────────────────────────────────────

# bs_config() looks for config.yml in the working directory, but when Claude
# Code launches this server the cwd may be anywhere. Temporarily switch to the
# package root (where config.yml lives) so credentials can be resolved.
tryCatch(
  {
    if (nchar(pkg_root) > 0 && file.exists(file.path(pkg_root, "config.yml"))) {
      old_wd <- setwd(pkg_root)
      on.exit(setwd(old_wd), add = TRUE)
    }
    suppressMessages(bs_auth())
    mcp_log("Authenticated successfully.")
  },
  error = function(e) {
    mcp_log("Warning: Authentication failed: ", conditionMessage(e))
    mcp_log("Tools requiring data access will fail. ",
            "Run bs_auth() interactively first.")
  }
)

# ── 15. Main Loop ───────────────────────────────────────────────────────────

mcp_log("Server started. Listening on stdin...")
audit_log("session_start")

stdin_con <- file("stdin", open = "r")

repeat {
  line <- readLines(stdin_con, n = 1, warn = FALSE)

  if (length(line) == 0) {
    # EOF — client disconnected
    mcp_log("stdin closed, shutting down.")
    break
  }

  # Skip empty lines
  if (nchar(trimws(line)) == 0) next

  request <- tryCatch(
    jsonlite::fromJSON(line, simplifyVector = FALSE),
    error = function(e) {
      mcp_log("Failed to parse JSON: ", conditionMessage(e))
      NULL
    }
  )

  if (is.null(request)) {
    # Send parse error
    response <- list(
      jsonrpc = "2.0",
      id = NULL,
      error = list(code = -32700L, message = "Parse error")
    )
    cat(as.character(to_json(response)), "\n", sep = "", file = stdout())
    flush(stdout())
    next
  }

  response <- tryCatch(
    handle_request(request),
    error = function(e) {
      mcp_log("Internal error: ", conditionMessage(e))
      list(
        jsonrpc = "2.0",
        id = request$id,
        error = list(code = -32603L, message = paste0("Internal error: ", conditionMessage(e)))
      )
    }
  )

  # Notifications don't get responses
  if (!is.null(response)) {
    cat(as.character(to_json(response)), "\n", sep = "", file = stdout())
    flush(stdout())
  }
}

audit_log("session_end")
close(stdin_con)
mcp_log("Server shut down.")
