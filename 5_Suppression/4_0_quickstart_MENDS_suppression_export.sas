/*******************************************************************************************/
/***PROGRAM: 4_0_quickstart_MENDS_suppression_export.SAS						 ***/
/***VERSION: 1.0 									 ***/
/***AUTHOR: DEVI CHELLURI (NORC) and NADARAJASUNDARAM GANESH (NORC)				 ***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 05/27/2026					 ***/
/***INPUT: PREVLENCE ESITMATES 						 ***/
/***OUTPUT: SUPPRESSED PREVELENCE ESTIMATES.				 ***/
/***OBJECTIVE: PROGRAM GENERATES SUPPRESSED PREVALENCE ESTIMATES  			 ***/
/***PREVALENCE ESTIMATES STORE: IN A COMMA SEPERATED VALUE (CSV) FILE OR EXCEL (XLS) FILE***/
/*******************************************************************************************/
/***/%LET PROGFILEPATH = ; /*@NOTE: Location of programs*/
/***/%LET OUTFILEPATH = ; /*@NOTE: Location of output files*/
/***/%LET START_YEAR = ; /*@NOTE: input should be 4 digit year, e.g., 2019*/
/***/%LET END_YEAR = ; /*@NOTE: input should be 4 digit year, e.g., 2019*/
/***/%LET END_MONTH = ; /*@NOTE: input should be 2 digit month, e.g., 1 or 12*/
/***/%LET GEOGRAPHIC_LEVEL = ;/*@NOTE: national, state, county, and &geographic_level., NEEDS TO BE LOWERCASE*/

/*************************************************************************************************************************************/
/*************************************************************************************************************************************/
/*@Action: Set SAS options ***/
OPTIONS FULLSTIMER NOFMTERR MLOGIC MPRINT MINOPERATOR SYMBOLGEN COMPRESS=YES;

/*@Note: Date time of SAS run, DO NOT CHANGE ***/
%LET DateTime = %SYSFUNC(Translate(%Quote(%SYSFUNC(COMPBL(%QUOTE(%SYSFUNC(Today(),date9.) %SYSFUNC(Time(), timeampm.))))),%Str(___),%Str( ,:)));
%PUT &DATETime.;
Libname xwalk "P:\A154\Common\PUF_Data\Crosswalks" Access=Readonly;
Libname SASOUT "&OUTFILEPATH.\2_Estimates";

Proc Datasets Library=WORK NOLIST Kill;
Quit;

Proc Printto Log="&OUTFILEPATH.\3_SAS LOG\4_Suppression_&geographic_level._&DateTime..log" New;
Run;

%Include "&PROGFILEPATH.\4_1_Create_report.sas" / LRECL = 1000;
%suppress();

