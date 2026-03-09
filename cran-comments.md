## R CMD check results

0 errors | 0 warnings | 2 notes

## Test environments

* local macOS Sequoia 15.5 (aarch64-apple-darwin20), R 4.5.2

## Notes

* This is the first submission of brightspaceR to CRAN.
* Examples use `\donttest{}` with `if (bs_has_token())` guards because they
  require OAuth2 credentials and network access to a Brightspace LMS instance.
* NOTE 1 (CRAN incoming): "New submission" — expected for first submission.
  URL redirect warnings are for claude.ai → claude.com and
  docs.anthropic.com → platform.claude.com (both return 200 OK).
* NOTE 2: `00LOCK-brightspaceR` in check directory — transient build artifact.
