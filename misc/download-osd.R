message("Downloading OSD and SC data...")

data_dir <- "/home/rstudio/labtaxa_data"
if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)

urls <- c(
  "https://github.com/ncss-tech/OSDRegistry/releases/download/main/OSD-data-snapshot.zip",
  "https://github.com/ncss-tech/OSDRegistry/releases/download/main/SC-data-snapshot.zip"
)

oldtimeout <- getOption("timeout")
options(timeout = 3600)

for (url in urls) {
  filename <- file.path(data_dir, basename(url))
  message(sprintf("Downloading %s...", basename(url)))

  result <- tryCatch({
    utils::download.file(url, filename, mode = "wb", quiet = FALSE)
    TRUE
  }, error = function(e) {
    stop(sprintf("Failed to download %s: %s", basename(url), conditionMessage(e)))
  })

  # Verify file
  if (!file.exists(filename) || file.size(filename) < 100000) {
    stop(sprintf("Download verification failed for %s", basename(url)))
  }

  message(sprintf("SUCCESS: %s (%.2f MB)", basename(url), file.size(filename) / 1024 / 1024))

  # Extract
  message(sprintf("Extracting %s...", basename(url)))
  utils::unzip(filename, exdir = data_dir)

  # Delete ZIP file after extraction
  file.remove(filename)
}

options(timeout = oldtimeout)
message("SUCCESS: OSD and SC data complete")
