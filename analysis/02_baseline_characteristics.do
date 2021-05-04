/*==============================================================================
DO FILE NAME:			02_baseline_characteristics 
PROJECT:				Vaccine Characteristics 
DATE: 					21 April 2021 
AUTHOR:					A Schultze (adapted from ICS study) 
								
DESCRIPTION OF FILE:	program 02, study characteristics 
						Produce a table of baseline characteristics, by exposure
						Generalised to produce same columns as levels of exposure
						Output to a textfile for further formatting
						
DATASETS USED:			output/tempdata/study_population.dta
DATASETS CREATED: 		NA
OTHER OUTPUT: 		    table 1, printed to folder output/tables
						logfile, printed to folder output/logs 

							
==============================================================================*/

/* HOUSEKEEPING===============================================================*/

* use input and output file names from project.yaml 
local inputfile `1'
local outputfile `2'

* create folders that do not exist on server 
capture	mkdir "`c(pwd)'/output/tables"
capture	mkdir "`c(pwd)'/output/logs"
capture	mkdir "`c(pwd)'/output/tempdata"

* set ado path
adopath + "`c(pwd)'/analysis/extra_ados"

* open a log file
cap log close
log using "`c(pwd)'/output/logs/02_baseline_characteristics.log", replace 

* IMPORT DATA=================================================================*/ 

use `c(pwd)'/`inputfile', clear

/* PROGRAMS TO AUTOMATE TABULATIONS===========================================*/ 

********************************************************************************
* All code for categorical variables from K Bhaskaran 
* Generic code to output one row within the table 

/* Explanatory Notes 
the syntax row specifies two inputs for the program: 
	a VARNAME which is your variable that you would like to tabulate, stratified 
	by the exposure 
	a LEVEL which is only used to extract a value label to print 
	a CONDITION which is a string of some condition you impose 
	
the program counts if variable and condition and returns the counts
column percentages are then automatically generated
this is then written to the text file 'tablecontent' 

*/ 

