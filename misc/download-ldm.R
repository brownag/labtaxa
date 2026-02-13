devtools::load_all("./labtaxa")

data_dir <- "/home/rstudio/labtaxa_data"
if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)

ldm_file <- file.path(data_dir, "ncss_labdata.gpkg")

# Skip if already downloaded
if (file.exists(ldm_file) && file.size(ldm_file) > 1000000) {
  message(sprintf("LDM snapshot already cached (%.2f MB)", file.size(ldm_file) / 1024 / 1024))
} else {
  message("Downloading LDM snapshot...")
  result <- get_LDM_snapshot(dirname = data_dir, verbose = TRUE)

  if (!file.exists(ldm_file) || file.size(ldm_file) < 1000000) {
    stop("LDM GeoPackage download failed or is invalid")
  }

  message(sprintf("SUCCESS: LDM snapshot complete (%.2f MB)", file.size(ldm_file) / 1024 / 1024))
}
