#!/usr/bin/env Rscript
# ── Basic test script for brightspaceR MCP server ─────────────────────────
# Tests internal functions without needing a live Brightspace connection.
# Run from the package root: Rscript inst/mcp/test_server.R

cat("=== brightspaceR MCP Server Tests ===\n\n")

pass <- 0L
fail <- 0L

test <- function(name, expr) {
  result <- tryCatch(
    {
      ok <- eval(expr)
      if (isTRUE(ok)) {
        cat("[PASS]", name, "\n")
        pass <<- pass + 1L
      } else {
        cat("[FAIL]", name, "-- returned", as.character(ok), "\n")
        fail <<- fail + 1L
      }
    },
    error = function(e) {
      cat("[FAIL]", name, "--", conditionMessage(e), "\n")
      fail <<- fail + 1L
    }
  )
}

# ── Load server internals ─────────────────────────────────────────────────
# Source just the helper functions, skip the auth and main loop
suppressPackageStartupMessages({
  library(jsonlite)
  library(stringr)
  library(ggplot2)
})

# Stub out brightspaceR functions so we don't need a live connection
pkg_root <- normalizePath(file.path(dirname(
  if (length(grep("^--file=", commandArgs(FALSE), value = TRUE)) > 0)
    sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  else "."
), "..", ".."), mustWork = FALSE)

cat("Package root:", pkg_root, "\n\n")

# ── 1. Test helper functions ──────────────────────────────────────────────

cat("--- Helper Functions ---\n")

empty_obj <- function() structure(list(), names = character(0))

test("empty_obj serializes as {}", {
  j <- as.character(jsonlite::toJSON(empty_obj(), auto_unbox = TRUE))
  j == "{}"
})

normalize_name <- function(name) {
  name <- str_replace_all(name, "[^A-Za-z0-9 ]", "")
  name <- str_trim(name)
  name <- str_replace_all(name, "\\s+", "_")
  str_to_lower(name)
}

test("normalize_name: basic", normalize_name("Grade Results") == "grade_results")
test("normalize_name: special chars", normalize_name("User (Enrollments)!") == "user_enrollments")
test("normalize_name: extra spaces", normalize_name("  Org  Units  ") == "org_units")

html_esc <- function(x) {
  x <- str_replace_all(x, fixed("&"), "&amp;")
  x <- str_replace_all(x, fixed("<"), "&lt;")
  x <- str_replace_all(x, fixed(">"), "&gt;")
  x <- str_replace_all(x, fixed("'"), "&#39;")
  x <- str_replace_all(x, fixed('"'), "&quot;")
  x
}

test("html_esc: escapes all special chars", {
  html_esc("<script>alert('x\"&')") == "&lt;script&gt;alert(&#39;x&quot;&amp;&#39;)"
})

# ── 2. Test mcp_text / mcp_result ────────────────────────────────────────

cat("\n--- Content Helpers ---\n")

to_json <- function(x) {
  jsonlite::toJSON(x, auto_unbox = TRUE, POSIXt = "ISO8601", null = "null",
                   na = "null", dataframe = "rows", pretty = FALSE)
}

MAX_RESULT_BYTES <- 800000L

mcp_text <- function(text, audience = NULL) {
  content <- list(type = "text", text = text)
  if (!is.null(audience)) {
    content$annotations <- list(audience = audience)
  }
  content
}

mcp_result <- function(contents, is_error = FALSE) {
  if (!is.list(contents[[1]])) {
    contents <- list(contents)
  }
  result <- list(content = contents, isError = is_error)
  json_size <- nchar(as.character(to_json(result)), type = "bytes")
  if (json_size > MAX_RESULT_BYTES) {
    for (i in seq_along(result$content)) {
      if (result$content[[i]]$type == "text") {
        text <- result$content[[i]]$text
        keep_bytes <- MAX_RESULT_BYTES - 500L
        text <- substr(text, 1, keep_bytes)
        text <- paste0(text, "\n\n... [TRUNCATED]")
        result$content[[i]]$text <- text
        break
      }
    }
  }
  result
}

