#' Cache and Load KSSL Data
#'
#' Manually save and load cached KSSL Lab Data Mart and morphologic datasets.
#'
#' @section Overview:
#' These functions provide explicit control over data caching. In most cases,
#' `get_LDM_snapshot(..., cache = TRUE)` automatically handles both downloading
#' and caching. Use these functions only when you need custom caching behavior
#' or want to manually manage cached files.
#'
#' @section Cache Directory:
#' All cached files are stored in `ldm_data_dir()`, typically:
#' - Linux/Mac: `~/.local/share/R/labtaxa`
#' - Windows: `C:\Users\USERNAME\AppData\Local\R\labtaxa`
#'
#' @param x A `SoilProfileCollection` object (typically from `get_LDM_snapshot()`)
#'   or any other object to cache in the labtaxa data directory
#' @param filename Default: `"cached-LDM-SPC.rds"`; name of the RDS file to save/load.
#'   Use descriptive names for custom caches (e.g., `"mollisols-subset.rds"`)
#' @param destdir Default: `tools::R_user_dir(package = "labtaxa")`; directory where
#'   cache files are stored. Normally you don't need to change this.
#' @param silent Default: `FALSE`; suppress error messages when loading fails?
#'   Useful if you're not sure whether the file exists. Set to `TRUE` to get a
#'   `try-error` object on failure without warnings.
#'
#' @return
#'   - `cache_labtaxa()`: Invisibly returns the full path to the saved file.
#'     Called for its side-effect of saving the object.
#'   - `load_labtaxa()`: Returns the cached object (typically a `SoilProfileCollection`),
#'     or `try-error` if the file doesn't exist or can't be read.
#'   - `load_labmorph()`: Returns the cached morphologic `SoilProfileCollection`,
#'     or `try-error` if not found.
#'
#' @seealso
#'   - `get_LDM_snapshot()` for automatic download and caching
#'   - `ldm_data_dir()` to find the cache directory
#'   - `load_labmorph()` to load morphologic data
#'
#' @export
#' @examples
#' \dontrun{
#' # Example 1: Download and cache automatically (recommended)
#' ldm <- get_LDM_snapshot(cache = TRUE)  # Auto-caches
#'
#' # Example 2: Load from cache (very fast)
#' ldm <- load_labtaxa()
#'
#' # Example 3: Manually cache a subset
#' mollisols <- subset(ldm, SSL_taxorder == "mollisols")
#' cache_labtaxa(mollisols, filename = "mollisols-subset.rds")
#'
#' # Example 4: Later, load your subset
#' mollisols <- load_labtaxa(filename = "mollisols-subset.rds")
#'
#' # Example 5: Load morphologic data
#' morph <- load_labmorph()
#'
#' # Example 6: Check if cache exists before loading
#' cache_file <- file.path(ldm_data_dir(), "cached-LDM-SPC.rds")
#' if (file.exists(cache_file)) {
#'   ldm <- load_labtaxa()
#' } else {
#'   ldm <- get_LDM_snapshot()  # Downloads if not cached
#' }
#' }
cache_labtaxa <- function(x,
                          filename = "cached-LDM-SPC.rds",
                          destdir = tools::R_user_dir(package = "labtaxa")) {

  # Ensure destination directory exists
  if (!dir.exists(destdir)) {
    dir.create(destdir, recursive = TRUE)
  }

  fp <- file.path(destdir, filename)

  tryCatch({
    saveRDS(x, file = fp)
    if (file.exists(fp)) {
      file_size <- file.size(fp)
      if (file_size > 0) {
        message(sprintf("Cached %s: %.2f MB", filename, file_size / 1024 / 1024))
      } else {
        warning(sprintf("Saved file is empty: %s", fp))
      }
    } else {
      warning(sprintf("Failed to save cache file: %s", fp))
    }
  }, error = function(e) {
    stop(sprintf(
      "Failed to cache data to %s: %s",
      fp,
      conditionMessage(e)
    ), call. = FALSE)
  })

  invisible(fp)
}

#' @param silent Default: `FALSE`; suppress error messages if file doesn't exist?
#'   When `TRUE`, returns `try-error` silently instead of printing warnings.
#' @export
#' @rdname cache_labtaxa
load_labtaxa <- function(filename = "cached-LDM-SPC.rds",
                         destdir = ldm_data_dir(),
                         silent = FALSE) {
  try(readRDS(file.path(destdir, filename)), silent = silent)
}

#' Load Cached Morphologic Data
#'
#' Convenience wrapper for loading the cached morphologic (field description)
#' `SoilProfileCollection` from the companion NASIS database.
#'
#' @param filename Default: `"cached-morph-SPC.rds"`; name of cached morphologic file
#' @param destdir Default: `ldm_data_dir()`; directory where file is stored
#' @param silent Default: `FALSE`; suppress error messages if file doesn't exist?
#'
#' @return The cached morphologic `SoilProfileCollection`, or `try-error` if not found
#'
#' @seealso `load_labtaxa()` for loading the main LDM data
#'
#' @export
#' @rdname cache_labtaxa
load_labmorph <- function(filename = "cached-morph-SPC.rds",
                          destdir = ldm_data_dir(),
                          silent = FALSE) {
  load_labtaxa(filename = filename, destdir = destdir, silent = silent)
}
