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
    .get_ldm_snapshot(
      port = port,
      dirname = dirname,
      dlname = dlname,
      default_dir = default_dir,
      baseurl = baseurl,
      timeout = timeout,
      companion = companiondlname,
      keep_zip = keep_zip
    )
  }
  .patch_ldm_snapshot(fp)
  .patch_morph_snapshot(mp)

  # create LDM SPC
  res <- soilDB::fetchLDM(dsn = fp, chunk.size = 1e7, ...)

  # create morphologic SPC
  su <- getOption("soilDB.NASIS.skip_uncode")
  options(soilDB.NASIS.skip_uncode = TRUE)
  morph <- soilDB::fetchNASIS(dsn = mp, SS = FALSE)
  options(soilDB.NASIS.skip_uncode = su)

  # TODO: process+join in companion DB
  if (cache) {
    cache_labtaxa(res, filename = cachename, destdir = dirname)
    cache_labtaxa(morph, filename = companioncachename, destdir = dirname)
  }
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
                              keep_zip = FALSE,
                              overwrite = FALSE,
                              default_dir = "~/Downloads",
                              port = 4567L,
                              baseurl = ldm_db_download_url(),
                              timeout = 1e5,
                              companion = "ncss_morphologic.zip") {

  stopifnot(requireNamespace("RSelenium"))

  target_dir <- dirname
  if (!dir.exists(target_dir)) {
    dir.create(target_dir, recursive = TRUE)
  }

  if (!dir.exists(default_dir)) {
    dir.create(default_dir, recursive = TRUE)
  }

  fprof <- RSelenium::makeFirefoxProfile(list(
    browser.download.dir = normalizePath(target_dir),
    browser.download.folderList = 2
  ))
  eCaps <- list(
    firefox_profile = fprof$firefox_profile,
    "moz:firefoxOptions" = list(args = list('--headless'))
  )
  res <- try({
    rD <- RSelenium::rsDriver(
      browser = "firefox",
      chromever = NULL,
      phantomver = NULL,
      extraCapabilities = eCaps,
      port = as.integer(port)
    )
  })
  stopifnot(!inherits(res, 'try-error'))

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

  # TODO: should this also be done via RSelenium?
  # if these files remain on cloudvault/direct download download.file() is easier
  dcompanion <- file.path(target_dir, companion)
  if (nchar(dcompanion) > 0 && !file.exists(dcompanion)) {
    # download companion db
    oldtimeout <- getOption("timeout")
    options(timeout = 1e5)
    utils::download.file(
      "https://new.cloudvault.usda.gov/index.php/s/tdnrQzzJ7ty39gs/download",
      destfile = dcompanion,
      mode = "wb"
    )
    options(timeout = oldtimeout)
  }

  zf <- list.files(target_dir, "zip$", full.names = TRUE)
  sapply(zf, function(z) utils::unzip(z, exdir = target_dir))

  # TODO: generalize this for a future standardized morphologic database internal filename
  oldfn <- file.path(target_dir, "NASIS_Morphological_09142021.sqlite")
  if (file.exists(oldfn)) {
    file.rename(oldfn, file.path(target_dir, companion))
  }

  if (isFALSE(keep_zip)) {
    file.remove(zf)
  }

  # close rselenium
  try(remDr$close())
}
