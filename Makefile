all: data/nash_crn_census_data_2010.rds data/nash_crn_census_data_2020.rds csv
	echo "you did it!"

clean:
	rm -rfv raw-data

data/states.rds: R/make_tracts.R
	Rscript R/make_tracts.R

data/tracts.rds: R/make_tracts.R
	Rscript R/make_tracts.R

data/acs.rds: data/states.rds R/make_acs_data.R
	Rscript R/make_acs_data.R

data/ejscreen.rds: R/make_ejscreen_data.R
	Rscript R/make_ejscreen_data.R

data/2000_to_2010_tract_cw.rds: R/make_2000_to_2010_cw.R
	Rscript R/make_2000_to_2010_cw.R

data/food.rds: data/2000_to_2010_tract_cw.rds R/make_food_data.R
	Rscript R/make_food_data.R

data/index.rds: R/make_index_data.R
	Rscript R/make_index_data.R

data/mua.rds: Rscript R/make_mua_data.R 
	Rscript R/make_mua_data.R

data/nash_crn_census_data_2010.rds: data/tracts.rds data/acs.rds data/ejscreen.rds data/food.rds data/index.rds
	Rscript R/join_all_saved_data.R

data/2010_to_2020_tract_cw.rds: R/make_2010_to_2020_cw.R
	Rscript R/make_2010_to_2020_cw.R

data/nash_crn_census_data_2020.rds: data/2010_to_2020_tract_cw.rds R/transform_data_to_2020_census_tract_geography.R
	Rscript R/transform_data_to_2020_census_tract_geography.R

csv: data/nash_crn_census_data_2010.rds data/nash_crn_census_data_2020.rds
	R -e "write.csv(readRDS('data/nash_crn_census_data_2010.rds'), 'data/nash_crn_census_data_2010.csv', row.names = F)"
	R -e "write.csv(readRDS('data/nash_crn_census_data_2020.rds'), 'data/nash_crn_census_data_2020.csv', row.names = F)"
