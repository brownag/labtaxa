#' Get 'Lab Data Mart' 'SQLite' Snapshot
#'
#' Downloads the USDA-NRCS Kellogg Soil Survey Laboratory (KSSL) 'Lab Data Mart'
#' database snapshot from the official download portal. Uses `RSelenium` for
#' automated browser control to navigate the webpage and initiate the download,
#' which is cached in the user's local data directory for fast subsequent access.
#'
#' Laboratory pedon (soil profile) data are retrieved from the downloaded GeoPackage
#' SQLite database using `soilDB::fetchLDM()` and cached as an RDS file containing
#' a `SoilProfileCollection` object. Companion morphologic (field description) data
#' are retrieved using `soilDB::fetchNASIS()` and cached separately.
#'
#' @section Caching Behavior:
#' By default (`cache = TRUE`), results are automatically cached as RDS files in
#' `tools::R_user_dir(package="labtaxa")`. Subsequent calls to `get_LDM_snapshot()`
#' with `cache = TRUE` will load the cached data without re-downloading or
#' re-processing. Use `cache = FALSE` to force a fresh download and rebuild.
#'
#' @section Data Versions:
#' KSSL data is versioned by month. Always check the Docker image or metadata
#' file to determine which data version you're working with. For reproducible
#' research, pin to specific Docker image tags: `ghcr.io/brownag/labtaxa:2026.02`
#'
#' @section Performance Notes:
#' The full KSSL database contains ~65,000 soil profiles with 500,000+ horizons.
#' Initial download and processing typically takes 10-30 minutes depending on
#' internet speed. Subsequent calls using cached data complete in <1 second.
#'
#' @param ... Arguments passed to `soilDB::fetchLDM()` for controlling data retrieval
#' @param cache Default: `TRUE`; cache the downloaded data as an RDS file and reuse
#'   on subsequent calls? When `FALSE`, forces fresh download and processing.
#' @param verbose Default: `TRUE`; print informative progress messages about download,
#'   processing, and caching operations? Set to `FALSE` for silent operation.
#' @param keep_zip Default: `FALSE`; retain the downloaded ZIP archive files after
#'   extraction? Set to `TRUE` to preserve raw downloads for manual inspection.
#' @param dlname Default: `"ncss_labdatagpkg.zip"`; file name for the main LDM database download
#' @param dbname Default: `"ncss_labdata.gpkg"`; file name for the extracted GeoPackage database
#' @param cachename Default: `"cached-LDM-SPC.rds"`; file name for the cached LDM `SoilProfileCollection`
#' @param companiondlname Default: `"ncss_morphologic.zip"`; file name for morphologic data download
#' @param companiondbname Default: `"ncss_morphologic.sqlite"`; file name for extracted morphologic database
#' @param companioncachename Default: `"cached-morph-SPC.rds"`; file name for cached morphologic `SoilProfileCollection`
#' @param dirname Data cache directory for the labtaxa package. Default: `tools::R_user_dir(package = "labtaxa")`.
#'   This directory is created automatically if it doesn't exist.
#' @param port Default: `4567L`; port number for Selenium WebDriver. Change if port is already in use.
#' @param timeout Default: `1e5` seconds (~27.8 hours); maximum time to wait for file download
#' @param baseurl Default: `"https://ncsslabdatamart.sc.egov.usda.gov/database_download.aspx"`;
#'   URL of the KSSL Lab Data Mart download page
#'
#' @importFrom soilDB fetchLDM fetchNASIS
#' @importFrom aqp site horizons
#' @importClassesFrom aqp SoilProfileCollection
#'
#' @return A `SoilProfileCollection` object (from the `aqp` package) containing
#'   laboratory-analyzed soil profile data. The object has two components:
#'   - `site` data: Profile-level attributes (e.g., soil taxonomy, coordinates)
#'   - `horizons` data: Horizon-level laboratory analyses (e.g., pH, texture, nutrients)
#'   Use `length(x)` to get the number of profiles, `site(x)` for site data,
#'   and `horizons(x)` for horizon (layer) data.
#'
#' @seealso
#'   - `load_labtaxa()` to load previously cached data (much faster)
#'   - `load_labmorph()` to load morphologic data from cache
#'   - `cache_labtaxa()` to manually save results to cache
#'   - `ldm_data_dir()` to find the data cache directory
#'   - `soilDB::fetchLDM()` for lower-level database access
#'   - `aqp::SoilProfileCollection` for manipulating profile data
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Download and cache KSSL data (typically takes 10-30 minutes on first run)
#' ldm <- get_LDM_snapshot()
#'
#' # Check what you downloaded
#' length(ldm)  # Number of profiles
#' head(site(ldm))  # Site-level attributes
#'
#' # Subsequent calls are fast (load from cache)
#' ldm <- get_LDM_snapshot()  # <1 second!
#'
#' # Access profile data
#' profiles <- site(ldm)
#' horizons <- horizons(ldm)
#'
#' # Subset to specific soil orders
#' mollisols <- subset(ldm, SSL_taxorder == "mollisols")
#' cat(sprintf("Found %d mollisols\\n", length(mollisols)))
#'
#' # Force fresh download (skip cache)
#' ldm_fresh <- get_LDM_snapshot(cache = FALSE, verbose = TRUE)
#'
#' # Use with soilDB for custom database queries
#' ldm <- get_LDM_snapshot()
#' horizons_data <- horizons(ldm)
#' mean_clay <- mean(horizons_data$clay_r, na.rm = TRUE)
#' cat(sprintf("Mean clay content: %.1f%%\\n", mean_clay))
#' }
get_LDM_snapshot <- function(...,
                             cache = TRUE,
                             verbose = TRUE,
                             keep_zip = FALSE,
                             dlname = "ncss_labdatagpkg.zip",
                             dbname = "ncss_labdata.gpkg",
                             cachename = "cached-LDM-SPC.rds",
                             companiondlname = "ncss_morphologic.zip",
                             companiondbname = "ncss_morphologic.sqlite",
                             companioncachename = "cached-morph-SPC.rds",
                             dirname = tools::R_user_dir(package = "labtaxa"),
                             port = 4567L,
                             timeout = 1e5,
                             baseurl = ldm_db_download_url()) {

  cp <- file.path(dirname, cachename)
  fp <- file.path(dirname, dbname)
  mp <- file.path(dirname, companiondbname)

  if (cache && file.exists(cp)) {
    return(load_labtaxa(cachename, dirname))
  }

  stopifnot(requireNamespace("RSQLite"))

  if (!file.exists(fp) || !cache) {
    if (verbose) message("Downloading KSSL Lab Data Mart snapshot...")
    tryCatch({
      .get_ldm_snapshot(
        port = port,
        dirname = dirname,
        dlname = dlname,
        morphdlname = companiondlname,
        companiondbname = companiondbname,
        baseurl = baseurl,
        timeout = timeout,
        keep_zip = keep_zip,
        verbose = verbose
      )
    }, error = function(e) {
      stop(sprintf(
        "Failed to download snapshot: %s\nPlease check your internet connection and try again.",
        conditionMessage(e)
      ), call. = FALSE)
    })
  } else {
    if (verbose) message(sprintf("Using cached database: %s", fp))
  }

  # Patch databases with error handling
  if (verbose) message("Patching Lab Data Mart database...")
  tryCatch({
    .patch_ldm_snapshot(fp)
  }, error = function(e) {
    warning(sprintf(
      "Error patching LDM database: %s\nDatabase may not be fully compatible.",
      conditionMessage(e)
    ), call. = FALSE)
  })

  if (file.exists(mp)) {
    if (verbose) message(sprintf("Validating morphologic database: %s", mp))
    # Quick validation: try to list tables
    validation_ok <- tryCatch({
      con <- RSQLite::dbConnect(RSQLite::SQLite(), mp)
      tbls <- RSQLite::dbListTables(con)
      RSQLite::dbDisconnect(con)
      if (verbose) message(sprintf("Database contains %d tables", length(tbls)))
      length(tbls) > 0
    }, error = function(e) {
      if (verbose) warning(sprintf("Failed to validate morphologic database: %s", conditionMessage(e)))
      FALSE
    })

    if (validation_ok) {
      if (verbose) message("Patching morphologic database...")
      tryCatch({
        .patch_morph_snapshot(mp)
      }, error = function(e) {
        warning(sprintf(
          "Error patching morphologic database: %s\nMorphologic data may not be available.",
          conditionMessage(e)
        ), call. = FALSE)
      })
    } else if (verbose) {
      message("Skipping morphologic database patching - validation failed")
    }
  } else {
    if (verbose) message(sprintf("Morphologic database not found: %s", mp))
  }

  # Load LDM data with error handling
  if (verbose) message(sprintf("Loading Lab Data Mart data from %s (%.2f MB)...", fp, file.size(fp) / 1024 / 1024))
  res <- tryCatch({
    soilDB::fetchLDM(dsn = fp, chunk.size = 1e7, ...)
  }, error = function(e) {
    stop(sprintf(
      "Failed to load Lab Data Mart data: %s\nPlease ensure the database is valid.",
      conditionMessage(e)
    ), call. = FALSE)
  })

  if (verbose) message(sprintf("Loaded %d soil profiles", length(res)))

  # Load morphologic data with graceful fallback
  if (file.exists(mp)) {
    if (verbose) message(sprintf("Loading morphologic data from %s (%.2f MB)...", mp, file.size(mp) / 1024 / 1024))
    su <- getOption("soilDB.NASIS.skip_uncode")
    options(soilDB.NASIS.skip_uncode = TRUE)
    morph <- tryCatch({
      soilDB::fetchNASIS(dsn = mp, SS = FALSE)
    }, error = function(e) {
      warning(sprintf(
        "Failed to load morphologic data: %s\nContinuing with LDM data only.",
        conditionMessage(e)
      ), call. = FALSE)
      NULL
    }, finally = {
      options(soilDB.NASIS.skip_uncode = su)
    })
  } else {
    morph <- NULL
    if (verbose) message("Morphologic database not found, continuing with LDM data only")
  }

  # Cache results
  if (cache) {
    if (verbose) message("Caching results...")
    cache_labtaxa(res, filename = cachename, destdir = dirname)
    if (!is.null(morph)) {
      cache_labtaxa(morph, filename = companioncachename, destdir = dirname)
    }
  }

  invisible(res)
}

