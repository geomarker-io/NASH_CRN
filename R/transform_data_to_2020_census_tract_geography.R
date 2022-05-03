cw <- readRDS("Data/2010_to_2020_tract_cw.rds")

# Update all variables
data2010 <- readRDS("./Data/census_track_level_data_2010.rds")

data2020 <- data2010 %>%
  rename(census_tract_fips_2010 = census_tract_fips) %>%
  left_join(cw, by = "census_tract_fips_2010") %>%
  mutate(across(acs_public_assistance_rate:food_insecurity_pct, ~ .x * weight_inverse)) %>%
  group_by(census_tract_fips_2020) %>%
  summarize(across(acs_public_assistance_rate:food_insecurity_pct, sum)) %>%
  mutate(
    mua = ifelse(is.na(mua), 0, mua),
    usda_low_food_access_flag = ifelse(is.na(usda_low_food_access_flag), 0, usda_low_food_access_flag)
  ) %>%
  # Handle NA in 2020 data
  rename(census_tract_fips = census_tract_fips_2020)

saveRDS(data2020, "Data/census_track_level_data_2020CT.rds")

write_csv(data2010, file = "./Data/census_track_level_data_2020CT.csv")