%macro zip2(year=);

	proc sort data=sasout.EXCL_&geographic_level._&type.&year.01_&year.06 out=EXCL_&geographic_level.&year.01_&year.06;
		by geographic_level;
	run;

	proc sort data=sasout.EXCL_&geographic_level._&type.&year.07_&year.12 out=EXCL_&geographic_level.&year.07_&year.12;
		by geographic_level;
	run;

	proc sql;
		create table &geographic_level._limit as
			select distinct &geographic_level. as geographic_level
				from xwalk.&geographic_level._xwalk_final
					where geographic_level ne "" 
						order by geographic_level;
	quit;

	data sasout.EXCL_&geographic_level.&year.01_&year.02 sasout.EXCL_&geographic_level.&year.03_&year.04 sasout.EXCL_&geographic_level.&year.05_&year.06;
		merge EXCL_&geographic_level.&year.01_&year.06 (in=a) &geographic_level._limit (in=b);
		by geographic_level;

		if a and b;

		if input(substr(year_month, 6, 2), 8.)>&endmonth. then
			delete;

		if 1<=input(substr(year_month, 6, 2), 8.)<=2 then
			output sasout.EXCL_&geographic_level.&year.01_&year.02;

		if 3<=input(substr(year_month, 6, 2), 8.)<=4 then
			output sasout.EXCL_&geographic_level.&year.03_&year.04;

		if 5<=input(substr(year_month, 6, 2), 8.)<=6 then
			output sasout.EXCL_&geographic_level.&year.05_&year.06;
	run;

	data sasout.EXCL_&geographic_level.&year.07_&year.08 sasout.EXCL_&geographic_level.&year.09_&year.10 sasout.EXCL_&geographic_level.&year.11_&year.12;
		merge EXCL_&geographic_level.&year.07_&year.12 (in=a) &geographic_level._limit (in=b);
		by geographic_level;

		if a and b;

		if input(substr(year_month, 6, 2), 8.)>&endmonth. then
			delete;

		if 7<=input(substr(year_month, 6, 2), 8.)<=8 then
			output sasout.EXCL_&geographic_level.&year.07_&year.08;

		if 9<=input(substr(year_month, 6, 2), 8.)<=10 then
			output sasout.EXCL_&geographic_level.&year.09_&year.10;

		if 11<=input(substr(year_month, 6, 2), 8.)<=12 then
			output sasout.EXCL_&geographic_level.&year.11_&year.12;
	run;

	proc export data=sasout.EXCL_&geographic_level.&year.01_&year.02
		outfile="&OUTFILEPATH.\2_Estimates\&geographic_level._BMI_Excl_Deliver_&Delivery_month._&YEAR..xlsx"
		dbms=xlsx
		replace;
		sheet="&geographic_level. Excl &year.01_&year.02";
	run;

	proc export data=sasout.EXCL_&geographic_level.&year.03_&year.04
		outfile="&OUTFILEPATH.\2_Estimates\&geographic_level._BMI_Excl_Deliver_&Delivery_month._&YEAR..xlsx"
		dbms=xlsx
		replace;
		sheet="&geographic_level. Excl &year.03_&year.04";
	run;

	proc export data=sasout.EXCL_&geographic_level.&year.05_&year.06
		outfile="&OUTFILEPATH.\2_Estimates\&geographic_level._BMI_Excl_Deliver_&Delivery_month._&YEAR..xlsx"
		dbms=xlsx
		replace;
		sheet="&geographic_level. Excl &year.05_&year.06";
	run;

	proc export data=sasout.EXCL_&geographic_level.&year.07_&year.08
		outfile="&OUTFILEPATH.\2_Estimates\&geographic_level._BMI_Excl_Deliver_&Delivery_month._&YEAR..xlsx"
		dbms=xlsx
		replace;
		sheet="&geographic_level. Excl &year.07_&year.08";
	run;

	proc export data=sasout.EXCL_&geographic_level.&year.09_&year.10
		outfile="&OUTFILEPATH.\2_Estimates\&geographic_level._BMI_Excl_Deliver_&Delivery_month._&YEAR..xlsx"
		dbms=xlsx
		replace;
		sheet="&geographic_level. Excl &year.09_&year.10";
	run;

	proc export data=sasout.EXCL_&geographic_level.&year.11_&year.12
		outfile="&OUTFILEPATH.\2_Estimates\&geographic_level._BMI_Excl_Deliver_&Delivery_month._&YEAR..xlsx"
		dbms=xlsx
		replace;
		sheet="&geographic_level. Excl &year.11_&year.12";
	run;

%end;
%mend;

%macro zipfinal();
	%if &startyear.=&endyear. %then
		%do;
			%zip2(year=&startyear.);
		%end;
	%else
		%do;
			%do year=&startyear. %to &endyear.;
				%zip2(year=&year.);
			%end;
		%end;
%mend;

%macro excl();
	%if &geographic_level.=national %then
		%do;

			data sasout.excl_&geographic_level.;
				set sasout.excl_&geographic_level.:;

				if substr(geographic_level, 1, 2) in (&statelist.);

				if input(substr(year_month, 1, 4), 8.)=&endyear. and input(substr(year_month, 6, 2), 8.)>&END_MONTH. then
					delete;
			run;

			proc sort data=sasout.excl_&geographic_level. nodupkey;
				*/
				by _all_;
			run;

			proc export data=sasout.excl_&geographic_level.
				outfile="&OUTFILEPATH.\2_Estimates\&geographic_level._Est_Deliver_&Delivery_month._&STARTYEAR._&ENDYEAR..xlsx"
				dbms=xlsx
				replace;
				sheet="&geographic_level. Excl";
			run;

		%end;
	%else %if &geographic_level.=state %then
		%do;

			proc import datafile= "&SAEPATH.\State_Estimates_Modeled.xlsx" 
				out= State_sae_est_all0
				dbms=xlsx
				replace;
				sheet="Sheet 1";
				getnames=yes;
			run;

			proc import datafile= "&SAEPATH.\State_Age_Estimates_Modeled.xlsx" 
				out= State_sae_est_agec0
				dbms=xlsx
				replace;
				sheet="Sheet 1";
				getnames=yes;
			run;

			proc import datafile= "&SAEPATH.\State_Sex_Estimates_Modeled.xlsx" 
				out= State_sae_est_sex0
				dbms=xlsx
				replace;
				sheet="Sheet 1";
				getnames=yes;
			run;

			proc import datafile= "&SAEPATH.\State_Race_Estimates_Modeled.xlsx" 
				out= State_sae_est_raceeth20
				dbms=xlsx
				replace;
				sheet="Sheet 1";
				getnames=yes;
			run;

			proc import datafile= "&SAEPATH.\State_Age_Collapsed_Estimates_Modeled.xlsx" 
				out= State_sae_est_agec_col0
				dbms=xlsx
				replace;
				sheet="Sheet 1";
				getnames=yes;
			run;

