.cran_packages <- c("purrr")
.inst <- .cran_packages %in% installed.packages()
if(any(!.inst)) {
  install.packages(.cran_packages[!.inst], repos = "http://cran.us.r-project.org")
}

library(purrr)

d <-
  c("tracts", "acs", "ejscreen", "food", "index", "mua") %>%
  map(~ readRDS(paste0("data/", ., ".rds"))) %>%
  reduce(dplyr::left_join, by = "census_tract_fips")

saveRDS(d, "data/nash_crn_census_data_2010.rds")
