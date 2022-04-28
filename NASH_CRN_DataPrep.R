
setwd("C:/Users/DUAHD6/Documents/Brokamp/NASH_CRN")

library(tidyverse)
library(sf)
library(tidycensus)
census_api_key(Sys.getenv("CENSUS_API_KEY"))
library(tigris)
library(readxl)
options(tigris_use_cache=TRUE)
options(tigris_class='sf')



#### get all tracks based on states (2010 data) -----------------------------------
# Data from different sources will be merged into all_tracks from tigris
# Note: YEAR=2010
# N tracts = 73057

states <- tigris::states(year=2010) %>%
  st_drop_geometry() %>%
  select(NAME10) %>%
  filter(!NAME10 %in% c('United States Virgin Islands',
                        'Commonwealth of the Northern Mariana Islands',
                        'Guam', 'American Samoa', 'Puerto Rico'))

all_tracts <- map(states$NAME, ~tigris::tracts(state = .x, year=2010)) %>%
  bind_rows() %>%
  st_drop_geometry() %>% 
  mutate(state_county_fips = str_c(STATEFP, COUNTYFP, sep="")) %>% 
  select(census_tract_fips = GEOID10,
         state_county_fips) 


#### get all 2015-2019 5-year ACS tract-level variables -----------------------------------

states_needed <- tigris::fips_codes %>%
  select(state_code, state_name) %>%
  filter(! state_name %in% c('American Samoa', 'Guam', 'Northern Mariana Islands',
                             'Puerto Rico', 'U.S. Minor Outlying Islands',
                             'U.S. Virgin Islands')) %>%
  unique() %>%
  pull(state_code)


#===================================================================================================
## public assistance rate: fraction households with public assistance income in the past 12 months
#===================================================================================================
# B19057: Public assistance income in the past 12 months for households
# B19057_001: total
# B19057_002: n with public assistance income
acs_public_assistance <- get_acs(geography = 'tract',
                                 variables = 'B19057_002',
                                 summary_var = 'B19057_001',
                                 year = 2019,
                                 state = states_needed) %>%
  mutate(acs_public_assistance_rate = estimate / summary_est) %>%
  select(GEOID, acs_public_assistance_rate)

#===================================================================================================
## poverty rate: fraction population with income in the past 12 months below poverty level
#===================================================================================================
# B17001: Poverty Status in the past 12 months by sex by age
# B17001_001: total
# B17001_002: n income in the past 12 months below poverty level:
acs_poverty <- get_acs(geography = 'tract',
                       variables = 'B17001_002',
                       summary_var = 'B17001_001',
                       year = 2019,
                       state = states_needed) %>%
  mutate(acs_poverty_rate = estimate / summary_est) %>%
  select(GEOID, acs_poverty_rate)

#==========================
## Unemployment rate
#==========================
# B23025: Employment Status for the Population 16 Years and Over
# B23025_001: total
# B23025_007: n not in labor force
acs_unemployment <- get_acs(geography = 'tract',
                       variables = 'B23025_007',
                       summary_var = 'B23025_001',
                       year = 2019,
                       state = states_needed) %>%
  mutate(acs_unemployment_rate = estimate / summary_est) %>%
  select(GEOID, acs_unemployment_rate)

#================
## median_income
#================
# median household income in the past 12 months in 2019 inflation-adjusted dollars
# B19013_001: est
acs_income <- get_acs(geography = 'tract',
                      variables = 'B19013_001',
                      year = 2019,
                      state = states_needed) %>%
  mutate(acs_median_income = estimate) %>%
  select(GEOID, acs_median_income)

#===================================================================================================
## racial ICE: closer to 1 indicates population is majority white non Hispanic, closer to -1 indicates population is majority black non Hispanic
#===================================================================================================
# B03002: Hispanic or Latino Origin by Race
# B03002_001: total
# B03002_003: n White alone 
# B03002_004: n Black or African American Alone
acs_racial_ICE <- get_acs(geography = 'tract',
                   variables = c('B03002_003', 'B03002_004'),
                   summary_var = 'B03002_001',
                   year = 2019,
                   state = states_needed) %>%
  group_by(GEOID) %>%
  summarize(n_diff = estimate[variable=='B03002_003'] - estimate[variable=='B03002_004'],
            total = unique(summary_est)) %>%
  mutate(acs_racial_ice = n_diff / total) %>%
  select(GEOID, acs_racial_ice)

