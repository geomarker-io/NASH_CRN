data/states.rds:
	Rscript R/make_tracts.R

data/tracts.rds: 
	Rscript R/make_tracts.R

data/acs.rds: data/states.rds
	Rscript R/make_acs_data.R

data/ejscreen.rds:
	Rscript R/make_ejscreen_data.R

data/2000_to_2010_tract_cw.rds:
	Rscript R/make_2000_to_2010_cw.R

data/food.rds: data/2000_to_2010_tract_cw.rds
	Rscript R/make_food_data.R

data/index.rds: 
	Rscript R/make_index_data.R

# data/mua.rds: 
# 	Rscript R/make_mua_data.R

data/nash_crn_census_data_2010.rds: data/tracts.rds data/acs.rds data/ejscreen.rds data/food.rds data/index.rds
	Rscript R/join_all_saved_data.R

data/2010_to_2020_tract_cw.rds:
	Rscript R/make_2010_to_2020_cw.R

data/nash_crn_census_data_2020.rds: data/2010_to_2020_tract_cw.rds
	Rscript R/transform_data_to_2020_census_tract_geography.R

rds: data/nash_crn_census_data_2010.rds data/nash_crn_census_data_2020.rds csv

csv: rds
	R -e "write.csv(readRDS('data/nash_crn_census_data_2010.rds'), 'data/nash_crn_census_data_2010.csv', row.names = F)"
	R -e "write.csv(readRDS('data/nash_crn_census_data_2020.rds'), 'data/nash_crn_census_data_2020.csv', row.names = F)"

all: rds csv

clean:
	rm -rfv raw-data
