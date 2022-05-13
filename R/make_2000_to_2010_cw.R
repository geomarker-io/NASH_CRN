.cran_packages <- c("tidyverse", "sf")
.inst <- .cran_packages %in% installed.packages()
if(any(!.inst)) {
  install.packages(.cran_packages[!.inst], repos = "http://cran.us.r-project.org")
}


library(tidyverse)
library(sf)

d_states_abb <- tigris::states() %>%
  sf::st_drop_geometry() %>%
  filter(!NAME %in% c(
    "American Samoa", "Guam", "Northern Mariana Islands",
    "Puerto Rico", "U.S. Minor Outlying Islands",
    "U.S. Virgin Islands", "United States Virgin Islands",
    "Commonwealth of the Northern Mariana Islands"
  )) %>%
  select(
    abb = STUSPS,
    fips = GEOID
  ) %>%
  mutate(abb = tolower(abb))

states_abb <- glue::glue("{d_states_abb$abb}{d_states_abb$fips}")
dwnld_url <- glue::glue("https://www2.census.gov/geo/docs/maps-data/data/rel/trf_txt/{states_abb}trf.txt")
dir.create("raw-data/2000_2010_cw", showWarnings = FALSE)
dest <- glue::glue("raw-data/2000_2010_cw/{d_states_abb$abb}.txt")

purrr::walk2(dwnld_url, dest, ~ download.file(.x, destfile = .y))

cw_col_names <- c(
  "STATE00",
  "COUNTY00",
  "TRACT00",
  "GEOID00",
  "POP00",
  "HU00",
  "PART00",
  "AREA00",
  "AREALAND00",
  "STATE10",
  "COUNTY10",
  "TRACT10",
  "GEOID10",
  "POP10",
  "HU10",
  "PART10",
  "AREA10",
  "AREALAND10",
  "AREAPT",
  "AREALANDPT",
  "AREAPCT00PT",
  "AREALANDPCT00PT",
  "AREAPCT10PT",
  "AREALANDPCT10PT",
  "POP10PT",
  "POPPCT00",
  "POPPCT10",
  "HU10PT",
  "HUPCT00",
  "HUPCT10"
)

cw <- purrr::map(dest, ~ read_delim(.x,
  delim = ",", col_names = cw_col_names,
  col_types = list(
    col_character(),
    col_character(),
    col_character(),
    col_character(),
    col_double(),
    col_double(),
    col_character(),
    col_double(),
    col_character(),
    col_character(),
    col_character(),
    col_character(),
    col_character(),
    col_double(),
    col_double(),
    col_character(),
    col_double(), col_double(), col_double(),
    col_double(), col_double(), col_double(),
    col_double(), col_double(), col_double(),
    col_double(), col_double(), col_double(),
    col_double(), col_double()
  )
))

cw <- bind_rows(cw)

cw <- cw %>%
  select(
    census_tract_id_2000 = GEOID00,
    census_tract_id_2010 = GEOID10,
    weight_inverse = AREALANDPCT10PT
  ) %>%
  mutate(weight_inverse = weight_inverse / 100) %>%
  filter(weight_inverse > 0.05)

# adjustment so that weights from one tract add up to one
cw_sum <- cw %>%
  group_by(census_tract_id_2010) %>%
  summarize(weight_inverse_sum = sum(weight_inverse))

cw <- left_join(cw, cw_sum, by = "census_tract_id_2010") %>%
  mutate(weight_inverse = weight_inverse / weight_inverse_sum) %>%
  select(-weight_inverse_sum)

saveRDS(cw, "data/2000_to_2010_tract_cw.rds")