#=======================
## vacant housing rate
#=======================
# B25002: Occupancy Status
# B25002_001: total 
# B25002_003: n vacant
acs_vacant_housing <- get_acs(geography = 'tract',
                       variables = 'B25002_003',
                       summary_var = 'B25002_001',
                       year = 2019,
                       state = states_needed) %>%
  mutate(acs_vacant_housing_rate = estimate / summary_est) %>%
  select(GEOID, acs_vacant_housing_rate)

#======================================================
## fraction of pop > 25 years with at least HS or GED
#======================================================
# B15003: Educational Attainment
# B15003_001: total
# B15003_{017 - 025}: n with at least HS or GED
acs_edu <- get_acs(geography = 'tract',
                   variables = paste0('B15003_0',17:25),
                   summary_var = 'B15003_001',
                   year = 2019,
                   state = states_needed) %>%
  group_by(GEOID) %>%
  summarize(high_school_edu = sum(estimate),
            total = unique(summary_est)) %>%
  mutate(acs_fraction_hs_edu = high_school_edu / total) %>%
  select(GEOID, acs_fraction_hs_edu)

#==========================================
## fraction of household with no vehicles
#==========================================
# B08201: Household Size by Vehicles Available
# B08201_001: total 
# B08201_002: n no vehicle available
acs_vehicle <- get_acs(geography = 'tract',
                              variables = 'B08201_002',
                              summary_var = 'B08201_001',
                              year = 2019,
                              state = states_needed) %>%
  mutate(acs_fraction_no_vehicle = estimate / summary_est) %>%
  select(GEOID, acs_fraction_no_vehicle)

#=========================================================
## fraction population with no health insurance coverage 
#=========================================================
# B27010: Types of Health Insurance Coverage by Age
# B27010_001: total
# B27010_{017,033,050,066}: n with no health insurance coverage
acs_ins <- get_acs(geography = 'tract',
                   variables = paste0('B27010_0',c(17, 33, 50, 66)),
                   summary_var = 'B27010_001',
                   year = 2019,
                   state = states_needed) %>%
  group_by(GEOID) %>%
  summarize(no_health_ins = sum(estimate),
            total = unique(summary_est)) %>%
  mutate(acs_fraction_no_health_ins = no_health_ins / total) %>%
  select(GEOID, acs_fraction_no_health_ins)

#=======================================================================================================================
## racial and socioeconomic ICE: high income white non-Hispanic households versus  low income people of color households
#=======================================================================================================================
# B19001: Household Income in the Past 12 Months (In 2019 Inflation-Adjusted Dollars)
# B19001_001: total
# B19001_{002 - 005}: n household income less than 25,000
# B19001H: Household Income in the Past 12 Months (In 2019 Inflation-Adjusted Dollars) (White Alone, Not Hispanic or Latino Householder)
# B19001H_{002 - 005}: n household income less than 25,000 (White alone, Not Hispanic or Latino Householder)
# B19001H_{014 - 017}: n household income 100,000 or more (White alone, Not Hispanic or Latino Householder)
# Calculation: 
#     ((B19001H_014 + B19001H_015 + B19001H_016 + B19001H_017) - 
#       ((B19001_002 + B19001_003 + B19001_004 + B19001_005) - 
#         (B19001H_002 + B19001H_003 + B19001H_004 + B19001H_005))) / B19001_001
acs_racial_ses_ICE <- get_acs(geography = 'tract',
                   variables = c(paste0('B19001H_0',c(14,15,16,17)),
                                 paste0('B19001_00',c(2,3,4,5)),
                                 paste0('B19001H_00',c(2,3,4,5))),
                   summary_var = 'B19001_001',
                   year = 2019,
                   state = states_needed) %>%
  group_by(GEOID) %>%
  summarize(n_diff = sum(estimate[variable=='B19001H_014'],estimate[variable=='B19001H_015'],estimate[variable=='B19001H_016'],estimate[variable=='B19001H_017'])-
                    (sum(estimate[variable=='B19001_002'],estimate[variable=='B19001_003'],estimate[variable=='B19001_004'],estimate[variable=='B19001_005']) -
                    sum(estimate[variable=='B19001H_002'],estimate[variable=='B19001H_003'],estimate[variable=='B19001H_004'],estimate[variable=='B19001H_005'])),
            total = unique(summary_est)) %>%
  mutate(acs_racial_socioeconomic_ice = n_diff / total) %>%
  select(GEOID, acs_racial_socioeconomic_ice)

