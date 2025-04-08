set more off
clear all
capture log close
program drop _all
set scheme modern
version 18
global dropbox_dir "~/dropbox (harvard university)/scientific equipment"

* Ruby's macros 
global dropbox_dir "$sci_equip"
cd "$github/hpc/derived/explore_govspend/code"

global raw "${dropbox_dir}/raw"
global derived_output "${dropbox_dir}/derived_output_hpc"

program main 

	govspend_main_schools
	
end 

program govspend_main_schools

	use "$raw/GovSpend/Pre-2015 Sample Computing", clear 
	ren (ItemDescription PurchasingAgency normalizedname issueddate) ///
		(description school vendor date)
	
	replace vendor = ustrtrim(lower(vendor))
	drop if inlist(vendor, "illumina", "millipore", "vwr international", "fisher scientific", "philips healthcare", "siemens medical solutions usa")
	drop if strpos(lower(description), "crayola") > 0
	drop if strpos(lower(description), "crayfish") > 0
	drop if strpos(lower(description), "crayon") > 0
	
	keep description issuedamount date ponumber vendor school
	duplicates drop 
		
	bys ponumber description: gen num = _N 
	sort num ponumber description date issuedamount school 
	
	bys ponumber description (date issuedamount school): replace num = _n
	keep if num == 1 
	isid ponumber description
	
	bys ponumber (description): replace num = _n 
	keep if num == 1 
	isid ponumber
	
	* Clean vendor names
	foreach name in dell apple oracle cdw {
		replace vendor = "`name'" if strpos(vendor, "`name'") == 1
	}

	tab vendor, sort
	
	gen year = year(date)
	
	gen num_po = 1
	collapse (sum) issuedamount num_po, by(school year) 
	
	collapse (min) min_year = year (sum) issuedamount num_po, by(school)
	gsort min_year -num_po -issuedamount
	
	* From here, we can probably deduce which universities to focus on, and which year the data starts for them. as a rule of thumb, should focus on the big schools with many entries. 

end 

main 
