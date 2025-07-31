/*********************************************************/
/***PROGRAM: 2_0_Quickstart_MENDS - state wgts.SAS     ***/
/***VERSION: 1.0 									   ***/
/***AUTHOR: DEVI CHELLURI (NORC) AND NADA GANESH (NORC)***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 7/22/2024 ***/
/***INPUT: PREPROCESSED MENDS DATA 					   ***/
/***INPUT: AMERICAN COMMUNITY SURVEY (ACS) DATA 	   ***/
/***OUTPUT: WEIGHTED DATA AT THE STATE LEVEL		   ***/
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

/*@Note: Date time of SAS run, DO NOT CHANGE ***/
%LET DateTime = %SYSFUNC(Translate(%Quote(%SYSFUNC(COMPBL(%QUOTE(%SYSFUNC(Today(),date9.) %SYSFUNC(Time(), timeampm.))))),%Str(___),%Str( ,:)));
%PUT &DATETime.;
Libname xwalk "P:\9778\Common\PUF_Data\crosswalks" Access=Readonly;
Libname ORIG "&OUTFILEPATH.\Pre_Processed_MENDS" Access=Readonly;
Libname SASIN "&OUTFILEPATH.\Pre_Processed_MENDS\&OUTFOLDER.";
Libname SASOUT "&OUTFILEPATH.\Estimates\&OUTFOLDER.";

Proc Datasets Library=WORK NOLIST Kill;
Quit;

/*@Action: Create LOG/PDF output folder and begin SAS log and PDF output ***/
Proc Printto Log="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\4_Weighting_state_&DateTime..log" New;
Run;

ods listing file="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\4_Weighting_state_&DateTime..lst";

/*@Action: declare raking macro, weighting macro, and age adjusted macro*/
%Include "&PROGFILEPATH.\2_1_Raking_macros.sas" / LRECL = 1000;
%Include "&PROGFILEPATH.\2_2_Weighting.sas" / LRECL = 1000;

/*@Action: declare global macros that will be used in the weighting macros*/
/*@Note: we will only weight by state and national*/				
%global max National_wgt state_wgt;
				
%let National_wgt = N;
%let state_wgt = Y;

/*@Action: create macro that will be the max month/years for hte weighting loop*/
proc sql noprint;
	select max(count) into: max trimmed
		from sasin.month_year_list;
quit;

%put &max.;

%macro weightloop();
	%do wgt_loop=1 %to &max.;

		/*@Action: Create state level weights*/
		proc sql noprint;
			select month into: month_loop  trimmed
				from sasin.month_year_list
					where count=&wgt_loop.;
			select year into: year_loop  trimmed
				from sasin.month_year_list
					where count=&wgt_loop.;
		quit;

		%put &year_loop. &month_loop.;

		/*Action: create freqency of states*/
		proc freq data=sasin.Pre_Processed_MENDS_ZIP&year_loop.&month_loop. noprint;
			table state_fips/list missing out=state_freq;
		quit;

		proc sort data=state_Freq;
			by descending count;
		run;

		/*Action: create a macro list of states that have at least 250 observations*/
		Proc Sql NOPRINT;
			Select State_FIPS into: DATA_STATE_LIST Separated by " " 
				From state_freq
					Where count ge 250;
		Quit;

		%put &DATA_STATE_LIST.;
		
		/*Action: loop through each state*/
		%Let STATELOOP=1;
		%Let Scan_STATE=%Scan(&DATA_STATE_LIST., &STATELOOP.);
		%Let OnDeck=%unquote(%str(%'&Scan_STATE.%'));

		%Do %While("&Scan_STATE." NE "");
			%weights();
			*%ageadj();
			%Let STATELOOP=%Eval(&STATELOOP.+1);
			%Let Scan_STATE=%Scan(&DATA_STATE_LIST., &STATELOOP.);
			%Let OnDeck=%unquote(%str(%'&Scan_STATE.%'));
		%End;

		/*Action: clear work folder*/
		Proc Datasets Library=WORK NOLIST Kill;
		Quit;

	%End;
%mend;

%weightloop();

/*@Action: Halt SAS log output ***/
ods listing close;

proc printto;
Run;
title;