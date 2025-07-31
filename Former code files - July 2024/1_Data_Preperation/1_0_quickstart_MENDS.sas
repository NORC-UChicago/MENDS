/*****************************************************************************/
/***PROGRAM: 1_0_Quickstart_MENDS.SAS					 				   ***/
/***VERSION: 1.0 									 					   ***/
/***AUTHOR: DEVI CHELLURI (NORC) AND NADA GANESH (NORC)					   ***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 7/22/2024			 		   ***/
/***INPUT: ORIGINAL MENDS DATA 						 					   ***/
/***INPUT: AMERICAN COMMUNITY SURVEY (ACS) DATA 					 	   ***/
/***OUTPUT: PROCESSED ACS AND EHR DATA									   ***/
/***OBJECTIVE: PROGRAM CREATES ACS DATA AND EHR DATA PREPARED FOR WEIGHTING***/
/*****************************************************************************/
/***/%LET ACSFILEPATH=P:\9778\Common\PUF_Data\ACS2022; /**NOTE: location of ACS files*/
/***/%LET ACSFILE=ACS2022_state_population_totals.xlsx; /**NOTE: nameof ACS files*/
/***/%LET PROGFILEPATH = P:\9778\Common\Programs\July 2024\1_SAS_Programs; /**NOTE: filepath for programs*/
/***/%LET OUTFILEPATH = P:\9778\SensitiveData\Summarized Results\July 2024\2_Output; /**NOTE: filepath for output*/
/***/%LET OUTFOLDER = 20240607 Run - 012019-092023; /**NOTE: filename for output*/
/***/%LET START_YEAR = 2019; /**NOTE: numeric year for start value*/
/***/%LET END_YEAR = 2023; /**NOTE: numeric year for end value*/
/***/%LET START_MONTH = 1; /**NOTE: numeric month for start value*/
/***/%LET END_MONTH = 9; /**NOTE: numeric month for end value*/
/***/%LET NEED_ACS_PREP = Y; /**NOTE: ACS prep is required*/
/***/%LET NEED_DATA_PREP = N; /**NOTE: Data prep is required*/
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

%macro prepasc();
	%if &NEED_ACS_PREP.=Y %then
		%do;
		
			/*@Action: Create LOG/PDF output folder and begin SAS log and PDF output ***/
			Proc Printto Log="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\2_ACS_PREP_&DateTime..log" New;
			Run;

			ods listing file="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\2_ACS_PREP_&DateTime..lst";

			/*@Action: start ACS prep*/
			%Include "&PROGFILEPATH.\1_1_ACS_prep.sas" / LRECL = 1000;

			Proc Datasets Library=WORK NOLIST Kill;
			Quit;


			/*@Action: Halt SAS log output ***/
			ods listing close;

			proc printto;
			Run;

		%end;
	%else
		%do;
			title "acs prep not needed";
		%end;
%mend;

%prepasc();
title;

/*@Action: Create the month year list*/
%macro month_year_list();
	%if &start_year.=&end_year. %then
		%do;

			proc sql;
				create table sasin.month_year_list as 	
					select distinct input(substr(memname,10,4),8.) as year
						, input(substr(memname,15,2),8.) as month
					from dictionary.tables
						where libname="ORIG"
							and (upcase(memname) contains "LPHI_EHR0202"
								or upcase(memname) contains "LPHI_EHR02019")
							and filesize>0
						having &start_year.=&end_year. 
							and (&start_year.=year and &start_month.<=month<=&end_month.);
			quit;

		%end;
	%else
		%do;

			proc sql;
				create table sasin.month_year_list as 	
					select distinct input(substr(memname,10,4),8.) as year
						, input(substr(memname,15,2),8.) as month
					from dictionary.tables
						where libname="ORIG"
							and (upcase(memname) contains "LPHI_EHR0202"
								or upcase(memname) contains "LPHI_EHR02019")
							and filesize>0
						having (&start_year. ne &end_year. 
							and (&start_year.=year and month ge &start_month.) 
							or (&start_year.<year<&end_year.)
							or (&end_year.=year and month le &end_month.));
			quit;

		%end;

	data sasin.month_year_list;
		set sasin.month_year_list;
		count=_N_;
	run;
%mend;

%month_year_list();

%macro prepdata();
	%if &NEED_DATA_PREP.=Y %then
		%do;
		
			/*@Action: Create LOG/PDF output folder and begin SAS log and PDF output ***/
			Proc Printto Log="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\3_Data_PREP_&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH._&DateTime..log" New;
			Run;

			ods listing file="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\3_Data_PREP_&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.&DateTime..lst";

			/*@Action: Load ZIP to county Crosswalk ***/
			PROC IMPORT DATAFILE= "P:\9778\Common\PUF_Data\crosswalks\ZIP_COUNTY_032024_From_HUDQ12024.xlsx" 
				OUT= WORK.zip_county_HUD0
				DBMS=XLSX
				REPLACE;
				SHEET="Export Worksheet";
				GETNAMES=YES;
			RUN;

			proc sort data=zip_county_HUD0 out=zip_county_HUD (keep=zip county res_ratio rename=(county=FIPS_STATE_COUNTY));
				by zip;
			run;

			/*includes RUCA and RUCC codes - merge based on ZIP only*/
			data zip_xwalk0;
				set xwalk.zip_walk_final;
				where zip ne "";
				keep zip ru ru2;
				length ru ru2 $100;

				if 1<=ruca1<=3 then
					ru='Mostly urban';
				else if 4<=ruca1<=7 then
					ru='Mostly rural';
				else if 8<=ruca1<=10 then
					ru='Completely rural';

				if 1<=ruca1<=3 then
					ru2='Mostly urban';
				else if 4<=ruca1<=10 then
					ru2='Mostly  or completely rural';
			Run;

			proc sort data=zip_xwalk0;
				by zip;
			run;

			data zip_xwalk;
				merge zip_xwalk0 (in=a) zip_county_HUD (in=b);
				by zip;

				if a and b;
			run;

			/*@Action: create macro that will create the max of month and year*/
			proc sql noprint;
				select max(count) into: max trimmed
					from sasin.month_year_list;
			quit;

			%put &max.;

			/*@Action: Declare the data prep macro*/
			%Include "&PROGFILEPATH.\1_2_Data_prep.sas" / LRECL = 1000;

			%do prep_loop=1 %to &max.;		
						
				proc sql noprint;
					select month into: month_loop  trimmed
						from sasin.month_year_list
							where count=&prep_loop.;
					select year into: year_loop  trimmed
						from sasin.month_year_list
							where count=&prep_loop.;
				quit;	
				
				/*Action: complete data prep*/
				%prep();

			%end;


			/*@Action: Halt SAS log output ***/
			ods listing close;

			proc printto;
			Run;

		%end;
	%else
		%do;
			title "data prep not needed";
		%end;
%mend;

/*@Action: clear work library*/
Proc Datasets Library=WORK NOLIST Kill;
Quit;

%prepdata();
title;