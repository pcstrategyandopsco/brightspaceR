# Prompt: Refactor brightspaceR MCP Server with 7-Layer Security Architecture

You are refactoring the brightspaceR MCP server to implement a
battle-tested, defence-in-depth security architecture. This architecture
was designed for selmaR (a SELMA student management system wrapper) and
is being adapted to brightspaceR (a Brightspace LMS API wrapper). Both
packages deal with sensitive student data and expose MCP servers for
AI-assisted analytics.

## Context

brightspaceR wraps the Brightspace (D2L Valence) API. Like SELMA,
Brightspace contains highly sensitive student data — grades,
submissions, personal details, enrolment records, and learning activity.
The MCP server lets an AI agent query this data conversationally, which
means **PII protection is paramount**. An AI model should never see raw
student names, emails, grades tied to identifiable individuals, or other
personal data unless the operator explicitly opts in.

## The 7 Defence Layers to Implement

Refactor the existing MCP server to implement ALL of the following
layers. Each layer is independent — if one fails, the others still
protect. This is defence-in-depth.

------------------------------------------------------------------------

### Layer 1: ID Pseudonymisation

**Purpose:** Replace all real student/user IDs with session-scoped,
deterministic hashes so the AI model cannot memorise or leak real
identifiers.

**Implementation pattern:**

``` r

# Generate a random seed per server session
.mcp_seed <- as.character(sample.int(1e9, 1))

# Map column name patterns to entity prefixes
ID_COLUMN_PATTERNS <- list(
  list(pattern = "^(user_id|userid|org_defined_id)$",  prefix = "U"),
  list(pattern = "^(org_unit_id|orgunitid)$",          prefix = "O"),
  list(pattern = "^(section_id|sectionid)$",           prefix = "SC"),
  list(pattern = "^(enrollment_id|enrollmentid)$",     prefix = "EN"),
  list(pattern = "^(grade_object_id)$",                prefix = "GO"),
  list(pattern = "^(submission_id)$",                  prefix = "SB"),
  list(pattern = "^(course_id|courseid)$",             prefix = "CR"),
  list(pattern = "^(semester_id|semesterid)$",         prefix = "SM")
  # Add more as you discover ID columns in Brightspace data
)

pseudonymise_id <- function(id, prefix = "U") {
  if (is.na(id) || id == "") return(id)
  hash <- substr(digest::digest(paste0(.mcp_seed, id), algo = "md5"), 1, 8)
  paste0(prefix, "-", hash)
}

# Apply to a data frame — all ID columns get pseudonymised
apply_pseudonymisation <- function(df) {
  if (.mcp_config$expose_real_ids) return(df)
  for (col in names(df)) {
    col_lower <- tolower(col)
    for (pat in ID_COLUMN_PATTERNS) {
      if (grepl(pat$pattern, col_lower)) {
        df[[col]] <- vapply(as.character(df[[col]]),
                            function(v) pseudonymise_id(v, pat$prefix),
                            character(1), USE.NAMES = FALSE)
        break
      }
    }
  }
  df
}
```

**Key properties:** - Deterministic within a session (same ID → same
hash) so joins still work - Different seed per session so hashes aren’t
stable across restarts - Opt-in to disable via
`mcp.expose_real_ids: true` in config.yml (generates a WARNING in audit
log) - Prefixes make cross-entity joins possible (user_id and userid
both map to `U-` prefix)

**Adapt for Brightspace:** Audit every entity your package returns and
identify ALL ID columns. Brightspace has user IDs, org unit IDs, section
IDs, grade object IDs, submission IDs, etc. Map them all.

------------------------------------------------------------------------

### Layer 2: AST Code Inspection

**Purpose:** If you expose an `execute_r` tool (sandboxed R code
execution), parse the code into an Abstract Syntax Tree BEFORE executing
it and reject code that uses dangerous constructs.

**Implementation pattern:**

