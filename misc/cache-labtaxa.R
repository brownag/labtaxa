devtools::load_all("./labtaxa")

message("Installing labtaxa package...")
remotes::install_local(
  "./labtaxa",
  repos = c("https://ncss-tech.r-universe.dev", getOption('repos')),
  dependencies = TRUE
)

message("Caching data as SoilProfileCollections...")

cache_dir <- tools::R_user_dir(package = "labtaxa")
download_dir <- "/home/rstudio/labtaxa_data"

message(sprintf("Cache directory: %s", cache_dir))
message(sprintf("Download directory: %s", download_dir))

# Ensure cache directory exists
if (!dir.exists(cache_dir)) {
  dir.create(cache_dir, recursive = TRUE)
  message(sprintf("Created cache directory: %s", cache_dir))
}

# Copy downloaded files to cache directory
if (dir.exists(download_dir)) {
  files <- list.files(download_dir, full.names = TRUE)
  if (length(files) > 0) {
    message(sprintf("Copying %d files from download directory...", length(files)))
    for (f in files) {
      message(sprintf("  Copying: %s", basename(f)))
      file.copy(f, cache_dir, overwrite = TRUE)
    }
  } else {
    message("No files found in download directory")
  }
} else {
  message("Download directory does not exist")
}

# Convert to SPC objects
if (file.exists(file.path(cache_dir, "ncss_labdata.gpkg"))) {
  message("Starting LDM snapshot conversion...")
  result <- get_LDM_snapshot(dirname = cache_dir, verbose = TRUE)

  if (is.null(result) || length(result) == 0) {
    stop("Failed to cache LDM data")
  }

  message(sprintf("SUCCESS: Cached %d soil profiles", length(result)))

  # Verify RDS files exist
  ldm_rds <- file.path(cache_dir, "cached-LDM-SPC.rds")
  morph_rds <- file.path(cache_dir, "cached-morph-SPC.rds")

  if (file.exists(ldm_rds)) {
    message(sprintf("[OK] LDM RDS file created: %s (%.2f MB)", basename(ldm_rds), file.size(ldm_rds) / 1024 / 1024))
  } else {
    warning(sprintf("[FAILED] LDM RDS file not found: %s", ldm_rds))
  }

  if (file.exists(morph_rds)) {
    message(sprintf("[OK] Morphologic RDS file created: %s (%.2f MB)", basename(morph_rds), file.size(morph_rds) / 1024 / 1024))
  } else {
    warning(sprintf("[MISSING] Morphologic RDS file not found: %s", morph_rds))
  }
} else {
  stop(sprintf("LDM database not found in cache directory: %s", file.path(cache_dir, "ncss_labdata.gpkg")))
}

# Cleanup downloaded files (but keep RDS cache)
if (dir.exists(download_dir)) {
  message("Cleaning up download directory...")
  unlink(download_dir, recursive = TRUE)
}

downloads_dir <- path.expand("~/Downloads")
if (dir.exists(downloads_dir)) {
  message("Cleaning up Downloads directory...")
  unlink(downloads_dir, recursive = TRUE)
}

message("Cache preparation complete!")
