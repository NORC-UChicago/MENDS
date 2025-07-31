/************************************************************************************************************************/
/******************************************* -- Create ZIP exclusion files -- *******************************************/
/************************************************************************************************************************/
%macro exlcusions();

	/*Action: declare macros*/
	%Let ESTIMATE_LEVEL = ZIP;
	%let geo_level_var=zip;
	%let inputfile=Pre_Processed_MENDS_ZIP;

	/*@Action: exclusion count***/
	proc sql;
		create table excl_&estimate_level._&year_loop.&month_loop. as
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 1 as sort
				, "Total number of patients before exclusions" as exclusion length=300
				, count(*) as excl 
			from sasin.EHR_for_Excl&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
				group by year_month
					, geographic_level
		union
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 2 as sort
				, "Patients 19 and younger or 85 and older" as exclusion length=300
				, count(*) as excl 
			from sasin.EHR_for_Excl&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
					and (agec0<5 or agec0>12)
				group by year_month
					, geographic_level
		union
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 3 as sort
				, "Patients without an encounter in two years" as exclusion length=300
				, count(*) as excl 
			from sasin.EHR_for_Excl&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
					and no_enctr2yr=1
				group by year_month
					, geographic_level
		union
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 4 as sort
				, "Patients without an BP measurement in two years" as exclusion length=300
				, count(*) as excl 
			from sasin.EHR_for_Excl&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
					and bp2yr=0
				group by year_month
					, geographic_level
		union
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 5 as sort
				, "Patients with missing sex" as exclusion length=300
				, count(*) as excl 
			from sasin.EHR_for_Excl&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
					and sex0=.
				group by year_month
					, geographic_level
		union
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 6 as sort
				, "Patients with missing race" as exclusion length=300
				, count(*) as excl 
			from sasin.EHR_for_Excl&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
					and raceeth in ("Unspecified","Missing")
				group by year_month
					, geographic_level
		union
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 7 as sort
				, "Pregnant males" as exclusion length=300
				, count(*) as excl 
			from sasin.EHR_for_Excl&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
					and pregnant=1
					and sex0=1
				group by year_month
					, geographic_level
		union
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 8 as sort
				, "Pregnant females" as exclusion length=300
				, count(*) as excl 
			from sasin.EHR_for_Excl&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
					and pregnant=1
					and sex0=2
				group by year_month
					, geographic_level
		union 
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 9 as sort
				, "Geo Code mismatch with ACS" as exclusion length=300
				, count(*) as excl 
			from sasin.EHR_for_Excl&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
					and Bad_Geo=1
				group by year_month
					, geographic_level
		union 
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 10 as sort
				, "Total number of patients after exclusions" as exclusion length=300
				, count(*) as excl 
			from sasin.&inputfile.&year_loop.&month_loop.
				where year=&year_loop. 
					and month=&month_loop.
				group by year_month
					, geographic_level
		union 
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 11 as sort
				, "Total number of patients after exclusions (with a value hypertension indicator)" as exclusion length=300
				, count(*) as excl 
			from sasin.&inputfile.&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
					and htnyn ne .
				group by year_month
					, geographic_level
		union 
			select "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 12 as sort
				, "Total number of patients after exclusions (with a value hypertension control indicator)" as exclusion length=300
				, count(*) as excl 
			from sasin.&inputfile.&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
					and htnc is not null
				group by year_month
					, geographic_level;
	quit;

	/*@Action: update the exclusions to include the percentage of total*/
	proc sql;
		create table excl_denom_&estimate_level._&year_loop.&month_loop. as 
			select distinct year_month
				, geographic_level
				, excl as denom
			from excl_&estimate_level._&year_loop.&month_loop.
				where sort=1
					order by year_month
						, geographic_level;
	quit;

	/*@Action: merge exclusion counts and denominator files*/
	proc sort data=excl_&estimate_level._&year_loop.&month_loop.;
		by year_month geographic_level;
	run;

	data excl_merge_&estimate_level._&year_loop.&month_loop. (drop=denom);
		merge excl_&estimate_level._&year_loop.&month_loop. excl_denom_&estimate_level._&year_loop.&month_loop.;
		by year_month geographic_level;
		percent=excl/denom;
	run;

	/*@Action: append to total file*/
	proc append data=excl_merge_&estimate_level._&year_loop.&month_loop. base=sasout.excl_&estimate_level._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. force;
	run;

%mend;

/*@Program End ***/