# brightspaceR 0.1.0.9000

## MCP Server Security (Phase 1)

* **AST code inspection**: `execute_r` now parses submitted R code and rejects
  dangerous constructs before execution. Blocked categories include direct
  package access (`brightspaceR::`, `httr::`, `curl::`, etc.), metaprogramming
  (`eval`, `do.call`, `get`), shell commands (`system`, `system2`), file I/O
  (`readLines`, `writeLines`, `readRDS`, etc.), and network functions
  (`download.file`, `url`). Safe code (dplyr pipelines, ggplot2, arithmetic)
  passes through unchanged.
* **`write_chart()` helper**: New safe alternative to `writeLines()` for
  Chart.js HTML output. Writes only `.html` files to the configured output
  directory. Server instructions updated to reference `write_chart()`.
* **PII field policy**: YAML-driven column allowlists per BDS dataset
  (`inst/mcp/field_policy.yml`). Datasets containing PII (Users, Grade Results,
  Assignment Submissions, Quiz User Answers) are filtered to exclude sensitive
  columns (names, emails, comments) before data reaches the AI model. Policy
  supports `allow`, `redact`, and `all` modes. Custom policies can be provided
  via the `BRIGHTSPACER_FIELD_POLICY` environment variable.
* **Audit logging**: Every tool call is logged as append-only JSONL to
  `mcp_audit.jsonl` in the output directory. Entries include timestamp, tool
  name, arguments (code truncated to 500 chars), response size, blocked
  status, and error flag. Session start/end events are also recorded.
* **35 new tests** in `inst/mcp/test_server.R`: 18 for AST inspection, 9 for
  field policy, 3 for audit logging, plus supporting infrastructure. All 68
  tests pass.

# brightspaceR 0.1.0

* Initial CRAN release.
* OAuth2 authentication with D2L Brightspace (`bs_auth()`).
* Download all Brightspace Data Sets (BDS) as tidy data frames (`bs_get_dataset()`).
* Download Advanced Data Sets (ADS) with automatic pagination (`bs_get_ads()`).
* Convenience join functions that know foreign-key relationships (`bs_join()`).
* Composable analytics helpers for engagement, performance, and retention.
* MCP server for LLM-assisted data exploration (`inst/mcp/`).
