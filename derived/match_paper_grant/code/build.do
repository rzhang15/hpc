set more off
clear all
capture log close
program drop _all
set scheme modern
version 18
global dropbox_dir "~/dropbox (harvard university)/scientific equipment"

* Ruby's macros 
global dropbox_dir "$sci_equip"
cd "$github/hpc/derived/match_paper_grant/code"

global raw "${dropbox_dir}/raw"
global derived_output "${dropbox_dir}/derived_output_hpc"

program main 

// 	openalex_grant_match
	match_author_list
	
end 

program openalex_grant_match

	clear all 
	set obs 1 
	gen counter = .
	save "${derived_output}/openalex_grant/paper_nsf_grant.dta", replace 

	local folderList : dir "${derived_output}/" dirs "pull_openalex_*"
	
	foreach folder of local folderList {
		
		use "${derived_output}/`folder'/grants_all_jrnls_merged.dta", clear 
			
			replace award_id = ustrtrim(award_id)
			replace award_id = "" if award_id == "NA"
			replace award_id = subinstr(award_id, " ", "", .)
			replace award_id = subinstr(award_id, "-", "", .)
			replace award_id = subinstr(award_id, ",", "", .)
			replace award_id = subinstr(award_id, "#", "", .)
			
			* Identify NSF 
			replace funder_name = ustrtrim(lower(funder_name))
			gen nsf = (funder_name == "national science foundation")
			replace nsf = 1 if (strpos(funder_name, "division of") == 1)
			replace nsf = 1 if (strpos(funder_name, "office of") == 1)
			
			gen last8_is_numeric = regexm(award_id, "[0-9]{8}$")
			gen last7_is_numeric = regexm(award_id, "[0-9]{7}$")
			
			keep if (nsf == 1) | (last8_is_numeric == 0 & last7_is_numeric == 1)
			
			gen award_full = award_id 
			
			replace award_id = substr(award_id, 1, 11)
			replace award_id = substr(award_id, length(award_id)-6, 7)
			destring award_id, replace force 
			
			drop if mi(award_id) 
			drop *is_numeric which_grant nsf funder*
			
			duplicates drop
	
		append using "${derived_output}/openalex_grant/paper_nsf_grant.dta"
		save "${derived_output}/openalex_grant/paper_nsf_grant.dta", replace 
	}
	
	drop if mi(id) 
	drop counter 
	duplicates drop
	
	isid id award_full, missok
	save "${derived_output}/openalex_grant/paper_nsf_grant.dta", replace 

end 

program match_author_list

	* Merge in institution name based on labeled ARRA institutions
	import excel "$derived_output/arra_institutions/mri_institutions_openalex_xwalk.xlsx", firstrow clear
	gen inst_id = upper(openalex_id) 
	drop openalex_id 
	drop if mi(inst_id) | mi(ipeds_id)
	
	merge 1:m ipeds_id using "$derived_output/clean_mri/mri_compute_grants.dta", nogen keep(matched)
	
	merge 1:m award_id using "${derived_output}/openalex_grant/paper_nsf_grant.dta", nogen keep(matched)
		
	save "${derived_output}/openalex_grant/matched_papers_mri_grant.dta", replace 
	
	* Merge onto author data
	keep id inst_id ipeds_id
	ren inst_id mri_inst_id 
	duplicates drop 
		
	merge 1:m id using "${derived_output}/uni_openalex_panel/uni_all_papers.dta", nogen keep(matched) keepusing(inst_id athr_id athr_name athr_pos)
	
	sort id athr_pos inst_id 
	keep if inst_id == mri_inst_id
	
	keep inst_id ipeds_id athr_id athr_name 
	duplicates drop 
	
	isid athr_id
	save "${derived_output}/author_openalex_panel/author_list.dta", replace

end 

main
