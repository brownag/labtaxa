remotes::install_local(
  "labtaxa",
  repos = c("https://ncss-tech.r-universe.dev",
            getOption('repos')),
  dependencies = TRUE
)

# use a folder within build context
library(labtaxa)
x <- "~/labtaxa_data"
ldm <- get_LDM_snapshot(dirname = x)

message("Snapshot files in ", x, ":")
message(paste0("\t", list.files(x), "\n"))
