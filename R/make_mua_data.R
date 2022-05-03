# =============================
# medically underserved areas
# =============================
# subsection: shortage areas
# Medically Underserved Areas/Populations (MUA/P)
# Medically Underserved Areas/Populations are areas or populations designated by HRSA as
# having too few primary care providers, high infant mortality, high poverty or a high elderly population.
# https://data.hrsa.gov/tools/shortage-area/mua-find#:~:text=Medically%20Underserved%20Areas%2FPopulations%20are,or%20a%20high%20elderly%20population.
# In this analysis, limit to Medically Underserved Areas; exclude Medically Underserved Populations

url <- "https://data.hrsa.gov/DataDownload/DD_Files/MUA_DET.csv"
destfile <- "Data/bySource/MUA.csv"

download.file(url, destfile = destfile, mode = "wb")

d <- read_csv("Data/bySource/MUA.csv")

d <- d %>%
  filter(`MUA/P Status Code` %in% c("P", "D")) %>%
  # keep only designated and proposed for withdrawal
  filter(`Designation Type Code` %in% c("MUA", "MUA-GE")) %>%
  # keep Medically Underserved Area; exclude MU population
  mutate(mua = "Yes") %>%
  select(
    census_tract_fips = `MUA/P Area Code`,
    state_county_fips = `State and County Federal Information Processing Standard Code`,
    csd = `County Subdivision FIPS Code`,
    geo_type = `Medically Underserved Area/Population (MUA/P) Component Geographic Type Description`,
    mua
  )

#> table(d$geo_type)
# Census Tract County Subdivision      Single County
#  8564               2282               1686

# process data with geo_type = 'Census Tract' / 'Conty Subdivision' / 'Single County' separately
d.ct <- d %>%
  filter(geo_type %in% c("Census Tract")) %>%
  filter(!duplicated(census_tract_fips)) %>%
  select(census_tract_fips, mua.ct = mua)

d.sc <- d %>%
  filter(geo_type %in% c("Single County")) %>%
  filter(!duplicated(state_county_fips)) %>%
  select(state_county_fips, mua.sc = mua)

d.cs <- d %>%
  filter(geo_type %in% c("County Subdivision")) %>%
  filter(!duplicated(csd)) %>%
  select(csd, mua.cs = mua)

#--------------------------------------------------------
# overlap conuty subdivision data with tract level data
#--------------------------------------------------------

csd <- map(states$NAME, ~ county_subdivisions(state = .x, year = 2010)) %>%
  bind_rows() %>%
  select(csd = GEOID10)

tracts <- map(states$NAME, ~ tracts(state = .x, year = 2010)) %>%
  bind_rows() %>%
  select(census_tract_fips = GEOID10)

csd_mua <- left_join(d.cs, csd) %>%
  st_as_sf()

mua_tracts_overlaps <- st_join(tracts, csd_mua, join = st_overlaps)
mua_tracts_contains <- st_join(tracts, csd_mua, join = st_contains)
mua_tracts_within <- st_join(tracts, csd_mua, join = st_within)

mua_tracts <- mua_tracts_overlaps %>%
  left_join(mua_tracts_contains %>% st_drop_geometry(), by = "census_tract_fips") %>%
  left_join(mua_tracts_within %>% st_drop_geometry(), by = "census_tract_fips")

mua_tracts <- mua_tracts %>%
  mutate(
    overlaps_csd_mua = ifelse(mua.cs.x == "Yes" | mua.cs.y == "Yes" | mua.cs == "Yes", "Yes", "No"),
    overlaps_csd_mua = ifelse(is.na(overlaps_csd_mua), "No", overlaps_csd_mua)
  ) %>%
  select(census_tract_fips, overlaps_csd_mua) %>%
  filter(!duplicated(census_tract_fips))

t <- mua_tracts %>%
  filter(substr(census_tract_fips, 1, 2) == "18")

# mapview::mapview(t, zcol = 'overlaps_csd_mua') +
#  mapview::mapview(csd_mua)

mua_tracts <- mua_tracts %>%
  st_drop_geometry()

saveRDS(mua_tracts, "./Data/bySource/mua_csd_overlap_tract_2010.rds")


mua_csd_overlap <- readRDS("./Data/bySource/mua_csd_overlap_tract_2010.rds")


#-------------------------------------------------------------------------
## merge tract level / single county level / county subdivision level data
#-------------------------------------------------------------------------
mua <- full_join(all_tracts, d.ct, by = "census_tract_fips") %>% # n=73058
  left_join(., d.sc, by = "state_county_fips") %>% # left join county level data
  left_join(., mua_csd_overlap, by = "census_tract_fips") %>% # left join county subdivision data
  mutate(
    mua = ifelse(mua.ct == "Yes" | mua.sc == "Yes" | overlaps_csd_mua == "Yes", 1, 0), # 1='Yes' / 0='No'
    mua = ifelse(is.na(mua), 0, mua)
  ) %>%
  select(census_tract_fips, mua)
# 73058

saveRDS(mua, "Data/bySource/mua.rds")

