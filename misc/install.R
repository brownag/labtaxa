remotes::install_local(
  "labtaxa",
  repos = c("https://ncss-tech.r-universe.dev",
            getOption('repos')),
  dependencies = TRUE
)

# use a folder within build context
library(labtaxa)
x <- "~/labtaxa_data"

message("DEBUG: About to call get_LDM_snapshot with dirname=", x)
message("DEBUG: Directory exists before: ", dir.exists(x))
message("DEBUG: Files before: ", paste(list.files(x, all.files = TRUE), collapse = ", "))

result <- tryCatch({
  get_LDM_snapshot(dirname = x, verbose = TRUE)
}, error = function(e) {
  message("ERROR during get_LDM_snapshot: ", conditionMessage(e))
  NULL
})

message("DEBUG: get_LDM_snapshot returned: ", if(is.null(result)) "NULL" else paste("object with", length(result), "profiles"))
message("DEBUG: Directory exists after: ", dir.exists(x))
message("DEBUG: Files after: ", paste(list.files(x, all.files = TRUE), collapse = ", "))

message("Snapshot files in ", x, ":")
files <- list.files(x)
if (length(files) > 0) {
  message(paste0("\t", files, collapse = "\n\t"))
} else {
  message("\t(WARNING: no files found in ", x, " - download may have failed)")
  message("\tThis is expected in GitHub Actions if network access to USDA server is restricted")
}
