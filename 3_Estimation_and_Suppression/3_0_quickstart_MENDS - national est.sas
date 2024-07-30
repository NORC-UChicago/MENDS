/*************************************************************/
/***PROGRAM: 3_0_Quickstart_MENDS - national est.SAS	   ***/
/***VERSION: 1.0 									 	   ***/
/***AUTHOR: DEVI CHELLURI (NORC) AND NADA GANESH (NORC)	   ***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 7/22/2024	   ***/
/***INPUT: PREPROCESSED MENDS DATA 						   ***/
/***INPUT: AMERICAN COMMUNITY SURVEY (ACS) DATA 		   ***/
/***OUTPUT: WEIGHTED DATA AT THE STATE LEVEL			   ***/
/***OBJECTIVE: PROGRAM COMPUTES WEIGHTED NATIONAL ESTIMATES***/
/*************************************************************/
/***/%LET PROGFILEPATH = P:\9778\Common\Programs\July 2024\1_SAS_Programs; /**NOTE: filepath for programs*/
/***/%LET OUTFILEPATH = P:\9778\SensitiveData\Summarized Results\July 2024\2_Output; /**NOTE: filepath for output*/
/***/%LET OUTFOLDER = 20240607 Run - 012019-092023; /**NOTE: filename for output*/
/***/%LET START_YEAR = 2019; /**NOTE: numeric year for start value*/
/***/%LET END_YEAR = 2023; /**NOTE: numeric year for end value*/
/***/%LET START_MONTH = 1; /**NOTE: numeric year for start value*/
/***/%LET END_MONTH = 9; /**NOTE: numeric month for end value*/
/***/%Let Delivery_month = July_2024; /**NOTE: month and year of data delivery*/

/*************************************************************************************************************************************/
/*@Action: Set SAS options ***/
OPTIONS FULLSTIMER NOFMTERR MLOGIC MPRINT MINOPERATOR SYMBOLGEN COMPRESS=YES;

/*@Action: clear work folder*/
Proc Datasets Library=WORK NOLIST Kill;
Quit;

/*@Action: Date time of SAS run, DO NOT CHANGE ***/
%LET DateTime = %SYSFUNC(Translate(%Quote(%SYSFUNC(COMPBL(%QUOTE(%SYSFUNC(Today(),date9.) %SYSFUNC(Time(), timeampm.))))),%Str(___),%Str( ,:)));
%PUT &DATETime.;
/*@Action: declare libraries*/
Libname xwalk "P:\9778\Common\PUF_Data\crosswalks" Access=Readonly;
Libname ORIG "&OUTFILEPATH.\Pre_Processed_MENDS" Access=Readonly;
Libname SASIN "&OUTFILEPATH.\Pre_Processed_MENDS\&OUTFOLDER." Access=Readonly;
Libname SASOUT "&OUTFILEPATH.\Estimates\&OUTFOLDER.";

%macro outputloop();

	/*@Action: Create LOG/PDF output folder and begin SAS log and PDF output ***/
	Proc Printto Log="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\5_Estimates_natl_&DateTime..log" New;
	Run;

	ods listing file="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\5_Estimates_natl_&DateTime..lst";

	/*@Action: clear appended files to make sure we have clean files*/
	proc datasets library=sasout nolist;
		delete excl_national
			est_national
			Est_wide_national
			supr_national;
	run;

	quit;
	
	/*@Action: Declare the national/state specifc macros*/
	%Include "&PROGFILEPATH.\3_1_exclusions.sas" / LRECL = 1000;
	%Include "&PROGFILEPATH.\3_2_estimates.sas" / LRECL = 1000;
	%Include "&PROGFILEPATH.\3_3_suppress.sas" / LRECL = 1000;
	
	/*@Action: declare global macros that will be used in the weighting macros*/
	%global max National_est state_est;
				
	%let National_est = Y;
	%let state_est = N;

	/*@Action: create macro that will be the max month/years for the weighting loop*/
	proc sql noprint;
		select max(count) into: max 
			from sasin.month_year_list;
	quit;

	%put &max.;

	%do est_loop=1 %to &max.;

		/*@Action: Create national level estimates ***/
		proc sql noprint;
			select month into: month_loop  trimmed
				from sasin.month_year_list
					where count=&est_loop.;
			select year into: year_loop  trimmed
				from sasin.month_year_list
					where count=&est_loop.;
		quit;

		%put &month_loop. &year_loop.;

		%exlcusions();
		%estimates();

	%end;

	/*@Action: create long version from wide original version*/
	data Est_crd (rename=(Sample_PT=Npats Crude_Prev=prevalance Crude_StdErr=se));
		set sasout.Est_wide_NATIONAL;
		keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Crude_Prev Crude_StdErr;
		length est_type $15.;
		est_type="crude";
	run;

	data Est_wgt (rename=(Sample_PT=Npats Pop_Perc=prevalance STD_Err=se));
		set sasout.Est_wide_NATIONAL;
		keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Pop_Perc STD_Err;
		length est_type $15.;
		est_type="modeled";
	run;

	data sasout.Est_NATIONAL;
		retain geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Npats prevalance se;
		set Est_crd Est_wgt;
	run;

	/*@Action: implement suppression*/
	%suppress();

	/*@Action: export files*/
	proc export data=sasout.excl_National
		outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./National_Est_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.xlsx"
		dbms=xlsx
		replace;
		sheet="Natl Excl";
	run;

	proc export data=sasout.Est_National
		outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./National_Est_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.xlsx"
		dbms=xlsx
		replace;
		sheet="Orig Natl Est";
	run;

	proc export data=sasout.Supr_National (drop=sort)
		outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./National_Est_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.xlsx"
		dbms=xlsx
		replace;
		sheet="Supp Natl Est";
	run;

	proc export data=sasout.excl_National
		outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./National_Est_Deliver_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.xlsx"
		dbms=xlsx
		replace;
		sheet="Natl Excl";
	run;

	proc export data=sasout.Supr_National (drop=sort)
		outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./National_Est_Deliver_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.xlsx"
		dbms=xlsx
		replace;
		sheet="Supp Natl Est";
	run;

	/*@Action: clean work folder*/
	proc datasets library=work nolist kill;
	run;

	quit;

	/*@Action: Halt SAS log output ***/
	ods listing close;

	proc printto;
	Run;

%mend;

%outputloop();
