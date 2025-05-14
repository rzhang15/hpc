set more off
clear all
capture log close
program drop _all
set scheme modern
version 18

* Ruby's macros 
global dropbox_dir "$dissertation"

global raw "${dropbox_dir}/raw"
global derived_output "${dropbox_dir}/derived_output_hpc"

program main 

// 	append_openalex_data
	build_uni_panel
	
end 

program append_openalex_data

	clear all 
	set obs 1 
	gen counter = .
	save "${derived_output}/uni_openalex_panel/uni_all_papers.dta", replace 

	local folderList : dir "${derived_output}/" dirs "pull_openalex*"
	
	foreach folder of local folderList {
		
		use "${derived_output}/`folder'/topics_all_jrnls_merged.dta", clear 
		
			keep if which_topic == "1" 
			duplicates drop 
			isid id 
			
		merge 1:m id using "${derived_output}/`folder'/openalex_all_jrnls_merged.dta", nogen assert(matched)
		
			gen date = date(pub_date, "YMD")
			format date %td 
			
			drop abstract_len doi jrnl title retracted pub_type pub_type_crossref 
			drop pmid which_athr inst which_affl n mi_inst has_nonmi_inst which_athr_counter 
			drop raw_affl num_which_athr min_which_athr author_id pub_date 

			duplicates drop 
			bys id athr_id: gen num_inst = _N 
					
		append using "${derived_output}/uni_openalex_panel/uni_all_papers.dta"
		save "${derived_output}/uni_openalex_panel/uni_all_papers.dta", replace 
	}
	
	* Merge in institution name based on labeled ARRA institutions
	import excel "$derived_output/arra_institutions/mri_institutions_openalex_xwalk.xlsx", firstrow clear
	gen inst_id = upper(openalex_id) 
	drop openalex_id 
	
	drop if mi(inst_id) 
	merge 1:m inst_id using "${derived_output}/uni_openalex_panel/uni_all_papers.dta", nogen
	
	drop if mi(inst_id)
	drop if mi(id)
	drop counter 
	
	bys id: egen citations = max(cite_count) 
	drop cite_count 
	duplicates drop 
	
	save "${derived_output}/uni_openalex_panel/uni_all_papers.dta", replace 

end 

program build_uni_panel

	use "${derived_output}/uni_openalex_panel/uni_all_papers.dta", clear
	
		keep if athr_pos == "last"
		drop athr_name athr_id
		keep if !mi(ipeds_id)
		
		gen num_paper = 1 / num_inst 
		
		* Weight annual citations (according to March 1, 2025)
		gen end_date = date("2025-03-01", "YMD")
		gen yr_since_publish = (end_date - date) / 365
		gen num_cite = citations / yr_since_publish
		
		gen date_month = mofd(date)
		format date_month %tm
		
		gen date_quarter = qofd(date)
		format date_quarter %tq
		
		gen time = date_quarter
		
		duplicates drop
		isid id ipeds_id
				
	collapse (rawsum) num_paper num_cite (sum) num_paper_wt = num_paper [iw = num_cite], ///
			by(inst_id ipeds_id name state subfield_id time)
	
	gsort ipeds_id subfield_id* time 
	isid ipeds_id subfield_id* time
	
	merge m:1 ipeds_id using "$derived_output/arra_institutions/mri_institutions_sample.dta", nogen assert(matched using) keep(matched)
		
	save "${derived_output}/uni_openalex_panel/uni_papers_panel.dta", replace

end 

main 