#' Get KSSL Lab Data Mart Download URL
#'
#' Returns the official USDA-NRCS Kellogg Soil Survey Laboratory
#' 'Lab Data Mart' download page URL.
#'
#' @details
#' This is the official USDA-NRCS webpage from which KSSL database
#' snapshots are downloaded. The page uses JavaScript and requires
#' browser automation via RSelenium to access.
#'
#' @return Character string containing the URL
#' @export
#' @rdname get_LDM_snapshot
#'
#' @examples
#' url <- ldm_db_download_url()
#' cat(sprintf("Download from: %s\\n", url))
ldm_db_download_url <- function() {
 "https://ncsslabdatamart.sc.egov.usda.gov/database_download.aspx"
}

#' Get labtaxa Data Cache Directory
#'
#' Returns the directory where labtaxa caches downloaded data and
#' processed results. Creates the directory if it doesn't exist.
#'
#' @details
#' The cache directory is located at:
#' - Linux/Mac: `~/.local/share/R/labtaxa`
#' - Windows: `C:\Users\USERNAME\AppData\Local\R\labtaxa`
#'
#' This follows the XDG Base Directory specification via `tools::R_user_dir()`.
#'
#' @return Character string containing the absolute path to the cache directory
#'
#' @seealso
#'   - `get_LDM_snapshot()` which downloads data to this directory
#'   - `load_labtaxa()` which loads cached data from this directory
#'   - `cache_labtaxa()` to manually save data to this directory
#'
#' @export
#' @rdname get_LDM_snapshot
#'
#' @examples
#' cache_dir <- ldm_data_dir()
#' cat(sprintf("Data cached at: %s\\n", cache_dir))
#'
#' # Check what's cached
#' files <- list.files(cache_dir)
#' cat(sprintf("Cached files:\\n%s\\n", paste(files, collapse = "\\n")))
ldm_data_dir <- function() {
  d <- tools::R_user_dir(package = "labtaxa")
  if (!dir.exists(d))
    dir.create(d, recursive = TRUE)
  d
}

