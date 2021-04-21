/*==============================================================================
DO FILE NAME:			00_data_management 
PROJECT:				Vaccine Characteristics 
DATE: 					20 April 2021 
AUTHOR:					A Schultze (based on code from K Bhaskaran, E Williamson and A Wong)
								
DESCRIPTION OF FILE:	program 00, data management 
						reformat variables 
						categorise variables
						label variables 
						
DATASETS USED:			output/input.csv
DATASETS CREATED: 		output/tempdata/tempdata.csv
OTHER OUTPUT: 			logfile, printed to folder output/logs 
							
==============================================================================*/

/* HOUSEKEEPING===============================================================*/

* use input and output file names from project.yaml 
local inputfile `1'
local outputfile `2'

di "`inputfile'"
di "`outputfile'"

* set directories that exist 
global projectdir `c(pwd)'
di "$projectdir"
global outdir "$projectdir/output" 
di "$outdir"

* create folders that do not exist on server 
capture	mkdir "$outdir/tables"
capture	mkdir "$outdir/output/plots"
capture	mkdir "$outdir/output/logs"
capture	mkdir "$outdir/output/tempdata"

* set ado path
adopath + "$projectdir/analysis/extra_ados"

* open a log file
cap log close
log using `c(pwd)'/output/00_data_management.log, replace 


* IMPORT DATA=================================================================*/ 

import delimited `c(pwd)'/`inputfile', clear

* DATA CLEANING===============================================================*/ 

* VACCINES 
  
* convert string variables to date 

foreach var of varlist any_covid_vaccine_date ///
					   pfizer_covid_vaccine_date /// 
					   az_covid_vaccine_date { 
					   	
						capture confirm string variable `var'
						rename `var' _tmp
						gen `var' = date(_tmp, "YMD")
						drop _tmp
						format %d `var'
							
					   }

* logical checks on dates (use datacheck instead of assert to enable run on dummy data)
* include nolist option to avoid printing out patient level data to the log in case of contradiction 

datacheck any_covid_vaccine_date != . if pfizer_covid_vaccine_date != ., nolist 
datacheck any_covid_vaccine_date != . if az_covid_vaccine_date != ., nolist 
datacheck az_covid_vaccine_date != pfizer_covid_vaccine_date if az_covid_vaccine_date != ., nolist 

datacheck any_covid_vaccine_date <= az_covid_vaccine_date if az_covid_vaccine_date != ., nolist  
datacheck any_covid_vaccine_date <= pfizer_covid_vaccine_date if pfizer_covid_vaccine_date != ., nolist 

gen vaccine_date_check = min(pfizer_covid_vaccine_date, az_covid_vaccine_date)
datacheck vaccine_date_check == any_covid_vaccine_date, nolist 

* [PLACEHOLDER - data cleaning if more than one vaccine at same date]

* generate vaccine variables 
gen any_covid_vaccine = (any_covid_vaccine_date != .) 
gen any_pfizer_vaccine = (pfizer_covid_vaccine_date != .) 
gen any_az_vaccine = (az_covid_vaccine_date != .) 

tab any_covid_vaccine any_pfizer_vaccine
tab any_covid_vaccine any_az_vaccine
tab any_pfizer_vaccine any_az_vaccine

* type of vaccine at first dose 
gen vaccine_type = "Pfizer" if pfizer_covid_vaccine_date == any_covid_vaccine_date & pfizer_covid_vaccine_date != . 
replace vaccine_type = "AZ" if az_covid_vaccine_date == any_covid_vaccine_date & az_covid_vaccine_date != . 

tab vaccine_type, m
summarize(any_covid_vaccine_date), format 

* [PLACEHOLDER - data cleaning if missing vaccine type]

* VTE TYPE 
* Convert dates (need to add hospital categorisation)
foreach var of varlist dvt_gp dvt_hospital ///
					   pe_gp pe_hospital ///
					   cvt_gp ///
					   portal_gp ///
					   smv_gp ///
					   hepatic_gp ///
					   unspecified_gp ///
					   other_gp { 
					   	
					    capture confirm string variable `var'
						rename `var' _tmp
						gen `var' = date(_tmp, "YMD")
						drop _tmp
						format %d `var'
						
					   }
* dvt 
tab dvt 
label define dvt 1 "Yes" 0 "No"
label values dvt dvt 

