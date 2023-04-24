remotes::install_local(
  "labtaxa",
  repos = c("https://ncss-tech.r-universe.dev",
            getOption('repos')),
  dependencies = TRUE
)

library(labtaxa)

x <- ldm_data_dir()
ldm <- get_LDM_snapshot()

message("Snapshot files in ", x, ":")
message(paste0("\t", list.files(x), "\n"))
