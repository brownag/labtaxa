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

# Copy downloaded files to cache directory
if (dir.exists(download_dir)) {
  files <- list.files(download_dir, full.names = TRUE)
  if (length(files) > 0) {
    for (f in files) {
      file.copy(f, cache_dir, overwrite = TRUE)
    }
  }
}

# Convert to SPC objects
if (file.exists(file.path(cache_dir, "ncss_labdata.gpkg"))) {
  result <- get_LDM_snapshot(dirname = cache_dir, verbose = TRUE)
  if (is.null(result) || length(result) == 0) {
    stop("Failed to cache LDM data")
  }
  message(sprintf("SUCCESS: Cached %d soil profiles", length(result)))
}

# Cleanup
unlink(download_dir, recursive = TRUE)
unlink(path.expand("~/Downloads"), recursive = TRUE)