#' Download File with Retry Logic
#'
#' Attempts to download a file with automatic retry on failure.
#' Provides informative error messages and exponential backoff.
#'
#' @param url URL to download from
#' @param destfile Path where file should be saved
#' @param max_attempts Maximum number of download attempts (default: 3)
#' @param verbose Print status messages
#' @return Invisibly returns TRUE on success, raises error on failure
#' @keywords internal
#' @noRd
.download_with_retry <- function(url, destfile, max_attempts = 3, verbose = TRUE) {
  for (attempt in 1:max_attempts) {
    result <- tryCatch({
      if (verbose && attempt > 1) {
        message(sprintf("Download attempt %d/%d for %s", attempt, max_attempts, basename(destfile)))
      }
      utils::download.file(url, destfile, mode = "wb", quiet = !verbose)
      TRUE
    }, error = function(e) {
      if (verbose) {
        warning(sprintf(
          "Download attempt %d failed: %s",
          attempt,
          conditionMessage(e)
        ), call. = FALSE)
      }
      FALSE
    })

    if (result) {
      if (verbose) {
        message(sprintf("Successfully downloaded %s", basename(destfile)))
      }
      return(invisible(TRUE))
    }

    if (attempt < max_attempts) {
      wait_time <- 2^attempt
      if (verbose) {
        message(sprintf("Retrying in %d seconds...", wait_time))
      }
      Sys.sleep(wait_time)
    }
  }

  stop(
    sprintf(
      "Failed to download %s after %d attempts. Please check the URL and your internet connection.",
      url,
      max_attempts
    ),
    call. = FALSE
  )
}

