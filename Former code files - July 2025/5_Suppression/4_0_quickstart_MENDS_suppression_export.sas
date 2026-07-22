/*******************************************************************************************/
/***PROGRAM: 4_0_quickstart_MENDS_suppression_export.SAS						 ***/
/***VERSION: 1.0 									 ***/
/***AUTHOR: DEVI CHELLURI (NORC) and NADARAJASUNDARAM GANESH (NORC)				 ***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 07/29/2025					 ***/
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
/***/%LET GEOGRAPHIC_LEVEL = ;/*@NOTE: national, state, county, and zip, NEEDS TO BE LOWERCASE*/
/***/%Let STATELIST="05","04","06","08","12","15","17","18","21","22","25","24","28","31","34","36","40","41","48","51","53","56"; 
/*@Note: List of states if needed. States need to be in quotations and separated by commas*/
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

data sasout.excl_&geographic_level.;
	set sasin.excl_&geographic_level.:;

	if substr(geographic_level, 1, 2) in (&statelist.);

	if input(substr(year_month, 1, 4), 8.)=&endyear. and input(substr(year_month, 6, 2), 8.)>&END_MONTH. then
		delete;
run;

proc export data=sasout.excl_&geographic_level.
	outfile="&OUTFILEPATH./2_Estimates/&OUTFOLDER./estimates/Delivery/&geographic_level._Est_Deliver_&Delivery_month._&START_YEAR._&END_YEAR..xlsx"
	dbms=xlsx
	replace;
	sheet="&geographic_level. Excl";
run;

proc export data=sasout.supr_&geographic_level. (drop=sort)
	outfile="&OUTFILEPATH./2_Estimates/&OUTFOLDER./estimates/Delivery/&geographic_level._Est_Deliver_&Delivery_month._&START_YEAR._&END_YEAR..xlsx"
	dbms=xlsx
	replace;
	sheet="Supp &geographic_level. Est";
run;

proc export data=sasout.supr_ivest_&geographic_level. (drop=sort)
	outfile="&OUTFILEPATH./2_Estimates/&OUTFOLDER./estimates/Delivery/&geographic_level._Est_Deliver_&Delivery_month._&START_YEAR._&END_YEAR..xlsx"
	dbms=xlsx
	replace;
	sheet="Supp &geographic_level. Est iVEST";
run;

proc export data=sasout.supr_ivest_&geographic_level. (drop=sort)
	outfile="&OUTFILEPATH./2_Estimates/&OUTFOLDER./estimates/Delivery/&geographic_level._level.csv"
	dbms=csv
	replace;
run;

/*@Action: Halt SAS log output ***/
proc printto;
run;