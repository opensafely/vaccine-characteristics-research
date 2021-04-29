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

* create folders that do not exist on server 
capture	mkdir "`c(pwd)'/output/logs"
capture	mkdir "`c(pwd)'/output/tempdata"

* set ado path
adopath + "$projectdir/analysis/extra_ados"

* open a log file
cap log close
log using "`c(pwd)'/output/logs/00_data_management.log", replace 


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
gen vaccine_type = 1 if pfizer_covid_vaccine_date == any_covid_vaccine_date & pfizer_covid_vaccine_date != . 
replace vaccine_type = 2 if az_covid_vaccine_date == any_covid_vaccine_date & az_covid_vaccine_date != . 

label define vaccine 1 "Pfizer" 2 "AstraZeneca"
label values vaccine_type vaccine 


tab vaccine_type, m
summarize(any_covid_vaccine_date), format 

* [PLACEHOLDER - data cleaning if missing vaccine type]

* VTE TYPE 
* Convert dates (need to add hospital categorisation)
foreach var of varlist dvt_gp dvt_hospital ///
					   pe_gp pe_hospital ///
					   cvt_vte_gp cvt_vte_hospital ///
					   portal_vte_gp portal_vte_hospital ///
					   smv_vte_gp ///
					   hepatic_vte_gp hepatic_vte_hospital ///
					   vc_vte_gp vc_vte_hospital ///
					   unspecified_vte_gp unspecified_vte_hospital ///
					   other_vte_gp { 
					   	
					    capture confirm string variable `var'
						rename `var' _tmp
						gen `var' = date(_tmp, "YMD")
						drop _tmp
						format %d `var'
						
					   }

* create indicator variables and apply labels 
foreach var of varlist dvt pe cvt_vte portal_vte hepatic_vte vc_vte unspecified_vte { 
	
	gen `var'_gp_any = (`var'_gp != .)
	gen `var'_hospital_any = (`var'_hospital != .)
	label define `var' 1 "Yes" 0 "No"
	label values `var' `var' 
	label values `var'_gp_any `var' 
	label values `var'_hospital_any `var' 
	
	* Basic cross tabulations for sense checking variables 
	
	safetab `var'_gp_any 
	safetab `var'_hospital_any
	safetab `var' 
	safetab `var'_gp_any `var'
	safetab `var'_hospital_any `var'
	safetab `var'_hospital_any `var'_gp_any 

}

* Handle SMV and other diiferently (only one source of information)

foreach var of varlist smv_vte other_vte { 
	
	label define `var' 1 "Yes" 0 "No"
	label values `var' `var' 

	safetab `var' 

}


* any vte 
gen any_vte = max(dvt, pe, cvt_vte, portal_vte, smv_vte, hepatic_vte, vc_vte, unspecified_vte, other_vte)
label define any_vte 1 "Yes" 0 "No"
label values any_vte any_vte 

* time since most recent thrombotic event (in months)
* max will ignore missing unless all values missing 
foreach var of varlist dvt pe cvt_vte portal_vte hepatic_vte vc_vte unspecified_vte { 
	
	gen latest_`var'= max(`var'_gp, `var'_hospital)
	gen time_since_`var'= (((any_covid_vaccine_date - latest_`var')/365.25)*12)

}

gen time_since_smv_vte = (((any_covid_vaccine_date - smv_vte_gp)/365.25)*12)
gen time_since_other_vte = (((any_covid_vaccine_date - other_vte_gp)/365.25)*12)

gen time_since_any = max(time_since_dvt, time_since_pe, time_since_cvt_vte, time_since_portal_vte, time_since_smv_vte, time_since_hepatic_vte, time_since_vc_vte, time_since_unspecified_vte, time_since_other_vte)

* event in last three months? 
foreach var of varlist dvt pe cvt_vte portal_vte smv_vte hepatic_vte vc_vte unspecified_vte other_vte { 
	
	gen recent_`var'= 1 if (time_since_`var' <= 3)
	replace recent_`var'= 0 if recent_`var' == . 
	label define recent_`var' 1 "Yes" 0 "No"
	label values recent_`var' recent_`var' 

}

gen recent_any = max(recent_dvt, recent_pe, recent_cvt_vte, recent_portal_vte, recent_smv_vte, recent_hepatic_vte, recent_vc_vte, recent_unspecified_vte, recent_other_vte)
label define recent_any 1 "Yes" 0 "No"
label values recent_any recent_any 

* DEMOGRAPHICS 

* Sex
gen male = 1 if sex == "M"
replace male = 2 if sex == "F"

label define male 1 "Yes" 2 "No"
label values male male 

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
replace care_home = 1 if care_home_type == "CareHome"  
replace care_home = 2 if care_home_type == "NursingHome"  
replace care_home = 3 if care_home_type == "CareOrNursingHome"  
replace care_home = .u if care_home >= .

label define care_home 3 "Care or Nursing Home" 2 "Nursing Home" 1 "Care Home" 0 "Private Home" .u "Missing"
label values care_home care_home 

safetab care_home care_home_type 

* OTHER CLINICAL COMORBIDITIES 

* [PLACEHOLDER]

* LABEL VARIABLES=============================================================*/ 

* Demographics
label var patient_id				"Patient ID"
label var age 						"Age (years)"
label var agegroup					"Grouped age"
label var sex 						"Sex"
label var male 						"Male"
label var bmi 						"Body Mass Index (BMI, kg/m2)"
label var bmicat 					"Grouped BMI"
label var imd 						"Index of Multiple Deprivation (IMD)"
label var ethnicity					"Ethnicity"

label var care_home_type 		    "Care Home Type"
label var care_home     		    "Care Home"

label var vaccine_type				"Type of COVID-19 Vaccine (First Dose)"

label var dvt						"DVT"
label var pe						"PE"
label var cvt_vte					"CVT"
label var portal_vte				"Portal"
label var smv_vte					"SMV"
label var hepatic_vte				"Hepatic" 
label var other_vte 				"Other"
label var vc_vte 					"Vena Cava"
label var unspecified_vte			"Unspecified"  
label var any_vte  					"Any VTE"

label var time_since_dvt 			"Months since latest DVT"
label var time_since_pe             "Months since latest PE"
label var time_since_cvt            "Months since latest CVT"
label var time_since_portal         "Months since latest Portal"
label var time_since_smv            "Months since latest SMV"
label var time_since_hepatic        "Months since latest Hepatic" 
label var time_since_vc       		"Months since latest Vena Cava" 
label var time_since_other          "Months since latest Other"
label var time_since_unspecified    "Months since latest Unspecified"  
label var time_since_any    		"Months since latest Any VTE"  

label var recent_dvt				"Recent DVT"
label var recent_pe                 "Recent PE"
label var recent_cvt                "Recent CVT"
label var recent_portal             "Recent Portal"
label var recent_smv                "Recent SMV"
label var recent_hepatic            "Recent Hepatic" 
label var recent_vc		            "Recent Vena Cava" 
label var recent_other              "Recent Other"
label var recent_unspecified        "Recent Unspecified"
label var recent_any		        "Recent Any VTE"  
									
* EXPORT DATA=================================================================*/ 

save `c(pwd)'/`outputfile', replace 

* CLOSE LOG===================================================================*/ 

log close