#=========================================================
## crowding: fraction households with >1 person per room
#=========================================================
# B25014: Tenure by Occupants Per Room
# B25014_001: total
# B25014_{005 - 007}: n with more than one occupants per room (owner occupied)
# B25014_{011 - 013}: n with more than one occupants per room (renter occupied)
# Calculation: 
#     (B25014_005 + B25014_006 + B25014_007 + B25014_011 + B25014_012 + B25014_013) / B25014_001
acs_crowding <- get_acs(geography = 'tract',
                        variables = c(paste0('B25014_00',c(5,6,7)),
                                      paste0('B25014_0',c(11,12,13))),
                        summary_var = 'B25014_001',
                        year = 2019,
                        state = states_needed) %>%
  group_by(GEOID) %>%
  summarize(n_gt_one = sum(estimate),
            total = unique(summary_est)) %>%
  mutate(acs_crowding = n_gt_one / total) %>%
  select(GEOID, acs_crowding)


## merge all acs variables in to data
acs_data <- reduce(.x = list(acs_public_assistance, acs_poverty, acs_unemployment,
                      acs_income, acs_racial_ICE, acs_vacant_housing,
                      acs_edu, acs_vehicle, acs_ins, 
                      acs_racial_ses_ICE, acs_crowding),
            .f = function(.x, .y) left_join(.x, .y, by='GEOID')) %>%
  rename(census_tract_fips = GEOID)

saveRDS(acs_data, './Data/bySource/acs.rds')

write_csv(acs_data, file="./Data/bySource/acs.csv")



#### get data readily available at tract level -----------------------------------

#============================
# material deprivation index
#============================

dep_index <- 'https://github.com/geomarker-io/dep_index/raw/master/2018_dep_index/ACS_deprivation_index_by_census_tracts.rds' %>% 
  url() %>% 
  gzcon() %>% 
  readRDS() %>% 
  as_tibble()

dep_index <- dep_index %>% 
  select(census_tract_fips, dep_index)

saveRDS(dep_index, './Data/bySource/dep_index.rds')


#==========================
# child opportunity index
#==========================

url <- "https://data.diversitydatakids.org/datastore/zip/080cfe52-90aa-4925-beaa-90efb04ab7fb?format=csv"
destfile <- "Data/bySource/coi.zip"
download.file(url, destfile=destfile, mode = "wb")

unzip('Data/bySource/coi.zip', exdir = 'Data/bySource')
unlink('Data/bySource/coi.zip')

d <- read_csv('Data/bySource/index.csv')

coi <- d %>%
  filter(year == 2015) %>%
  select(census_tract_fips = geoid,
         coi_education = z_ED_nat,
         coi_health_env = z_HE_nat,
         coi_social_econ = z_SE_nat,
         coi = z_COI_nat)

saveRDS(d, 'Data/bySource/coi.rds')

# n = 72213 rows


#==========================
# community resilience
#==========================

url <- "https://www2.census.gov/programs-surveys/demo/datasets/community-resilience/2019/CRE_19_Tract.csv"
destfile <- "Data/bySource/resilience.csv"
download.file(url, destfile=destfile, mode = "wb")

d <- read_csv('data/bySource/resilience.csv')

resilience <- d %>%
  mutate(census_tract_fips = glue::glue('{STATE}{COUNTY}{TRACT}')) %>%
  select(census_tract_fips,
         resilience_pct_1or2_risk_factors = PRED12_PE,
         resilience_pct_3ormore_risk_factors = PRED3_PE)

saveRDS(d, 'data/resilience.rds')

# n = 73056 rows


#==========================
# social deprivation index
#==========================

url <- "https://www.graham-center.org/content/dam/rgc/documents/maps-data-tools/sdi/ACS2015_CTallvars.xlsx"
destfile <- "./Data/bySource/SDI2015.xlsx"

download.file(url, destfile=destfile, mode = "wb")

d <- read_excel('./Data/bySource/SDI2015.xlsx')

sdi <- d %>% 
  mutate(CT_char = as.character(CT)) %>% 
  mutate(census_tract_fips = ifelse(str_length(CT_char) == 10, 
                                    str_c("0", CT_char, sep = ""), 
                                    CT_char)) %>% 
  select(census_tract_fips, sdi = sdi_score)

saveRDS(d, 'Data/bySource/sdi.rds')

# n = 73056 rows 


#============================
# social vulnerability index
#============================

