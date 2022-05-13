.cran_packages <- c("dplyr")
.inst <- .cran_packages %in% installed.packages()
if(any(!.inst)) {
  install.packages(.cran_packages[!.inst], repos = "http://cran.us.r-project.org")
}

library(dplyr)
options(timeout = 1000)

url <- "https://gaftp.epa.gov/EJSCREEN/2020/EJSCREEN_2020_USPR.csv.zip"
dir.create("raw-data", showWarnings = FALSE)
destfile <- "raw-data/ejscreen.zip"
download.file(url, destfile = destfile, mode = "wb")
unzip("raw-data/ejscreen.zip", exdir = "raw-data")
unlink("raw-data/ejscreen.zip")

d <- readr::read_csv("raw-data/EJSCREEN_2020_USPR.csv")

ejs <-
  d %>%
  select(
    block_group_fips = ID,
    ej_lead_paint = PRE1960PCT, # % pre-1960 housing (lead paint indicator)
    ej_diesel_pm = DSLPM, # Diesel particulate matter level in air
    ej_cancer_risk = CANCER, # Air toxics cancer risk
    ej_resp_hazard_ind = RESP, # Air toxics respiratory hazard index
    ej_traffic_proximity = PTRAF, # Traffic proximity and volume
    ej_major_discharger_water = PWDIS, # Indicator for major direct dischargers to water
    ej_nat_priority_proximity = PNPL, # Proximity to National Priorities List (NPL) sites
    ej_risk_management_proximity = PRMP, # Proximity to Risk Management Plan (RMP) facilities
    ej_disposal_proximity = PTSDF, # Proximity to Treatment Storage and Disposal (TSDF) facilities
    ej_ozone_conc = OZONE, # Ozone level in air
    ej_pm_conc = PM25
  ) # PM2.5 level in air

ejs <- ejs %>%
  mutate(census_tract_fips = stringr::str_sub(block_group_fips, 1, 11)) %>%
  group_by(census_tract_fips) %>%
  summarize_if(is.numeric, ~ mean(.x, na.rm = TRUE))

saveRDS(ejs, "data/ejscreen.rds")