%macro state_list();

	proc sql;
		create table State_list0 as
			select distinct State_fips as State
				, year_month
				, condition
			from State_sae_est_all0
				union
			select distinct State_fips as State
				, year_month
				, condition
			from State_sae_est_agec0
				union
			select distinct State_fips as State
				, year_month
				, condition
			from State_sae_est_sex0
				union
			select distinct State_fips as State
				, year_month
				, condition
			from State_sae_est_raceeth20
				union
			select distinct State_fips as State
				, year_month
				, condition
			from State_sae_est_agec_col0;
	quit;

%mend;

%state_list();

proc sort data=State_list0 nodupkey;
	by _all_;
run;

proc sql;
	create table state_list_abbr as
		select distinct put(state, z2.) as state
			, statecode as geographic_level_abbr
		from sashelp.&geographic_level.code;
quit;

proc sql;
	create table state_list as 
		select a.*
			, b.geographic_level_abbr
		from state_list0 as a 
			left join state_list_abbr as b
				on a.state=b.state;
quit;

data excl_State;
	set sasout.excl_State:;

	if (substr(year_month,1,4)="&endyear." and substr(year_month,6,2) > put(&endmonth.,z2.)) then
		delete;
run;

proc sort data=excl_State nodupkey;
	by _all_;
run;

proc sql;
	create table state_list_nocondition as
		select distinct State
			, YEAR_MONTH
			, geographic_level_abbr
		from state_list;
quit;

proc sql;
	create table sasout.excl_&geographic_level. as 
		select a.geographic_type
			, a.geographic_level
			, b.geographic_level_abbr
			, a.year_month
			, a.sort
			, a.exclusion
			, a.excl
			, a.percent
		from excl_State as a 
			, state_list_nocondition as b
		where b.state=a.geographic_level
			and a.year_month=b.year_month
		order by geographic_level
			, year_month
			, sort;
quit;

proc export data=sasout.excl_&geographic_level.
	outfile="&OUTFILEPATH.\2_Estimates\&geographic_level._Est_Deliver_&Delivery_month._&STARTYEAR._&ENDYEAR..xlsx"
	dbms=xlsx
	replace;
	sheet="&geographic_level. Excl";
run;

%end;
%else %if &geographic_level.=county %then
	%do;
		%do year=&startyear. %to &endyear.;

			data sasout.excl_&geographic_level.&year.;
				set sasout.excl_&geographic_level._HTN&year.:;

				if input(substr(year_month, 1, 4), 8.)=&endyear. and input(substr(year_month, 6, 2), 8.)>&endmonth. then
					delete;

				if input(substr(year_month, 1, 4), 8.)=&year.;

				if sort in (1, 2, 5, 6, 8, 9, 11);
			run;

			proc sort data=sasout.excl_&geographic_level.&year. nodupkey;
				by _all_;
			run;

			proc sort data=sasout.excl_&geographic_level.&year.;
				by geographic_level year_month sort;
			run;

			proc export data=sasout.excl_&geographic_level.&year.
				outfile="&OUTFILEPATH.\2_Estimates\&geographic_level._Excl_Deliver_&Delivery_month._&STARTYEAR._&ENDYEAR..xlsx"
				dbms=xlsx
				replace;
				sheet="&geographic_level. Excl &year.";
			run;

		%end;
	%end;
%else %if &geographic_level.=zip %then
	%do;
		%zipfinal();
	%end;
%mend;

proc export data=sasout.supr_&geographic_level. (drop=sort)
	outfile="&OUTFILEPATH.\2_Estimates\&geographic_level._Est_&Delivery_month._&STARTYEAR._&ENDYEAR..xlsx"
	dbms=xlsx
	replace;
	sheet="Supp &geographic_level. Est";
run;

/*@Action: Halt SAS log output ***/
proc printto;
run;