set more off
clear all
capture log close
program drop _all
set scheme modern
version 18
set maxvar 120000, perm 
global dropbox_dir "~/dropbox (harvard university)/scientific equipment"

* Ruby's macros 
global dropbox_dir "$sci_equip"
cd "$github/hpc/analysis/author_event_study/code"

global raw "${dropbox_dir}/raw"
global derived_output "${dropbox_dir}/derived_output_hpc"

program main   
    
	create_event_study_panel
	event_study
end

program create_event_study_panel
    
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
	gen long_last_mri = (start_year - last_mri_year >= 5) | mi(last_mri_year)
	
	bys ipeds_id (start_year): gen next_mri_year = start_year[_n+1]
	gen long_next_mri = (next_mri_year - start_year >= 5) | (mi(next_mri_year) & start_year <= 2020)
	
	* Code as track 1 or track 2 
	gen track_1 = inrange(award_amt, 100000, 1400000)
	gen track_2 = (award_amt > 1400000)
	
	* Restrict to possible events with 2005 to 2015 data, see 3 years of data pre- and post-
	keep if inrange(start_year, 2007, 2013) | min_year > 2018
	keep if long_last_mri & long_next_mri 
	
	* Ensure that each school is treated only once 
	gen control = (min_year > 2018)
	drop if control & (start_year != min_year)
	
	isid ipeds_id 
	
	* Merge onto the uni papers panel 
	merge 1:m ipeds_id using "${derived_output}/author_openalex_panel/author_papers_panel.dta", nogen keep(matched)
	
	* Stretch out into a panel and relative treatment variable
	gen start_month = mofd(date(startdate, "MDY"))
	format start_month %tm 
	
	gen start_quarter = qofd(date(startdate, "MDY"))
	format start_quarter %tq
	
	gen rel_time = (time - start_year) 
	replace rel_time = . if control == 1
	
	* Additional conditions that we can change 
// 	drop if !mi(xsede)
// 	keep if track_1
		
	gen compute = strpos(disciplines, "interdisciplinary") > 0 | strpos(disciplines, "comput") > 0 | strpos(disciplines, "nlp") > 0 | strpos(disciplines, "cyber") > 0
	
	gen physics = strpos(disciplines, "interdisciplinary") > 0 | strpos(disciplines, "physics") > 0
	replace physics = strpos(abstract, "physics") > 0
	
	save "../temp/event_study_panel", replace
	
end

program event_study 

	use "../temp/event_study_panel", clear
	
		ren subfield_id* subfield_id
		
	* Plot with corresponding fields 	
	eventdd num_paper_wt i.time, timevar(rel_time) method(hdfe, absorb(athr_id) cluster(athr_id)) lags(2) leads(2) keepbal(athr_id)
	
end 

main
