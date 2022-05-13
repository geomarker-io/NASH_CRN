.cran_packages <- c("dplyr", "purrr", "sf", "tigris")
.inst <- .cran_packages %in% installed.packages()
if(any(!.inst)) {
  install.packages(.cran_packages[!.inst], repos = "http://cran.us.r-project.org")
}

library(dplyr)
library(purrr)
library(sf)

library(tigris)
options(tigris_use_cache = TRUE)
options(tigris_class = "sf")

dir.create("Data", showWarnings = FALSE)

states <-
  states(year = 2010) %>%
  st_drop_geometry() %>%
  select(name = NAME10, state_county_fips = STATEFP10) %>%
  filter(!name %in% c(
    "United States Virgin Islands",
    "Commonwealth of the Northern Mariana Islands",
    "Guam", "American Samoa", "Puerto Rico"
  )) %>%
  as_tibble()

saveRDS(states, "data/states.rds")

tracts <-
  map(states$state_county_fips, ~ tracts(state = .x, year = 2010)) %>%
  bind_rows() %>%
  st_drop_geometry() %>%
  mutate(state_county_fips = paste0(STATEFP, COUNTYFP)) %>%
  select(
    census_tract_fips = GEOID10,
    state_county_fips
  ) %>%
  as_tibble()

saveRDS(tracts, "data/tracts.rds")
