remotes::install_local("labtaxa",
                       repos = c("https://ncss-tech.r-universe.dev", getOption('repos')),
                       dependencies = TRUE)
library(labtaxa)
if (!dir.exists("~/Downloads"))
  dir.create("~/Downloads", recursive = TRUE)
ldm <- get_LDM_snapshot()
x <- ldm_data_dir()
if (!dir.exists("/home/rstudio/.local/share/R/labtaxa"))
  dir.create("/home/rstudio/.local/share/R/labtaxa", recursive = TRUE)
file.copy(list.files(x), "/home/rstudio/.local/share/R/labtaxa")
