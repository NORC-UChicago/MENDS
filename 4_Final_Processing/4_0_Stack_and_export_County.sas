/*********************************************************/
/***PROGRAM: 4_0_Stack_and_export_County.SAS  		   ***/
/***VERSION: 1.0 									   ***/
/***AUTHOR: DEVI CHELLURI (NORC) AND NADA GANESH (NORC)***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 7/22/2024 ***/
/***INPUT: Annual county files  					   ***/
/***OUTPUT: Excel files with county estimates		   ***/
/*********************************************************/
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

/*@Note: Date time of SAS run***/
%LET DateTime = %SYSFUNC(Translate(%Quote(%SYSFUNC(COMPBL(%QUOTE(%SYSFUNC(Today(),date9.) %SYSFUNC(Time(), timeampm.))))),%Str(___),%Str( ,:)));
%PUT &DATETime.;

/*@Action: declare log*/
Proc Printto Log="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\Stack_county_files_&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH._&DateTime..log" New;
Run;

/*@Action: declare libname*/
Libname SASOUT "&OUTFILEPATH.\Estimates\&OUTFOLDER.";

/*@Action: Stack exclusion files*/
data sasout.EXCL_COUNTY_2019_2020;
	set sasout.EXCL_COUNTY_20191_201912
		sasout.EXCL_COUNTY_20201_202012;
run;

data sasout.EXCL_county_2021_2023;
	set sasout.EXCL_COUNTY_20211_202112
		sasout.EXCL_COUNTY_20221_202212
		sasout.EXCL_COUNTY_20231_20239;
run;

/*@Action: Stack estimate files*/
data sasout.EST_WIDE_county;
	set sasout.EST_WIDE_county_20191_201912
		sasout.EST_WIDE_county_20201_202012
		sasout.EST_WIDE_county_20211_202112
		sasout.EST_WIDE_county_20221_202212
		sasout.EST_WIDE_county_20231_20239;
run;

data sasout.EST_county;
	set sasout.EST_county_20191_201912
		sasout.EST_county_20201_202012
		sasout.EST_county_20211_202112
		sasout.EST_county_20221_202212
		sasout.EST_county_20231_20239;
run;

/*@Action: Stack supressed estimate files*/
data sasout.SUPR_county;
	set sasout.SUPR_county_20191_201912
		sasout.SUPR_county_20201_202012
		sasout.SUPR_county_20211_202112
		sasout.SUPR_county_20221_202212
		sasout.SUPR_county_20231_20239;
run;

/*@Action: Export files*/
proc export data=sasout.EXCL_COUNTY_2019_2020
	outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./County_Est_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH..xlsx"
	dbms=xlsx
	replace;
	sheet="county Excl 2019-2020";
run;

proc export data=sasout.EXCL_county_2021_2023
	outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./County_Est_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH..xlsx"
	dbms=xlsx
	replace;
	sheet="county Excl 2021-2023";
run;

proc export data=sasout.Est_county
	outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./County_Est_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH..xlsx"
	dbms=xlsx
	replace;
	sheet="Orig county Est";
run;

proc export data=sasout.Supr_county (drop=sort)
	outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./County_Est_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH..xlsx"
	dbms=xlsx
	replace;
	sheet="Supp county Est";
run;

proc export data=sasout.EXCL_COUNTY_2019_2020
	outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./County_Est_Deliver_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH..xlsx"
	dbms=xlsx
	replace;
	sheet="county Excl 2019-2020";
run;

proc export data=sasout.EXCL_county_2021_2023
	outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./County_Est_Deliver_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH..xlsx"
	dbms=xlsx
	replace;
	sheet="county Excl 2021-2023";
run;

proc export data=sasout.Supr_county (drop=sort)
	outfile="&OUTFILEPATH./Estimates/&OUTFOLDER./County_Est_Deliver_&Delivery_month._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH..xlsx"
	dbms=xlsx
	replace;
	sheet="Supp county Est";
run;

proc printto;
Run;