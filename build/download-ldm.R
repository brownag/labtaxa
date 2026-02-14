library(labtaxa)

data_dir <- "/home/rstudio/labtaxa_data"
cache_dir <- "/home/rstudio/.local/share/R/labtaxa"

if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)
if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)

ldm_file <- file.path(data_dir, "ncss_labdata.gpkg")
ldm_cache <- file.path(cache_dir, "ncss_labdata.gpkg")

# Skip if already downloaded
if (file.exists(ldm_file) && file.size(ldm_file) > 1000000) {
  message(sprintf("LDM snapshot already cached (%.2f MB)", file.size(ldm_file) / 1024 / 1024))
  file.copy(ldm_file, ldm_cache, overwrite = TRUE)
} else {
  message("Downloading LDM snapshot...")
  result <- get_LDM_snapshot(dirname = data_dir, verbose = TRUE)

  if (!file.exists(ldm_file) || file.size(ldm_file) < 1000000) {
    stop("LDM GeoPackage download failed or is invalid")
  }

  message(sprintf("SUCCESS: LDM snapshot complete (%.2f MB)", file.size(ldm_file) / 1024 / 1024))

  # Copy to final cache directory for persistence
  file.copy(ldm_file, ldm_cache, overwrite = TRUE)
}
