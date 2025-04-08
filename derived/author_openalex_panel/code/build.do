set more off
clear all
capture log close
program drop _all
set scheme modern
version 18
global dropbox_dir "~/dropbox (harvard university)/scientific equipment"

* Ruby's macros 
global dropbox_dir "$sci_equip"
cd "$github/hpc/derived/author_openalex_panel/code"

global raw "${dropbox_dir}/raw"
global derived_output "${dropbox_dir}/derived_output_hpc"

program main 

	select_all_author_works
	
end 

program select_all_author_works

	use "${derived_output}/uni_openalex_panel/uni_all_papers.dta", clear
	
		drop athr_name ipeds_id name state 
	
	merge m:1 athr_id inst_id using "${derived_output}/author_openalex_panel/author_list.dta", nogen keep(matched)
			
// 		keep if inlist(athr_pos, "first", "last")
		gen num_paper = 1 /// num_inst 
		
		* Weight annual citations (according to March 1, 2025)
		gen end_date = date("2025-03-01", "YMD")
		gen yr_since_publish = (end_date - date) / 365
		gen num_cite = citations / yr_since_publish
		
		gen date_month = mofd(date)
		format date_month %tm
		
		gen date_quarter = qofd(date)
		format date_quarter %tq
		
		gen time = year
		
		duplicates drop
	
	isid id athr_id 
	collapse (rawsum) num_paper num_cite (sum) num_paper_wt = num_paper [iw = num_cite], ///
			by(athr_id athr_name time ipeds_id inst_id subfield_id)
	
	merge m:1 ipeds_id using "$derived_output/arra_institutions/mri_institutions_sample.dta", nogen assert(matched using) keep(matched)
		
	isid athr_id time inst_id subfield_id
	
	save "${derived_output}/author_openalex_panel/author_papers_panel.dta", replace
	
end

main
