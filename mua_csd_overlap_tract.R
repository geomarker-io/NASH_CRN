library(tidyverse)
library(sf)

url <- "https://data.hrsa.gov/DataDownload/DD_Files/MUA_DET.csv"
destfile <- "MUA.csv"

download.file(url, destfile=destfile)

d <- read_csv(destfile)

csd_mua <- d %>%
  filter(`MUA/P Status Code` %in% c("P", "D"), # keep only designated and proposed for withdrawal
         `Designation Type` %in% c("Medically Underserved Area",
                                   "Medically Underserved Area – Governor’s Exception"),
         `Medically Underserved Area/Population (MUA/P) Component Geographic Type Description` == "County Subdivision") %>%
  mutate(mua = 'Yes') %>%
  select(csd = `County Subdivision FIPS Code`,
         mua)

# csd_mua_oh <- csd_mua %>%
#   filter(substr(csd, 1, 2) == '39')
#
# csd <- tigris::county_subdivisions(state = 'oh') %>%
#   select(csd = GEOID)
#
# tracts <- tigris::tracts(state = 'oh') %>%
#   select(tract_id = GEOID)
#
# csd_mua_oh <- left_join(csd_mua_oh, csd) %>%
#   st_as_sf()
#
# mua_oh_tracts_overlaps <- st_join(tracts, csd_mua_oh, join = st_overlaps)
# mua_oh_tracts_contains <- st_join(tracts, csd_mua_oh, join = st_contains)
# mua_oh_tracts_within <- st_join(tracts, csd_mua_oh, join = st_within)
#
# mua_oh_tracts <- mua_oh_tracts_overlaps %>%
#   left_join(mua_oh_tracts_contains %>% st_drop_geometry(), by = 'tract_id') %>%
#   left_join(mua_oh_tracts_within %>% st_drop_geometry(), by = 'tract_id')
#
# mua_oh_tracts <- mua_oh_tracts %>%
#   mutate(overlaps_csd_mua = ifelse(mua.x == "Yes" | mua.y == "Yes" | mua == "Yes", "Yes", "No"),
#          overlaps_csd_mua = ifelse(is.na(overlaps_csd_mua), "No", overlaps_csd_mua)) %>%
#   select(tract_id, overlaps_csd_mua)
#
# mapview::mapview(mua_oh_tracts, zcol = 'overlaps_csd_mua') +
#   mapview::mapview(csd_mua_oh)
#
# mua_oh_tracts %>%
#   st_drop_geometry()
states <- tigris::states() %>%
  st_drop_geometry() %>%
  select(NAME) %>%
  filter(!NAME %in% c('United States Virgin Islands',
                      'Commonwealth of the Northern Mariana Islands',
                      'Guam', 'American Samoa', 'Puerto Rico'))

csd <- map(states$NAME, ~tigris::county_subdivisions(state = .x, year=2010)) %>%
  bind_rows() %>%
  select(csd = GEOID)

tracts <- map(states$NAME, ~tigris::tracts(state = .x, year=2010)) %>%
  bind_rows() %>%
  select(tract_id = GEOID)

csd_mua <- left_join(csd_mua, csd) %>%
  st_as_sf()

mua_tracts_overlaps <- st_join(tracts, csd_mua, join = st_overlaps)
mua_tracts_contains <- st_join(tracts, csd_mua, join = st_contains)
mua_tracts_within <- st_join(tracts, csd_mua, join = st_within)

mua_tracts <- mua_tracts_overlaps %>%
  left_join(mua_tracts_contains %>% st_drop_geometry(), by = 'tract_id') %>%
  left_join(mua_tracts_within %>% st_drop_geometry(), by = 'tract_id')

mua_tracts <- mua_tracts %>%
  mutate(overlaps_csd_mua = ifelse(mua.x == "Yes" | mua.y == "Yes" | mua == "Yes", "Yes", "No"),
         overlaps_csd_mua = ifelse(is.na(overlaps_csd_mua), "No", overlaps_csd_mua)) %>%
  select(tract_id, overlaps_csd_mua)

t <- mua_tracts %>%
  filter(substr(tract_id, 1, 2) == '18')

mapview::mapview(t, zcol = 'overlaps_csd_mua') +
  mapview::mapview(csd_mua)

mua_tracts <- mua_tracts %>%
  st_drop_geometry()

saveRDS(mua_tracts, 'Data/bySource/mua_csd_overlap_tract.rds')

