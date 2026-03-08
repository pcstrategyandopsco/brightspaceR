# Package index

## Authentication

Connect to your Brightspace instance via OAuth2.

- [`bs_auth()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth.md)
  : Authenticate with Brightspace
- [`bs_auth_refresh()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth_refresh.md)
  : Authenticate with a refresh token
- [`bs_auth_token()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth_token.md)
  : Set Brightspace authentication token directly
- [`bs_deauth()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_deauth.md)
  : Clear Brightspace authentication
- [`bs_has_token()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_has_token.md)
  : Check if authenticated with Brightspace

## Datasets

Discover and download Brightspace Data Sets.

- [`bs_list_datasets()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_list_datasets.md)
  : List available Brightspace Data Sets
- [`bs_list_extracts()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_list_extracts.md)
  : List available extracts for a dataset
- [`bs_download_dataset()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_download_dataset.md)
  : Download a dataset extract
- [`bs_download_all()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_download_all.md)
  : Download all available datasets
- [`bs_get_dataset()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_dataset.md)
  : Get a dataset by name

## Joins

Convenience functions for joining related datasets.

- [`bs_join()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_join.md)
  : Smart join two BDS tibbles
- [`bs_join_users_enrollments()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_join_users_enrollments.md)
  : Join users with enrollments
- [`bs_join_enrollments_grades()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_join_enrollments_grades.md)
  : Join enrollments with grade results
- [`bs_join_grades_objects()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_join_grades_objects.md)
  : Join grade results with grade objects
- [`bs_join_content_progress()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_join_content_progress.md)
  : Join content objects with user progress
- [`bs_join_enrollments_roles()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_join_enrollments_roles.md)
  : Join enrollments with role details
- [`bs_join_enrollments_orgunits()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_join_enrollments_orgunits.md)
  : Join enrollments with org units

## Schemas & Parsing

Column type definitions and data cleaning.

- [`bs_get_schema()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_schema.md)
  : Get the schema for a dataset
- [`bs_list_schemas()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_list_schemas.md)
  : List all registered dataset schemas
- [`bs_clean_names()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_clean_names.md)
  : Convert column names from PascalCase to snake_case

## Advanced Data Sets (ADS)

Ad-hoc data exports via the Reporting API.

- [`bs_list_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_list_ads.md)
  : List available Advanced Data Sets
- [`bs_get_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_ads.md)
  : Get an ADS dataset by name (convenience wrapper)
- [`bs_create_ads_job()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_create_ads_job.md)
  : Create an ADS export job
- [`bs_ads_job_status()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_ads_job_status.md)
  : Check ADS export job status
- [`bs_list_ads_jobs()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_list_ads_jobs.md)
  : List all submitted ADS export jobs
- [`bs_download_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_download_ads.md)
  : Download a completed ADS export
- [`bs_ads_filter()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_ads_filter.md)
  : Build an ADS export filter
- [`bs_org_id()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_org_id.md)
  : Get the root organisation ID
- [`bs_get_ads_schema()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_ads_schema.md)
  : Get the schema for an ADS dataset
- [`bs_list_ads_schemas()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_list_ads_schemas.md)
  : List all registered ADS dataset schemas

## Analytics

Composable analytics functions for engagement, performance, and
retention.

- [`bs_filter_test_users()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_filter_test_users.md)
  : Filter test users from a dataset
- [`bs_enrich_enrollments()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_enrich_enrollments.md)
  : Enrich enrollments with org unit and user details
- [`bs_summarize_enrollments()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_summarize_enrollments.md)
  : Summarize enrollments to one row per user per course
- [`bs_course_engagement()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_course_engagement.md)
  : Calculate per-user per-course engagement metrics
- [`bs_engagement_summary()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_engagement_summary.md)
  : Summarize engagement by grouping dimension
- [`bs_engagement_score()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_engagement_score.md)
  : Add a composite engagement score
- [`bs_grade_summary()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_grade_summary.md)
  : Summarize grades with percentages
- [`bs_assessment_performance()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_assessment_performance.md)
  : Summarize assessment performance per user per quiz
- [`bs_assignment_completion()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_assignment_completion.md)
  : Summarize assignment submission completion
- [`bs_identify_at_risk()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_identify_at_risk.md)
  : Identify at-risk students
- [`bs_retention_summary()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_retention_summary.md)
  : Summarize retention and dropout rates
- [`bs_course_summary()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_course_summary.md)
  : Summarize course effectiveness

## Configuration

Package configuration options.

- [`bs_api_version()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_api_version.md)
  : Get or set the Brightspace API version
- [`bs_config()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_config.md)
  : Read Brightspace credentials from a config file
- [`bs_config_set()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_config_set.md)
  : Create or update a Brightspace config file
- [`bs_set_timezone()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_set_timezone.md)
  : Set the timezone for Brightspace analytics
- [`bs_get_timezone()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_timezone.md)
  : Get the current Brightspace analytics timezone
- [`bs_check_scopes()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_check_scopes.md)
  : Test Brightspace API scope access