test("mcp_text: basic", {
  t <- mcp_text("hello")
  t$type == "text" && t$text == "hello" && is.null(t$annotations)
})

test("mcp_text: with audience", {
  t <- mcp_text("info", audience = list("assistant"))
  !is.null(t$annotations) && identical(t$annotations$audience, list("assistant"))
})

test("mcp_text: audience serializes as array", {
  t <- mcp_text("info", audience = list("assistant"))
  j <- as.character(to_json(t))
  grepl('"audience":\\["assistant"\\]', j)
})

test("mcp_result: wraps single content", {
  r <- mcp_result(list(mcp_text("hi")))
  length(r$content) == 1 && r$content[[1]]$text == "hi" && !r$isError
})

test("mcp_result: error flag", {
  r <- mcp_result(list(mcp_text("bad")), is_error = TRUE)
  r$isError == TRUE
})

test("mcp_result: truncates oversized text", {
  big <- paste(rep("x", 900000), collapse = "")
  r <- mcp_result(list(mcp_text(big)))
  grepl("TRUNCATED", r$content[[1]]$text)
})

# ── 3. Test summarize_column ─────────────────────────────────────────────

cat("\n--- Column Summarizer ---\n")

summarize_column <- function(x, col_name) {
  n_missing <- sum(is.na(x))
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

test("summarize_column: numeric", {
  s <- summarize_column(c(1, 2, 3, NA), "x")
  s$type == "numeric" && s$min == 1 && s$max == 3 && s$mean == 2 && s$n_missing == 1
})

test("summarize_column: character", {
  s <- summarize_column(c("a", "b", "a", "c", "a"), "x")
  s$type == "character" && s$n_unique == 3 && grepl("a \\(3\\)", s$top_values)
})

test("summarize_column: logical", {
  s <- summarize_column(c(TRUE, FALSE, TRUE, NA), "x")
  s$type == "logical" && s$n_true == 2 && s$n_false == 1 && s$n_missing == 1
})

test("summarize_column: date", {
  d <- as.Date(c("2024-01-01", "2024-06-15", NA))
  s <- summarize_column(d, "x")
  s$type == "Date" && s$min == "2024-01-01" && s$max == "2024-06-15" && s$n_missing == 1
})

test("summarize_column: empty numeric", {
  s <- summarize_column(numeric(0), "x")
  s$type == "numeric" && is.null(s$min) && s$n_missing == 0
})

# ── 4. Test save_plot ────────────────────────────────────────────────────

cat("\n--- Plot Saving ---\n")

MCP_OUTPUT_DIR <- tempdir()
mcp_log <- function(...) invisible(NULL)

save_plot <- function(plot_obj, title = NULL) {
  title <- title %||% plot_obj$labels$title %||% "plot"
  slug <- str_replace_all(title, "[^A-Za-z0-9]+", "_")
  slug <- str_replace_all(slug, "^_|_$", "")
  slug <- tolower(substr(slug, 1, 60))
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  base_name <- paste0(slug, "_", timestamp)
  png_path <- file.path(MCP_OUTPUT_DIR, paste0(base_name, ".png"))
  html_path <- file.path(MCP_OUTPUT_DIR, paste0(base_name, ".html"))
  if (requireNamespace("ragg", quietly = TRUE)) {
    ragg::agg_png(png_path, width = 900, height = 600, res = 150, background = "white")
  } else {
    grDevices::png(png_path, width = 900, height = 600, res = 150, bg = "white")
  }
  print(plot_obj)
  grDevices::dev.off()
  png_file <- basename(png_path)
  html_title <- if (!is.null(plot_obj$labels$title)) plot_obj$labels$title else title
  html_content <- paste0(
    "<!DOCTYPE html>\n<html>\n<head>\n",
    "  <meta charset='utf-8'>\n",
    "  <title>", html_esc(html_title), "</title>\n",
    "  <style>body{font-family:system-ui;margin:2rem}img{max-width:100%}</style>\n",
    "</head>\n<body>\n",
    "  <h1>", html_esc(html_title), "</h1>\n",
    "  <img src='", png_file, "'>\n",
    "</body>\n</html>"
  )
  writeLines(html_content, html_path)
  list(png_path = png_path, html_path = html_path)
}

test("save_plot: creates PNG and HTML", {
  p <- ggplot(mtcars, aes(x = factor(cyl))) + geom_bar() + labs(title = "Test Plot")
  paths <- save_plot(p)
  file.exists(paths$png_path) && file.exists(paths$html_path)
})

test("save_plot: PNG is non-empty", {
  p <- ggplot(mtcars, aes(x = factor(cyl))) + geom_bar() + labs(title = "Size Check")
  paths <- save_plot(p)
  file.info(paths$png_path)$size > 1000
})

test("save_plot: HTML references the PNG", {
  p <- ggplot(mtcars, aes(x = hp, y = mpg)) + geom_point() + labs(title = "Scatter")
  paths <- save_plot(p)
  html <- readLines(paths$html_path, warn = FALSE)
  any(str_detect(html, basename(paths$png_path)))
})

test("save_plot: HTML has correct title", {
  p <- ggplot(mtcars, aes(x = wt)) + geom_histogram() + labs(title = "Weight Dist")
  paths <- save_plot(p)
  html <- paste(readLines(paths$html_path, warn = FALSE), collapse = "\n")
  str_detect(html, "Weight Dist")
})

test("save_plot: slug sanitizes special chars", {
  p <- ggplot(mtcars, aes(x = cyl)) + geom_bar() + labs(title = "Test: <Special> & 'Chars'")
  paths <- save_plot(p)
  # Filename should not contain special chars
  !str_detect(basename(paths$png_path), "[<>&']")
})

# ── 5. Test execute_r workspace ──────────────────────────────────────────

cat("\n--- Workspace & execute_r ---\n")

.mcp_workspace <- new.env(parent = globalenv())
local({
  suppressPackageStartupMessages({
    require(dplyr, quietly = TRUE)
    require(tidyr, quietly = TRUE)
    require(ggplot2, quietly = TRUE)
  })
}, envir = .mcp_workspace)

test("workspace: dplyr is loaded", {
  exists("filter", envir = .mcp_workspace, inherits = TRUE)
})

test("workspace: ggplot2 is loaded", {
  exists("ggplot", envir = .mcp_workspace, inherits = TRUE)
})

test("workspace: variables persist", {
  eval(parse(text = "test_var <- 42"), envir = .mcp_workspace)
  eval(parse(text = "test_var"), envir = .mcp_workspace) == 42
})

test("workspace: dplyr pipeline works", {
  result <- eval(parse(text = "mtcars %>% count(cyl) %>% nrow()"), envir = .mcp_workspace)
  result == 3
})

test("workspace: ggplot object detection", {
  result <- eval(parse(text = "ggplot(mtcars, aes(x = cyl)) + geom_bar()"),
                 envir = .mcp_workspace)
  inherits(result, "gg")
})

# ── 5b. Test execute_r eval chain (mirrors handle_execute_r exactly) ────

cat("\n--- execute_r eval chain ---\n")

test("eval chain: env-based capture gets ggplot", {
  .res <- new.env(parent = emptyenv())
  .res$val <- NULL
  .res$output <- character(0)
  .res$messages <- character(0)
  eval_result <- tryCatch(
    withCallingHandlers(
      {
        .res$output <- utils::capture.output({
          .res$val <- eval(
            parse(text = "ggplot(mtcars, aes(x = factor(cyl))) + geom_bar()"),
            envir = .mcp_workspace
          )
        })
        "success"
      },
      message = function(m) {
        .res$messages <- c(.res$messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    ),
    error = function(e) conditionMessage(e)
  )
  eval_result == "success" &&
    !is.null(.res$val) &&
    inherits(.res$val, "gg")
})

test("eval chain: env-based capture gets data frame", {
  .res <- new.env(parent = emptyenv())
  .res$val <- NULL
  .res$output <- character(0)
  .res$messages <- character(0)
  eval_result <- tryCatch(
    withCallingHandlers(
      {
        .res$output <- utils::capture.output({
          .res$val <- eval(
            parse(text = "mtcars %>% count(cyl)"),
            envir = .mcp_workspace
          )
        })
        "success"
      },
      message = function(m) {
        .res$messages <- c(.res$messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    ),
    error = function(e) conditionMessage(e)
  )
  eval_result == "success" &&
    !is.null(.res$val) &&
    is.data.frame(.res$val) &&
    nrow(.res$val) == 3
})

test("eval chain: multi-line code returns last expression", {
  .res <- new.env(parent = emptyenv())
  .res$val <- NULL
  .res$output <- character(0)
  .res$messages <- character(0)
  code <- "data <- mtcars\nggplot(data, aes(x = hp, y = mpg)) + geom_point()"
  eval_result <- tryCatch(
    withCallingHandlers(
      {
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
    error = function(e) conditionMessage(e)
  )
  eval_result == "success" &&
    inherits(.res$val, "gg")
})

test("eval chain: ggplot saves to disk via save_plot", {
  .res <- new.env(parent = emptyenv())
  .res$val <- NULL
  .res$output <- character(0)
  tryCatch(
    {
      .res$output <- utils::capture.output({
        .res$val <- eval(
          parse(text = "ggplot(mtcars, aes(x = wt, y = mpg)) + geom_point() + labs(title = 'Chain Test')"),
          envir = .mcp_workspace
        )
      })
    },
    error = function(e) NULL
  )
  result_val <- .res$val
  is_ggplot <- inherits(result_val, "gg") || inherits(result_val, "ggplot") ||
    any(c("gg", "ggplot") %in% class(result_val))
  if (!is_ggplot) return(FALSE)
  paths <- save_plot(result_val)
  file.exists(paths$png_path) && file.exists(paths$html_path)
})

# ── 6. Test timeout ──────────────────────────────────────────────────────

cat("\n--- Timeout ---\n")

test("timeout: setTimeLimit fires on R computation", {
  err <- tryCatch(
    {
      setTimeLimit(elapsed = 1, transient = TRUE)
      # Busy loop in R (not C-level sleep) so time limit can interrupt
      x <- 0; while (TRUE) x <- x + 1
      setTimeLimit(elapsed = Inf, transient = TRUE)
      "no error"
    },
    error = function(e) {
      setTimeLimit(elapsed = Inf, transient = TRUE)
      conditionMessage(e)
    }
  )
  grepl("time limit|elapsed", err, ignore.case = TRUE)
})

# ── 7. Test JSON-RPC response structure ──────────────────────────────────

cat("\n--- JSON-RPC Structure ---\n")

test("tool result JSON: valid structure", {
  r <- mcp_result(list(mcp_text("hello world")))
  j <- as.character(to_json(list(jsonrpc = "2.0", id = 1L, result = r)))
  parsed <- fromJSON(j, simplifyVector = FALSE)
  parsed$jsonrpc == "2.0" &&
    parsed$id == 1 &&
    parsed$result$content[[1]]$type == "text" &&
    parsed$result$content[[1]]$text == "hello world" &&
    parsed$result$isError == FALSE
})

test("tool result JSON: error structure", {
  r <- mcp_result(list(mcp_text("something broke")), is_error = TRUE)
  j <- as.character(to_json(list(jsonrpc = "2.0", id = 2L, result = r)))
  parsed <- fromJSON(j, simplifyVector = FALSE)
  parsed$result$isError == TRUE
})

test("initialize response: has instructions", {
  resp <- list(
    jsonrpc = "2.0",
    id = 1L,
    result = list(
      protocolVersion = "2025-06-18",
      capabilities = list(tools = empty_obj()),
      serverInfo = list(name = "brightspaceR", version = "0.1.0"),
      instructions = "test instructions"
    )
  )
  j <- as.character(to_json(resp))
  parsed <- fromJSON(j, simplifyVector = FALSE)
  parsed$result$instructions == "test instructions"
})

# ── Summary ──────────────────────────────────────────────────────────────

cat("\n=== Results ===\n")
cat(pass, "passed,", fail, "failed\n")
if (fail > 0) quit(status = 1)
