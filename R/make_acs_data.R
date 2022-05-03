library(dplyr)
library(tidyr)
library(tidycensus)
options(timeout = 1000)

states <- readRDS("data/states.rds")

acs <- list()

acs$public_assistance <- get_acs(
  geography = "tract",
  variables = "B19057_002",
  summary_var = "B19057_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  mutate(acs_public_assistance_rate = estimate / summary_est) %>%
  select(GEOID, acs_public_assistance_rate)

acs$poverty <- get_acs(
  geography = "tract",
  variables = "B17001_002",
  summary_var = "B17001_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  mutate(acs_poverty_rate = estimate / summary_est) %>%
  select(GEOID, acs_poverty_rate)

acs$unemployment <- get_acs(
  geography = "tract",
  variables = "B23025_007",
  summary_var = "B23025_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  mutate(acs_unemployment_rate = estimate / summary_est) %>%
  select(GEOID, acs_unemployment_rate)

acs$income <- get_acs(
  geography = "tract",
  variables = "B19013_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  mutate(acs_median_income = estimate) %>%
  select(GEOID, acs_median_income)

acs$vacant_housing <- get_acs(
  geography = "tract",
  variables = "B25002_003",
  summary_var = "B25002_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  mutate(acs_vacant_housing_rate = estimate / summary_est) %>%
  select(GEOID, acs_vacant_housing_rate)

acs$hs_edu <- get_acs(
  geography = "tract",
  variables = paste0("B15003_0", 17:25),
  summary_var = "B15003_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  group_by(GEOID) %>%
  summarize(
    high_school_edu = sum(estimate),
    total = unique(summary_est)
  ) %>%
  mutate(acs_fraction_hs_edu = high_school_edu / total) %>%
  select(GEOID, acs_fraction_hs_edu)

acs$no_vehicle <- get_acs(
  geography = "tract",
  variables = "B08201_002",
  summary_var = "B08201_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  mutate(acs_fraction_no_vehicle = estimate / summary_est) %>%
  select(GEOID, acs_fraction_no_vehicle)

acs$no_health_ins <- get_acs(
  geography = "tract",
  variables = paste0("B27010_0", c(17, 33, 50, 66)),
  summary_var = "B27010_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  group_by(GEOID) %>%
  summarize(
    no_health_ins = sum(estimate),
    total = unique(summary_est)
  ) %>%
  mutate(acs_fraction_no_health_ins = no_health_ins / total) %>%
  select(GEOID, acs_fraction_no_health_ins)

acs$racial_ice <- get_acs(
  geography = "tract",
  variables = c("B03002_003", "B03002_004"),
  summary_var = "B03002_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  group_by(GEOID) %>%
  summarize(
    n_diff = estimate[variable == "B03002_003"] - estimate[variable == "B03002_004"],
    total = unique(summary_est)
  ) %>%
  mutate(acs_racial_ice = n_diff / total) %>%
  select(GEOID, acs_racial_ice)

acs$racial_ses_ice <- get_acs(
  geography = "tract",
  variables = c(
    paste0("B19001H_0", c(14, 15, 16, 17)),
    paste0("B19001_00", c(2, 3, 4, 5)),
    paste0("B19001H_00", c(2, 3, 4, 5))
  ),
  summary_var = "B19001_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  group_by(GEOID) %>%
  summarize(
    n_diff = sum(
      estimate[variable == "B19001H_014"],
      estimate[variable == "B19001H_015"],
      estimate[variable == "B19001H_016"],
      estimate[variable == "B19001H_017"]
    ) -
      (sum(
        estimate[variable == "B19001_002"],
        estimate[variable == "B19001_003"],
        estimate[variable == "B19001_004"],
        estimate[variable == "B19001_005"]
      ) -
        sum(
          estimate[variable == "B19001H_002"],
          estimate[variable == "B19001H_003"],
          estimate[variable == "B19001H_004"],
          estimate[variable == "B19001H_005"]
        )),
    total = unique(summary_est)
  ) %>%
  mutate(acs_racial_socioeconomic_ice = n_diff / total) %>%
  select(GEOID, acs_racial_socioeconomic_ice)

acs$crowding <- get_acs(
  geography = "tract",
  variables = c(
    paste0("B25014_00", c(5, 6, 7)),
    paste0("B25014_0", c(11, 12, 13))
  ),
  summary_var = "B25014_001",
  year = 2019,
  state = states
) %>%
  unique() %>%
  group_by(GEOID) %>%
  summarize(
    n_gt_one = sum(estimate),
    total = unique(summary_est)
  ) %>%
  mutate(acs_crowding = n_gt_one / total) %>%
  select(GEOID, acs_crowding)

acs_data <-
  purrr::reduce(acs, full_join, by = "GEOID") %>%
  rename(census_tract_fips = GEOID)

saveRDS(acs_data, "data/acs.rds")
