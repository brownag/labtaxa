#' Get 'Lab Data Mart' 'SQLite' Snapshot
#'
#' Downloads the SQLite database snapshot from
#' `"https://ncsslabdatamart.sc.egov.usda.gov/database_download.aspx"`. Uses RSelenium to navigate
#' the webpage and download the file, which is cached in a `tools::R_user_dir(package="labtaxa")`.
#' Laboratory pedon data are retrieved from the local SQLite file using `soilDB::fetchLDM()` and
#' cached as RDS. Companion morphologic data are retrieved using `soilDB::fetchNASIS()` and cached
#' as RDS.
#'
#' @param ... Arguments passed to `soilDB::fetchLDM()`
#' @param cache Default: `TRUE`; store result `SoilProfileCollection` object in an RDS file in the
#'   `labtaxa` user data directory and load it rather than rebuilding on subsequent calls?
#' @param verbose Default: `TRUE`; print informative messages about download progress and operations?
#' @param keep_zip Default: `FALSE`; retain `dlname` and `companiondlname` files after extraction?
#' @param dlname Default: `"ncss_labdatagpkg.zip"`
#' @param dbname Default: `"ncss_labdata.gpkg"`
#' @param cachename File name to use for cache RDS file containing SoilProfileCollection of LDM
#'   data. Default: `"cached-LDM-SPC.rds",`
#' @param companiondlname File name to use for companion morphologic database. Default:
#'   `"ncss_companion.zip"`
#' @param companiondbname File name to use for companion morphologic database. Default:
#'   `"ncss_companion.sqlite"`
#' @param companioncachename File name to use for cache RDS file containing SoilProfileCollection of
#'   NASIS morphologic data. Default: `"cached-morph-SPC.rds",`
#' @param dirname Data cache diretory for `labtaxa` package. Default: `tools::R_user_dir(package =
#'   "labtaxa")`.
#' @param default_dir Default directory where RSelenium Gecko (Firefox) downloads files. Default:
#'   `"~/Downloads"`. Customize as needed.
#' @param port Default: `4567L`
#' @param timeout Default: `1e5` seconds
#' @param baseurl Default: `"https://ncsslabdatamart.sc.egov.usda.gov/database_download.aspx"`
#' @importFrom soilDB fetchLDM
#' @importFrom aqp site horizons
#' @importClassesFrom aqp SoilProfileCollection
#' @return A SoilProfileCollection
#' @export
#'
#' @examples
#' \dontrun{
#' get_LDM_snapshot()
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
                             default_dir = "~/Downloads",
                             port = 4567L,
                             timeout = 1e5,
                             baseurl = ldm_db_download_url()) {

  cp <- file.path(dirname, cachename)
  fp <- file.path(dirname, dbname)
  mp <- file.path(dirname, companiondbname)

  if (cache && file.exists(cp)) {
    load_labtaxa(cachename, dirname)
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
        default_dir = default_dir,
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
    if (verbose) message("Patching morphologic database...")
    tryCatch({
      .patch_morph_snapshot(mp)
    }, error = function(e) {
      warning(sprintf(
        "Error patching morphologic database: %s\nMorphologic data may not be available.",
        conditionMessage(e)
      ), call. = FALSE)
    })
  }

  # Load LDM data with error handling
  if (verbose) message("Loading Lab Data Mart data...")
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
    if (verbose) message("Loading morphologic data...")
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

#' @export
#' @rdname get_LDM_snapshot
ldm_db_download_url <- function() {
 "https://ncsslabdatamart.sc.egov.usda.gov/database_download.aspx"
}

#' @export
#' @rdname get_LDM_snapshot
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
                              keep_zip = FALSE,
                              overwrite = FALSE,
                              default_dir = "~/Downloads",
                              port = 4567L,
                              baseurl = ldm_db_download_url(),
                              timeout = 1e5,
                              verbose = TRUE) {

  stopifnot(requireNamespace("RSelenium"))

  target_dir <- dirname
  if (!dir.exists(target_dir)) {
    if (verbose) message(sprintf("Creating data directory: %s", target_dir))
    dir.create(target_dir, recursive = TRUE)
  }

  if (!dir.exists(default_dir)) {
    if (verbose) message(sprintf("Creating downloads directory: %s", default_dir))
    dir.create(default_dir, recursive = TRUE)
  }

  # Create Firefox profile for headless download
  fprof <- RSelenium::makeFirefoxProfile(list(
    browser.download.dir = normalizePath(target_dir),
    browser.download.folderList = 2
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
  orig_dfile_name <- list.files(default_dir, dlname)

  if (overwrite ||
      (!dlname %in% orig_file_name && !dlname %in% orig_dfile_name)) {

    remDr$navigate(baseurl)

        # need to click the tab to access the "spatial" lab data downloads
    tabElem <- remDr$findElement("name" , "tabularSpatial")
    tabElem$clickElement()
    webElem <- remDr$findElement("id", "btnDownloadSpatialGeoPackageFile")
    webElem$clickElement()

    ncycle <- 0
    file_name <- dfile_name <- character()

    # wait for downloaded file to appear in browser download directory
    while (length(file_name) <= length(orig_file_name) &
           length(dfile_name) <= length(orig_dfile_name)) {
      file_name <- list.files(target_dir, dlname, full.names = TRUE)
      dfile_name <- list.files(default_dir, dlname, full.names = TRUE)
      if (length(dfile_name) > 0 || length(file_name) > 0) {
        if ((!is.na(dfile_name[1]) && file.size(dfile_name[1]) > 0)
            || (!is.na(file_name[1]) && file.size(file_name[1]) > 0)) {
          break
        } else {
          if (ncycle %% 60 == 0) {
            print(ncycle)
          }
        }
      }
      Sys.sleep(1)
      ncycle <- ncycle + 1
      # print(ncycle)
      if (ncycle > timeout) {
        print("Timed out")
        break
      }
    }
  } else {
     dfile_name <- orig_dfile_name
  }

  # allow download to default directory, just move to target first
  new_dfile_name <- dfile_name[!dfile_name %in% orig_dfile_name]
  if (length(new_dfile_name) > 0) {
    file.copy(new_dfile_name, target_dir)
    file.remove(new_dfile_name)
  }

  # Download companion morphologic database with retry logic
  dcompanion <- file.path(target_dir, morphdlname)
  if (nchar(dcompanion) > 0 && !file.exists(dcompanion)) {
    if (verbose) message("Downloading companion morphologic database...")
    oldtimeout <- getOption("timeout")
    options(timeout = 1e5)
    tryCatch({
      .download_with_retry(
        "https://new.cloudvault.usda.gov/index.php/s/tdnrQzzJ7ty39gs/download",
        destfile = dcompanion,
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
  sapply(zf, function(z) utils::unzip(z, exdir = target_dir))

  # TODO: generalize this for a future standardized morphologic database internal filename
  oldfn <- file.path(target_dir, "NASIS_Morphological_09142021.sqlite")
  if (file.exists(oldfn)) {
    file.rename(oldfn, file.path(target_dir, morphdlname))
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

  # close rselenium
  try(remDr$close())
}