url <- "https://svi.cdc.gov/Documents/Data/2018_SVI_Data/CSV/SVI2018_US.csv"
destfile <- "Data/bySource/SVI2018.csv"

download.file(url, destfile=destfile, mode = "wb")

# note: -999 denotes NA
d <- read_csv('Data/bySource/SVI2018.csv', na=c("-999", "-999.0"))

svi <- d %>% 
  select(census_tract_fips = FIPS,
         svi_socioeconomic = RPL_THEME1,
         svi_household_comp = RPL_THEME2,
         svi_minority = RPL_THEME3,
         svi_housing_transportation = RPL_THEME4,
         svi = RPL_THEMES)

saveRDS(d, 'Data/bySource/svi.rds')

# n = 72837 rows


#========================================
# modified retail food environment index 
#========================================

url <- "https://stacks.cdc.gov/view/cdc/61367/cdc_61367_DS2.xls"
destfile <- "Data/bySource/mRFEI.xls"

download.file(url, destfile=destfile, mode = "wb")

d <- read_excel('Data/bySource/mRFEI.xls')

mrfei2000 <- d %>% 
  select(census_tract_id_2000 = fips,
         mrfei2000=mrfei)
# N=65345

# 2000 to 2010 mapping
cw <- readRDS("./Data/2000_to_2010_tract_cw.rds")
# N2000 = 65167 and N2010 = 72739

mrfei <- mrfei2000 %>%
  left_join(cw, by = "census_tract_id_2000") %>%
  mutate(mrfei2010 = mrfei2000 * weight_inverse) %>%
  group_by(census_tract_id_2010) %>%
  summarize(mrfei = sum(mrfei2010)) %>% 
  rename(census_tract_fips = census_tract_id_2010)
# N = 71490

saveRDS(mrfei, 'Data/bySource/mrfei.rds')



#============================
# USDA food atlas
#============================

url <- "https://www.ers.usda.gov/webdocs/DataFiles/80591/FoodAccessResearchAtlasData2019.xlsx?v=5255"
destfile <- "Data/bySource/food_atlas.xlsx"

download.file(url, destfile=destfile, mode = "wb")

d <- read_excel('Data/bySource/food_atlas.xlsx', sheet = 3, na = c("NULL"))

food_atlas <- d %>%
  select(census_tract_fips = CensusTract,
         low_food_access_flag = LA1and10,
         low_food_access_pop = LAPOP1_10,
         total_pop = Pop2010) %>%
  mutate(usda_low_food_access_flag = ifelse(low_food_access_flag == 1, 1, 0),  # 1='Yes'/0='No'
         usda_low_food_access_pct = round(low_food_access_pop/total_pop * 100)) %>%
  select(census_tract_fips, usda_low_food_access_flag, usda_low_food_access_pct)

saveRDS(d, 'data/bySource/food_atlas.rds')

# n = 72531 rows


#=============================
# medically underserved areas
#=============================
# subsection: shortage areas
# Medically Underserved Areas/Populations (MUA/P)
# Medically Underserved Areas/Populations are areas or populations designated by HRSA as
# having too few primary care providers, high infant mortality, high poverty or a high elderly population.
# https://data.hrsa.gov/tools/shortage-area/mua-find#:~:text=Medically%20Underserved%20Areas%2FPopulations%20are,or%20a%20high%20elderly%20population.
# In this analysis, limit to Medically Underserved Areas; exclude Medically Underserved Populations

url <- "https://data.hrsa.gov/DataDownload/DD_Files/MUA_DET.csv"
destfile <- "Data/bySource/MUA.csv"

download.file(url, destfile=destfile, mode = "wb")

d <- read_csv('Data/bySource/MUA.csv')

d <- d %>% 
  filter(`MUA/P Status Code` %in% c("P", "D")) %>%  # keep only designated and proposed for withdrawal 
  filter(`Designation Type Code` %in% c("MUA", "MUA-GE")) %>%  # keep Medically Underserved Area; exclude MU population 
  mutate(mua = 'Yes') %>% 
  select(census_tract_fips = `MUA/P Area Code`,
         state_county_fips = `State and County Federal Information Processing Standard Code`,
         csd = `County Subdivision FIPS Code`,
         geo_type = `Medically Underserved Area/Population (MUA/P) Component Geographic Type Description`,
         mua)

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

csd <- map(states$NAME, ~tigris::county_subdivisions(state = .x, year=2010)) %>%
  bind_rows() %>%
  select(csd = GEOID10)

