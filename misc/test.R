library(aqp)
library(labtaxa)

ldm <- load_labtaxa()

if (is.null(ldm)) {
  ldm <- get_LDM_snapshot(cache = FALSE)
  cache_labtaxa(ldm)
}

ldmsub <- subset(ldm, checkHzDepthLogic(ldm)$valid)
ldmsub$SSL_taxorder[is.na(ldmsub$SSL_taxorder)] <- "<NA>"
ldmsub$mtr <- mollic.thickness.requirement(ldmsub)

plot(density(ldmsub$mtr, kernel = "rectangular", bw = 0.05))

# 50/50 18 or less v.s. more than 18

prop.table(table(cut(
  ldmsub$mtr, c(9.99, 10.1, 17.99, 18.01, 24.99, 25.01)
)))

# orders <- split(ldmsub, ldmsub$SSL_taxorder)
# mollic.thickness.requirement(orders$mollisols)
