/*==============================================================================
DO FILE NAME:			01_study_population
PROJECT:				Vaccine Characteristics 
DATE: 					21 April 2021 
AUTHOR:					A Schultze (based on code from K Bhaskaran, E Williamson and A Wong)
								
DESCRIPTION OF FILE:	program 01, study_population
						drop individuals who do not meet inclusion/exclusion criteria
						
DATASETS USED:			output/tempdata.csv
DATASETS CREATED: 		output/tempdata/study_population.csv
OTHER OUTPUT: 			logfile, printed to folder output/logs 
							
==============================================================================*/

/*HOUSEKEEPING================================================================*/ 

* use input and output file names from project.yaml 
local inputfile `1'
local outputfile `2'
local outputfile2 `3'

* create folders that do not exist on server 
capture	mkdir "`c(pwd)'/output/logs"
capture	mkdir "`c(pwd)'/output/tempdata"

* set ado path
adopath + "`c(pwd)'/analysis/extra_ados"

* open a log file
cap log close
log using "`c(pwd)'/output/logs/01_study_population.log", replace 

* IMPORT DATA=================================================================*/ 

use `c(pwd)'/`inputfile', clear

* POPULATION SELECTION========================================================*/ 

* Known Gender
datacheck inlist(sex,"M", "F"), nolist

* Adult and known age 
datacheck age >= 16 & age <= 105, nolist

* Registration history and alive 

datacheck has_follow_up == 1, nolist
datacheck has_died == 0, nolist

* Known vaccine date
datacheck any_covid_vaccine_date != ., nolist 

* Known vaccine type 
datacheck inlist(vaccine_type, 1, 2, 3, .), nolist
noi di "DROP MISSING VACCINE TYPE"
drop if vaccine_type == 3 

* Not AZ & Pfizer at same date 
noi di "DROP DUPLICATE DATES"
drop if az_covid_vaccine_date == pfizer_covid_vaccine_date 

* Confirm one row per patient 
duplicates tag patient_id, generate(dup_check)
assert dup_check == 0 
drop dup_check

* EXPORT DATA=================================================================*/ 

save `c(pwd)'/`outputfile', replace
export delimited using `c(pwd)'/`outputfile2', replace 


* CLOSE LOG===================================================================*/ 

log close