``` r

BLOCKED_PACKAGES <- c("brightspaceR", "httr", "httr2", "curl", "jsonlite", "config")

BLOCKED_FUNCTIONS <- c(
  # Metaprogramming / indirect dispatch
  "eval", "evalq", "do.call", "get", "mget", "exists",
  "match.fun", "getExportedValue", "loadNamespace", "requireNamespace",
  # Environment / credential access
  "Sys.getenv", "Sys.setenv",
  # Shell execution
  "system", "system2", "shell",
  # File I/O
  "readLines", "scan", "file", "readRDS", "writeLines",
  "write.csv", "write.csv2", "saveRDS",
  # Network
  "download.file", "url", "socketConnection"
)

check_code_safety <- function(code) {
  expr <- tryCatch(parse(text = code), error = function(e) NULL)
  if (is.null(expr)) return(list(safe = TRUE))  # syntax error — will fail at eval

  blocked <- character(0)

  walk <- function(node) {
    if (is.call(node)) {
      fn <- node[[1]]
      # Detect :: and ::: with blocked packages
      if (is.call(fn) && length(fn) >= 3 &&
          as.character(fn[[1]]) %in% c("::", ":::")) {
        pkg <- as.character(fn[[2]])
        if (pkg %in% BLOCKED_PACKAGES) {
          blocked <<- c(blocked, paste0(pkg, "::", as.character(fn[[3]])))
        }
      }
      # Detect blocked bare function calls
      fn_name <- if (is.symbol(fn)) as.character(fn) else ""
      if (fn_name %in% BLOCKED_FUNCTIONS) {
        blocked <<- c(blocked, fn_name)
      }
    }
    if (is.recursive(node)) {
      for (child in as.list(node)) walk(child)
    }
  }

  for (e in as.list(expr)) walk(e)

  if (length(blocked) > 0) {
    list(safe = FALSE, blocked = unique(blocked))
  } else {
    list(safe = TRUE)
  }
}
```

**Why AST, not regex:** Regex would false-positive on comments
(`# don't use system()`) and strings (`x <- "call system admin"`). AST
inspection only matches actual function calls in the parsed syntax tree.

**Critical:** Block `brightspaceR::` namespace access so the model can’t
bypass the policy-wrapped workspace functions and call the raw API
directly.

------------------------------------------------------------------------

### Layer 3: Input Allowlisting (Tool Surface Restriction)

**Purpose:** Expose only a small set of safe, purpose-built tools. Do
NOT expose raw API access functions.

**Expose these tools (adapt names for Brightspace):**

| Tool | Purpose | Returns |
|----|----|----|
| `auth_status` | Check connection status | Connection info, policy status |
| `list_entities` | Catalog of available entity types | Names + descriptions |
| `search_entities` | Keyword search over entity catalog | Matching entities |
| `describe_entity` | Per-column summary statistics | Aggregates only (counts, distributions, ranges) — NEVER individual rows |
| `get_entity_summary` | Filtered/grouped aggregate stats | Counts and means — NEVER individual rows |
| `execute_r` | Sandboxed R code execution | Output with all guards applied |

**Do NOT expose:**
[`bs_get()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get.md),
[`bs_request()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_request.md),
`bs_connect()`, raw connection objects, or any function that returns
unfiltered individual records.

**For Brightspace specifically, consider adding:** -
`get_grade_distribution` — aggregate grade stats by course/assessment
(never individual grades) - `get_completion_summary` — completion rates
by org unit (never individual completion) - `get_enrollment_counts` —
headcounts by semester/course (never individual enrollments)

------------------------------------------------------------------------

### Layer 4: PII Field Policy (YAML Allowlist)

**Purpose:** Configure which columns are visible per entity type.
Unknown/new fields are excluded by default.

**Implementation:**

Create `inst/mcp/field_policy.yml`:

