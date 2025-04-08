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
cd "$github/hpc/analysis/uni_event_study/code"

global raw "${dropbox_dir}/raw"
global derived_output "${dropbox_dir}/derived_output_hpc"

program main   
    
	create_event_study_panel
// 	event_study_all_schools
	event_study_subset_schools
	
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
	
// 	* Restrict see 3 years of data pre- and post-
// 	keep if inrange(start_year, 2010, 2022) | min_year > 2018
// 	keep if long_last_mri & long_next_mri 
//	
// 	* Ensure that each school is treated only once 
	gen control = (min_year > 2022)
	drop if control & (start_year != min_year)
	
	keep if inlist(award_id, 959097,1626364,960081,960354,1919789,1229081,1828315,1040196,1531492,1228509,2117681,2318210,2320292,2117575,1228312) 
	
	* Merge onto the uni papers panel 
	merge 1:m ipeds_id using "${derived_output}/uni_openalex_panel/uni_papers_panel.dta", nogen keep(matched)
	
	* Stretch out into a panel and relative treatment variable
	gen start_month = mofd(date(startdate, "MDY"))
	format start_month %tm 
	
	gen start_quarter = qofd(date(startdate, "MDY"))
	format start_quarter %tq
	
	gen rel_time = (time - start_quarter) 
	replace rel_time = . if control == 1
	
	* Additional conditions that we can change 
// 	drop if !mi(xsede)
// 	keep if track_1
		
	gen compute = strpos(disciplines, "interdisciplinary") > 0 | strpos(disciplines, "comput") > 0 | strpos(disciplines, "nlp") > 0 | strpos(disciplines, "cyber") > 0
	
	gen physics = strpos(disciplines, "interdisciplinary") > 0 | strpos(disciplines, "physics") > 0
	replace physics = strpos(abstract, "physics") > 0
	
	gen biology = strpos(disciplines, "interdisciplinary") > 0 | strpos(disciplines, "biology") > 0
	
	gen interdisciplinary = strpos(disciplines, "interdisciplinary") > 0 
	
	save "../temp/event_study_panel", replace
	
end

program event_study_all_schools 

	use "../temp/event_study_panel", clear
	
		ren subfield_id* subfield_id
		
	* Plot with corresponding fields 	
	eventdd num_paper_wt i.time if compute & subfield_id == "1702", timevar(rel_time) method(hdfe, absorb(ipeds_id) cluster(ipeds_id)) lags(20) leads(20) accum
	count if rel_time == 0 & compute & subfield_id == "1702"
	
	eventdd num_paper_wt i.time if physics & subfield_id == "3107", timevar(rel_time) method(hdfe, absorb(ipeds_id) cluster(ipeds_id)) lags(20) leads(20) accum 
	count if rel_time == 0 & physics & subfield_id == "3107"
	
	eventdd num_paper_wt i.time if biology & subfield_id == "1312", timevar(rel_time) method(hdfe, absorb(ipeds_id) cluster(ipeds_id)) lags(20) leads(20) accum 
	
end 

program event_study_subset_schools

	use "../temp/event_study_panel", clear
	
		ren subfield_id* subfield_id
		
	eventdd num_paper_wt i.time if subfield_id == "3103", timevar(rel_time) method(hdfe, absorb(ipeds_id) cluster(ipeds_id)) lags(20) leads(20) accum

end 

main
