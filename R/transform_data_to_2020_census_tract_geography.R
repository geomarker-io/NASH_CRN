.cran_packages <- c("dplyr")
.inst <- .cran_packages %in% installed.packages()
if(any(!.inst)) {
  install.packages(.cran_packages[!.inst], repos = "http://cran.us.r-project.org")
}

library(dplyr)

cw <- readRDS("data/2010_to_2020_tract_cw.rds")

# Update all variables
data2010 <- readRDS("data/nash_crn_census_data_2010.rds")

variables <- names(data2010)[-c(1,2)]

data2020 <- data2010 %>%
  rename(census_tract_fips_2010 = census_tract_fips) %>%
  left_join(cw, by = "census_tract_fips_2010") %>%
  filter(!is.na(census_tract_fips_2020)) %>%
  mutate(
	across(variables[1]:variables[length(variables)], ~ .x * weight_inverse)) %>%
  group_by(census_tract_fips_2020) %>%
  summarize(
	across(variables[1]:variables[length(variables)], sum)) %>%
  rename(census_tract_fips = census_tract_fips_2020)

saveRDS(data2020, "data/nash_crn_census_data_2020.rds")