``` yaml
# brightspaceR MCP Server — Default PII Field Policy
#
# Three modes:
#   allow  — only listed fields pass through (whitelist)
#   redact — listed fields replaced with [REDACTED]
#   all    — no restrictions (for lookup tables with no PII)

users:
  mode: allow
  fields:
    - user_id
    - org_defined_id
    - role_id
    - activation_date
    - last_accessed_date
    - is_active
  # Hidden: first_name, last_name, username, email,
  #         external_email, unique_identifier

enrollments:
  mode: allow
  fields:
    - enrollment_id
    - org_unit_id
    - user_id
    - role_id
    - enrollment_date
    - enrollment_type
    - is_active

grades:
  mode: allow
  fields:
    - grade_object_id
    - org_unit_id
    - user_id
    - points_numerator
    - points_denominator
    - weighted_numerator
    - weighted_denominator
    - grade_object_name
    - grade_object_type
  # Hidden: comments, private_comments, last_modified_by

course_offerings:
  mode: allow
  fields:
    - org_unit_id
    - name
    - code
    - start_date
    - end_date
    - is_active
    - semester_id
    - department_id

submissions:
  mode: allow
  fields:
    - submission_id
    - org_unit_id
    - user_id
    - dropbox_id
    - submitted_date
    - is_late
    - score
  # Hidden: file_name, comments, feedback

discussions:
  mode: allow
  fields:
    - forum_id
    - topic_id
    - org_unit_id
    - post_count
    - created_date
  # Hidden: post_content, author_name, subject (may contain names)

quizzes:
  mode: allow
  fields:
    - quiz_id
    - org_unit_id
    - user_id
    - attempt_id
    - score
    - time_started
    - time_completed
    - is_graded
  # Hidden: answers, feedback, question_responses

attendance:
  mode: allow
  fields:
    - register_id
    - org_unit_id
    - user_id
    - status
    - date
  # Hidden: notes, excuse_reason

# Lookup entities — no PII
roles:
  mode: all
org_structure:
  mode: all
semesters:
  mode: all
departments:
  mode: all
```

**Resolution order for the policy file:** 1. `BRIGHTSPACER_FIELD_POLICY`
environment variable 2. `field_policy.yml` in the working directory
(project override) 3. `{pkg_root}/inst/mcp/field_policy.yml` (package
default)

**Secure by default:** If an entity is not in the policy, all fields
pass through (warn in log). If an entity uses `allow` mode, any NEW
fields the API adds in the future are automatically excluded — you must
explicitly add them to the allowlist.

``` r

apply_field_policy <- function(df, entity_name) {
  policy <- .mcp_policy[[entity_name]]
  if (is.null(policy) || identical(policy$mode, "all")) return(df)

  if (identical(policy$mode, "allow")) {
    allowed <- intersect(names(df), policy$fields)
    if (length(allowed) == 0) return(df[0, , drop = FALSE])
    return(df[, allowed, drop = FALSE])
  }

  if (identical(policy$mode, "redact")) {
    for (col in intersect(names(df), policy$fields)) {
      df[[col]] <- "[REDACTED]"
    }
    return(df)
  }

  df
}
```

------------------------------------------------------------------------

### Layer 5: Hybrid Data Access

**Purpose:** Structured tools return aggregates only. Row-level access
is only available through `execute_r` with all guards active.

- `describe_entity` → column summaries (type, min/max, top values,
  counts) — never individual rows
- `get_entity_summary` → filtered/grouped counts and means — never
  individual rows
- `execute_r` → provides policy-wrapped entity fetch functions in the
  workspace that always apply field policy + pseudonymisation before the
  code sees the data

**Workspace setup pattern:**

