# ============================================================================
# Manual live test — Course Access differential-merge fix
#
# Run interactively (after a one-time browser auth):
#   source("tests/manual/test-course-access-live.R")
#
# Or non-interactively once a token is cached:
#   R --no-save -q -e 'pkgload::load_all("."); brightspaceR::bs_auth()'   # once
#   Rscript tests/manual/test-course-access-live.R
#
# Requires a real token + network. Excluded from R CMD check (subdirectory).
# PII-safe: prints only column names, row counts, manifests, and pass/fail
# flags — never raw learner rows.
#
# Validates:
#   1. Course Access is listed by the API
#   2. Real column headers match the registered schema (day_accessed exists)
#   3. bs_get_dataset_current() merges full + diffs without dropping diff rows
#   4. The old _id-only key would have collapsed the per-day grain
#   5. Privacy layer (pseudonymise + field policy) works on real data
# ============================================================================

if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  suppressMessages(pkgload::load_all(quiet = TRUE))
} else {
  library(brightspaceR)
}

ok  <- function(m) cat(sprintf("  [PASS] %s\n", m))
no  <- function(m) { cat(sprintf("  [FAIL] %s\n", m)); .fail <<- TRUE }
hd  <- function(m) cat(sprintf("\n== %s ==\n", m))
chk <- function(cond, m) if (isTRUE(cond)) ok(m) else no(m)
.fail <- FALSE

hd("Authenticate (config.yml + cached token)")
tryCatch(
  bs_auth(),
  error = function(e) {
    cat("\nAUTH FAILED: ", conditionMessage(e), "\n",
        "Run once interactively:  ",
        "R --no-save -q -e 'pkgload::load_all(\".\"); brightspaceR::bs_auth()'\n",
        sep = "")
    quit(status = 2, save = "no")
  }
)

hd("Scope gate — hard stop before any dataset call")
scopes <- suppressMessages(bs_check_scopes())
bds <- scopes[scopes$tier == "Tier 1 (BDS)", ]
print(bds[, c("endpoint", "status")])
if (!all(bds$status == "OK")) {
  cat("\nABORT: token missing BDS access ",
      "(need datasets:bds:read + datahub:dataexports:read/download).\n",
      "Fix the app scopes / re-consent, then re-run.\n", sep = "")
  quit(status = 3, save = "no")
}
ok("BDS scopes present — proceeding")

hd("1. Course Access dataset is listed by the API")
ds <- bs_list_datasets()
idx <- grep("course access", ds$name, ignore.case = TRUE)
cat("  matches:", paste(ds$name[idx], collapse = " | "), "\n")
if (length(idx) == 0) {
  no("Course Access not found in dataset listing")
  quit(status = 4, save = "no")
}
exact <- which(tolower(ds$name[idx]) == "course access")
ca_name <- if (length(exact)) ds$name[idx][exact[1]] else ds$name[idx][1]
cat("  using dataset:", ca_name, "\n")
chk(TRUE, "Course Access present in dataset listing")

hd("2. REAL column headers match the registered schema")
full <- suppressMessages(bs_get_dataset(ca_name))
cat("  real columns:", paste(names(full), collapse = ", "), "\n")
expected_keys <- bs_key_cols(ca_name)
cat("  schema key_cols:", paste(expected_keys, collapse = ", "), "\n")
chk(all(expected_keys %in% names(full)),
    "all schema key columns exist in the real extract")
chk("day_accessed" %in% names(full),
    "day_accessed present (the column the old code dropped)")
chk(inherits(full$day_accessed, "POSIXct"),
    "day_accessed parsed as datetime")

hd("3. Merge incorporates differential rows (the original anomaly)")
merged <- suppressMessages(bs_get_dataset_current(ca_name))
man <- bs_diff_manifest(merged)
print(man)
full_rows <- man$rows[man$extract == "Full"]
diff_rows <- sum(man$rows[grepl("^Diff", man$extract)], na.rm = TRUE)
cat(sprintf("  full=%s  diff_rows=%s  merged=%d\n",
            full_rows, diff_rows, nrow(merged)))
distinct_full   <- nrow(unique(full[expected_keys]))
distinct_merged <- nrow(unique(merged[expected_keys]))
cat(sprintf("  distinct (org,user,day) keys: full=%d merged=%d\n",
            distinct_full, distinct_merged))
chk(distinct_merged >= distinct_full,
    "merged has at least as many distinct per-day keys as full")
if (isTRUE(diff_rows > 0)) {
  chk(nrow(merged) >= full_rows,
      "merged row count is not below full (diffs not silently dropped)")
} else {
  cat("  (no diff extracts newer than the full — merge is a no-op today)\n")
}

hd("4. Grain check — old _id-only key would collapse per-day rows")
guessed <- setdiff(grep("_id$", names(full), value = TRUE), "is_deleted")
cat("  guessed keys (old logic):", paste(guessed, collapse = ", "), "\n")
collapsed <- nrow(unique(full[guessed]))
cat(sprintf("  full per-day rows=%d  vs  collapsed-to-guessed-keys=%d\n",
            nrow(full), collapsed))
chk(collapsed <= nrow(full),
    "guessed keys collapse the grain (>= as many real rows as guessed keys)")

hd("5. Privacy layer works on the REAL data")
key_hmac <- openssl::rand_bytes(32)
p <- bs_pseudonymise_df(merged, ca_name, key = key_hmac)
chk(all(grepl("^usr_", p$user_id)), "user_id pseudonymised on live data")
chk(identical(p$org_unit_id, merged$org_unit_id), "org_unit_id left intact")
fp <- bs_apply_field_policy(merged, ca_name)
cat("  field-policy kept cols:", ncol(fp), "of", ncol(merged), "\n")
chk(ncol(fp) > 0, "field policy did not drop every column")

cat("\n")
if (isTRUE(.fail)) {
  cat("LIVE TEST: ONE OR MORE CHECKS FAILED\n")
  if (!interactive()) quit(status = 1, save = "no")
} else {
  cat("LIVE TEST COMPLETE — ALL CHECKS PASSED\n")
}
