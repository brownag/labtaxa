test_that("ldm_data_dir creates directory if it doesn't exist", {
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "test-labtaxa-nonexistent")

  # Clean up if it exists
  if (dir.exists(test_dir)) {
    unlink(test_dir, recursive = TRUE)
  }

  expect_false(dir.exists(test_dir))

  # Temporarily override R_user_dir
  with_mock(
    `tools::R_user_dir` = function(package = "labtaxa", type = "cache") {
      test_dir
    },
    {
      result <- ldm_data_dir()
      expect_true(dir.exists(result))
      expect_equal(result, test_dir)
    }
  )

  # Clean up
  unlink(test_dir, recursive = TRUE)
})

test_that("cache_labtaxa saves object to RDS file", {
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "test-cache.rds")

  # Create mock SPC-like object
  mock_spc <- list(
    class = "SoilProfileCollection",
    data = data.frame(id = 1:3, name = c("Profile1", "Profile2", "Profile3"))
  )

  # Cache the object
  result <- cache_labtaxa(mock_spc, filename = "test-cache.rds", destdir = temp_dir)

  # Check file was created
  expect_true(file.exists(test_file))

  # Check return value is the file path
  expect_equal(result, test_file)

  # Load and verify content
  loaded <- readRDS(test_file)
  expect_equal(loaded$class, "SoilProfileCollection")
  expect_equal(nrow(loaded$data), 3)

  # Clean up
  unlink(test_file)
})

test_that("load_labtaxa returns try-error when file doesn't exist", {
  temp_dir <- tempdir()
  nonexistent_file <- "nonexistent-cache.rds"

  result <- load_labtaxa(
    filename = nonexistent_file,
    destdir = temp_dir,
    silent = TRUE
  )

  expect_true(inherits(result, "try-error"))
})

test_that("load_labtaxa successfully loads cached object", {
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "test-load.rds")

  # Create and save test data
  test_data <- list(
    class = "SoilProfileCollection",
    profiles = 100,
    horizons = 500
  )
  saveRDS(test_data, test_file)

  # Load it back
  result <- load_labtaxa(filename = "test-load.rds", destdir = temp_dir, silent = TRUE)

  expect_false(inherits(result, "try-error"))
  expect_equal(result$profiles, 100)
  expect_equal(result$horizons, 500)

  # Clean up
  unlink(test_file)
})

test_that("load_labmorph is wrapper for load_labtaxa with correct filename", {
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "cached-morph-SPC.rds")

  # Create test data
  test_data <- list(
    class = "SoilProfileCollection",
    morphologic = TRUE,
    profiles = 50
  )
  saveRDS(test_data, test_file)

  # Load morphologic data
  result <- load_labmorph(destdir = temp_dir, silent = TRUE)

  expect_false(inherits(result, "try-error"))
  expect_true(result$morphologic)
  expect_equal(result$profiles, 50)

  # Clean up
  unlink(test_file)
})

test_that("cache and load roundtrip works correctly", {
  temp_dir <- tempdir()
  test_filename <- "roundtrip-test.rds"

  # Create test data
  original_data <- list(
    name = "Test Data",
    values = 1:100,
    matrix = matrix(rnorm(100), nrow = 10)
  )

  # Cache it
  cache_path <- cache_labtaxa(original_data, filename = test_filename, destdir = temp_dir)
  expect_true(file.exists(cache_path))

  # Load it back
  loaded_data <- load_labtaxa(filename = test_filename, destdir = temp_dir, silent = TRUE)

  # Verify it matches
  expect_equal(loaded_data$name, original_data$name)
  expect_equal(loaded_data$values, original_data$values)
  expect_equal(loaded_data$matrix, original_data$matrix)

  # Clean up
  unlink(cache_path)
})
