/*********************************************************/
/***PROGRAM: 4_0_Stack_and_export_ZIP.SAS	  		   ***/
/***VERSION: 1.0 									   ***/
/***AUTHOR: DEVI CHELLURI (NORC) AND NADA GANESH (NORC)***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 7/22/2024 ***/
/***INPUT: Annual ZIP files  						   ***/
/***OUTPUT: Excel files with ZIP estimates		   	   ***/
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
Proc Printto Log="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\Stack_ZIP_files_&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH._&DateTime..log" New;
Run;

/*@Action: declare libname*/
Libname SASOUT "&OUTFILEPATH.\Estimates\&OUTFOLDER.";

/*@Action: subset exclusion files into 2 per year due to excel row restrictions*/
%macro subset();
	%do year=2019 %to 2023;
		%if &year.=2023 %then %do;
			data sasout.EXCL_ZIP_&year.1_&year.5 sasout.EXCL_ZIP_&year.6_&year.9;
				set sasout.EXCL_ZIP_&year.1_&year.9;
				if find(year_month, "-01","i")>0 or find(year_month, "-02","i")>0 or find(year_month, "-03","i")>0 or find(year_month, "-04","i")>0 or find(year_month, "-05","i")>0 then output sasout.EXCL_ZIP_&year.1_&year.5;
				else if find(year_month, "-06","i")>0 or find(year_month, "-07","i")>0 or find(year_month, "-08","i")>0 or find(year_month, "-09","i")>0 then output sasout.EXCL_ZIP_&year.6_&year.9;
			run;

			proc export data=sasout.EXCL_ZIP_&year.1_&year.5
				outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ZIP_Code_Est_July_2024_20191_20239.xlsx"
				dbms=xlsx
				replace;
				sheet="ZIP Excl &year.1-&year.5";
			run;

			proc export data=sasout.EXCL_ZIP_&year.6_&year.9
				outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ZIP_Code_Est_July_2024_20191_20239.xlsx"
				dbms=xlsx
				replace;
				sheet="ZIP Excl &year.6-&year.9";
			run;
		%end;
		%else %do;
			data sasout.EXCL_ZIP_&year.1_&year.6 sasout.EXCL_ZIP_&year.7_&year.12;
				set sasout.EXCL_ZIP_&year.1_&year.12;
				if find(year_month, "-01","i")>0 or find(year_month, "-02","i")>0 or find(year_month, "-03","i")>0 or find(year_month, "-04","i")>0 or find(year_month, "-05","i")>0 or find(year_month, "-06","i")>0 then output sasout.EXCL_ZIP_&year.1_&year.6;
				else if find(year_month, "-07","i")>0 or find(year_month, "-08","i")>0 or find(year_month, "-09","i")>0 or find(year_month, "-10","i")>0 or find(year_month, "-11","i")>0 or find(year_month, "-12","i")>0 then output sasout.EXCL_ZIP_&year.7_&year.12;
			run;

			proc export data=sasout.EXCL_ZIP_&year.1_&year.6
				outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ZIP_Code_Est_July_2024_20191_20239.xlsx"
				dbms=xlsx
				replace;
				sheet="ZIP Excl &year.1-&year.6";
			run;

			proc export data=sasout.EXCL_ZIP_&year.7_&year.12
				outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ZIP_Code_Est_July_2024_20191_20239.xlsx"
				dbms=xlsx
				replace;
				sheet="ZIP Excl &year.7-&year.12";
			run;
		%end;
	%end;
%mend;

%subset();

/*@Action: Stack estimate files*/
data sasout.EST_WIDE_ZIP;
	set sasout.EST_WIDE_ZIP_20191_201912
		sasout.EST_WIDE_ZIP_20201_202012
		sasout.EST_WIDE_ZIP_20211_202112
		sasout.EST_WIDE_ZIP_20221_202212
		sasout.EST_WIDE_ZIP_20231_20239;
run;

data sasout.EST_ZIP_CRUDE sasout.EST_ZIP_MODELED;
	set sasout.EST_ZIP_20191_201912
		sasout.EST_ZIP_20201_202012
		sasout.EST_ZIP_20211_202112
		sasout.EST_ZIP_20221_202212
		sasout.EST_ZIP_20231_20239;

	if est_type="crude" then
		output sasout.EST_ZIP_CRUDE;
	else if est_type="modeled" then
		output sasout.EST_ZIP_MODELED;
run;

/*@Action: Stack supressed estimate files*/
data sasout.SUPR_ZIP;
	set sasout.SUPR_ZIP_20191_201912
		sasout.SUPR_ZIP_20201_202012
		sasout.SUPR_ZIP_20211_202112
		sasout.SUPR_ZIP_20221_202212
		sasout.SUPR_ZIP_20231_20239;
run;

data sasout.SUPR_ZIP_CRUDE sasout.SUPR_ZIP_MODELED;
	set sasout.SUPR_ZIP_20191_201912
		sasout.SUPR_ZIP_20201_202012
		sasout.SUPR_ZIP_20211_202112
		sasout.SUPR_ZIP_20221_202212
		sasout.SUPR_ZIP_20231_20239;

	if est_type="crude" then
		output sasout.SUPR_ZIP_CRUDE;
	else if est_type="modeled" then
		output sasout.SUPR_ZIP_MODELED;
run;

/*@Action: Export files*/
proc export data=sasout.Est_zip_crude
	outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ZIP_Code_Est_July_2024_20191_20239.xlsx"
	dbms=xlsx
	replace;
	sheet="Orig ZIP Est Crude";
run;

proc export data=sasout.Supr_zip_crude (drop=sort)
	outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ZIP_Code_Est_July_2024_20191_20239.xlsx"
	dbms=xlsx
	replace;
	sheet="Supp ZIP Est Crude";
run;

proc export data=sasout.Est_zip_modeled
	outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ZIP_Code_Est_July_2024_20191_20239.xlsx"
	dbms=xlsx
	replace;
	sheet="Orig ZIP Est Modeled";
run;

proc export data=sasout.Supr_zip_modeled (drop=sort)
	outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ZIP_Code_Est_July_2024_20191_20239.xlsx"
	dbms=xlsx
	replace;
	sheet="Supp ZIP Est Modeled";
run;

proc export data=sasout.Supr_zip_crude (drop=sort)
	outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ZIP_Code_Est_Deliver_July_2024_20191_20239.xlsx"
	dbms=xlsx
	replace;
	sheet="Supp ZIP Est Crude";
run;

proc export data=sasout.Supr_zip_modeled (drop=sort)
	outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ZIP_Code_Est_Deliver_July_2024_20191_20239.xlsx"
	dbms=xlsx
	replace;
	sheet="Supp ZIP Est Modeled";
run;

proc printto;
Run;