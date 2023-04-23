remotes::install_local("labtaxa",
                       repos = c("https://ncss-tech.r-universe.dev", getOption('repos')),
                       dependencies = TRUE)
library(labtaxa)
if (!dir.exists("~/Downloads"))
  dir.create("~/Downloads", recursive = TRUE)
ldm <- get_LDM_snapshot()
