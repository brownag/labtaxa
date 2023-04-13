#' Cache Object
#'
#' @param x A `SoilProfileCollection` (or other object to cache in `labtaxa` directory)
#' @param filename Default: `"cached-LDM-SPC.rds"`
#' @param destdir Default: `tools::R_user_dir(package = "labtaxa")`
#'
#' @return `cache_labtaxa()`: `x` is cached in `destdir` as `filename` as a side-effect. Invisibly returns the full file path.
#' @export
#' @examples
#' \dontrun{
#'  x <- get_LDM_snapshot()
#'  cache_labtaxa(x)
#'  y <- load_labtaxa()
#'  all(profile_id(x) == profile_id(y))
#' }
cache_labtaxa <- function(x,
                          filename = "cached-LDM-SPC.rds",
                          destdir = tools::R_user_dir(package = "labtaxa")) {
  fp <- file.path(destdir, filename)
  saveRDS(x, file = fp)
  invisible(fp)
}

#' @param silent Suppress error messages? Passed to `try()`. Default `FALSE`
#' @return `load_labtaxa()`: Read a .rds file (`filename`) from `destdir` (the labtaxa "user data" directory). Returns the object contained in the file, or `try-error` on failure to read file.
#' @export
#' @rdname cache_labtaxa
load_labtaxa <- function(filename = "cached-LDM-SPC.rds",
                         destdir = tools::R_user_dir(package = "labtaxa"),
                         silent = FALSE) {
  try(readRDS(file.path(destdir, filename)), silent = silent)
}

