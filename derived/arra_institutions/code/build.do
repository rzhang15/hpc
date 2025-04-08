set more off
clear all
capture log close
program drop _all
set scheme modern
version 18
global dropbox_dir "~/dropbox (harvard university)/scientific equipment"

* Ruby's macros 
global dropbox_dir "$sci_equip"
cd "$github/hpc/derived/clean_mri/code"

global raw "${dropbox_dir}/raw"
global derived_output "${dropbox_dir}/derived_output_hpc"

program main 

	construct_sample_schools
	
end 

program construct_sample_schools 

	use "$derived_output/clean_mri/mri_compute_grants.dta", clear 
	
	* Keep list of schools that we want to look at 
	keep if inrange(start_year, 2005, 2024) 
	drop if inlist(disciplines, "data storage", "networks", "data visualization", "data center")
	drop if !in_ipeds
	
	gen num_grant = 1 
	gen min_year = start_year 
	gen max_year = start_year 
	
	gen total_award = award_amt 
	gen avg_award = award_amt 
	
	gen total_arra = arra_amt 
	gen avg_arra = arra_amt 
	
	gcollapse (sum) num_grant total_* (mean) avg_* (min) min_year (max) max_year, by(ipeds_id state)
	
	merge 1:1 ipeds_id using "$raw/Carnegie/carnegie_classification_clean.dta", nogen assert(matched using) keep(matched) keepusing(name serd stem_rsd ugtenr20 grtenr20 doctotaldeg totalrd carnegie2021 county)
	
	gsort -serd
	drop if _n < 15
	
	order ipeds_id name 
	export excel "$derived_output/arra_institutions/mri_institutions_sample.xlsx", firstrow(variables) replace
	
	save "$derived_output/arra_institutions/mri_institutions_sample.dta", replace

end

main