tracts <- map(states$NAME, ~tigris::tracts(state = .x, year=2010)) %>%
  bind_rows() %>%
  select(census_tract_fips = GEOID10)

csd_mua <- left_join(d.cs, csd) %>%
  st_as_sf()

mua_tracts_overlaps <- st_join(tracts, csd_mua, join = st_overlaps)
mua_tracts_contains <- st_join(tracts, csd_mua, join = st_contains)
mua_tracts_within <- st_join(tracts, csd_mua, join = st_within)

mua_tracts <- mua_tracts_overlaps %>%
  left_join(mua_tracts_contains %>% st_drop_geometry(), by = 'census_tract_fips') %>%
  left_join(mua_tracts_within %>% st_drop_geometry(), by = 'census_tract_fips')

mua_tracts <- mua_tracts %>%
  mutate(overlaps_csd_mua = ifelse(mua.cs.x == "Yes" | mua.cs.y == "Yes" | mua.cs == "Yes", "Yes", "No"),
         overlaps_csd_mua = ifelse(is.na(overlaps_csd_mua), "No", overlaps_csd_mua)) %>%
  select(census_tract_fips, overlaps_csd_mua) %>% 
  filter(!duplicated(census_tract_fips))

t <- mua_tracts %>%
  filter(substr(census_tract_fips, 1, 2) == '18')

#mapview::mapview(t, zcol = 'overlaps_csd_mua') +
#  mapview::mapview(csd_mua)

mua_tracts <- mua_tracts %>%
  st_drop_geometry()

saveRDS(mua_tracts, './Data/bySource/mua_csd_overlap_tract_2010.rds')


mua_csd_overlap <- readRDS('./Data/bySource/mua_csd_overlap_tract_2010.rds')


#-------------------------------------------------------------------------
## merge tract level / single county level / county subdivision level data
#-------------------------------------------------------------------------
mua <- full_join(all_tracts, d.ct, by='census_tract_fips') %>% # n=73058
  left_join(., d.sc, by='state_county_fips') %>%  # left join county level data    
  left_join(., mua_csd_overlap, by="census_tract_fips") %>%    # left join county subdivision data
  mutate(mua = ifelse(mua.ct=="Yes" | mua.sc=="Yes" | overlaps_csd_mua=="Yes", 1, 0), #1='Yes' / 0='No'
         mua = ifelse(is.na(mua), 0, mua))  %>% 
  select(census_tract_fips, mua) 
#73058

saveRDS(mua, 'Data/bySource/mua.rds')


#=================================
# Merge all files in this section
#=================================

ct_data <- reduce(.x = list(dep_index, coi, resilience,
                      sdi, svi, mrfei, food_atlas, mua),
            .f = function(.x, .y) full_join(.x, .y, by='census_tract_fips')) 

saveRDS(ct_data, './Data/bySource/ct_data.rds')

write_csv(ct_data, file="./Data/bySource/ct_data.csv")

# check number of obs merged
dim(full_join(dep_index, coi, by='census_tract_fips') %>%  
      full_join(., resilience, by='census_tract_fips') %>%  # n=73081
      full_join(., sdi, by='census_tract_fips') %>%  # n=73081
      full_join(., svi, by='census_tract_fips') %>%  # n=73081
      full_join(., food_atlas, by='census_tract_fips')%>%  # n=73081 
      full_join(., mrfei, by='census_tract_fips')%>%  # n=73082 
      full_join(., mua, by='census_tract_fips')) # n=73083



#### get data readily available at other geography -----------------------------------

#=============================
# EJ Screen
#=============================

options(timeout=1000)
url <- "https://gaftp.epa.gov/EJSCREEN/2020/EJSCREEN_2020_USPR.csv.zip"
destfile <- "data/bySource/ejscreen.zip"

download.file(url, destfile=destfile, mode = "wb")

unzip('data/bySource/ejscreen.zip', exdir = 'data/bySource')
unlink('data/bySource/ejscreen.zip')

d <- read_csv('data/bySource/EJSCREEN_2020_USPR.csv')

