# NASH CRN Data

April 26, 2022

## Data definitions

1.	GEOID 
a.	GEOID should be a character variable with str_length=11.
b.	Current data set uses variable name, census_tract_fips, for GEOID.
c.	leading "0" in GEOID is lost if a csv file is opened using excel.
2.	Before data merge, process data set from each data source separately,
a.	Adding mode="wb" for windows downloading in function download.file(). E.g., download.file(url, destfile=destfile, mode = "wb").
b.	Data at different levels (tracts, single county, county subdivision) have to be consisted to the census tract level
i.	For data at single county level, map to tract level by merging county level data using state+county FIPS with a mapping file containing state+county FIPS and census tract FIPS as variables (MUA and food insecurity data).
ii.	For data at county subdivision level, since there is no nested relationship between county subdivision and census tracts, the mapping requires tract-level spatial overlays for the whole country. 
c.	Consist across data sources the year of census tract fips used. Data from current data sources are consisted to the 2010 census tracts before merging (mrfei data are mapped from 2000 to 2010 census tracts).
d.	Files read from local folder: Food insecurity data from feedingamerica.org. Data file downloading has to be requested.
e.	SVI data set: -999 and -999.0 are used as NA.
f.	Medically underserved areas (MUA): 
i.	Limit to “Medically Underserved Areas”, excluding “Medically Underserved Populations.”
ii.	Keep only MUA/P Status designated or proposed for withdrawal.
3.	During data merge, 
a.	Left_join data sets from different sources to 2010 tigris::tracts, excluding the following areas: United States Virgin Islands, Commonwealth of the Northern Mariana Islands, Guam, American Samoa, and Puerto Rico.
4.	After data merge,
a.	Save the final data set in both rds and csv format.
b.	Map the final data set from 2010 to 2020 census tracts based on census tract crosswalk. All variables need to be recalculated for 2020 census tracts using weights. 
c.	Keep numeric representations of dichotomous variables. E.g., 
census_tract_fips_2020 census_tract_fips_2010 AREALAND_PART AREALAND_TRACT_20 weight_inverse mua
1 06085504424            06085504417                  8591682          25455452          0.338 1
2 06085504424            06085504420                 16847398          25455452          0.662 0
> subset(data2020, census_tract_fips =='06085504424')$mua_num
[1] 0.3375183
d.	Handle NA: usda_low_food_access_flag and mua were set to 0 if NA in the final data set.
5.	Census tract crosswalk:
a.	Census tract crosswalks describe how U.S. census tracts from one census year correspond to census tract from another year. The tracts could split or merge. Use the calculated weight inverse to calculate the new data values for the new tracts.
b.	Weight inverse calculation: weight_inverse = AREALAND_PART / AREALAND_TRACT_20
AREALAND_TRACT_20	Total Land area of 2020 tract in square meters
AREALAND_PART	Calculated Land area of the overlapping part in square meters
Source: 2020 Census Tract to 2010 Census Tract Relationship File Layout (https://www.census.gov/programs-surveys/geography/technical-documentation/records-layout/2020-comp-record-layout.html)
c.	New data value calculation based on weight inverse:
i.	Split: remain the same for the new census tracts.
ii.	Merge: a weighted sum of the merged tracts.
iii.	Minor boundary corrections / refinement (weight inverse < 0.05): not considering the refinement in new data value calculation by filtering out changes with weight inverse less than 0.05. After filtering, adjust weight inverses, so that the weights within each 2020 tract totaling 1.







