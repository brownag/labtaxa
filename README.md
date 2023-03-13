
<!-- README.md is generated from README.Rmd. Please edit that file -->

# labtaxa

<!-- badges: start -->
<!-- badges: end -->

The goal of {labtaxa} is to support automatic download of ‘Lab Data
Mart’ (<https://ncsslabdatamart.sc.egov.usda.gov/>) database snapshots
and apply patches to the cached database for testing and use in R.

## Installation

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
