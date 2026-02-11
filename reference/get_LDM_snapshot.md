# Get 'Lab Data Mart' 'SQLite' Snapshot

Downloads the USDA-NRCS Kellogg Soil Survey Laboratory (KSSL) 'Lab Data
Mart' database snapshot from the official download portal. Uses
`RSelenium` for automated browser control to navigate the webpage and
initiate the download, which is cached in the user's local data
directory for fast subsequent access.

Returns the official USDA-NRCS Kellogg Soil Survey Laboratory 'Lab Data
Mart' download page URL.

Returns the directory where labtaxa caches downloaded data and processed
results. Creates the directory if it doesn't exist.

## Usage

``` r
get_LDM_snapshot(
  ...,
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
  timeout = 1e+05,
  baseurl = ldm_db_download_url()
)

ldm_db_download_url()

ldm_data_dir()
```

## Arguments

- ...:

  Arguments passed to
  [`soilDB::fetchLDM()`](http://ncss-tech.github.io/soilDB/reference/fetchLDM.md)
  for controlling data retrieval

- cache:

  Default: `TRUE`; cache the downloaded data as an RDS file and reuse on
  subsequent calls? When `FALSE`, forces fresh download and processing.

- verbose:

  Default: `TRUE`; print informative progress messages about download,
  processing, and caching operations? Set to `FALSE` for silent
  operation.

- keep_zip:

  Default: `FALSE`; retain the downloaded ZIP archive files after
  extraction? Set to `TRUE` to preserve raw downloads for manual
  inspection.

- dlname:

  Default: `"ncss_labdatagpkg.zip"`; file name for the main LDM database
  download

- dbname:

  Default: `"ncss_labdata.gpkg"`; file name for the extracted GeoPackage
  database

- cachename:

  Default: `"cached-LDM-SPC.rds"`; file name for the cached LDM
  `SoilProfileCollection`

- companiondlname:

  Default: `"ncss_morphologic.zip"`; file name for morphologic data
  download

- companiondbname:

  Default: `"ncss_morphologic.sqlite"`; file name for extracted
  morphologic database

- companioncachename:

  Default: `"cached-morph-SPC.rds"`; file name for cached morphologic
  `SoilProfileCollection`

- dirname:

  Data cache directory for the labtaxa package. Default:
  `tools::R_user_dir(package = "labtaxa")`. This directory is created
  automatically if it doesn't exist.

- default_dir:

  Default directory where RSelenium Firefox downloads files before
  moving to cache. Default: `"~/Downloads"`. Useful if your default
  browser download location differs.

- port:

  Default: `4567L`; port number for Selenium WebDriver. Change if port
  is already in use.

- timeout:

  Default: `1e5` seconds (~27.8 hours); maximum time to wait for file
  download

- baseurl:

  Default:
  `"https://ncsslabdatamart.sc.egov.usda.gov/database_download.aspx"`;
  URL of the KSSL Lab Data Mart download page

## Value

A `SoilProfileCollection` object (from the `aqp` package) containing
laboratory-analyzed soil profile data. The object has two components:

- `site` data: Profile-level attributes (e.g., soil taxonomy,
  coordinates)

- `horizons` data: Horizon-level laboratory analyses (e.g., pH, texture,
  nutrients) Use `length(x)` to get the number of profiles, `site(x)`
  for site data, and `horizons(x)` for horizon (layer) data.

Character string containing the URL

Character string containing the absolute path to the cache directory

## Details

Laboratory pedon (soil profile) data are retrieved from the downloaded
GeoPackage SQLite database using
[`soilDB::fetchLDM()`](http://ncss-tech.github.io/soilDB/reference/fetchLDM.md)
and cached as an RDS file containing a `SoilProfileCollection` object.
Companion morphologic (field description) data are retrieved using
[`soilDB::fetchNASIS()`](http://ncss-tech.github.io/soilDB/reference/fetchNASIS.md)
and cached separately.

This is the official USDA-NRCS webpage from which KSSL database
snapshots are downloaded. The page uses JavaScript and requires browser
automation via RSelenium to access.

The cache directory is located at:

- Linux/Mac: `~/.local/share/R/labtaxa`

- Windows: `C:\Users\USERNAME\AppData\Local\R\labtaxa`

This follows the XDG Base Directory specification via
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html).

## Caching Behavior

By default (`cache = TRUE`), results are automatically cached as RDS
files in `tools::R_user_dir(package="labtaxa")`. Subsequent calls to
`get_LDM_snapshot()` with `cache = TRUE` will load the cached data
without re-downloading or re-processing. Use `cache = FALSE` to force a
fresh download and rebuild.

## Data Versions

KSSL data is versioned by month. Always check the Docker image or
metadata file to determine which data version you're working with. For
reproducible research, pin to specific Docker image tags:
`ghcr.io/brownag/labtaxa:2026.02`

## Performance Notes

The full KSSL database contains ~65,000 soil profiles with 500,000+
horizons. Initial download and processing typically takes 10-30 minutes
depending on internet speed. Subsequent calls using cached data complete
in \<1 second.

## See also

- [`load_labtaxa()`](https://brownag.github.io/labtaxa/reference/cache_labtaxa.md)
  to load previously cached data (much faster)

- [`load_labmorph()`](https://brownag.github.io/labtaxa/reference/cache_labtaxa.md)
  to load morphologic data from cache

- [`cache_labtaxa()`](https://brownag.github.io/labtaxa/reference/cache_labtaxa.md)
  to manually save results to cache

- `ldm_data_dir()` to find the data cache directory

- [`soilDB::fetchLDM()`](http://ncss-tech.github.io/soilDB/reference/fetchLDM.md)
  for lower-level database access

- [`aqp::SoilProfileCollection`](https://ncss-tech.github.io/aqp/reference/SoilProfileCollection-class.html)
  for manipulating profile data

&nbsp;

- `get_LDM_snapshot()` which downloads data to this directory

- [`load_labtaxa()`](https://brownag.github.io/labtaxa/reference/cache_labtaxa.md)
  which loads cached data from this directory

- [`cache_labtaxa()`](https://brownag.github.io/labtaxa/reference/cache_labtaxa.md)
  to manually save data to this directory

## Examples

``` r
if (FALSE) { # \dontrun{
# Download and cache KSSL data (typically takes 10-30 minutes on first run)
ldm <- get_LDM_snapshot()

# Check what you downloaded
length(ldm)  # Number of profiles
head(site(ldm))  # Site-level attributes

# Subsequent calls are fast (load from cache)
ldm <- get_LDM_snapshot()  # <1 second!

# Access profile data
profiles <- site(ldm)
horizons <- horizons(ldm)

# Subset to specific soil orders
mollisols <- subset(ldm, SSL_taxorder == "mollisols")
cat(sprintf("Found %d mollisols\\n", length(mollisols)))

# Force fresh download (skip cache)
ldm_fresh <- get_LDM_snapshot(cache = FALSE, verbose = TRUE)

# Use with soilDB for custom database queries
ldm <- get_LDM_snapshot()
horizons_data <- horizons(ldm)
mean_clay <- mean(horizons_data$clay_r, na.rm = TRUE)
cat(sprintf("Mean clay content: %.1f%%\\n", mean_clay))
} # }
url <- ldm_db_download_url()
cat(sprintf("Download from: %s\\n", url))
#> Download from: https://ncsslabdatamart.sc.egov.usda.gov/database_download.aspx\n
cache_dir <- ldm_data_dir()
cat(sprintf("Data cached at: %s\\n", cache_dir))
#> Data cached at: /home/runner/.local/share/R/labtaxa\n

# Check what's cached
files <- list.files(cache_dir)
cat(sprintf("Cached files:\\n%s\\n", paste(files, collapse = "\\n")))
#> Cached files:\n\n
```
