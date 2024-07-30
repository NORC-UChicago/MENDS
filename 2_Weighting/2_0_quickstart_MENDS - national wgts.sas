/*********************************************************/
/***PROGRAM: 2_0_Quickstart_MENDS - national wgts.SAS  ***/
/***VERSION: 1.0 									   ***/
/***AUTHOR: DEVI CHELLURI (NORC) AND NADA GANESH (NORC)***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 7/22/2024 ***/
/***INPUT: PREPROCESSED MENDS DATA 					   ***/
/***INPUT: AMERICAN COMMUNITY SURVEY (ACS) DATA 	   ***/
/***OUTPUT: WEIGHTED DATA AT THE NATIONAL LEVEL		   ***/
/***OBJECTIVE: PROGRAM COMPUTES STATISTICAL WEIGHTS	   ***/
/**********************************************************/
/***/%LET PROGFILEPATH = P:\9778\Common\Programs\July 2024\1_SAS_Programs; /**NOTE: filepath for programs*/
/***/%LET OUTFILEPATH = P:\9778\SensitiveData\Summarized Results\July 2024\2_Output; /**NOTE: filepath for output*/
/***/%LET OUTFOLDER = 20240607 Run - 012019-092023; /**NOTE: filename for output*/
/***/%LET START_YEAR = 2019; /**NOTE: numeric year for start value*/
/***/%LET END_YEAR = 2023; /**NOTE: numeric year for end value*/
/***/%LET START_MONTH = 1; /**NOTE: numeric month for start value*/
/***/%LET END_MONTH = 9; /**NOTE: numeric month for end value*/
/***/%Let Delivery_month = July_2024; /**NOTE: month and year of data delivery*/

/*************************************************************************************************************************************/
/*@Action: Set SAS options ***/
OPTIONS FULLSTIMER NOFMTERR MLOGIC MPRINT MINOPERATOR SYMBOLGEN COMPRESS=YES;

Proc Datasets Library=WORK NOLIST Kill;
Quit;

/*@Note: Date time of SAS run, DO NOT CHANGE ***/
%LET DateTime = %SYSFUNC(Translate(%Quote(%SYSFUNC(COMPBL(%QUOTE(%SYSFUNC(Today(),date9.) %SYSFUNC(Time(), timeampm.))))),%Str(___),%Str( ,:)));
%PUT &DATETime.;
Libname xwalk "P:\9778\Common\PUF_Data\crosswalks" Access=Readonly;
Libname ORIG "&OUTFILEPATH.\Pre_Processed_MENDS" Access=Readonly;
Libname SASIN "&OUTFILEPATH.\Pre_Processed_MENDS\&OUTFOLDER.";
Libname SASOUT "&OUTFILEPATH.\Estimates\&OUTFOLDER.";

/*@Action: Create LOG/PDF output folder and begin SAS log and PDF output ***/
Proc Printto Log="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\4_Weighting_natl_&DateTime..log" New;
Run;

ods listing file="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\4_Weighting_natl_&DateTime..lst";

/*@Action: declare raking macro, weighting macro, and age adjusted macro*/
%Include "&PROGFILEPATH.\2_1_Raking_macros.sas" / LRECL = 1000;
%Include "&PROGFILEPATH.\2_2_Weighting.sas" / LRECL = 1000;

/*@Action: declare global macros that will be used in the weighting macros*/
/*@Note: we will only weight by state and national*/
%global max National_wgt state_wgt;
	
%let National_wgt = Y;
%let state_wgt = N;

/*@Action: create macro that will be the max month/years for the weighting loop*/
proc sql noprint;
	select max(count) into: max trimmed
		from sasin.month_year_list;
quit;

%put &max.;

%macro weightloop();
	/*@Action: Create national level weights*/
	%do wgt_loop=1 %to &max.;

		proc sql noprint;
			select month into: month_loop  trimmed
				from sasin.month_year_list
					where count=&wgt_loop.;
			select year into: year_loop  trimmed
				from sasin.month_year_list
					where count=&wgt_loop.;
		quit;

		%put &month_loop. &year_loop.;

		%weights();
	%end;
%mend;

%weightloop();

/*@Action: Halt SAS log output ***/
ods listing close;

proc printto;
Run;
title;