#' Verify File Checksum
#'
#' Validates that a file's SHA256 checksum matches expected value.
#'
#' @param filepath Path to file to verify
#' @param expected_checksum Expected SHA256 hexadecimal string
#' @param verbose Print status messages
#' @return TRUE if checksum matches, FALSE otherwise
#' @keywords internal
#' @noRd
.verify_checksum <- function(filepath, expected_checksum, verbose = TRUE) {
  if (!file.exists(filepath)) {
    if (verbose) {
      warning(sprintf("File not found for checksum verification: %s", filepath), call. = FALSE)
    }
    return(FALSE)
  }

  actual_checksum <- .calculate_checksum(filepath)

  if (actual_checksum == expected_checksum) {
    if (verbose) {
      message(sprintf("Checksum verified for %s", basename(filepath)))
    }
    return(TRUE)
  } else {
    if (verbose) {
      warning(sprintf(
        "Checksum mismatch for %s\n  Expected: %s\n  Actual: %s",
        filepath,
        expected_checksum,
        actual_checksum
      ), call. = FALSE)
    }
    return(FALSE)
  }
}

#' Calculate SHA256 Checksum of a File
#'
#' Computes the SHA256 cryptographic hash of a file for integrity verification.
#'
#' @param filepath Path to the file to hash
#' @return Character string containing the hexadecimal SHA256 digest
#' @keywords internal
#' @noRd
.calculate_checksum <- function(filepath) {
  if (!file.exists(filepath)) {
    stop("File not found: ", filepath, call. = FALSE)
  }
  digest::digest(file = filepath, algo = "sha256")
}

#' Write Snapshot Metadata JSON
#'
#' Creates a JSON metadata file documenting the downloaded database snapshot,
#' including checksums, timestamps, and version information for reproducibility.
#'
#' @param dirname Directory where metadata will be written
#' @param data_files Character vector of file paths to hash
#' @param metadata_file Name of output metadata file
#'
#' @details
#' The metadata JSON contains:
#' - `snapshot_date`: Date of data snapshot
#' - `download_timestamp`: When the data was downloaded
#' - `r_version`: R version used
#' - `package_version`: labtaxa package version
#' - `checksums`: SHA256 hash and file size for each data file
#'
#' @return Invisibly returns the metadata list (for testing)
#' @keywords internal
#' @noRd
.write_snapshot_metadata <- function(dirname,
                                     data_files,
                                     metadata_file = "snapshot-metadata.json") {
  # Build metadata structure
  metadata <- list(
    snapshot_date = as.character(Sys.Date()),
    download_timestamp = as.character(Sys.time()),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    package_version = as.character(utils::packageVersion("labtaxa")),
    checksums = lapply(data_files, function(f) {
      if (file.exists(f)) {
        list(
          file = basename(f),
          sha256 = .calculate_checksum(f),
          size_bytes = file.size(f)
        )
      } else {
        list(
          file = basename(f),
          sha256 = "NOT_FOUND",
          size_bytes = NA_integer_
        )
      }
    })
  )

  # Write to JSON file
  metadata_path <- file.path(dirname, metadata_file)
  jsonlite::write_json(
    metadata,
    path = metadata_path,
    auto_unbox = TRUE,
    pretty = TRUE
  )

  message(sprintf("Metadata written to: %s", metadata_path))
  invisible(metadata)
}

