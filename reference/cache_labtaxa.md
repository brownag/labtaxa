# Cache and Load KSSL Data

Manually save and load cached KSSL Lab Data Mart and morphologic
datasets.

Convenience wrapper for loading the cached morphologic (field
description) `SoilProfileCollection` from the companion NASIS database.

## Usage

``` r
cache_labtaxa(
  x,
  filename = "cached-LDM-SPC.rds",
  destdir = tools::R_user_dir(package = "labtaxa")
)

load_labtaxa(
  filename = "cached-LDM-SPC.rds",
  destdir = ldm_data_dir(),
  silent = FALSE
)

load_labmorph(
  filename = "cached-morph-SPC.rds",
  destdir = ldm_data_dir(),
  silent = FALSE
)
```

## Arguments

- x:

  A `SoilProfileCollection` object (typically from
  [`get_LDM_snapshot()`](https://brownag.github.io/labtaxa/reference/get_LDM_snapshot.md))
  or any other object to cache in the labtaxa data directory

- filename:

  Default: `"cached-morph-SPC.rds"`; name of cached morphologic file

- destdir:

  Default:
  [`ldm_data_dir()`](https://brownag.github.io/labtaxa/reference/get_LDM_snapshot.md);
  directory where file is stored

- silent:

  Default: `FALSE`; suppress error messages if file doesn't exist?

## Value

- `cache_labtaxa()`: Invisibly returns the full path to the saved file.
  Called for its side-effect of saving the object.

- `load_labtaxa()`: Returns the cached object (typically a
  `SoilProfileCollection`), or `try-error` if the file doesn't exist or
  can't be read.

- `load_labmorph()`: Returns the cached morphologic
  `SoilProfileCollection`, or `try-error` if not found.

The cached morphologic `SoilProfileCollection`, or `try-error` if not
found

## Overview

These functions provide explicit control over data caching. In most
cases, `get_LDM_snapshot(..., cache = TRUE)` automatically handles both
downloading and caching. Use these functions only when you need custom
caching behavior or want to manually manage cached files.

## Cache Directory

All cached files are stored in
[`ldm_data_dir()`](https://brownag.github.io/labtaxa/reference/get_LDM_snapshot.md),
typically:

- Linux/Mac: `~/.local/share/R/labtaxa`

- Windows: `C:\Users\USERNAME\AppData\Local\R\labtaxa`

## See also

- [`get_LDM_snapshot()`](https://brownag.github.io/labtaxa/reference/get_LDM_snapshot.md)
  for automatic download and caching

- [`ldm_data_dir()`](https://brownag.github.io/labtaxa/reference/get_LDM_snapshot.md)
  to find the cache directory

- `load_labmorph()` to load morphologic data

`load_labtaxa()` for loading the main LDM data

## Examples

``` r
if (FALSE) { # \dontrun{
# Example 1: Download and cache automatically (recommended)
ldm <- get_LDM_snapshot(cache = TRUE)  # Auto-caches

# Example 2: Load from cache (very fast)
ldm <- load_labtaxa()

# Example 3: Manually cache a subset
mollisols <- subset(ldm, SSL_taxorder == "mollisols")
cache_labtaxa(mollisols, filename = "mollisols-subset.rds")

# Example 4: Later, load your subset
mollisols <- load_labtaxa(filename = "mollisols-subset.rds")

# Example 5: Load morphologic data
morph <- load_labmorph()

# Example 6: Check if cache exists before loading
cache_file <- file.path(ldm_data_dir(), "cached-LDM-SPC.rds")
if (file.exists(cache_file)) {
  ldm <- load_labtaxa()
} else {
  ldm <- get_LDM_snapshot()  # Downloads if not cached
}
} # }
```
