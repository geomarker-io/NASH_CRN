

# 2020 Comparability Relationship File Record Layouts
# https://www.census.gov/programs-surveys/geography/technical-documentation/records-layout/2020-comp-record-layout.html

url <- "https://www2.census.gov/geo/docs/maps-data/data/rel2020/tract/tab20_tract20_tract10_natl.txt"
destfile <- "Data/cw/2010_to_2020_tract_cw.txt"

download.file(url, destfile=destfile, mode = "wb")

d <- readr::read_delim("Data/cw/2010_to_2020_tract_cw.txt", delim = "|")

cw <- d %>%
  select(census_tract_fips_2020 = GEOID_TRACT_20,
         census_tract_fips_2010 = GEOID_TRACT_10,
         AREALAND_PART,
         AREALAND_TRACT_20) %>%
  mutate(weight_inverse = AREALAND_PART / AREALAND_TRACT_20) %>%
  filter(weight_inverse > 0.05) 

cw_sum <- cw %>% 
  group_by(census_tract_fips_2020) %>% 
  summarise(weight_inverse_sum = sum(weight_inverse))

cw <- left_join(cw, cw_sum, by='census_tract_fips_2020') %>% 
  mutate(weight_inverse = weight_inverse / weight_inverse_sum) %>% 
  select(-weight_inverse_sum)

saveRDS(cw, 'Data/2010_to_2020_tract_cw.rds')