.patch_ldm_snapshot <- function(dsn, ...) {
  con <- RSQLite::dbConnect(RSQLite::SQLite(), dsn, ...)
  tbls <- RSQLite::dbListTables(con)
  new_view_names <- gsub("_vw$", "", tbls)
  lapply(tbls, function(i) {
    if (grepl("_vw$", tbls[i])) {
      try(RSQLite::dbRemoveTable(con, new_view_names[i]))
      if (RSQLite::dbWriteTable(con, new_view_names[i], RSQLite::dbReadTable(con, tbls[i]))) {
        RSQLite::dbRemoveTable(con, tbls[i])
      }
    }
  })
}

.patch_morph_snapshot <- function(dsn, ...) {

  # patch companion db
  con <- soilDB::NASIS(dsn = dsn)

  ## add missing columns
  # ecologicalsitehistory: recwlupdated
  # site: stateareaiidref, countyareaiidref, mlraareaiidref

  seh <- DBI::dbGetQuery(con, "SELECT * FROM siteecositehistory")
  if (is.null(seh$recwlupdated))
    seh$recwlupdated <- as.POSIXct(0)
  RSQLite::dbWriteTable(con, "siteecositehistory", seh, overwrite = TRUE)

  sit <- DBI::dbGetQuery(con, "SELECT * FROM site")
  if (is.null(sit$stateareaiidref))
    sit$stateareaiidref <- integer(1)
  if (is.null(sit$countyareaiidref))
    sit$countyareaiidref <- integer(1)
  if (is.null(sit$mlraareaiidref))
    sit$mlraareaiidref <- integer(1)
  RSQLite::dbWriteTable(con, "site", sit, overwrite = TRUE)

  ## add missing lookup tables
  tables <- c("othvegclass", "geomorfeattype", "geomorfeat")
  for (tbl in tables) {
    if (!tbl %in% RSQLite::dbListTables(con)) {
      x <- readRDS(file.path("inst", "extdata", paste0(tbl, ".rds")))
      RSQLite::dbWriteTable(con, tbl, x, overwrite = TRUE)
    }
  }

  DBI::dbDisconnect(con)
}