ejs <- d %>%
  select(block_group_fips = ID,
         ej_lead_paint = PRE1960PCT, # % pre-1960 housing (lead paint indicator)
         ej_diesel_pm = DSLPM,       # Diesel particulate matter level in air
         ej_cancer_risk = CANCER,    # Air toxics cancer risk
         ej_resp_hazard_ind = RESP,  # Air toxics respiratory hazard index
         ej_traffic_proximity = PTRAF,  # Traffic proximity and volume
         ej_major_discharger_water = PWDIS,  # Indicator for major direct dischargers to water
         ej_nat_priority_proximity = PNPL,   # Proximity to National Priorities List (NPL) sites
         ej_risk_management_proximity = PRMP,# Proximity to Risk Management Plan (RMP) facilities
         ej_disposal_proximity = PTSDF,      # Proximity to Treatment Storage and Disposal (TSDF) facilities
         ej_ozone_conc = OZONE,     # Ozone level in air
         ej_pm_conc = PM25)         # PM2.5 level in air

ejs <- ejs %>%
  mutate(census_tract_fips = stringr::str_sub(block_group_fips, 1, 11)) %>%
  group_by(census_tract_fips) %>%
  summarize_if(is.numeric, ~mean(.x))
# N=74001


#ejs <- ejs %>%
#  mutate(census_tract_fips = stringr::str_sub(block_group_fips, 1, 11)) %>%
#  group_by(census_tract_fips) %>%
#  summarize_if(is.numeric, ~mean(.x, na.rm=TRUE))

# ej_traffic_proximity n NAs drops from 7007 to 2659
# ej_major_discharger_water n NAs drops from 29730 to 20179

saveRDS(ejs, 'data/bySource/ej_screen.rds')


#======================================
# Food insecurity - feedingamerica.org
#======================================
# Data have to be requested; not directly downloadable

d <- read_excel("./Data/bySource/FANO Projections - March 2021 - Food Insecurity - v2.xlsx", sheet = ' County - 2020 Projections')

# range(str_length(food_ins$FIPS[1:dim(food_ins)[1]]))
# updated FIPS
food_ins <- d %>% 
  mutate(FIPS_char = as.character(FIPS)) %>% 
  mutate(state_county_fips = ifelse(str_length(FIPS_char) == 4, 
                                    str_c("0", FIPS_char, sep = ""), 
                                    FIPS_char)) %>% 
  select(state_county_fips, food_insecurity_pct = `2019 Food Insecurity %`)

# merge food_ins county level data with all_tracts to get tract level data
food_ins <- left_join(all_tracts, food_ins, by='state_county_fips') %>%  
  select(census_tract_fips, food_insecurity_pct) 
# N=73057; if full join n=73059

saveRDS(food_ins, 'data/bySource/food_insecurity.rds')

#=================================
# Merge all files in this section
#=================================

og_data <- full_join(ejs, food_ins, by='census_tract_fips') #n=74027

saveRDS(og_data, 'data/bySource/og_data.rds')




#### Merge all data sets -----------------------------------

acs_data <- readRDS("./Data/bySource/acs.rds")
ct_data <- readRDS("./Data/bySource/ct_data.rds")
og_data <- readRDS("./Data/bySource/og_data.rds")

data2010 <- reduce(.x = list(all_tracts, acs_data, ct_data, og_data),
            .f = function(.x, .y) left_join(.x, .y, by='census_tract_fips')) 

#> dim(acs_data)
#[1] 73056    12
#> dim(ct_data)
#[1] 73083    18
#> dim(og_data)
#[1] 74027    13

saveRDS(data2010, './Data/census_track_level_data_2010.rds')

write_csv(data2010, file="./Data/census_track_level_data_2010.csv")



#### Update 2010 census tracts to 2020 census tracts -----------------------------------

cw <- readRDS("Data/2010_to_2020_tract_cw.rds")

# Update all variables
data2010 <- readRDS("./Data/census_track_level_data_2010.rds")

data2020 <- data2010 %>%
  rename(census_tract_fips_2010=census_tract_fips) %>%
  left_join(cw, by = "census_tract_fips_2010") %>%
  mutate(across(acs_public_assistance_rate:food_insecurity_pct, ~ .x * weight_inverse)) %>%
  group_by(census_tract_fips_2020) %>%
  summarize(across(acs_public_assistance_rate:food_insecurity_pct, sum)) %>% 
  mutate(mua = ifelse(is.na(mua), 0, mua),
         usda_low_food_access_flag = ifelse(is.na(usda_low_food_access_flag), 0, usda_low_food_access_flag))
  rename(census_tract_fips = census_tract_fips_2020) 

saveRDS(data2020, 'Data/census_track_level_data_2020.rds')

write_csv(data2010, file="./Data/census_track_level_data_2020.csv")


