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

unlink("/home/rstudio/labtaxa_data", recursive = TRUE)
unlink(path.expand("~/Downloads"), recursive = TRUE)