#' @importFrom utils download.file unzip
#' @importFrom RSelenium makeFirefoxProfile rsDriver
.get_ldm_snapshot <- function(dirname = ldm_data_dir(),
                              dlname = "ncss_labdatagpkg.zip",
                              morphdlname = "ncss_morphologic.zip",
                              companiondbname = "ncss_morphologic.sqlite",
                              keep_zip = FALSE,
                              overwrite = FALSE,
                              port = 4567L,
                              baseurl = ldm_db_download_url(),
                              timeout = 1e5,
                              default_dir = "~/Downloads",
                              verbose = TRUE) {

  stopifnot(requireNamespace("RSelenium"))

  target_dir <- dirname
  if (!dir.exists(target_dir)) {
    if (verbose) message(sprintf("Creating data directory: %s", target_dir))
    dir.create(target_dir, recursive = TRUE)
  }

  # Create Firefox profile for headless download with improved settings
  fprof <- RSelenium::makeFirefoxProfile(list(
    browser.download.dir = normalizePath(target_dir),
    browser.download.folderList = 2,  # Use custom folder
    browser.helperApps.neverAsk.saveToDisk = "application/zip,application/octet-stream",
    browser.download.manager.showAlertOnComplete = FALSE,
    browser.download.manager.showWhenStarting = FALSE,
    pdfjs.disabled = TRUE,
    plugin.scan.plg.state = 0
  ))
  eCaps <- list(
    firefox_profile = fprof$firefox_profile,
    "moz:firefoxOptions" = list(args = list('--headless'))
  )

  # Initialize Selenium with informative error handling
  if (verbose) message("Starting Selenium WebDriver (Firefox)...")
  rD <- tryCatch({
    RSelenium::rsDriver(
      browser = "firefox",
      chromever = NULL,
      phantomver = NULL,
      extraCapabilities = eCaps,
      port = as.integer(port)
    )
  }, error = function(e) {
    stop(
      sprintf(
        "Failed to start Selenium WebDriver. This typically means:\n",
        "1. Firefox is not installed (install with: apt-get install firefox)\n",
        "2. geckodriver is not available\n",
        "3. Port %d is already in use\n",
        "Technical error: %s",
        port,
        conditionMessage(e)
      ),
      call. = FALSE
    )
  })

  remDr <- rD[["client"]]
  remDr$open()
  on.exit(try(remDr$close()))

  orig_file_name <- list.files(target_dir, dlname)
  default_dir <- path.expand(default_dir)
  orig_default_file_name <- if (dir.exists(default_dir)) list.files(default_dir, dlname) else character(0)

  if (overwrite || !dlname %in% orig_file_name) {

    remDr$navigate(baseurl)
    if (verbose) message(sprintf("Navigated to %s", baseurl))

    # Wait for page to load before clicking elements
    Sys.sleep(2)

    # Click the tab to access the "spatial" lab data downloads
    tryCatch({
      if (verbose) message("Clicking spatial data tab...")
      tabElem <- remDr$findElement("name", "tabularSpatial")
      tabElem$clickElement()
      Sys.sleep(1)
    }, error = function(e) {
      if (verbose) warning(sprintf("Could not find/click spatial tab: %s", conditionMessage(e)))
    })

    # Click the download button
    tryCatch({
      if (verbose) message("Clicking GeoPackage download button...")
      webElem <- remDr$findElement("id", "btnDownloadSpatialGeoPackageFile")
      webElem$clickElement()
      Sys.sleep(2)
    }, error = function(e) {
      if (verbose) warning(sprintf("Could not find/click download button: %s", conditionMessage(e)))
    })

    if (verbose) message("Download initiated")

    ncycle <- 0

    # Wait for downloaded file to appear in browser download directory
    # Firefox creates .part file during download, .zip file stays 0 bytes until complete
    if (verbose) message("Waiting for LDM database download to complete...")
    download_complete <- FALSE
    while (!download_complete) {
      file_name <- list.files(target_dir, dlname, full.names = TRUE)
      dfile_name <- list.files(default_dir, dlname, full.names = TRUE)

      # Check for .part files (actual download in progress)
      part_files_target <- list.files(target_dir, "\\.part$", full.names = TRUE)
      part_files_default <- list.files(default_dir, "\\.part$", full.names = TRUE)

      # Determine current download size from .part files or final files
      target_size <- 0
      default_size <- 0

      if (length(part_files_target) > 0) {
        target_size <- file.size(part_files_target[1])
      } else if (length(file_name) > 0) {
        target_size <- file.size(file_name[1])
      }

      if (length(part_files_default) > 0) {
        default_size <- file.size(part_files_default[1])
      } else if (length(dfile_name) > 0) {
        default_size <- file.size(dfile_name[1])
      }

      current_size <- max(target_size, default_size)

      # Download complete when .part files disappear and final files have content
      if (length(part_files_target) == 0 && length(part_files_default) == 0 &&
          (length(file_name) > 0 || length(dfile_name) > 0) &&
          current_size > 0) {
        if (verbose) message(sprintf("Download complete: %.2f MB", current_size / 1024 / 1024))
        download_complete <- TRUE
        break
      }

      if (ncycle %% 10 == 0 && verbose) {
        message(sprintf("Elapsed time %d seconds - current size: %.2f MB", ncycle, current_size / 1024 / 1024))
      }

      Sys.sleep(1)
      ncycle <- ncycle + 1
      if (ncycle > timeout) {
        if (verbose) warning(sprintf("Download timeout after %d seconds - file may be incomplete", timeout))
        break
      }
    }
  }

  # Move any files that were downloaded to default_dir to target_dir
  dfile_name <- list.files(default_dir, dlname, full.names = TRUE)
  new_dfile_name <- dfile_name[!dfile_name %in% file.path(default_dir, orig_default_file_name)]
  if (length(new_dfile_name) > 0) {
    if (verbose) message(sprintf("Found file(s) in %s:", default_dir))
    valid_files <- character()
    for (f in new_dfile_name) {
      f_size <- file.size(f)
      if (verbose) message(sprintf("  %s: %.2f MB", basename(f), f_size / 1024 / 1024))
      if (f_size > 0) {
        valid_files <- c(valid_files, f)
      }
    }

    if (length(valid_files) > 0) {
      if (verbose) message(sprintf("Moving %d file(s) to target directory", length(valid_files)))
      file.copy(valid_files, target_dir)
      file.remove(valid_files)
    } else {
      if (verbose) warning("Found files in default directory but all are 0 bytes - download may have failed")
    }
  }

  # Validate that LDM file was actually downloaded with reasonable size
  ldm_file <- file.path(target_dir, dlname)
  if (!file.exists(ldm_file) || file.size(ldm_file) < 1000000) {
    # File is missing or suspiciously small (< 1 MB)
    warning(
      sprintf(
        "Warning: LDM database file %s is missing or suspiciously small (%s bytes).\n",
        dlname,
        if (file.exists(ldm_file)) file.size(ldm_file) else "0"
      ),
      "The RSelenium browser download may have failed.\n",
      "This can happen in headless/Docker environments.\n",
      "Continuing with available data, but results may be incomplete.",
      call. = FALSE
    )
  }

  # Download companion morphologic database with retry logic
  dcompanion <- file.path(target_dir, morphdlname)
  if (nchar(dcompanion) > 0 && !file.exists(dcompanion)) {
    if (verbose) message("Downloading companion morphologic database...")
    oldtimeout <- getOption("timeout")
    # Set very long timeout for large file downloads (135+ MB)
    # Handles slow/unreliable network connections
    options(timeout = 3600)  # 1 hour timeout per attempt, with 5 retries = 5 hours max
    tryCatch({
      .download_with_retry(
        "https://new.cloudvault.usda.gov/index.php/s/tdnrQzzJ7ty39gs/download",
        destfile = dcompanion,
        max_attempts = 5,
        verbose = verbose
      )
    }, error = function(e) {
      warning(
        sprintf(
          "Could not download companion morphologic database. %s\n",
          "You can continue with LDM data only.",
          conditionMessage(e)
        ),
        call. = FALSE
      )
    }, finally = {
      options(timeout = oldtimeout)
    })
  }

  zf <- list.files(target_dir, "zip$", full.names = TRUE)

  # Extract zip files with validation
  for (z in zf) {
    z_size <- file.size(z)
    if (verbose) message(sprintf("Extracting %s (%.2f MB)...", basename(z), z_size / 1024 / 1024))

    if (z_size < 100000) {
      warning(sprintf("Zip file %s is suspiciously small (%.2f MB) - may be invalid", basename(z), z_size / 1024 / 1024), call. = FALSE)
    }

    tryCatch({
      files_extracted <- utils::unzip(z, exdir = target_dir, list = FALSE)
      if (length(files_extracted) > 0) {
        if (verbose) message(sprintf("Successfully extracted %d file(s) from %s", length(files_extracted), basename(z)))
      } else {
        warning(sprintf("No files extracted from %s - zip may be empty or invalid", basename(z)), call. = FALSE)
      }
    }, error = function(e) {
      warning(sprintf(
        "Failed to extract %s: %s",
        basename(z),
        conditionMessage(e)
      ), call. = FALSE)
    })
  }

  # TODO: generalize this for a future standardized morphologic database internal filename
  oldfn <- file.path(target_dir, "NASIS_Morphological_09142021.sqlite")
  if (file.exists(oldfn)) {
    if (verbose) message(sprintf("Renaming %s to %s", basename(oldfn), companiondbname))
    file.rename(oldfn, file.path(target_dir, companiondbname))
  }

  # Validate that expected database files exist after extraction
  expected_files <- c(
    file.path(target_dir, gsub("\\.zip$", ".gpkg", dlname)),
    file.path(target_dir, companiondbname)
  )
  for (f in expected_files) {
    if (!file.exists(f)) {
      if (verbose) warning(sprintf("Expected file not found after extraction: %s", basename(f)))
    } else if (verbose) {
      message(sprintf("Confirmed: %s (%.2f MB)", basename(f), file.size(f) / 1024 / 1024))
    }
  }

  if (isFALSE(keep_zip)) {
    file.remove(zf)
  }

  # Generate metadata with checksums for reproducibility
  data_files <- c(
    file.path(target_dir, gsub("\\.zip$", ".gpkg", dlname)),
    file.path(target_dir, gsub("\\.zip$", ".gpkg", morphdlname))
  )
  .write_snapshot_metadata(target_dir, data_files)

  # close rselenium (non-blocking)
  if (verbose) message("Closing RSelenium driver...")
  tryCatch({
    remDr$close()
    if (verbose) message("RSelenium driver closed")
  }, error = function(e) {
    if (verbose) warning(sprintf("RSelenium close failed: %s", conditionMessage(e)))
  })
}
