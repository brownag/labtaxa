remotes::install_local(
  "./labtaxa",
  repos = c("https://ncss-tech.r-universe.dev", getOption('repos')),
  dependencies = TRUE
)

library(labtaxa)

cache_dir <- "/home/rstudio/.local/share/R/labtaxa"

if (file.exists(file.path(cache_dir, "ncss_labdata.gpkg"))) {
  message("Converting LDM data to SoilProfileCollection...")
  result <- get_LDM_snapshot(dirname = cache_dir, verbose = TRUE)

  if (is.null(result) || length(result) == 0) {
    stop("Failed to cache LDM data")
  }

  message(sprintf("Cached %d profiles", length(result)))

  # Verify RDS files
  ldm_rds <- file.path(cache_dir, "cached-LDM-SPC.rds")
  if (file.exists(ldm_rds)) {
    message(sprintf("[OK] LDM RDS: %.2f MB", file.size(ldm_rds) / 1024 / 1024))
  } else {
    warning("LDM RDS file not created")
  }

  morph_rds <- file.path(cache_dir, "cached-morph-SPC.rds")
  if (file.exists(morph_rds)) {
    message(sprintf("[OK] Morphologic RDS: %.2f MB", file.size(morph_rds) / 1024 / 1024))
  }
} else {
  stop("LDM database not found")
}

# Generate snapshot metadata with checksums for reproducibility
message("Generating snapshot metadata...")
ldm_db <- file.path(cache_dir, "ncss_labdata.gpkg")
morph_db <- file.path(cache_dir, "ncss_morphologic.sqlite")

metadata <- list(
  snapshot_date = as.character(Sys.Date()),
  download_timestamp = as.character(Sys.time()),
  r_version = paste(R.version$major, R.version$minor, sep = "."),
  package_version = as.character(utils::packageVersion("labtaxa")),
  checksums = list()
)

# Add checksums for existing files
if (file.exists(ldm_db)) {
  metadata$checksums[[basename(ldm_db)]] <- list(
    file = basename(ldm_db),
    sha256 = digest::digest(file = ldm_db, algo = "sha256"),
    size_bytes = file.size(ldm_db)
  )
}

if (file.exists(morph_db)) {
  metadata$checksums[[basename(morph_db)]] <- list(
    file = basename(morph_db),
    sha256 = digest::digest(file = morph_db, algo = "sha256"),
    size_bytes = file.size(morph_db)
  )
}

metadata_path <- file.path(cache_dir, "snapshot-metadata.json")
jsonlite::write_json(metadata, path = metadata_path, auto_unbox = TRUE, pretty = TRUE)
message(sprintf("Metadata written to: %s", metadata_path))

unlink("/home/rstudio/labtaxa_data", recursive = TRUE)
unlink(path.expand("~/Downloads"), recursive = TRUE)
