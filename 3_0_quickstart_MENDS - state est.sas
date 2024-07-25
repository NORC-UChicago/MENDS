/**********************************************************/
/***PROGRAM: 3_0_Quickstart_MENDS - state est.SAS	    ***/
/***VERSION: 1.0 									    ***/
/***AUTHOR: DEVI CHELLURI (NORC) AND NADA GANESH (NORC) ***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 7/22/2024  ***/
/***INPUT: PREPROCESSED MENDS DATA 					    ***/
/***INPUT: AMERICAN COMMUNITY SURVEY (ACS) DATA 	    ***/
/***OUTPUT: WEIGHTED DATA AT THE STATE LEVEL		    ***/
/***OBJECTIVE: PROGRAM COMPUTES WEIGHTED STATE ESTIMATES***/
/**********************************************************/
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

/*@Action: Date time of SAS run, DO NOT CHANGE ***/
%LET DateTime = %SYSFUNC(Translate(%Quote(%SYSFUNC(COMPBL(%QUOTE(%SYSFUNC(Today(),date9.) %SYSFUNC(Time(), timeampm.))))),%Str(___),%Str( ,:)));
%PUT &DATETime.;
/*@Action: declare libraries*/
Libname xwalk "P:\9778\Common\PUF_Data\crosswalks" Access=Readonly;
Libname ORIG "&OUTFILEPATH.\Pre_Processed_MENDS" Access=Readonly;
Libname SASIN "&OUTFILEPATH.\Pre_Processed_MENDS\&OUTFOLDER." Access=Readonly;
Libname SASOUT "&OUTFILEPATH.\Estimates\&OUTFOLDER.";

/*@Action: clear work folder*/
Proc Datasets Library=WORK NOLIST Kill;
Quit;

%macro outputloop();

	/*@Action: Create LOG/PDF output folder and begin SAS log and PDF output ***/
	Proc Printto Log="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\5_Estimates_state_&DateTime..log" New;
	Run;

	ods listing file="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\5_Estimates_state_&DateTime..lst";

	/*@Action: clear appended files to make sure we have clean files*/
	proc datasets library=sasout nolist;
		delete excl_state
			est_state
			Est_wide_state
			supr_state;
	run;

	quit;

	/*@Action: Declare the national/state specifc macros*/
	%Include "&PROGFILEPATH.\3_1_exclusions.sas" / LRECL = 1000;
	%Include "&PROGFILEPATH.\3_2_estimates.sas" / LRECL = 1000;
	%Include "&PROGFILEPATH.\3_3_suppress.sas" / LRECL = 1000;
		
	/*@Action: declare global macros that will be used in the weighting macros*/
	%global max National_est state_est;
				
	%let National_est = N;
	%let state_est = Y;
	
	/*@Action: create macro that will be the max month/years for the weighting loop*/
	proc sql noprint;
		select max(count) into: max 
			from sasin.month_year_list;
	quit;

	%put &max.;

	%do est_loop=1 %to &max.;

		/*@Action: Loop through state level estimates ***/
		proc sql noprint;
			select month into: month_loop  trimmed
				from sasin.month_year_list
					where count=&est_loop.;
			select year into: year_loop  trimmed
				from sasin.month_year_list
					where count=&est_loop.;
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

		%exlcusions();
		%Let STATELOOP=1;
		%Let Scan_STATE=%Scan(&DATA_STATE_LIST., &STATELOOP.);
		%Let OnDeck=%unquote(%str(%'&Scan_STATE.%'));
		%Put &OnDeck.;

		%Do %While("&Scan_STATE." NE "");
			%estimates();
			%Let STATELOOP=%Eval(&STATELOOP.+1);
			%Let Scan_STATE=%Scan(&DATA_STATE_LIST., &STATELOOP.);
			%Let OnDeck=%unquote(%str(%'&Scan_STATE.%'));
		%End;

	%end;

	/*@Action: create long version from wide original version*/
	data Est_crd (rename=(Sample_PT=Npats Crude_Prev=prevalance Crude_StdErr=se));
		set sasout.Est_wide_STATE;
		keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Crude_Prev Crude_StdErr;
		length est_type $15.;
		est_type="crude";
	run;

	data Est_wgt (rename=(Sample_PT=Npats Pop_Perc=prevalance STD_Err=se));
		set sasout.Est_wide_STATE;
		keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Pop_Perc STD_Err;
		length est_type $15.;
		est_type="modeled";
	run;

	data sasout.Est_STATE;
		retain geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Npats prevalance se;
		set Est_crd Est_wgt;
	run;

	/*@Action: implement suppression*/
	%suppress();

	proc export data=sasout.excl_State
		outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./State_Est_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.xlsx"
		dbms=xlsx
		replace;
		sheet="State Excl";
	run;

	proc export data=sasout.Est_State
		outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./State_Est_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.xlsx"
		dbms=xlsx
		replace;
		sheet="Orig State Est";
	run;

	proc export data=sasout.Supr_State (drop=sort)
		outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./State_Est_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.xlsx"
		dbms=xlsx
		replace;
		sheet="Supp State Est";
	run;

	proc export data=sasout.excl_State
		outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./State_Est_Deliver_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.xlsx"
		dbms=xlsx
		replace;
		sheet="State Excl";
	run;

	proc export data=sasout.Supr_State (drop=sort)
		outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./State_Est_Deliver_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.xlsx"
		dbms=xlsx
		replace;
		sheet="Supp State Est";
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
