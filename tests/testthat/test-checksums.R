test_that(".calculate_checksum fails for nonexistent file", {
  nonexistent_file <- "/tmp/definitely-nonexistent-file-12345.txt"

  expect_error(
    .calculate_checksum(nonexistent_file),
    "File not found"
  )
})

test_that(".calculate_checksum computes SHA256 correctly", {
  temp_file <- tempfile(fileext = ".txt")
  on.exit(unlink(temp_file))

  # Write known content
  writeLines("test content", temp_file)

  # Calculate checksum
  checksum <- .calculate_checksum(temp_file)

  # Verify it's a valid hex string
  expect_match(checksum, "^[a-f0-9]{64}$")

  # Same file should always produce same checksum
  checksum2 <- .calculate_checksum(temp_file)
  expect_equal(checksum, checksum2)
})

test_that(".calculate_checksum is sensitive to file changes", {
  temp_file <- tempfile(fileext = ".txt")
  on.exit(unlink(temp_file))

  # Create file with content
  writeLines("original content", temp_file)
  checksum1 <- .calculate_checksum(temp_file)

  # Change content
  writeLines("modified content", temp_file)
  checksum2 <- .calculate_checksum(temp_file)

  # Checksums should be different
  expect_not_equal(checksum1, checksum2)
})

test_that(".write_snapshot_metadata creates valid JSON file", {
  temp_dir <- tempdir()
  test_file1 <- file.path(temp_dir, "test1.txt")
  test_file2 <- file.path(temp_dir, "test2.txt")
  on.exit({
    unlink(test_file1)
    unlink(test_file2)
    unlink(file.path(temp_dir, "snapshot-metadata.json"))
  })

  # Create test files
  writeLines("file 1", test_file1)
  writeLines("file 2", test_file2)

  # Generate metadata
  metadata <- .write_snapshot_metadata(
    temp_dir,
    c(test_file1, test_file2),
    "snapshot-metadata.json"
  )

  # Check metadata structure
  expect_true(!is.null(metadata$snapshot_date))
  expect_true(!is.null(metadata$download_timestamp))
  expect_true(!is.null(metadata$r_version))
  expect_true(!is.null(metadata$package_version))
  expect_equal(length(metadata$checksums), 2)

  # Check checksums are valid hex
  for (cs_info in metadata$checksums) {
    expect_match(cs_info$sha256, "^[a-f0-9]{64}$")
    expect_true(cs_info$size_bytes > 0)
  }

  # Check JSON file was created and is readable
  json_file <- file.path(temp_dir, "snapshot-metadata.json")
  expect_true(file.exists(json_file))

  # Load and verify JSON
  loaded_metadata <- jsonlite::read_json(json_file)
  expect_equal(loaded_metadata$snapshot_date, metadata$snapshot_date)
  expect_equal(length(loaded_metadata$checksums), 2)
})

test_that(".write_snapshot_metadata handles missing files gracefully", {
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "exists.txt")
  missing_file <- file.path(temp_dir, "missing.txt")
  on.exit({
    unlink(test_file)
    unlink(file.path(temp_dir, "snapshot-metadata.json"))
  })

  # Create one file, not the other
  writeLines("content", test_file)

  # Generate metadata for mix of existing and missing files
  metadata <- .write_snapshot_metadata(
    temp_dir,
    c(test_file, missing_file),
    "snapshot-metadata.json"
  )

  # First file should have valid checksum
  expect_match(metadata$checksums[[1]]$sha256, "^[a-f0-9]{64}$")

  # Second file should have NOT_FOUND marker
  expect_equal(metadata$checksums[[2]]$sha256, "NOT_FOUND")
  expect_true(is.na(metadata$checksums[[2]]$size_bytes))
})

test_that(".verify_checksum validates matching checksums", {
  temp_file <- tempfile(fileext = ".txt")
  on.exit(unlink(temp_file))

  writeLines("test data", temp_file)
  correct_checksum <- .calculate_checksum(temp_file)

  result <- .verify_checksum(temp_file, correct_checksum, verbose = FALSE)
  expect_true(result)
})

test_that(".verify_checksum rejects mismatched checksums", {
  temp_file <- tempfile(fileext = ".txt")
  on.exit(unlink(temp_file))

  writeLines("test data", temp_file)
  wrong_checksum <- "0000000000000000000000000000000000000000000000000000000000000000"

  result <- .verify_checksum(temp_file, wrong_checksum, verbose = FALSE)
  expect_false(result)
})

test_that(".verify_checksum handles missing files", {
  missing_file <- "/tmp/nonexistent-verify-test.txt"

  result <- .verify_checksum(missing_file, "somechecksum", verbose = FALSE)
  expect_false(result)
})
