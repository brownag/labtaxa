devtools::load_all("./labtaxa")

data_dir <- "/home/rstudio/labtaxa_data"
if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)

morph_file <- file.path(data_dir, "ncss_morphologic.sqlite")

# Skip if already downloaded
if (file.exists(morph_file) && file.size(morph_file) > 1000000) {
  message(sprintf("Morphologic database already cached (%.2f MB)", file.size(morph_file) / 1024 / 1024))
} else {
  message("Downloading morphologic database...")

  oldtimeout <- getOption("timeout")
  options(timeout = 3600)

  result <- tryCatch({
    labtaxa:::.download_with_retry(
      "https://new.cloudvault.usda.gov/index.php/s/tdnrQzzJ7ty39gs/download",
      destfile = file.path(data_dir, "ncss_morphologic.zip"),
      max_attempts = 5,
      verbose = TRUE
    )
    TRUE
  }, error = function(e) {
    stop(sprintf("Morphologic download failed: %s", conditionMessage(e)))
  }, finally = {
    options(timeout = oldtimeout)
  })

  # Extract morphologic zip
  zf <- list.files(data_dir, "\\.zip$", full.names = TRUE)
  for (z in zf) {
    if (grepl("morphologic", basename(z))) {
      utils::unzip(z, exdir = data_dir)
    }
  }

  # Handle legacy filename
  oldfn <- file.path(data_dir, "NASIS_Morphological_09142021.sqlite")
  if (file.exists(oldfn)) {
    file.rename(oldfn, file.path(data_dir, "ncss_morphologic.sqlite"))
  }

  if (!file.exists(morph_file) || file.size(morph_file) < 1000000) {
    stop("Morphologic database not found or invalid")
  }

  message(sprintf("SUCCESS: Morphologic database complete (%.2f MB)", file.size(morph_file) / 1024 / 1024))
}
