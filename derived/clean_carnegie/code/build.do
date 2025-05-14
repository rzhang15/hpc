clear all

* Data 
global carnegie "$dissertation/raw/Carnegie"

* Code
program main 

	clean_carnegie_classification
	merge_carnegie_year

end 

program clean_carnegie_classification

	* Load the variable labels and save all labels
	import excel using "$carnegie/2025/2025-Public-Data-File.xlsx", sheet("labels") firstrow clear
		
		local vars
	
		forvalues i = 1/`=_N' {
			local v = Variablename[`i']
			local lbl = Description[`i']
			local `v'_lbl `lbl'
			local vars `vars' `v'
		}
		
	* Load data 
	import excel using "$carnegie/2025/2025-Public-Data-File.xlsx", sheet("data") firstrow clear
		
		* Label variables 
		foreach v of local vars {
			label var `v' `"``v'_lbl'"'
		}
	
	ren unitid ipeds_id
	ren stabbr state
	ren instnm name 
	
	gen carnegie2025 = 1 if strpos(research2025name, "Research 1") > 0
	replace carnegie2025 = 1 if strpos(research2025name, "Research 2") > 0
	replace carnegie2025 = 1 if (research2025name == "Research Colleges and Universities")
	label var carnegie2025 "Carnegie Classification for R1, R2, R3 in 2025"
	
	gen public = (control == 1)
	label var public "Indicator for public institution"
	gen forprofit = (control == 3)
	label var forprofit "Indicator for for-profit (private) institution"
	
	drop if mi(ipeds_id)
	
	save "$carnegie/2025/carnegie_classification_2025", replace
	
end

program merge_carnegie_year

	use "$carnegie/2021/carnegie_classification_clean", clear 
	
		drop carnegie2025
	
	* Merge in 2025 carnegie data
	merge 1:1 ipeds_id using "$carnegie/2025/carnegie_classification_2025", update ///
		keepusing(carnegie2025 name city state public forprofit rpu medical *ratio *_avg)

	order ipeds_id name city state county carnegie* public forprofit rpu medical
	save "$carnegie/carnegie_classification", replace

end 

main
