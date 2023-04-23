#' Get 'Lab Data Mart' 'SQLite' Snapshot
#'
#' Downloads the SQLite database snapshot from `"https://ncsslabdatamart.sc.egov.usda.gov/database_download.aspx"`. Uses RSelenium to navigate the webpage and download the file, which is cached in a `tools::R_user_dir(package="labtaxa")`. Lboratory pedon data are retrieved from the local SQLite file using `soilDB::fetchLDM()`.
#'
#' @param ... Arguments passed to `soilDB::fetchLDM()`
#' @param cache Default: `TRUE`; store result `SoilProfileCollection` object in an RDS file in the `labtaxa` user data directory and load it rather than rebuilding on subsequent calls?
#' @param dlname Default: `"ncss_labdatagpkg.zip"`
#' @param dbname Default: `"ncss_labdata.gpkg"`
#' @param dirname Data cache diretory for `labtaxa` package. Default: `tools::R_user_dir(package = "labtaxa")`.
#' @param default_dir Default directory where RSelenium Gecko (Firefox) downloads files. Default: `"~/Downloads"`. Customize as needed.
#' @param cachename File name to use for cache RDS file containing SoilProfileCollection of combined LDM snapshots. Default: `"cached-LDM-SPC.rds",`
#' @param companion File name to use for companion morphologic database. Default: `"LDMCompanion.zip"`
#' @param port Default: `4567L`
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
                             companion = "LDMCompanion.gpkg",
                             dlname = "ncss_labdatagpkg.zip",
                             dbname = "ncss_labdata.gpkg",
                             cachename = "cached-LDM-SPC.rds",
                             dirname = tools::R_user_dir(package = "labtaxa"),
                             default_dir = "~/Downloads",
                             port = 4567L,
                             baseurl = ldm_db_download_url()) {

  cp <- file.path(dirname, cachename)
  fp <- file.path(dirname, dbname)

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
      companion = companion
    )
    .patch_ldm_snapshot(fp)
  }

  res <- soilDB::fetchLDM(dsn = fp, chunk.size = 1e7, ...)
  # TODO: process+join in companion DB
  if (cache) {
    cache_labtaxa(res, filename = cachename, destdir = dirname)
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
      if (RSQLite::dbWriteTable(con, new_view_names[i],
                                RSQLite::dbReadTable(con, tbls[i]))) {
        RSQLite::dbRemoveTable(con, tbls[i])
      }
    }
  })
}

#' @importFrom utils download.file unzip
#' @importFrom RSelenium makeFirefoxProfile rsDriver
.get_ldm_snapshot <- function(dirname = ldm_data_dir(),
                              dlname = "ncss_labdatagpkg.zip",
                              default_dir = "~/Downloads",
                              port = 4567L,
                              baseurl = ldm_db_download_url(),
                              companion = "LDMCompanion.gpkg") {

  stopifnot(requireNamespace("RSelenium"))
  target_dir <- dirname
  if (!dir.exists(target_dir)) {
    dir.create(target_dir, recursive = TRUE)
  }

  if (!dir.exists(default_dir)) {
    dir.create(default_dir, recursive = TRUE)
  }

  fprof <- RSelenium::makeFirefoxProfile(list(browser.download.dir = normalizePath(target_dir),
                                              browser.download.folderList = 2))
  eCaps <- list(
    firefox_profile = fprof$firefox_profile,
    "moz:firefoxOptions" = list(args = list('--headless'))
  )
  res <- try({rD <- RSelenium::rsDriver(browser = "firefox",
                                        chromever = NULL,
                                        extraCapabilities = eCaps,
                                        port = as.integer(port))})
  stopifnot(!inherits(res, 'try-error'))

  remDr <- rD[["client"]]
  remDr$open()
  on.exit(try(remDr$close()))

  remDr$navigate(baseurl)
  # need to click the tab to access the "spatial" lab data downloads
  tabElem <- remDr$findElement("name" , "tabularSpatial")
  tabElem$clickElement()
  webElem <- remDr$findElement("id", "btnDownloadSpatialGeoPackageFile")
  webElem$clickElement()

  orig_file_name <- list.files(target_dir, dlname)
  orig_dfile_name <- list.files(default_dir, dlname)
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
    if (ncycle > 1200) {
      print("Timed out")
      break
    }
  }

  # allow download to default directory, just move to target first
  new_dfile_name <- dfile_name[!dfile_name %in% orig_dfile_name]
  file.copy(new_dfile_name, target_dir)
  file.remove(new_dfile_name)

  # TODO: should this also be done via RSelenium?
  # if these files remain on cloudvault/direct download download.file() is easier
  dcompanion <- file.path(target_dir, companion)
  if (nchar(dcompanion) > 0 && !file.exists(dcompanion)) {
    # download companion db
    oldtimeout <- getOption("timeout")
    options(timeout = 1e5)
    utils::download.file("https://new.cloudvault.usda.gov/index.php/s/tdnrQzzJ7ty39gs/download", destfile = dcompanion)
    options(timeout = oldtimeout)
  }

  utils::unzip(list.files(target_dir, "zip$", full.names = TRUE), exdir = target_dir)
  remDr$close()
}
