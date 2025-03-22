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

	append_nsf_mri_grants
	nsf_mri_compute
	merge_institutional_details
	
end 

program append_nsf_mri_grants

	import excel "$raw/NSF/MRI/2006before.xls", firstrow case(lower) clear
	
		tempfile mri1
		save `mri1', replace
		
	import excel "$raw/NSF/MRI/2007to2015.xls", firstrow case(lower) clear
	
		tempfile mri2 
		save `mri2', replace
		 
	import excel "$raw/NSF/MRI/2016after.xls", firstrow case(lower) clear
	
		append using `mri2'
		append using `mri1'
		
	drop program*
	gen start_year = substr(startdate, -4, 4)
	gen end_year = substr(enddate, -4, 4)
	destring *_year, replace
	
	gsort -start_year -startdate
	
	save "$derived_output/clean_mri/all_mri_grants.dta", replace
	
end 

program nsf_mri_compute

	use "$derived_output/clean_mri/all_mri_grants.dta", clear

		drop copinames piemailaddress organizationstreet ///
				organizationcity organizationstate ///
				organizationzip organizationphone
				
		ren (awardnumber awardedamounttodate arraamount ///
			principalinvestigator awardinstrument lastamendmentdate) ///
			(award_id award_amt arra_amt pi award_type amenddate) 
		
			foreach var in award arra {
				foreach sym in "$" "," {
					replace `var'_amt = subinstr(`var'_amt, "`sym'", "", .)
				}
			}
			
			destring award_amt arra_amt, replace force
	
	* Define HPC resources
	gen hpc = 0 
	gen grid_cluster = 0
	
	foreach var in abstract title {
		replace `var' = lower(`var')
		replace `var' = ustrtrim(`var')
		replace `var' = subinstr(`var', "high-performance", "high performance", .)
		
		* Likely HPC 
		replace grid_cluster = 1 if (strpos(`var', " cluster") > 0) | (strpos(`var', " grid") > 0)
		replace hpc = 0.5 if (strpos(`var', "comput") > 0) & grid_cluster 
		replace hpc = 0.5 if (strpos(`var', "gpu") > 0) & grid_cluster 
		replace hpc = 0.5 if (strpos(`var', "cpu") > 0) & grid_cluster 
		replace hpc = 0.5 if (strpos(`var', "linux") > 0) & grid_cluster 
		replace hpc = 0.5 if (strpos(`var', "research cluster") > 0) | (strpos(`var', "research grid") > 0)
		
		* Definitely HPC
		replace hpc = 1 if (strpos(`var', "high performance comput") > 0) 
		replace hpc = 1 if (strpos(`var', "hpc") > 0) 
		replace hpc = 1 if (strpos(`var', "supercomput") > 0) 
		replace hpc = 1 if (strpos(`var', "beowulf") > 0) 

	}

	* Special indicator for beowolf clusters, GPU, CPU, linux
	foreach var in beowulf gpu cpu linux {
		gen `var' = (strpos(title, "`var'") > 0) | (strpos(abstract, "`var'") > 0)
	}

	* Not HPC 
	replace hpc = 0 if strpos(title, "spectro") > 0
	replace hpc = 0 if strpos(title, "diffractometer") > 0
	replace hpc = 0 if strpos(title, "tomography") > 0
	
	keep if hpc != 0
	
	sort nsfdirectorate nsforganization organization start_year
	
	* Save the data as the raw list of MRI grants
	export excel "$derived_output/clean_mri/mri_compute_grants_raw.xlsx", firstrow(variables) replace
end 

program merge_institutional_details

	* Clean IPEDS data 
	use "$raw/IPEDS/ipeds_clean.dta", clear 
	
	ren name organization 
	ren stabbr state 
	
	keep ipeds_id opeid organization state
	gen in_ipeds = 1
	
	tempfile ipeds_data
	save `ipeds_data', replace
	
	* MRI data 
	import excel "$derived_output/clean_mri/mri_compute_grants_clean.xlsx", firstrow case(lower) clear
	
		keep if !mi(disciplines)
		drop hpc grid_cluster
		replace shared = 0 if mi(shared) 
		destring xsede, force replace
		
		replace disciplines = ustrtrim(lower(disciplines))
		replace disciplines = "data visualization" if disciplines == "visualization"
		
		* Clean school names
		replace organization = subinstr(organization, "CSU", "California State University", .)
		replace organization = subinstr(organization, "Cal Poly", "California State Polytechnic University", .)
		replace organization = strproper(organization)
		
		replace organization = subinstr(organization, "Of ", "of ", .)
		replace organization = subinstr(organization, "And ", "and ", .)
		replace organization = subinstr(organization, "At ", "at ", .)
		replace organization = subinstr(organization, "For ", "for ", .)
		replace organization = subinstr(organization, "In ", "in ", .)
		replace organization = subinstr(organization, "'S ", "'s ", .)
		
		replace organization = subinstr(organization, "Suny", "SUNY", .)
		replace organization = subinstr(organization, "Cuny", "CUNY", .)
		replace organization = subinstr(organization, "Research Foundation of The City University of New York", "CUNY", .)
		replace organization = subinstr(organization, "at Brownsville", "Rio Grande Valley", .)
		replace organization = subinstr(organization, "Donahue Institute", "Amherst", .)
		replace organization = subinstr(organization, "The University Corporation", "California State University", .) 
		
		* Main campus for easy string matching later 
		replace organization = organization + " Main Campus" if inlist(organization, "New Mexico State University", "University of New Mexico", "Oklahoma State University", "University of New Hampshire", "Purdue University", "Wright State University", "Ohio State University", "Ohio University")
		
		replace organization = organization + " and Agricultural & Mechanical College" if organization == "Louisiana State University"
		replace organization = organization + " Daytona Beach" if organization == "Embry-Riddle Aeronautical University"
		replace organization = organization + " Fort Collins" if organization == "Colorado State University"
		replace organization = organization + " Bloomington" if organization == "Indiana University"
		replace organization = organization + " Pittburgh" if organization == "University of Pittsburgh"
		replace organization = organization + " Manoa" if organization == "University of Hawaii"
		replace organization = organization + " College Station" if inlist(organization, "Texas A&M University", "Texas A&M Agrilife Research")
		replace organization = organization + " Seattle" if organization == "University of Washington"
		replace organization = organization + " of Pennsylvania" if organization == "Millersville University"
		replace organization = "University of California-San Diego" if strpos(organization, "University of California-San Diego") > 0
		replace organization = "University at Buffalo" if organization == "SUNY at Buffalo"
		replace organization = "Georgia Institute of Technology" if organization == "Georgia Tech Research Corporation"
		replace organization = "Georgia Southern University" if organization == "Armstrong State University"
		replace organization = "Stony Brook University" if organization == "SUNY at Stony Brook"

		* Not a university 
		gen in_ipeds = !inlist(organization, "International Computer Science Institute", "Polytechnic University of Puerto Rico", "New York Botanical Garden", "West Virginia High Technology Consortium Foundation", "Santa Fe Institute", "University Corporation for Atmospheric Res", "National Bureau of Economic Research Inc", "Nevada System of Higher Education, Desert Research Institute")
		label var in_ipeds "Indicator for school being a higher ed institution and in IPEDS"
		
	* Merge to IPEDS data
	destring award_id, replace 
	
	reclink organization state in_ipeds using "`ipeds_data'", idmaster(award_id) idusing(ipeds_id) gen(match_score) minscore(0.9)
	
	replace in_ipeds = 0 if _merge == 1 
	assert Uin_ipeds == in_ipeds if !mi(Uin_ipeds)
	assert Ustate == state if !mi(Ustate)
	drop match_score _merge U*
	
	* Merge in Carnegie Data
	merge m:1 ipeds_id using "$raw/Carnegie/carnegie_classification_clean.dta", keep(master matched) 
	
	assert _merge == 3 if in_ipeds 
	drop _merge
	
	save "$derived_output/clean_mri/mri_compute_grants.dta", replace 
	
end 

main
