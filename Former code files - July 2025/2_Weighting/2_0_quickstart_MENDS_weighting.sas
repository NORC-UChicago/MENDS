/*******************************************************************************************/
/***PROGRAM: 2_0_quickstart_MENDS_weighting.SAS						 ***/
/***VERSION: 1.0 									 ***/
/***AUTHOR: DEVI CHELLURI (NORC) and NADARAJASUNDARAM GANESH (NORC)				 ***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 07/29/2025					 ***/
/***INPUT: PREPROCESSED MENDS DATA 						 ***/
/***INPUT: AMERICAN COMMUNITY SURVEY (ACS) DATA 					 ***/
/***OUTPUT: WEIGHTS FOR MENDS DATA AT THE STATE OR NATIONAL LEVEL.				 ***/
/***OBJECTIVE: PROGRAM COMPUTES STATISTICAL WEIGHTS***/
/***WEIGHTS STORE: WEIGHTS WILL BE STORED AS SAS FILES (SAS7BDAT)***/
/*******************************************************************************************/
/***/%LET ACSFILEPATH = ; /*@NOTE: Location of ACS files*/
/***/%LET PROGFILEPATH = ; /*@NOTE: Location of programs*/
/***/%LET OUTFILEPATH = ; /*@NOTE: Location of output files*/
/***/%LET START_YEAR = ; /*@NOTE: input should be 4 digit year, e.g., 2019*/
/***/%LET END_YEAR = ; /*@NOTE: input should be 4 digit year, e.g., 2019*/
/***/%LET START_MONTH = ; /*@NOTE: input should be 2 digit month, e.g., 1 or 12*/
/***/%LET END_MONTH = ; /*@NOTE: input should be 2 digit month, e.g., 1 or 12*/
/***/%LET GEOGRAPHIC_LEVEL = ;/*@NOTE: either national or state*/
/***/%LET ITER=; /*@NOTE: number of iterations for the raking algorithm*/
/***/%LET TOL=; /*@NOTE: tolerance for marginal differences in the raking algorithm*/
/*************************************************************************************************************************************/
/*@Action: Set SAS options ***/
OPTIONS FULLSTIMER NOFMTERR MLOGIC MPRINT MINOPERATOR SYMBOLGEN COMPRESS=YES;
ods graphics off;
ods listing;
ods html close;

Proc Datasets Library=WORK NOLIST Kill;
Quit;

/*@Note: Date time of SAS run, DO NOT CHANGE ***/
%LET DateTime = %SYSFUNC(Translate(%Quote(%SYSFUNC(COMPBL(%QUOTE(%SYSFUNC(Today(),date9.) %SYSFUNC(Time(), timeampm.))))),%Str(___),%Str( ,:)));
%PUT &DATETime.;
Libname xwalk "P:\A154\Common\PUF_Data\Crosswalks" Access=Readonly;
Libname SASIN "&OUTFILEPATH.\1_Pre_Processed_MENDS" Access=Readonly;
Libname SASOUT "&OUTFILEPATH.\2_Estimates";

/*@Action: Bring in code from external files*/
%Include "&PROGFILEPATH.\2_1_Raking_macros.sas" / LRECL = 1000;
%Include "&PROGFILEPATH.\2_2_Weighting_alt2_&geographic_level..sas" / LRECL = 1000;

/*@Action: Import national ACS control totals to be used in weighting ***/
%macro acs_controls_natl(var=);

	proc import datafile= "P:\A154\Common\PUF_Data\ACS2023\ACS2023_national_population_totals.xlsx" 
		out= &var.
		dbms=xlsx
		replace;
		sheet="&var.";
		getnames=yes;
	run;

	%if &var. in age_sex race_sex ins_race ins_age %then
		%do;
			%if &var.=age_sex %then
				%do;
					%let var1=age3;
					%let var2=sex;
				%end;

			%if &var.=race_sex %then
				%do;
					%let var1=raceeth4;
					%let var2=sex;
				%end;

			%if &var.=ins_race %then
				%do;
					%let var1=insurance2;
					%let var2=raceeth4;
				%end;

			%if &var.=ins_age %then
				%do;
					%let var1=insurance2;
					%let var2=age3;
				%end;

			data acs_natl_&var.;
				set &var.;
				mrgtotal=ACS23;
				&var._raking=catx("_", &var1., &var2.);
				keep mrgtotal &var._raking;
			run;

		%end;
	%else
		%do;

			data acs_natl_&var.;
				set &var.;
				&var._raking=&var.;
				mrgtotal=ACS23;
				keep mrgtotal &var._raking;
			run;

		%end;

	proc datasets library=work nolist;
		delete &var.;
	run;

	quit;

%mend;