* pe 
tab pe 
label define pe 1 "Yes" 0 "No"
label values pe pe 

* generate indicator variables (note: code not needed when ICD-10 codes available)
gen cvt = . 
gen portal = . 
gen smv = . 
gen hepatic = . 
gen unspecified = . 
gen other = . 

foreach var of varlist cvt portal smv hepatic unspecified other { 
	
	replace `var' = (`var'_gp != .)
	label define `var' 1 "Yes" 0 "No"
	label values `var' `var' 
}

* any vte 
gen any_vte = max(dvt, pe, cvt, portal, smv, hepatic, unspecified, other)

* time since most recent thrombotic event
* max will ignore missing unless all values missing 
* ADD IN HOSPITAL FOR FINAL RUN AND MAKE THIS A MAX STATAMENT 
foreach var of varlist dvt pe cvt portal smv hepatic unspecified other { 
	
	gen time_since_`var'= `var'_gp

}

gen ime_since_any = max(time_since_dvt, time_since_pe, time_since_cvt, time_since_portal, time_since_smv, time_since_hepatic, time_since_unspecified, time_since_other)

* event in last three months? 
foreach var of varlist dvt pe cvt portal smv hepatic unspecified other { 
	
	gen recent_`var'= 1 if ((any_covid_vaccine_date - time_since_`var') <= 90)
	replace recent_`var'= 0 if recent_`var' == . 

}

* DEMOGRAPHICS 

* Sex
gen male = 1 if sex == "M"
replace male = 0 if sex == "F"

* Ethnicity 
/* classified as White, South Asian, Black, Mixed, Other, Not Known
https://codelists.opensafely.org/codelist/opensafely/ethnicity/2020-04-27/ */ 
replace ethnicity = .u if ethnicity == .

label define ethnicity 	1 "White"  					///
						2 "Mixed" 					///
						3 "Asian or Asian British"	///
						4 "Black"  					///
						5 "Other"					///
						.u "Unknown"

label values ethnicity ethnicity

* IMD 
* grouping is done in the study_definition 
label define imd 1 "1 least deprived" 2 "2" 3 "3" 4 "4" 5 "5 most deprived" .u "Unknown"
label values imd imd 

* Age 
* classified as 16-49, 50-64, 65-69, 70-74, 75-79, or 80-105 years 
gen     agegroup=1 if age>=16 & age<49
replace agegroup=2 if age>=50 & age<64
replace agegroup=3 if age>=65 & age<69
replace agegroup=4 if age>=70 & age<74
replace agegroup=5 if age>=75 & age<79
replace agegroup=6 if age>=80

label define agegroup 	1 "18-<40" ///
						2 "40-<50" ///
						3 "50-<60" ///
						4 "60-<70" ///
						5 "70-<80" ///
						6 "80+"
						
label values agegroup agegroup

* Body Mass Index  
/* based on latest Body Mass Index (BMI) and classified as 30-39, or 40+ kg/m2. Individuals with missing BMI measurements will be classified as being normal weight (BMI less than 30). */ 

* recode strange values 
replace bmi = . if bmi == 0 
replace bmi = . if !inrange(bmi, 15, 50)

* generate categories 
gen 	bmicat = .
recode  bmicat . = 1 if bmi < 30 
recode  bmicat . = 2 if bmi < 40 
recode  bmicat . = 3 if bmi < .
replace bmicat = .u if bmi >= .

label define bmicat 1 "Normal (<30)" 	///
					2 "Obese I - II"    ///
					3 "Obese III (40+)" ///
					.u "Unknown (.u)"
					
label values bmicat bmicat

* Care Home Status 
datacheck inlist(care_home_type, "CareHome", "NursingHome", "CareOrNursingHome", "PrivateHome", "")

* Create a binary varaible 
gen care_home = 0 if care_home_type == "PrivateHome"
replace care_home = 1 if care_home_type != "" & care_home_type != "PrivateHome"  
replace care_home = .u if care_home >= .

label define care_home 1 "Care or Nursing Home" 0 "Private Home" .u "Missing"
label values care_home care_home 

tab care_home care_home_type 

* OTHER CLINICAL COMORBIDITIES 

* [PLACEHOLDER]


* EXPORT DATA=================================================================*/ 

save `c(pwd)'/output/`outputfile', replace 

* CLOSE LOG===================================================================*/ 

log close
