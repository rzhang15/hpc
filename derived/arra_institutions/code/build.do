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
	construct_trt_control
	
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

program construct_trt_control

	use "$derived_output/clean_mri/mri_compute_grants.dta", clear 
	
	* Don't keep following main disciplines
	drop if inlist(disciplines, "data storage", "networks", "data visualization", "data center")
	drop if !in_ipeds
	
	sort ipeds_id start_year
	bys ipeds_id: egen min_year = min(start_year) 
	bys ipeds_id: egen max_year = max(start_year)
	
	* Exclude institutions that receive cluster in 2005-2008 
	gen ind_2005_2008 = inrange(start_year, 2005, 2008)
	bys ipeds_id: egen inst_2005_2008 = max(ind_2005_2008)
	
	* Exclude institutions that receive cluster in 2011-2017 
	gen ind_2011_2017 = inrange(start_year, 2011, 2017)
	bys ipeds_id: egen inst_2011_2017 = max(ind_2011_2017)
	
	* Indicator for MRI being relatively isolated event in a window
	bys ipeds_id (start_year): gen last_mri_year = start_year[_n-1]
	gen long_last_mri = (start_year - last_mri_year >= 8) | mi(last_mri_year)
	
	bys ipeds_id (start_year): gen next_mri_year = start_year[_n+1]
	gen long_next_mri = (next_mri_year - start_year >= 8) | (mi(next_mri_year) & start_year <= 2020)
	
	save "$derived_output/clean_mri/mri_compute_grants_indicators.dta", replace
	
end 

main
