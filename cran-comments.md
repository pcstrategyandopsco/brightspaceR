## R CMD check results

0 errors | 0 warnings | 1 note

The only NOTE is "New submission", expected for a first CRAN submission.

## Test environments

* local macOS Sequoia 15.5 (aarch64-apple-darwin20), R 4.5.2
* R-hub: Ubuntu 24.04.3 LTS (x86_64-pc-linux-gnu), R-devel (2026-03-07 r89568)
* R-hub: Windows Server 2022 (x86_64-w64-mingw32), R-devel (2026-03-07 r89568)
* R-hub: macOS Sequoia 15.7.4 (aarch64-apple-darwin20), R-devel (2026-02-28 r89501)
* win-builder: Windows, R-devel (2026-03-08 r89578) — 1 NOTE (new submission)

## Notes

* This is the first submission of brightspaceR to CRAN.
* Examples use `\donttest{}` with `if (bs_has_token())` guards because they
  require OAuth2 credentials and network access to a Brightspace LMS instance.
