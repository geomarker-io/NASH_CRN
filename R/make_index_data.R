.cran_packages <- c("dplyr")
.inst <- .cran_packages %in% installed.packages()
if(any(!.inst)) {
  install.packages(.cran_packages[!.inst], repos = "http://cran.us.r-project.org")
}

library(dplyr)
options(timeout = 1000)

index <- list()

index$dep_index <- "https://github.com/geomarker-io/dep_index/raw/master/2018_dep_index/ACS_deprivation_index_by_census_tracts.rds" %>%
  url() %>%
  gzcon() %>%
  readRDS() %>%
  as_tibble() %>%
  select(census_tract_fips, dep_index)

if (!file.exists("raw-data/index.csv")) {
  download.file(
    url = "https://data.diversitydatakids.org/datastore/zip/080cfe52-90aa-4925-beaa-90efb04ab7fb?format=csv",
    destfile = "raw-data/coi.zip",
    mode = "wb"
  )
  unzip("raw-data/coi.zip", exdir = "raw-data")
  unlink("raw-data/coi.zip")
}

index$coi <-
  readr::read_csv("raw-data/index.csv") %>%
  filter(year == 2015) %>%
  select(
    census_tract_fips = geoid,
    coi_education = z_ED_nat,
    coi_health_env = z_HE_nat,
    coi_social_econ = z_SE_nat,
    coi = z_COI_nat
  )

if (!file.exists("raw-data/resilience.csv")) {
  download.file(
    url = "https://www2.census.gov/programs-surveys/demo/datasets/community-resilience/2019/CRE_19_Tract.csv",
    destfile = "raw-data/resilience.csv",
    mode = "wb"
  )
}

index$resilience <-
  readr::read_csv("raw-data/resilience.csv") %>%
  mutate(census_tract_fips = glue::glue("{STATE}{COUNTY}{TRACT}")) %>%
  select(census_tract_fips,
    resilience_pct_1or2_risk_factors = PRED12_PE,
    resilience_pct_3ormore_risk_factors = PRED3_PE
  )

if (!file.exists("raw-data/SDI2015.xlsx")) {
  download.file(
    url = "https://www.graham-center.org/content/dam/rgc/documents/maps-data-tools/sdi/ACS2015_CTallvars.xlsx",
    destfile = "raw-data/SDI2015.xlsx",
    mode = "wb"
  )
}

index$sdi <-
  readxl::read_excel("raw-data/SDI2015.xlsx", col_types = "text") %>%
  select(census_tract_fips = CT, sdi = sdi_score) %>%
  mutate(sdi = as.numeric(sdi))

if (!file.exists("raw-data/SVI2018.csv")) {
  download.file(
    url = "https://svi.cdc.gov/Documents/Data/2018_SVI_Data/CSV/SVI2018_US.csv",
    destfile = "raw-data/SVI2018.csv",
    mode = "wb"
  )
}

index$svi <-
  readr::read_csv("raw-data/SVI2018.csv", na = c("-999", "-999.0")) %>%
  select(
    census_tract_fips = FIPS,
    svi_socioeconomic = RPL_THEME1,
    svi_household_comp = RPL_THEME2,
    svi_minority = RPL_THEME3,
    svi_housing_transportation = RPL_THEME4,
    svi = RPL_THEMES
  )

index_data <- purrr::reduce(index, full_join, by = "census_tract_fips")

saveRDS(index_data, "data/index.rds")
