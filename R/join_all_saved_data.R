library(purrr)

d <-
  c("tracts", "acs", "ejscreen", "food", "index") %>%
  map(~ readRDS(paste0("data/", ., ".rds"))) %>%
  reduce(dplyr::left_join, by = "census_tract_fips")

saveRDS(d, "data/nash_crn_census_data_2010.rds")
