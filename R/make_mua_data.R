.cran_packages <- c("dplyr", "purrr", "sf", "tigris")
.inst <- .cran_packages %in% installed.packages()
if(any(!.inst)) {
  install.packages(.cran_packages[!.inst], repos = "http://cran.us.r-project.org")
}

library(dplyr)
library(purrr)
library(sf)
library(tigris)
options(timeout = 1000)

states <- readRDS("Data/states.rds")
tracts <- readRDS("Data/tracts.rds")

if (!file.exists("raw-data/mua.csv")) {
  download.file(
    url = "https://data.hrsa.gov/DataDownload/DD_Files/MUA_DET.csv",
    destfile = "raw-data/mua.csv",
    mode = "wb"
  )
}

mua <- readr::read_csv("raw-data/mua.csv") %>%
  filter(`MUA/P Status Code` %in% c("P", "D")) %>%
  filter(`Designation Type Code` %in% c("MUA", "MUA-GE")) %>%
  mutate(mua = "Yes") %>%
  select(
    census_tract_fips = `MUA/P Area Code`,
    state_county_fips = `State and County Federal Information Processing Standard Code`,
    csd = `County Subdivision FIPS Code`,
    geo_type = `Medically Underserved Area/Population (MUA/P) Component Geographic Type Description`,
    mua
  )

# process data with geo_type = 'Census Tract' / 'Conty Subdivision' / 'Single County' separately
mua.ct <- mua %>%
  filter(geo_type %in% c("Census Tract")) %>%
  filter(!duplicated(census_tract_fips)) %>%
  select(census_tract_fips, mua.ct = mua)

mua.sc <- mua %>%
  filter(geo_type %in% c("Single County")) %>%
  filter(!duplicated(state_county_fips)) %>%
  select(state_county_fips, mua.sc = mua)

mua.cs <- mua %>%
  filter(geo_type %in% c("County Subdivision")) %>%
  filter(!duplicated(csd)) %>%
  select(csd, mua.cs = mua)

#--------------------------------------------------------
# overlap conuty subdivision data with tract level data
#--------------------------------------------------------

csd <- map(states$name, ~ county_subdivisions(state = .x, year = 2010)) %>%
  bind_rows() %>%
  select(csd = GEOID10)

tracts <- map(states$name, ~ tracts(state = .x, year = 2010)) %>%
  bind_rows() %>%
  select(census_tract_fips = GEOID10)

csd_mua <- left_join(mua.cs, csd) %>%
  st_as_sf()

mua_tracts_overlaps <- st_join(tracts, csd_mua, join = st_overlaps)
mua_tracts_contains <- st_join(tracts, csd_mua, join = st_contains)
mua_tracts_within <- st_join(tracts, csd_mua, join = st_within)

mua_csd_overlap <- mua_tracts_overlaps %>%
  left_join(mua_tracts_contains %>% st_drop_geometry(), by = "census_tract_fips") %>%
  left_join(mua_tracts_within %>% st_drop_geometry(), by = "census_tract_fips") %>%
  mutate(
    overlaps_csd_mua = ifelse(mua.cs.x == "Yes" | mua.cs.y == "Yes" | mua.cs == "Yes", "Yes", "No"),
    overlaps_csd_mua = ifelse(is.na(overlaps_csd_mua), "No", overlaps_csd_mua)
  ) %>%
  select(census_tract_fips, overlaps_csd_mua) %>%
  filter(!duplicated(census_tract_fips)) %>%
  st_drop_geometry()

#-------------------------------------------------------------------------
## merge tract level / single county level / county subdivision level data
#-------------------------------------------------------------------------
mua <- full_join(tracts, mua.ct, by = "census_tract_fips") %>% 
  left_join(., mua_csd_overlap, by = "census_tract_fips") %>%
  mutate(state_county_fips = substr(census_tract_fips, 1, 5)) %>%
  left_join(., mua.sc, by = "state_county_fips") %>% 
  mutate(
    mua = ifelse(mua.ct == "Yes" | mua.sc == "Yes" | overlaps_csd_mua == "Yes", 1, 0), # 1='Yes' / 0='No'
    mua = ifelse(is.na(mua), 0, mua)
  ) %>%
  select(census_tract_fips, mua) %>%
  st_drop_geometry()

saveRDS(mua, "Data/mua.rds")