/*@Action: Import state ACS control totals to be used in weighting ***/
%macro acs_controls_state(var=);

	proc import datafile= "&ACSFILEPATH.\ACS2023_state_population_totals.xlsx" 
		out= &var.
		dbms=xlsx
		replace;
		sheet="&var.";
		getnames=yes;
	run;

	%if &var. in age_sex race_col_sex ins_age ins_race_col %then
		%do;
			%if &var.=age_sex %then
				%do;
					%let var1=age3;
					%let var2=sex;
				%end;

			%if &var.=race_col_sex %then
				%do;
					%let var1=raceeth_col;
					%let var2=sex;
				%end;

			%if &var.=ins_age %then
				%do;
					%let var1=insurance2;
					%let var2=age3;
				%end;

			%if &var.=ins_race_col %then
				%do;
					%let var1=insurance2;
					%let var2=raceeth_col;
				%end;

			data acs_state_&var.;
				set &var.;
				mrgtotal=ACS23;
				state_&var._raking=catx("_", state_fips, &var1., &var2.);
				keep mrgtotal state_&var._raking;
			run;

		%end;
	%else
		%do;
			%if &var.=ru2 %then %do;

					data acs_state_&var.;
						set &var.;
						mrgtotal=ACS23;
						state_&var._raking=catx("_", state_fips, &var.);
						keep mrgtotal state_&var._raking;
					run;

			%end;
			%else
				%do;

					data acs_state_&var.0;
						set &var.;
						mrgtotal=ACS23;
						state_&var._raking=catx("_", state_fips, &var.);
						keep mrgtotal state_&var._raking;
					run;

				%end;

		%end;

	proc datasets library=work nolist;
		delete &var.;
	run;

	quit;

%mend;

/*@Action: Execute sample size check for national level***/
%macro checkfreq(filein=, var=);

	proc freq data=&filein. noprint;
		table &var./list missing out=geo_&var. (drop=percent rename=(&var.=values1));
	run;

%mend;

%macro checkfreq2(filein=, var1=, var2=);

	proc freq data=&filein. noprint;
		table &var1.*&var2./list missing out=geo_&var1._&var2. (drop=percent rename=(&var1.=values1 &var2.=values2));
	run;

%mend;

/*@Action: Execute sample size check for state level***/
%macro checkfreqstate(filein=, var=);

	proc freq data=&filein. noprint;
		table state*&var./list missing out=geo_state_&var. (drop=percent rename=(&var.=values1));
	run;

%mend;

%macro checkfreqstate2(filein=, var1=, var2=);

	proc freq data=&filein. noprint;
		table state*&var1.*&var2./list missing out=geo_state_&var1._&var2. (drop=percent rename=(&var1.=values1 &var2.=values2));
	run;

%mend;

/*@Action: Update the ACS files for national level***/
%macro fixacs_natl(var=);

	proc sql;
		create table acs_natl_&var. as 
			select *
				from acs_natl_&var.0
					where &var._raking in (select distinct &var._raking from prepped_file1);
	quit;

%mend;

/*@Action: Update the ACS files for state level***/
%macro fixacs_state(var=);

	proc sql;
		create table &var._list as 
			select distinct state_&var._raking 
				from prepped_file1&year_loop.&month_loop.;
	quit;

	proc sort data=acs_state_&var.;
		by state_&var._raking;
	run;

	data acs_state_&var.&year_loop.&month_loop.;
		merge acs_state_&var. (in=a) &var._list (in=b);
		by state_&var._raking;
		if a and b;
	run;

%mend;

%macro weightloop();
	
	%if &start_year.=&end_year. %then
		%do;
		
			proc sql;
				create table sasout.month_year_list&start_year.&start_month._&end_year.&end_month. as 	
					select distinct input(substr(memname,12,4),8.) as year
						, input(substr(memname,16,2),8.) as month
					from dictionary.tables
 						where libname="SASIN" 
 							and upcase(memname) contains "INCLUDE_EHR" 
 							and filesize>0
 						having (year=&start_year.  
 							and &start_month.<=month<=&end_month.); 
			quit;

		%end;
	%else
		%do;

			proc sql;
				create table sasout.month_year_list&start_year.&start_month._&end_year.&end_month. as 	
					select distinct input(substr(memname,12,4),8.) as year
						, input(substr(memname,16,2),8.) as month
					from dictionary.tables
						where libname="SASIN"
							and upcase(memname) contains "INCLUDE_EHR"
							and filesize>0
 						having (&start_year.=year and month ge &start_month.) 
 							or (&start_year.<year<&end_year.) 
 							or (&end_year.=year and month le &end_month.); 
			quit;

		%end;
		
	data sasout.month_year_list&start_year.&start_month._&end_year.&end_month.;
		set sasout.month_year_list&start_year.&start_month._&end_year.&end_month.;
		count=_N_;
	run;

	proc sql noprint;
		select max(count) into: max 
			from sasout.month_year_list&start_year.&start_month._&end_year.&end_month.;
	quit;

	%put &max.;

	/*@Action: Create national level estimates ***/
	%do wgt_loop=1 %to &max.;

		proc sql noprint;
			select month into: month_loop  trimmed
				from sasout.month_year_list&start_year.&start_month._&end_year.&end_month.
					where count=&wgt_loop.;
			select year into: year_loop  trimmed
				from sasout.month_year_list&start_year.&start_month._&end_year.&end_month.
					where count=&wgt_loop.;
		quit;

		%put &month_loop. &year_loop.;

        %if &geographic_level.=national %then
            %do;

                %weights_national();
            
            %end;
        %else &geographic_level.=state %then
            %do;

                %weights_state();
            
            %end;
	%end;
%mend;

/*@Action: Create LOG/PDF output folder and begin SAS log and PDF output ***/
Proc Printto Log="&OUTFILEPATH.\3_SAS LOG\2_Weighting_&geographic_level.&start_year.&start_month._&end_year.&end_month._&DateTime..log" New;
Run;

ods listing file="&OUTFILEPATH.\3_SAS LOG\2_Weighting_&geographic_level.&start_year.&start_month._&end_year.&end_month._&DateTime..lst";


%weightloop();

/*@Action: Halt SAS log output ***/
ods listing close;

proc printto;
Run;
title;