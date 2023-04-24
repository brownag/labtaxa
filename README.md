
<!-- README.md is generated from README.Rmd. Please edit that file -->

# labtaxa

<!-- badges: start -->

[![R-CMD-check](https://github.com/brownag/labtaxa/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/brownag/labtaxa/actions/workflows/R-CMD-check.yaml)
[![docker-publish](https://github.com/brownag/labtaxa/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/brownag/labtaxa/actions/workflows/docker-publish.yml)
[![Docker
Pulls](https://badgen.net/docker/pulls/brownag/labtaxa?icon=docker&label=pulls)](https://hub.docker.com/r/brownag/labtaxa/)
[![ghcn.io](https://ghcr-badge.egpl.dev/brownag/labtaxa/size)](https://github.com/users/brownag/packages/container/package/labtaxa)
<!-- badges: end -->

The goal of {labtaxa} is to provide ‘Lab Data Mart’
(<https://ncsslabdatamart.sc.egov.usda.gov/>) database snapshots for use
in R. This repository is an R package used to download and cache the
contents of the Lab Data Mart GeoPackage database.

## Docker

To get up and running quickly you can use the Docker container. The
`labtaxa` container is based on
[`"rocker/rstudio:latest"`](https://hub.docker.com/r/rocker/rstudio). In
addition to the standard RStudio tools, the container has the cached Lab
Data Mart GeoPackage (containing lab and spatial data) and the companion
morphologic database (derived from NASIS pedon descriptions)
pre-downloaded. Also, the results of `soilDB::fetchLDM()` called on the
LDM GeoPackage data source are cached as an R object file (.rds).
Finally, a variety of useful R packages are pre-installed. All can be
accessed via an RStudio Server web browser interface.

From Docker Hub:

``` sh
docker pull brownag/labtaxa:latest
```

Or from GitHub:

``` sh
docker pull ghcr.io/brownag/labtaxa:latest
```

Once you have a local copy of the `labtaxa` container you can run:

``` sh
docker run -d -p 8787:8787 -e PASSWORD=mypassword -v ~:/home/rstudio/HOME -e ROOT=TRUE brownag/labtaxa
```

Then open your web browser and navigate to `http://localhost:8787`. The
default username is `rstudio` and the default password is `mypassword`.

## R Package Installation

You can install the development version of {labtaxa} from GitHub:

``` r
if (!require("labtaxa")) 
 remotes::install_github("brownag/labtaxa")
```

## Example

Download (and cache) the latest Lab Data Mart SQLite snapshot from
<https://ncsslabdatamart.sc.egov.usda.gov/> like so:

``` r
library(labtaxa)
ldm <- get_LDM_snapshot()
```

Downloaded and derived files will be cached in platform-specific
directory specified by `ldm_data_dir()`.
