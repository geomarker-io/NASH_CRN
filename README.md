# NASH CRN Data

This group of R scripts is used to create a dataset for application of DeGAUSS in the NASH CRN. Run R scripts to compile geospatial data from multiple data sources at census tract level.

Data sources:

- American Community Survey (ACS)
- Material deprivation index - github.com/geomarker-io/dep_index
- Child opportunity index - data.diversitydatakids.org
- Community resilience - www.census.gov
- Social deprivation index - www.graham-center.org
- Social vulnerability index - www.atsdr.cdc.gov
- Modified retail food environment index - www.cdc.gov
- USDA food atlas - www.ers.usda.gov
- Medically Underserved Areas - data.hrsa.gov
- EJ Screen - gaftp.epa.gov
- Food insecurity - feedingamerica.org 

### Before Data Merge

- census_tract_fips is used to merge across data sources
  + Make sure the variable name, census_tract_fips, is consistently used and the variable type is character with length 11
  + The leading 0's in census_tract_fips are not displayed, if excel is used to open a saved csv file
- If using PC, add mode="wb" in function ```download.file()```. For example,
  ```
  download.file(url, destfile=destfile, mode = "wb")
  ```
- Map data at single county/county subdivision level to the census tract level
  + For data at single county level, map to tract level by merging county level data using state+county FIPS with a mapping file containing state+county FIPS and census tract FIPS as variables (MUA and food insecurity data)
  + For data at county subdivision level, since there is no nested relationship between county subdivision and census tract FIPS, the mapping requires tract-level spatial overlays for the whole country
- Make sure the year of census tract FIPS is consistent across data sources
  + Data from current data sources are consisted to the 2010 census tracts before merging (mrfei data mapped from 2000 to 2010 census tracts).
- Read food insecurity data from local folder, as data file downloading has to be requested from feedingamerica.org
- Social vulnerability index (SVI) data set: -999 and -999.0 are used as NA
- Medically underserved areas (MUA): 
  + Limit to “Medically Underserved Areas”, excluding “Medically Underserved Populations”
  + Keep only MUA/P Status designated or proposed for withdrawal
- EJ Screen: When mapping data from block group FIPS to census tract FIPS, variable values at census tract level are calculated by taking the mean across non-NA values at block levels:
  ```
  ejs <- ejs %>%
    mutate(census_tract_fips = stringr::str_sub(block_group_fips, 1, 11)) %>%
    group_by(census_tract_fips) %>%
    summarize_if(is.numeric, ~mean(.x, na.rm=TRUE))
  ```

###	During Data Merge

- Left_join data sets from different sources to 2010 tigris::tracts, excluding the following areas: United States Virgin Islands, Commonwealth of the Northern Mariana Islands, Guam, American Samoa, and Puerto Rico.

### After Data Merge

-	Save the final data set in both rds and csv format
-	Map the final data set from 2010 to 2020 census tracts based on census tract crosswalk. Recalculate all variables for the 2020 census tracts using weights
-	Keep numeric representations of dichotomous variables
- Handle NA: NAs in usda_low_food_access_flag and mua are set to 0
- Note that the variable, *ej_major_discharger_water*, has an extemely large value of 429574 at block group FIPS 461099407001

### Notes on Census Tract Crosswalk

- Census tract crosswalk describes how U.S. census tracts from one census year correspond to census tract from another year. The tracts could split or merge. Use the calculated weight inverse to calculate the new data values for the new tracts
-	Weight inverse calculation: ```weight_inverse = AREALAND_PART / AREALAND_TRACT_20``` (AREALAND_TRACT_20 = Total Land area of 2020 tract in square meters and  AREALAND_PART =	Calculated Land area of the overlapping part in square meters)
- New data value calculation based on weight inverse:
  + Split: remain the same for the new census tracts
  + Merge: a weighted sum of the merged tracts
  + Minor boundary corrections / refinement (weight inverse < 0.05): not considering the refinement in new data value calculation by filtering out changes with weight inverse less than 0.05. After filtering, adjust weight inverses, so that the weight inverses within each new tract totaling 1







