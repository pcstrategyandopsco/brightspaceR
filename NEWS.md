# brightspaceR 0.1.0.9000

## Exported Privacy Functions

* Exported `bs_pseudonymise_id()`, `bs_pseudonymise_df()`, and
  `bs_apply_field_policy()` so regular R scripts can apply the same
  privacy protections as the MCP server. These are opt-in tools for use
  in dplyr pipelines — they do not wrap or change existing functions like
  `bs_get_dataset()`. The MCP server now calls the package functions
  instead of maintaining its own copies.

## MCP Server Security (Phase 2)

* **ID pseudonymisation**: All person-referencing ID columns (UserId,
  SubmitterId, LastModifiedBy, etc.) are hashed with a session-scoped
  HMAC-SHA256 key. The AI model sees deterministic pseudonyms like
  `usr_a3f2b1c8` instead of raw integers. Consistent within a session
  (joins and grouping work), unrecoverable across sessions. Combined
  with Phase 1's field policy (which drops names and emails), this
  achieves full pseudonymisation.
* **Privacy compliance vignette**: New `vignette("privacy-compliance")`
  documents alignment with ENISA, NIST SP 800-188, NIST IR 8053,
  ISO 25237:2017, GDPR/EDPB Guidelines 01/2025, FERPA, and HIPAA Safe
  Harbor. Includes compliance summary table with degree of compliance and
  organisational gaps. Provides complete worked examples for applying the
  same protections in regular R scripts outside the MCP server.

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
