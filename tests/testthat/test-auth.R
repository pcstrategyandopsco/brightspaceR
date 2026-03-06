test_that("bs_has_token() returns FALSE when not authenticated", {
  withr::defer(bs_deauth(clear_cache = FALSE))
  bs_deauth(clear_cache = FALSE)
  expect_false(bs_has_token())
})

test_that("bs_token() errors when not authenticated", {
  withr::defer(bs_deauth(clear_cache = FALSE))
  bs_deauth(clear_cache = FALSE)
  expect_error(brightspaceR:::bs_token(), "Not authenticated")
})

test_that("bs_instance_url() errors when not authenticated", {
  withr::defer(bs_deauth(clear_cache = FALSE))
  bs_deauth(clear_cache = FALSE)
  expect_error(brightspaceR:::bs_instance_url(), "No instance URL")
})

test_that("bs_auth() errors without client_id", {
  expect_error(
    bs_auth(client_id = "", client_secret = "secret",
            instance_url = "https://example.com"),
    "No client ID"
  )
})

test_that("bs_auth() errors without client_secret", {
  expect_error(
    bs_auth(client_id = "id", client_secret = "",
            instance_url = "https://example.com"),
    "No client secret"
  )
})

test_that("bs_auth() errors without instance_url", {
  expect_error(
    bs_auth(client_id = "id", client_secret = "secret",
            instance_url = ""),
    "No instance URL"
  )
})

test_that("bs_auth_refresh() errors without client_id", {
  expect_error(
    bs_auth_refresh(refresh_token = "tok", client_id = "",
                    client_secret = "secret",
                    instance_url = "https://example.com"),
    "No client ID"
  )
})

test_that("bs_auth_token() sets token and instance URL", {
  withr::defer(bs_deauth(clear_cache = FALSE))

  mock_token <- list(access_token = "test-token-123")
  bs_auth_token(
    token = mock_token,
    instance_url = "https://test.brightspace.com/",
    client_id = "test-id",
    client_secret = "test-secret"
  )

  expect_true(bs_has_token())
  expect_equal(brightspaceR:::bs_instance_url(), "https://test.brightspace.com")
  expect_equal(brightspaceR:::bs_token()$access_token, "test-token-123")
})

test_that("bs_deauth() clears credentials", {
  mock_token <- list(access_token = "test-token-123")
  bs_auth_token(
    token = mock_token,
    instance_url = "https://test.brightspace.com",
    client_id = "test-id",
    client_secret = "test-secret"
  )

  expect_true(bs_has_token())
  bs_deauth(clear_cache = FALSE)
  expect_false(bs_has_token())
})

test_that("bs_token_needs_refresh detects expired tokens", {
  fresh_token <- list(
    access_token = "tok",
    created_at = as.numeric(Sys.time()),
    expires_in = 3600
  )
  expect_false(brightspaceR:::bs_token_needs_refresh(fresh_token))

  expired_token <- list(
    access_token = "tok",
    created_at = as.numeric(Sys.time()) - 7200,
    expires_in = 3600
  )
  expect_true(brightspaceR:::bs_token_needs_refresh(expired_token))
})

test_that("bs_pkce_challenge produces valid S256 challenge", {
  challenge <- brightspaceR:::bs_pkce_challenge("test_verifier")
  expect_type(challenge, "character")
  expect_true(nchar(challenge) > 0)
  # Should not contain padding or non-URL-safe chars

  expect_false(grepl("=", challenge))
  expect_false(grepl("\\+", challenge))
  expect_false(grepl("/", challenge))
})

test_that("bs_random_string produces correct length", {
  s <- brightspaceR:::bs_random_string(64)
  expect_equal(nchar(s), 64)
})
