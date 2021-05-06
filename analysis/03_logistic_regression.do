/*==============================================================================
DO FILE NAME:			03_logistic_regression  
PROJECT:				Vaccine Characteristics 
DATE: 					5 May 2021 
AUTHOR:					A Schultze 
								
DESCRIPTION OF FILE:	program 03, odds of having VTE history by vaccine type
						output to a textfile for further formatting
						
DATASETS USED:			output/tempdata/study_population.dta
DATASETS CREATED: 		NA
OTHER OUTPUT: 		    table 2, printed to folder output/tables
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
log using "`c(pwd)'/output/logs/03_logistic_regression.log", replace 

* IMPORT DATA=================================================================*/ 

use `c(pwd)'/`inputfile', clear

/* RUN LOGISTIC REGRESSION AND SAVE RESULTS===================================*/

logistic any_vte vaccine_type 
estimates save `c(pwd)'/output/tempdata/univar, replace 

logistic any_vte vaccine_type i.agegroup
estimates save `c(pwd)'/output/tempdata/multivar, replace 


/* Print table================================================================*/ 
*  Print the results for the main model 

cap file close tablecontent
file open tablecontent using `c(pwd)'/output/tables/table2.txt, write text replace

* Column headings 
file write tablecontent ("Table 2: Association between Vaccination Status and VTE History") _n
file write tablecontent _tab _tab ("Univariable") _tab _tab ("Age Adjusted") _tab  _tab _n
file write tablecontent _tab ("OR") _tab ("95% CI") _tab ("OR") _tab ("95% CI") _n				

* Row headings 
local lab1: label vaccine_type 1
local lab2: label vaccine_type 2

file write tablecontent ("`lab1'") _tab ("1.00") _tab _tab ("1.00") _tab _n     
file write tablecontent ("`lab2'") _tab   


/* Main Model */ 
estimates use `c(pwd)'/output/tempdata/univar
matrix m1 = r(table)
matrix list m1
file write tablecontent %4.2f (m1[1,1]) _tab %4.2f (m1[5,1]) (" - ") %4.2f (m1[6,1]) _tab    
      
estimates use `c(pwd)'/output/tempdata/multivar
matrix m2 = r(table)
matrix list m2
file write tablecontent %4.2f (m2[1,1]) _tab %4.2f (m2[5,1]) (" - ") %4.2f (m2[6,1]) _tab 

file close tablecontent

* Close log file 
log close
    
