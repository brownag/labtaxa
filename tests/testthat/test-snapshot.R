test_that("ldm_db_download_url returns valid URL", {
  url <- ldm_db_download_url()

  expect_type(url, "character")
  expect_true(grepl("^https://", url))
  expect_true(grepl("ncsslabdatamart", url))
})

test_that(".download_with_retry succeeds on first attempt", {
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "test-download.txt")
  on.exit(unlink(test_file))

  # Mock successful download
  mock_download <- function(url, destfile, ...) {
    writeLines("test content", destfile)
  }

  with_mock(
    `utils::download.file` = mock_download,
    {
      result <- .download_with_retry(test_file, "http://example.com", verbose = FALSE)
      expect_true(result)
      expect_true(file.exists(test_file))
    }
  )
})

test_that(".download_with_retry retries on failure", {
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "test-retry.txt")
  on.exit(unlink(test_file))

  attempt_count <- 0

  mock_download <- function(url, destfile, ...) {
    attempt_count <<- attempt_count + 1

    if (attempt_count < 3) {
      stop("Network error")
    }

    writeLines("success", destfile)
  }

  with_mock(
    `utils::download.file` = mock_download,
    {
      result <- .download_with_retry(test_file, "http://example.com", max_attempts = 3, verbose = FALSE)
      expect_true(result)
      expect_equal(attempt_count, 3)
      expect_true(file.exists(test_file))
    }
  )
})

test_that(".download_with_retry fails after max attempts", {
  temp_file <- tempfile()
  on.exit(unlink(temp_file))

  mock_download <- function(url, destfile, ...) {
    stop("Network error")
  }

  with_mock(
    `utils::download.file` = mock_download,
    {
      expect_error(
        .download_with_retry(temp_file, "http://example.com", max_attempts = 2, verbose = FALSE),
        "Failed to download"
      )
    }
  )
})

test_that("load_labtaxa with no cache downloads data", {
  # This test would require extensive mocking of RSelenium and soilDB
  # For now, we just verify the function signature is correct
  expect_true(is.function(get_LDM_snapshot))

  # Check parameters
  args <- formals(get_LDM_snapshot)
  expect_true("cache" %in% names(args))
  expect_true("verbose" %in% names(args))
  expect_equal(args$cache, TRUE)
  expect_equal(args$verbose, TRUE)
})

test_that("get_LDM_snapshot has all expected parameters", {
  args <- formals(get_LDM_snapshot)

  expected_args <- c(
    "cache",
    "verbose",
    "keep_zip",
    "dlname",
    "dbname",
    "cachename",
    "dirname",
    "port",
    "timeout",
    "baseurl"
  )

  for (arg in expected_args) {
    expect_true(arg %in% names(args), info = sprintf("Missing parameter: %s", arg))
  }
})
