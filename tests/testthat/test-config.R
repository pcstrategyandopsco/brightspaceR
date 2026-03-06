test_that("bs_config() returns NULL when file does not exist", {
  expect_null(bs_config(file = "nonexistent-config.yml"))
})

test_that("bs_config() reads credentials from config.yml", {
  tmp <- withr::local_tempfile(fileext = ".yml")
  writeLines(c(
    "default:",
    "  brightspace:",
    "    client_id: test-id",
    "    client_secret: test-secret",
    "    instance_url: https://example.brightspace.com",
    "    redirect_uri: https://localhost:1410/",
    "    scope: datahub:dataexports:*"
  ), tmp)

  cfg <- bs_config(file = tmp)
  expect_type(cfg, "list")
  expect_equal(cfg$client_id, "test-id")
  expect_equal(cfg$client_secret, "test-secret")
  expect_equal(cfg$instance_url, "https://example.brightspace.com")
  expect_equal(cfg$redirect_uri, "https://localhost:1410/")
  expect_equal(cfg$scope, "datahub:dataexports:*")
})

test_that("bs_config() returns NULL when brightspace key is missing", {
  tmp <- withr::local_tempfile(fileext = ".yml")
  writeLines(c(
    "default:",
    "  other_service:",
    "    key: value"
  ), tmp)

  expect_null(bs_config(file = tmp))
})

test_that("bs_config() respects profile parameter", {
  tmp <- withr::local_tempfile(fileext = ".yml")
  writeLines(c(
    "default:",
    "  brightspace:",
    "    client_id: default-id",
    "",
    "production:",
    "  inherits: default",
    "  brightspace:",
    "    client_id: prod-id"
  ), tmp)

  cfg_default <- bs_config(file = tmp, profile = "default")
  expect_equal(cfg_default$client_id, "default-id")

  cfg_prod <- bs_config(file = tmp, profile = "production")
  expect_equal(cfg_prod$client_id, "prod-id")
})

test_that("bs_resolve_cred() uses correct priority order", {
  resolve <- brightspaceR:::bs_resolve_cred

  # Explicit arg wins

  expect_equal(resolve("explicit", "config", ""), "explicit")

  # Config value used when arg is empty
  expect_equal(resolve("", "config-val", ""), "config-val")

  # Env var used when arg and config are empty
  withr::local_envvar(TEST_CRED_VAR = "env-val")
  expect_equal(resolve("", NULL, "TEST_CRED_VAR"), "env-val")

  # Fallback used when all else empty
  withr::local_envvar(TEST_CRED_EMPTY = "")
  expect_equal(resolve("", NULL, "TEST_CRED_EMPTY", fallback = "fb"), "fb")
})

test_that("bs_auth() picks up config file values", {
  tmp <- withr::local_tempfile(fileext = ".yml")
  writeLines(c(
    "default:",
    "  brightspace:",
    "    client_id: cfg-id",
    "    client_secret: cfg-secret",
    "    instance_url: https://cfg.brightspace.com"
  ), tmp)

  withr::local_envvar(
    BRIGHTSPACE_CLIENT_ID = "",
    BRIGHTSPACE_CLIENT_SECRET = "",
    BRIGHTSPACE_INSTANCE_URL = ""
  )

  # Mock bs_config to return our test config
  local_mocked_bindings(
    bs_config = function(file = "config.yml", profile = "default") {
      bs_config(file = tmp, profile = profile)
    },
    .package = "brightspaceR"
  )

  # bs_auth will error at the cache/interactive stage but credentials

  # should resolve -- we test that it doesn't error on missing creds
  # by checking that the error is NOT about missing credentials
  err <- tryCatch(
    bs_auth(),
    error = function(e) e
  )

  # If we get here without a "No client ID" type error, config worked
  expect_false(grepl("No client ID", conditionMessage(err)))
  expect_false(grepl("No client secret", conditionMessage(err)))
  expect_false(grepl("No instance URL", conditionMessage(err)))
})
