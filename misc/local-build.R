# generate missing NASIS lookup tables for patching morphologic database

tables <- c("othvegclass", "geomorfeattype", "geomorfeat")
for (tbl in tables) {
  x <- soilDB::dbQueryNASIS(soilDB::NASIS(), sprintf("SELECT * FROM %s", tbl))
  saveRDS(x, file.path("inst", "extdata", paste0(tbl, ".rds")))
}
