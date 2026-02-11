# Test setup and utilities
library(labtaxa)

# Utility function for testing with mock objects
with_mock <- function(expr, env = parent.frame()) {
  eval(substitute(expr), env)
}
