# OAuth2 Setup for Brightspace Data Sets

Before you can use brightspaceR, you need to register an OAuth2
application in your Brightspace instance and configure your R
environment with the credentials. This guide walks through every step.

## Step 1: Register an OAuth2 Application

You need administrator access (or help from an admin) to register an
app.

1.  Log in to your Brightspace instance (e.g.,
    `https://myschool.brightspace.com`).
2.  Navigate to **Admin Tools** \> **Manage Extensibility**.
3.  Select the **OAuth 2.0** tab.
4.  Click **Register an app**.
5.  Fill in the registration form:

| Field | Value |
|----|----|
| **Application Name** | `brightspaceR` (or any name you like – this is shown to users on the consent page) |
| **Authentication Workflow** | **Authorization Code Grant** |
| **Redirect URI** | `https://localhost:1410/` |
| **Scope** | See [About Scopes](#about-scopes) below |
| **Access Token Lifetime** | Leave at default (3600 seconds is fine) |
| **Enable Refresh Tokens** | **Yes** (recommended) |
| **Prompt User for Consent** | Optional (Yes if you want users to see a consent screen) |

6.  Accept the **Non-Commercial Developer Agreement** (or your
    institution’s terms).
7.  Click **Register**.

After registration you’ll receive a **Client ID** and **Client Secret**.
Save these securely – you’ll need them in the next step.

### About the Redirect URI

Brightspace requires all redirect URIs to use HTTPS – `http://` is not
accepted. brightspaceR uses `https://localhost:1410/` by default.

**How the flow works:** When you run
[`bs_auth()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth.md),
the package opens your browser to the Brightspace authorization page.
After you authorize, Brightspace redirects to
`https://localhost:1410/?code=...`. Since there’s no local HTTPS server
listening, your browser will show a connection error – that’s expected.
You simply copy the full URL from your browser’s address bar and paste
it back into R. The package extracts the authorization code from the URL
and exchanges it for an access token.

You can use a different redirect URI by setting the
`BRIGHTSPACE_REDIRECT_URI` environment variable or passing
`redirect_uri` to
[`bs_auth()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth.md).
Just make sure it matches what you registered in Brightspace exactly.

### About Scopes

{#about-scopes}

Scopes control what API endpoints your application can access.
Brightspace scopes follow the pattern `<group>:<resource>:<action>`.
brightspaceR needs scopes from two tiers depending on which features you
use.

#### Tier 1: BDS only (minimum)

These scopes are sufficient for
[`bs_get_dataset()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_dataset.md),
joins, grade and enrollment analytics – everything except Advanced Data
Sets:

| Scope | Used by |
|----|----|
| `datasets:bds:read` | [`bs_list_datasets()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_list_datasets.md), [`bs_get_schema()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_schema.md) |
| `datahub:dataexports:read` | [`bs_list_extracts()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_list_extracts.md), [`bs_download_dataset()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_download_dataset.md) |
| `datahub:dataexports:download` | [`bs_get_dataset()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_dataset.md), [`bs_download_all()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_download_all.md) |
| `users:profile:read` | [`bs_check_scopes()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_check_scopes.md) |

**Scope string for Tier 1:**

    datasets:bds:read datahub:dataexports:read datahub:dataexports:download users:profile:read

#### Tier 2: BDS + ADS (recommended)

Add these scopes to also use
[`bs_get_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_ads.md)
for Advanced Data Sets like Learner Usage. The ADS functions power the
engagement, retention, and risk analytics
([`bs_course_engagement()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_course_engagement.md),
[`bs_identify_at_risk()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_identify_at_risk.md),
[`bs_retention_summary()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_retention_summary.md),
etc.):

| Scope | Used by |
|----|----|
| `reporting:dataset:list` | [`bs_list_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_list_ads.md) |
| `reporting:dataset:fetch` | [`bs_create_ads_job()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_create_ads_job.md) (filter auto-detection) |
| `reporting:job:create` | [`bs_create_ads_job()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_create_ads_job.md), [`bs_get_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_ads.md) |
| `reporting:job:list` | [`bs_list_ads_jobs()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_list_ads_jobs.md) |
| `reporting:job:fetch` | [`bs_ads_job_status()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_ads_job_status.md) (polling) |
| `reporting:job:download` | [`bs_download_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_download_ads.md) |

**Scope string for Tier 2 (recommended – paste this into Brightspace):**

    datasets:bds:read datahub:dataexports:read datahub:dataexports:download reporting:dataset:list reporting:dataset:fetch reporting:job:create reporting:job:list reporting:job:fetch reporting:job:download users:profile:read

> **Note:** If you register with Tier 1 scopes only, ADS functions like
> [`bs_get_ads()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_get_ads.md)
> will return `NULL` with an informative warning instead of crashing.
> BDS workflows are completely unaffected. You can upgrade to Tier 2
> later by updating the scopes in **Manage Extensibility** and
> re-authenticating with
> [`bs_deauth(); bs_auth()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_deauth.md).

#### Verifying scopes

After authenticating, run
[`bs_check_scopes()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_check_scopes.md)
to confirm which capabilities are available:

``` r

bs_check_scopes()
#> i Testing API access with current token...
#> v All 4 scope checks passed.
```

If any checks fail, compare the registered scopes in Brightspace
(**Admin Tools** \> **Manage Extensibility** \> **OAuth 2.0** \> your
app) with the scope strings above.

#### Scope reference

The canonical list of Brightspace OAuth2 scopes is published at:

- [Brightspace API Scopes
  Table](https://docs.valence.desire2learn.com/http-scopestable.html)

## Step 2: Configure Your R Environment

There are two ways to store your credentials: a **config file**
(recommended for projects) or **environment variables** (traditional
approach). Both are picked up automatically by
[`bs_auth()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth.md).

### Option A: Config file (recommended)

{#config-file}

Create a `config.yml` file in your project root:

``` yaml
default:
  brightspace:
    client_id: "your-client-id"
    client_secret: "your-client-secret"
    instance_url: "https://myschool.brightspace.com"
    redirect_uri: "https://localhost:1410/"
    scope: "datasets:bds:read datahub:dataexports:read datahub:dataexports:download reporting:dataset:list reporting:dataset:fetch reporting:job:create reporting:job:list reporting:job:fetch reporting:job:download users:profile:read"
```

Or use
[`bs_config_set()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_config_set.md)
to create it interactively:

``` r

bs_config_set(
  client_id = "your-client-id",
  client_secret = "your-client-secret",
  instance_url = "https://myschool.brightspace.com"
)
```

The config file supports environment-based profiles via the
[config](https://rstudio.github.io/config/) package. Set the
`R_CONFIG_ACTIVE` environment variable to switch profiles:

``` yaml
default:
  brightspace:
    client_id: "dev-id"
    instance_url: "https://dev.brightspace.com"

production:
  inherits: default
  brightspace:
    client_id: "prod-id"
    instance_url: "https://myschool.brightspace.com"
```

> **Security note**: Make sure `config.yml` is in your `.gitignore` to
> avoid committing secrets to version control.

### Option B: Environment variables

You can pass credentials directly to
[`bs_auth()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth.md),
but it’s more convenient (and safer) to store them as environment
variables. Add the following to your `.Renviron` file:

``` r

# Open .Renviron for editing
usethis::edit_r_environ()
```

Then add these lines:

    BRIGHTSPACE_CLIENT_ID=your-client-id-here
    BRIGHTSPACE_CLIENT_SECRET=your-client-secret-here
    BRIGHTSPACE_INSTANCE_URL=https://myschool.brightspace.com

Restart R for the changes to take effect.

> **Security note**: Never commit `.Renviron` to version control. It
> should already be listed in `.gitignore` by default.

### Credential resolution order

[`bs_auth()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth.md)
resolves each credential in this order:

1.  Explicit argument (e.g., `bs_auth(client_id = "...")`)
2.  `config.yml` in the working directory (if present)
3.  Environment variable (e.g., `BRIGHTSPACE_CLIENT_ID`)

## Step 3: Authenticate

``` r

library(brightspaceR)

# Uses environment variables automatically
bs_auth()
```

This will:

1.  Open your default browser to the Brightspace login/consent page.
2.  You log in with your Brightspace credentials and authorize the app.
3.  Brightspace redirects to
    `https://localhost:1410/?code=...&state=...`.
4.  Your browser shows a connection error (because there’s no local
    HTTPS server) – **this is expected and normal**.
5.  Copy the entire URL from your browser’s address bar.
6.  Paste it into the R console when prompted.
7.  brightspaceR extracts the authorization code, exchanges it for
    tokens, and caches them to disk.

You should see:

    v Authenticated with Brightspace at <https://myschool.brightspace.com>

### Token Caching and Refresh

Tokens are cached to disk automatically. On subsequent calls,
[`bs_auth()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_auth.md)
will reuse the cached token and refresh it if expired – no browser
interaction needed.

To force re-authentication:

``` r

bs_deauth()
bs_auth()
```

### Non-interactive Environments (Scheduled Scripts)

For scripts that run unattended (e.g., cron jobs, scheduled ETL
pipelines), use a refresh token obtained from a prior interactive
session:

``` r

bs_auth_refresh(
  refresh_token = Sys.getenv("BRIGHTSPACE_REFRESH_TOKEN")
)
```

This exchanges the refresh token for a new access token without any
browser interaction. Store the refresh token as an environment variable
or in a secure secrets manager.

## Step 4: Verify It Works

``` r

# Check authentication status
bs_has_token()
#> [1] TRUE

# Verify API scopes are configured correctly
bs_check_scopes()
#> i Testing API access with current token...
#> v All 4 scope checks passed.

# List available BDS datasets
datasets <- bs_list_datasets()
datasets
#> # A tibble: 67 x 5
#>    schema_id plugin_id name               description             created_date
#>    <chr>     <chr>     <chr>              <chr>                   <chr>
#>  1 abc123    def456    Users              User demographics ...   2024-01-01...
#>  2 ghi789    jkl012    User Enrollments   Enrollment records ...  2024-01-01...
#> ...

# If you have Tier 2 (ADS) scopes, also verify ADS access
ads <- bs_list_ads()
ads
#> # A tibble: 12 x 4
#>    dataset_id   name             description          category
#>    <chr>        <chr>            <chr>                 <chr>
#>  1 abc-def-...  Learner Usage    Activity metrics ...  Engagement
#> ...
```

## Troubleshooting

### “No client ID found”

Make sure your environment variables are set. Check with:

``` r

Sys.getenv("BRIGHTSPACE_CLIENT_ID")
```

If empty, re-check your `.Renviron` file and restart R.

### Browser doesn’t open

If you’re in an environment without a browser (e.g., RStudio Server),
the authorization URL is printed to the console. Copy it into a browser
on any machine, authorize, then copy the redirect URL back.

### “No authorization code found in the redirect URL”

Make sure you copy the **entire** URL from the address bar, including
the `?code=...&state=...` query parameters. It should start with
`https://localhost:1410/`.

### 403 Forbidden errors

Your OAuth2 app may not have the correct scopes, or the user account you
authenticated with may not have permission to access Data Hub. Check:

- Run
  [`bs_check_scopes()`](https://pcstrategyandopsco.github.io/brightspaceR/reference/bs_check_scopes.md)
  to see which API capabilities are available.
- The registered scopes include `datasets:bds:read`,
  `datahub:dataexports:read`, and `datahub:dataexports:download` for
  BDS.
- For ADS access, add the `reporting:*` scopes listed above.
- Your Brightspace user role has the **Data Hub** permissions enabled
  (typically requires an admin or a role with “Can Access Data Hub”
  permission).
- The scopes registered in the Brightspace **Manage Extensibility**
  OAuth2 settings must match the scopes requested by your application.

### Token expired and won’t refresh

Clear the cached token and re-authenticate:

``` r

bs_deauth()
bs_auth()
```

## References

- [Brightspace API Scopes
  Table](https://docs.valence.desire2learn.com/http-scopestable.html) –
  canonical list of all OAuth2 scopes
- [Brightspace OAuth 2.0
  Documentation](https://docs.valence.desire2learn.com/basic/oauth2.html)
- [Getting Started with OAuth
  2.0](https://community.d2l.com/brightspace/kb/articles/21863-how-to-get-started-with-oauth-2-0)
- [Getting Started with Data Hub APIs: Brightspace Data
  Sets](https://community.d2l.com/brightspace/kb/articles/1130-how-to-get-started-with-data-hubs-apis-brightspace-data-sets)
- [BDS Headless Client Example (D2L
  GitHub)](https://github.com/Brightspace/bds-headless-client-example)