``` r

.mcp_workspace <- new.env(parent = globalenv())

# Policy-wrapped entity fetch — ALWAYS applies field policy + pseudonymisation
.mcp_workspace$bs_get_entity <- function(entity_name) {
  ds <- get_cached_entity(entity_name)  # fetches, applies policy, pseudonymises, caches
  ds
}

# Convenience aliases that shadow real package functions
.mcp_workspace$bs_users       <- function() .mcp_workspace$bs_get_entity("users")
.mcp_workspace$bs_enrollments <- function() .mcp_workspace$bs_get_entity("enrollments")
.mcp_workspace$bs_grades      <- function() .mcp_workspace$bs_get_entity("grades")
# ... etc

# Pre-load safe packages
local({
  suppressPackageStartupMessages({
    require(dplyr, quietly = TRUE)
    require(tidyr, quietly = TRUE)
    require(ggplot2, quietly = TRUE)
    require(lubridate, quietly = TRUE)
    require(scales, quietly = TRUE)
  })
}, envir = .mcp_workspace)
```

**Critical data flow:** Raw API data → build PII dictionary (Layer 6) →
apply field policy (Layer 4) → apply pseudonymisation (Layer 1) → cache
→ return to workspace. The PII dictionary is built from the UNFILTERED
data so it can catch leaked names even after the fields are stripped.

------------------------------------------------------------------------

### Layer 6: Output Scanning

**Purpose:** A safety net that scans ALL text output before it reaches
the AI model, catching PII that leaked through other layers (e.g., names
appearing in free-text fields, error messages containing emails).

**Two scanning modes:**

**6a. Regex Pattern Matching:**

``` r

PII_PATTERNS <- list(
  email    = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
  nz_phone = "\\+64[0-9]{7,10}",
  au_phone = "\\+61[0-9]{8,9}",
  nz_mobile = "(?:^|\\s)02[0-9]{7,9}",
  # Add patterns relevant to your user base:
  # us_phone, uk_phone, etc.
  dob_iso  = "\\b(?:19[5-9][0-9]|200[0-9]|201[0-9])-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])\\b"
)
```

**6b. PII Dictionary (Dynamic, Session-Specific):**

``` r

PII_DICTIONARY_SOURCES <- list(
  users = c("first_name", "last_name", "username",
            "email", "external_email", "unique_identifier"),
  # Add Brightspace-specific PII fields
  submissions = c("file_name"),  # may contain student names
  discussions = c("author_name", "subject")
)

build_pii_dictionary <- function(df, entity_name) {
  cols <- PII_DICTIONARY_SOURCES[[entity_name]]
  if (is.null(cols)) return(invisible(NULL))

  for (col in intersect(cols, names(df))) {
    values <- unique(na.omit(as.character(df[[col]])))
    values <- values[nchar(values) >= 3]  # skip "Jo", "Li" — too many false positives
    .pii_dictionary$values <- unique(c(.pii_dictionary$values, values))
  }
}
```

**The dictionary is built from UNFILTERED data** (before field policy
strips names), then used to scan all output text. This catches scenarios
like: - An error message that includes “User John Smith not found” - A
chart title generated from data: “Submissions by Smith, J.” - Free-text
fields that reference students by name

**Scanning function:**

``` r

scan_output_for_pii <- function(text) {
  if (!is.character(text) || length(text) == 0)
    return(list(text = text, redactions = character(0)))

  redacted <- text
  redactions <- character(0)

  # Regex scan
  for (pii_type in names(PII_PATTERNS)) {
    pattern <- PII_PATTERNS[[pii_type]]
    matches <- gregexpr(pattern, redacted, perl = TRUE)
    n_matches <- sum(vapply(matches, function(m) sum(m > 0), integer(1)))
    if (n_matches > 0) {
      redacted <- gsub(pattern, paste0("[REDACTED:", pii_type, "]"), redacted, perl = TRUE)
      redactions <- c(redactions, paste0(pii_type, ": ", n_matches, " match(es)"))
    }
  }

  # Dictionary scan (case-insensitive whole-word matching)
  dict_hits <- 0L
  for (val in .pii_dictionary$values) {
    pattern <- paste0("\\b", escape_regex(val), "\\b")
    if (grepl(pattern, redacted, ignore.case = TRUE, perl = TRUE)) {
      redacted <- gsub(pattern, "[REDACTED:pii]", redacted, ignore.case = TRUE, perl = TRUE)
      dict_hits <- dict_hits + 1L
    }
  }
  if (dict_hits > 0) {
    redactions <- c(redactions, paste0("dictionary: ", dict_hits, " match(es)"))
  }

  list(text = redacted, redactions = redactions)
}
```

