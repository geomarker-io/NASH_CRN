.cran_packages <- c("dplyr")
.inst <- .cran_packages %in% installed.packages()
if(any(!.inst)) {
  install.packages(.cran_packages[!.inst], repos = "http://cran.us.r-project.org")
}

library(dplyr)

if (!file.exists("raw-data/mRFEI.xls")) {
  download.file(
    url = "https://stacks.cdc.gov/view/cdc/61367/cdc_61367_DS2.xls",
    destfile = "raw-data/mRFEI.xls",
    mode = "wb"
  )
}

cw <- readRDS("data/2000_to_2010_tract_cw.rds")

mrfei <-
  readxl::read_excel("raw-data/mRFEI.xls") %>%
  select(
    census_tract_id_2000 = fips,
    mrfei2000 = mrfei
  ) %>%
  left_join(cw, by = "census_tract_id_2000") %>%
  mutate(mrfei2010 = mrfei2000 * weight_inverse) %>%
  group_by(census_tract_id_2010) %>%
  summarize(mrfei = sum(mrfei2010)) %>%
  rename(census_tract_fips = census_tract_id_2010)

if (!file.exists("raw-data/food_atlas.xlsx")) {
  download.file(
    url = "https://www.ers.usda.gov/webdocs/DataFiles/80591/FoodAccessResearchAtlasData2019.xlsx?v=5255",
    destfile = "raw-data/food_atlas.xlsx",
    mode = "wb"
  )
}

food_atlas <-
  readxl::read_excel("raw-data/food_atlas.xlsx", sheet = 3, na = c("NULL")) %>%
  select(
    census_tract_fips = CensusTract,
    low_food_access_flag = LA1and10,
    low_food_access_pop = LAPOP1_10,
    total_pop = Pop2010
  ) %>%
  mutate(
    usda_low_food_access_flag = ifelse(low_food_access_flag == 1, 1, 0), # 1='Yes'/0='No'
    usda_low_food_access_pct = round(low_food_access_pop / total_pop * 100)
  ) %>%
  select(census_tract_fips, usda_low_food_access_flag, usda_low_food_access_pct)

# feedingamerica.org Data have to be requested; not directly downloadable
food_ins <-
  readxl::read_excel("data/source/fano_projections_march_2021_food_insecurity_v2.xlsx",
    sheet = " County - 2020 Projections"
  ) %>%
  mutate(FIPS_char = as.character(FIPS)) %>%
  mutate(state_county_fips = ifelse(stringr::str_length(FIPS_char) == 4,
    stringr::str_c("0", FIPS_char, sep = ""),
    FIPS_char
  )) %>%
  select(state_county_fips, food_insecurity_pct = `2019 Food Insecurity %`)

food_data <- full_join(mrfei, food_atlas, by = "census_tract_fips")

food_data <-
  food_data |>
  mutate(state_county_fips = substr(census_tract_fips, 1, 5)) |>
  full_join(food_ins, by = "state_county_fips") |>
  select(-state_county_fips)

saveRDS(food_data, "data/food.rds")
