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
cd "$github/hpc/analysis/mri_descriptives/code"

global raw "${dropbox_dir}/raw"
global derived_output "${dropbox_dir}/derived_output_hpc"

program main   
    
	basic_stats
	perc_requesting_gpu
	
end

program basic_stats

	use "$derived_output/clean_mri/mri_compute_grants.dta", clear
	
		drop if mi(disciplines)
		drop if inlist(disciplines, "data storage", "networks", "data visualization", "data center")
		drop if !in_ipeds
		
	* Correlations
	pwcorr doc* *_rsd serd *_amt
	tab start_year carnegie2021
	distinct ipeds_id 

	* Total amount of grants adjusted by price deflator 
	collapse (count) num_grant = award_id (sum) beowulf cpu gpu linux *_amt ///
			(mean) deflator* (median) med_award_amt = award_amt, by(start_year)
			
	drop if mi(deflator_gdp)
	
	gen deflator_2021 = deflator_gdp if start_year == 2021
	egen deflator_base = max(deflator_2021)
	
	foreach var in award_amt arra_amt med_award_amt {
		gen `var'_adj = `var' * (deflator_base / deflator_gdp)
	}
		
	gen avg_award_adj = award_amt_adj / num_grant
	
	* Plot average award amount
	tw ///
		(connected avg_award_adj start_year) ///
		(connected med_award_amt_adj start_year) ///
		, ///
		xtitle("Year", size(small)) ///
		ytitle("Average Dollars per Compute Grant (Indexed to 2021)", size(small)) ///
		xlabel(1996(4)2024, nogrid) 
	
	graph export "../output/avg_grant.png", replace
	
	* Plot average award amount
	tw ///
		(connected med_award_amt_adj start_year) ///
		, ///
		xtitle("Year", size(small)) ///
		ytitle("Median Dollars per Compute Grant (Indexed to 2021)", size(small)) ///
		xlabel(1996(4)2024, nogrid) 
	
	graph export "../output/median_grant.png", replace
	
end 

program perc_requesting_gpu

	use "$derived_output/clean_mri/mri_compute_grants.dta", clear
	
		drop if mi(disciplines)
		drop if inlist(disciplines, "data storage", "networks", "data visualization", "data center")
		drop if !in_ipeds
		
		gen upgrade = (strpos(title, "upgrade") > 0) | (strpos(abstract, "upgrade") > 0)
		
	* Correlations
	pwcorr doc* *_rsd serd *_amt

	* Total amount of grants adjusted by price deflator 
	collapse (count) num_grant = award_id (sum) beowulf cpu linux upgrade *_amt ///
			(mean) deflator*, by(start_year gpu)
	
	drop if mi(deflator_gdp)
	
	gen deflator_2021 = deflator_gdp if start_year == 2021
	egen deflator_base = max(deflator_2021)
	
	foreach var in award_amt arra_amt {
		gen `var'_adj = `var' * (deflator_base / deflator_gdp)
	}
	
	foreach var in award_amt_adj num_grant {
		bys start_year: egen `var'_total = total(`var')
	}
	
	gen perc_award_adj = award_amt_adj / award_amt_adj_total * 100
	
	* Plot spend by total and GPU 
	tw ///
		(connected award_amt_adj start_year if gpu == 1) ///
		, ///
		xtitle("Year", size(small)) ///
		ytitle("Total Dollars Awarded to HPC (Indexed to 2021)", size(small)) ///
		xlabel(2008(4)2024, nogrid) 
	
	graph export "../output/total_amount_spent_gpus.png", replace
	
	tw ///
		(connected num_grant_total start_year) ///
		(connected num_grant start_year if gpu == 1) ///
		, ///
		xtitle("Year", size(small)) ///
		ytitle("Number of Grants", size(small)) ///
		legend(order(1 "All" 2 "GPU ") pos(11) col(1) ring(0)) ///
		xlabel(1996(4)2024, nogrid) 
	
	graph export "../output/total_grants_gpus.png", replace
	
	tw ///
		(connected perc_award_adj start_year if gpu == 1) ///
		, ///
		xtitle("Year", size(small)) ///
		ytitle("Percent HPC Awards to GPU Upgrades (Indexed to 2021)", size(small)) ///
		xlabel(2008(4)2024, nogrid) 
	
	graph export "../output/percent_spent_gpus.png", replace
		
	
	
end 

main