------------------------------------------------------------------------

### Layer 7: Audit Logging

**Purpose:** Record every tool call, every blocked code attempt, every
PII redaction. Generate a human-readable session report on shutdown.

**JSONL audit log** (one JSON object per line, append-only):

``` r

audit_log <- function(tool, arguments = list(), response_bytes = 0L,
                      redactions = character(0), code_blocked = FALSE,
                      blocked_constructs = character(0), is_error = FALSE,
                      entity = NA_character_) {
  entry <- list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    tool = tool,
    arguments = arguments,
    response_bytes = response_bytes,
    redactions_applied = if (length(redactions) > 0) redactions else list(),
    code_blocked = code_blocked,
    is_error = is_error
  )
  if (!is.na(entity)) entry$entity <- entity
  if (code_blocked && length(blocked_constructs) > 0) {
    entry$blocked_constructs <- blocked_constructs
  }
  line <- as.character(jsonlite::toJSON(entry, auto_unbox = TRUE, null = "null"))
  cat(line, "\n", sep = "", file = .audit$log_path, append = TRUE)
}
```

**HTML session report** (generated on server shutdown via
[`on.exit()`](https://rdrr.io/r/base/on.exit.html)): - Session duration,
server version - Field policy status, pseudonymisation on/off - Table of
all tool calls (timestamp, tool, response size, errors) - Entities
accessed with row counts - Blocked code attempts with the blocked
constructs - PII redaction counts by type

------------------------------------------------------------------------

## Additional Defences to Recommend for Brightspace Data

Beyond the 7 core layers, consider these Brightspace-specific
protections:

### A. Grade Anonymisation Threshold

Brightspace contains individual grades. Even with pseudonymised IDs,
small cohorts (\< 5 students) can be re-identified from grade
distributions. Add a **k-anonymity threshold**:

``` r

MIN_GROUP_SIZE <- 5  # configurable

# In describe_entity and get_entity_summary:
# If a group_by result has fewer than MIN_GROUP_SIZE rows, suppress it
group_counts <- group_counts[group_counts$count >= MIN_GROUP_SIZE, ]
```

This prevents the model from seeing “Section X has 2 students, both with
grade A” which could identify individuals.

### B. Content Sanitisation for Discussion/Assignment Text

Brightspace has rich free-text fields: discussion posts, assignment
submissions, feedback comments. These frequently contain student names,
email addresses, and personal information. Even if the `post_content`
column is stripped by field policy, consider:

1.  **Never expose** discussion post content, assignment text, or
    feedback through the MCP server
2.  If you must expose it (e.g., for topic analysis), run it through the
    PII output scanner BEFORE including it in any response
3.  Add discussion/assignment content fields to `PII_DICTIONARY_SOURCES`
    so names in those fields get caught

### C. Temporal Access Control

Consider limiting the date range of data the MCP server can access:

``` yaml
mcp:
  max_lookback_days: 730  # 2 years
```

This prevents the model from accessing very old records where students
may have since changed circumstances (e.g., withdrawal reasons,
disability records).

### D. API Scope Restriction

If Brightspace supports OAuth scopes or API permissions, configure the
MCP server’s API credentials with the **minimum required scopes**. Don’t
give the MCP server’s API user admin access if it only needs read access
to enrollments and grades.

### E. Row-Level Security for Multi-Tenant Use

If brightspaceR could be used in a context where one instructor should
only see their own courses:

``` r

# Apply org_unit filter to all queries based on config
.mcp_config$allowed_org_units <- c(12345, 67890)  # from config.yml

apply_row_security <- function(df, entity_name) {
  if (is.null(.mcp_config$allowed_org_units)) return(df)
  if ("org_unit_id" %in% names(df)) {
    df <- df[df$org_unit_id %in% .mcp_config$allowed_org_units, ]
  }
  df
}
```

### F. Sensitive Entity Gating

Some Brightspace entities are more sensitive than others. Consider a
tiered access model:

``` yaml
entity_sensitivity:
  users: high          # requires explicit opt-in
  grades: high         # requires explicit opt-in
  submissions: high    # requires explicit opt-in
  enrollments: medium  # available by default
  course_offerings: low  # always available
  semesters: low       # always available
```

High-sensitivity entities could require an explicit `--enable-sensitive`
flag or config setting before the MCP server will serve them.

------------------------------------------------------------------------

## Testing Requirements

**This is non-negotiable. Every defence layer MUST have dedicated
tests.** The test suite should be runnable WITHOUT Brightspace API
credentials (pure unit tests of the security functions).

### Required Test File: `inst/mcp/test_server.R`

Structure the test suite by layer. Minimum required tests:

### Layer 1 Tests: ID Pseudonymisation (minimum 8 tests)

    - Same ID produces same hash (deterministic within session)
    - Different IDs produce different hashes
    - Hash format is {prefix}-{8 hex chars}
    - Different prefixes for different column types (U- vs O- vs EN-)
    - NA and empty string pass through unchanged
    - Different seed produces different hash (session isolation)
    - apply_pseudonymisation handles full data frames correctly
    - Joins work across entities with pseudonymised IDs (user_id in enrollments matches user_id in users)
    - expose_real_ids=TRUE disables pseudonymisation

### Layer 2 Tests: AST Code Inspection (minimum 18 tests)

    Clean code that MUST pass:
    - dplyr pipe chains (filter, mutate, summarise)
    - ggplot2 code
    - Basic assignment and arithmetic
    - Comments containing blocked function names (should NOT trigger)
    - Strings containing blocked function names (should NOT trigger)

    Blocked code that MUST fail:
    - brightspaceR:: namespace access
    - brightspaceR::: internal access
    - httr:: / httr2:: / curl:: network access
    - config:: credential access
    - eval() / evalq()
    - do.call()
    - get() / mget()
    - Sys.getenv() / Sys.setenv()
    - system() / system2() / shell()
    - readLines() / writeLines() / readRDS() / saveRDS()
    - download.file() / url() / socketConnection()
    - Multiple blocked constructs in one expression
    - Syntax errors pass through (they'll fail at eval, not at safety check)

### Layer 4 Tests: PII Field Policy (minimum 9 tests)

    - allow mode keeps only listed fields
    - allow mode excludes PII fields (names, emails, DOB)
    - redact mode replaces values with [REDACTED]
    - all mode passes everything through (lookup tables)
    - Unknown entity passes through with no policy (or defaults to restrictive — your choice)
    - New/unknown fields are excluded by allow mode (secure by default)
    - Default field_policy.yml is valid YAML and parseable
    - Default policy has students/users in allow mode with PII excluded
    - Default policy has lookup entities in all mode

### Layer 6 Tests: Output Scanning (minimum 15 tests)

    Regex tests:
    - Email addresses are redacted
    - NZ phone numbers (+64...) are redacted
    - AU phone numbers (+61...) are redacted
    - NZ mobile numbers (02x...) are redacted
    - DOB-like dates (1990-05-15) are redacted
    - Future dates (2025-03-01) are NOT redacted (not DOBs)
    - Clean text passes through unchanged
    - Multiple PII items in one text all get redacted

    Dictionary tests:
    - Known surnames are caught and redacted
    - Whole-word matching works (don't match "Lee" inside "employee" or "Leeds")
    - Case-insensitive matching works (SMITH → redacted)
    - Short values (<3 chars) are excluded at dictionary build time
    - Dictionary + regex combined in one text

### Layer 7 Tests: Audit Log (minimum 3 tests)

    - Audit log entry is valid JSONL (parseable by jsonlite::fromJSON)
    - Blocked code attempts are logged with constructs
    - Redaction counts are recorded in audit entries

### Integration Test (minimum 1 test)

    - Full pipeline: simulate raw data → build PII dictionary → apply field policy → apply pseudonymisation → format output → scan for PII leaks → verify no PII in final output

### Additional Brightspace-Specific Tests (minimum 5 tests)

    - Grade anonymisation threshold: groups smaller than MIN_GROUP_SIZE are suppressed
    - Org unit ID columns are correctly pseudonymised with O- prefix
    - Grade data with student identifiers: field policy strips names, pseudonymisation hashes IDs, output scan catches any remaining PII
    - Submission file names containing student names are caught by dictionary
    - Discussion post content is excluded by default field policy

### Test Infrastructure

Use a lightweight custom test harness (no testthat dependency needed for
the MCP test file — it should be self-contained):

``` r

.test_results <- list(passed = 0L, failed = 0L, errors = character(0))

test_that <- function(description, expr) {
  result <- tryCatch({ eval(expr); TRUE },
    error = function(e) {
      .test_results$errors <<- c(.test_results$errors,
        paste0("FAIL: ", description, " — ", conditionMessage(e)))
      FALSE
    })
  if (result) {
    .test_results$passed <<- .test_results$passed + 1L
    cat(paste0("  PASS: ", description, "\n"))
  } else {
    .test_results$failed <<- .test_results$failed + 1L
    cat(paste0("  FAIL: ", description, "\n"))
  }
}
```

**Exit with non-zero status on failure** so CI catches it:

``` r

if (.test_results$failed > 0) quit(status = 1)
```

------------------------------------------------------------------------

## Implementation Checklist

Read the existing brightspaceR MCP server code and understand the
current tool surface

Identify ALL entity types and their columns — especially which columns
contain PII

Identify ALL ID columns across all entities (for pseudonymisation
mapping)

Create `inst/mcp/field_policy.yml` with appropriate allowlists for each
entity

Implement Layer 1: ID Pseudonymisation with Brightspace-specific column
patterns

Implement Layer 2: AST Code Inspection (block brightspaceR::, httr::,
etc.)

Implement Layer 3: Restrict tool surface to safe aggregate-returning
tools

Implement Layer 4: Field policy loading and application

Implement Layer 5: Workspace setup with policy-wrapped entity fetch
functions

Implement Layer 6: Output scanning (regex + PII dictionary)

Implement Layer 7: Audit logging (JSONL + HTML session report)

Add execution timeout (30 seconds) and response size limit (800KB)

Add grade anonymisation threshold (k-anonymity, MIN_GROUP_SIZE = 5)

Write the complete test suite (`inst/mcp/test_server.R`) — minimum 59
tests

Run the test suite and ensure all tests pass

Update server instructions (the text sent to the AI model on initialize)
to document security constraints and available workspace functions

Update MCP documentation/vignettes if they exist

## Architecture Notes

- **Single file:** The entire MCP server lives in one file
  (`inst/mcp/server.R`). This is intentional — it makes deployment
  simple (just point Rscript at the file).
- **stdio transport:** JSON-RPC 2.0 over stdin/stdout. All diagnostic
  output goes to stderr.
- **No external dependencies beyond what the package already imports:**
  jsonlite, digest, yaml, stringr. Don’t add new dependencies.
- **Session-scoped state:** Entity cache, PII dictionary,
  pseudonymisation seed, and workspace all live in the server process.
  No persistence across restarts.
- **Config via config.yml or env vars:** Never hardcode credentials.