cap prog drop generaterow
program define generaterow
syntax, variable(varname) [level(string)] condition(string) 

	* indent once for first row, two for others 
	if ("`level'" != "") & ("`level'" != "1") {
		file write tablecontent _tab
	} 
	else if ("`level'" == "") {
			file write tablecontent _tab
	} 
	
	* print a value label at beginning of row 
	if ("`level'" != "") { 
			local vlab: label `variable' `level'
			file write tablecontent ("`vlab'") _tab 
			}
	else {
			file write tablecontent ("missing") _tab
			}
	
	* create denominator and print total 
	qui count
	local overalldenom=r(N)
	
	* total column
	qui count if `variable' `condition'
	local rowdenom = r(N)
	local colpct = 100*(r(N)/`overalldenom')
	file write tablecontent %15.0gc (`rowdenom')  (" (") %3.2f (`colpct') (")") _tab

	* first exposure value 
	qui count if vaccine_type == 1 
	local rowdenom = r(N)
	qui count if vaccine_type == 1 & `variable' `condition'
	local pct = 100*(r(N)/`rowdenom') 
	file write tablecontent %15.0gc (r(N)) (" (") %3.2f (`pct') (")") _tab

	* second exposure value 
	qui count if vaccine_type == 2
	local rowdenom = r(N)
	qui count if vaccine_type == 2 & `variable' `condition'
	local pct = 100*(r(N)/`rowdenom')
	file write tablecontent %15.0gc (r(N)) (" (") %3.2f  (`pct') (")") _n
	
end

* Generic code to output one section (varible) within table (calls above)

/* Explanatory Notes 
defines program tabulate variable 
syntax is : 

	- a VARNAME which is your variable of interest 
	- a numeric minimum (min value of your variable you want to tabulate)
	- a numeric maximum (max value of your variable you want to tabulate)
	- optional missing option, default value is no missing  
	
for values lowest to highest of the variable, the program then calls the 
generate row program defined above to generate a row 
if there is a missing specified, then run the generate row for missing vals
*/ 

cap prog drop tabulatevariable
prog define tabulatevariable
syntax, variable(varname) min(real) max(real) [missing]
	
	local lab: variable label `variable'
	file write tablecontent ("`lab'") _tab 

	forvalues varlevel = `min'/`max'{ 
		generaterow, variable(`variable') level(`varlevel') condition("==`varlevel'")
	}
	
	if "`missing'"!="" generaterow, variable(`variable') condition(">=.")

end

* Generic code to summarise a continuous variable 

cap prog drop summarizevariable 
prog define summarizevariable
syntax, variable(varname) 

	local lab: variable label `variable'
	file write tablecontent ("`lab'") _tab
	
	qui summarize `variable', d
	file write tablecontent ("Median (IQR)") _tab 
	file write tablecontent (round(r(p50)),0.01) (" (") (round(r(p25)),0.01) ("-") (round(r(p75)),0.01) (")") _tab
							
	qui summarize `variable' if vaccine_type == 1, d
	file write tablecontent (round(r(p50)),0.01) (" (") (round(r(p25)),0.01) ("-") (round(r(p75)),0.01) (")") _tab

	qui summarize `variable' if vaccine_type == 2, d
	file write tablecontent (round(r(p50)),0.01) (" (") (round(r(p25)),0.01) ("-") (round(r(p75)),0.01) (")") _n
	
	qui summarize `variable', d
	file write tablecontent _tab ("Min, Max") _tab 
	file write tablecontent (round(r(min)),0.01) (", ") (round(r(max)),0.01) ("") _tab
							
	qui summarize `variable' if vaccine_type == 1, d
	file write tablecontent (round(r(min)),0.01) (", ") (round(r(max)),0.01) ("") _tab

	qui summarize `variable' if vaccine_type == 2, d
	file write tablecontent (round(r(min)), 0.01) (", ") (round(r(max)),0.01) ("") _n
	
end


/* INVOKE PROGRAMS FOR TABLE 1================================================*/ 
* include cross tabs in log for QC 

*Set up output file
cap file close tablecontent
file open tablecontent using `c(pwd)'/output/tables/table1.txt, write text replace

file write tablecontent ("Table 1: Demographic and Clinical Characteristics by Vaccine Type") _n

* Exposure labelled columns

local lab1: label vaccine 1
local lab2: label vaccine 2

di "`lab1'"

file write tablecontent _tab _tab   ("Total")			    _tab ///
									("`lab1'")			   	_tab ///
									("`lab2'")  			_n

* DEMOGRAPHICS (more than one level, potentially missing) 

gen byte cons=1
tabulatevariable, variable(cons) min(1) max(1) 
file write tablecontent _n 

safetab vaccine_type

tabulatevariable, variable(agegroup) min(1) max(6) 
file write tablecontent _n 

safetab vaccine_type agegroup, col 

tabulatevariable, variable(male) min(1) max(2) 
file write tablecontent _n 

safetab vaccine_type male, col

tabulatevariable, variable(ethnicity) min(1) max(5) missing 
file write tablecontent _n 

safetab vaccine_type ethnicity, col 

tabulatevariable, variable(imd) min(1) max(5) missing
file write tablecontent _n 

safetab vaccine_type imd, col 

tabulatevariable, variable(bmicat) min(1) max(3) missing
file write tablecontent _n 

safetab vaccine_type bmicat, col 

tabulatevariable, variable(care_home) min(1) max(3) missing
file write tablecontent _n 

safetab vaccine_type care_home, col  

* VTE variables (binary)

foreach varlist in  dvt					    ///
					pe					    ///
					cvt_vte				    ///
					portal_vte			    ///
					smv_vte				    ///
					hepatic_vte 			///
				    vc_vte					///
					other_vte			    ///
					unspecified_vte		    ///
					any_vte  			    ///
					recent_dvt				///
					recent_pe				///
					recent_cvt				///
					recent_portal			///
					recent_smv				///
					recent_hepatic			///
					recent_vc				///
					recent_other 			///
					recent_unspecified		///
					recent_any  {
						
						tabulatevariable, variable(`varlist') min(1) max(1)
						
						safetab vaccine_type `varlist', col
	
					}
	
file write tablecontent _n _n

* VTE variables (continuous)

foreach varlist in time_since_dvt 				///	
                   time_since_pe                ///
                   time_since_cvt               ///
                   time_since_portal            ///
                   time_since_smv               ///
                   time_since_hepatic           ///
				   time_since_vc				///
                   time_since_other             ///
                   time_since_unspecified       ///
                   time_since_any    {
				   	
						summarizevariable, variable(`varlist')
						summarize `variable' if vaccine_type == 1
						summarize `variable' if vaccine_type == 2
					
				   }	

file close tablecontent

* COMORBIDITIES [PLACEHOLDER]

* Close log file 
log close


