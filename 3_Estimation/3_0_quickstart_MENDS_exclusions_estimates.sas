/*******************************************************************************************/
/***PROGRAM: 3_0_Quickstart_MENDS_exclusions_estimates.SAS						 ***/
/***VERSION: 1.0 									 ***/
/***AUTHOR: DEVI CHELLURI (NORC) and NADARAJASUNDARAM GANESH (NORC)				 ***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 07/29/2025					 ***/
/***INPUT: Weighted MENDS DATA 						 ***/
/***OUTPUT: PREVALENCE ESTIMATES BASED ON SELECTION CRITERIA.				 ***/
/***OBJECTIVE: DATA AND USER SELECTIONS WILL BE USED TO QUERY DATA. 	 ***/
/***OBJECTIVE: PROGRAM GENERATES PREVALENCE ESTIMATES  			 ***/
/*******************************************************************************************/
/***/%LET PROGFILEPATH = ; /*@NOTE: Location of programs*/
/***/%LET OUTFILEPATH = ; /*@NOTE: Location of output files*/
/***/%LET START_YEAR = ; /*@NOTE: input should be 4 digit year, e.g., 2019*/
/***/%LET END_YEAR = ; /*@NOTE: input should be 4 digit year, e.g., 2019*/
/***/%LET START_MONTH = ; /*@NOTE: input should be 2 digit month, e.g., 1 or 12*/
/***/%LET END_MONTH = ; /*@NOTE: input should be 2 digit month, e.g., 1 or 12*/
/***/%LET GEOGRAPHIC_LEVEL = ;/*@NOTE: national, state, county, and zip, NEEDS TO BE LOWERCASE*/
/***/%Let STATELIST="05","04","06","08","12","15","17","18","21","22","25","24","28","31","34","36","40","41","48","51","53","56"; 
/*@Note: List of states if needed. States need to be in quotations and separated by commas*/
/*************************************************************************************************************************************/
/*@Action: Set SAS options ***/
OPTIONS FULLSTIMER NOFMTERR MLOGIC MPRINT MINOPERATOR SYMBOLGEN COMPRESS=YES;

Proc Datasets Library=WORK NOLIST Kill;
Quit;

/*@Note: Date time of SAS run, DO NOT CHANGE ***/
%LET DateTime = %SYSFUNC(Translate(%Quote(%SYSFUNC(COMPBL(%QUOTE(%SYSFUNC(Today(),date9.) %SYSFUNC(Time(), timeampm.))))),%Str(___),%Str( ,:)));
%PUT &DATETime.;
Libname xwalk "P:\A154\Common\PUF_Data\Crosswalks" Access=Readonly;
Libname SASIN "&OUTFILEPATH.\1_Pre_Processed_MENDS" Access=Readonly;
Libname SASOUT "&OUTFILEPATH.\2_Estimates";

%macro outputloop();
	Proc Printto Log="&OUTFILEPATH.\3_SAS LOG\3_Estimates_&geographic_level._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH._&DateTime..log" New;
	Run;

	ods listing file="&OUTFILEPATH.\3_SAS LOG\3_Estimates_&geographic_level._&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH._&DateTime..lst";

	proc datasets library=sasout nolist;
		delete excl_&geographic_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.
			est_&geographic_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.
			Est_wide_&geographic_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.;
	run;

	quit;

	%Include "&PROGFILEPATH.\3_1_exclusions.sas" / LRECL = 1000;
	%Include "&PROGFILEPATH.\3_2_estimates.sas" / LRECL = 1000;

	%if &start_year.=&end_year. %then
		%do;

			proc sql;
				create table sasout.monthyear_&geographic_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. as 	
 					select distinct input(substr(memname, 12, 4),8.) as year 
 						, input(substr(memname, 16, 2),8.) as month 
					from dictionary.tables
						where libname="SASIN"
 							and upcase(memname) contains "INCLUDE_EHR" 
							and filesize>0
						having &start_year.=&end_year. 
							and (&start_year.=year and &start_month.<=month<=&end_month.);
			quit;

		%end;
	%else
		%do;

			proc sql;
				create table sasout.monthyear_&geographic_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. as 
 					select distinct input(substr(memname, 12, 4),8.) as year 
 						, input(substr(memname, 16, 2),8.) as month 
					from dictionary.tables
						where libname="SASIN"
 							and upcase(memname) contains "INCLUDE_EHR" 
							and filesize>0
 						having (&start_year. ne &end_year.  
 							and (&start_year.=year and month ge &start_month.)  
 							or (&start_year.<year<&end_year.) 
 							or (&end_year.=year and month le &end_month.)); 
			quit;

		%end;

	data sasout.monthyear_&geographic_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.;
		set sasout.monthyear_&geographic_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.;
		count=_N_;
	run;
		
	%global National_est state_est county_est zip_est;

    %if &geographic_level.=national %then
        %do;

            %let National_est = N;

        %end;
	%else %if &geographic_level.=state %then
        %do;

            %let state_est = Y;

        %end;
	%else %if &geographic_level.=county %then
        %do;

            %let county_est = Y;

        %end;
	%else %if &geographic_level.=zip %then
        %do;

            %let zip_est = Y;

        %end;

	proc sql noprint;
		select max(count) into: max 
			from sasout.monthyear_&geographic_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.;
	quit;

	%put &max.;

/*%let est_loop=1;*/
	%do est_loop=1 %to &max.;

		proc sql noprint;
			select month into: month_loop  trimmed
				from sasout.monthyear_&geographic_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.
					where count=&est_loop.;
			select year into: year_loop  trimmed
				from sasout.monthyear_&geographic_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.
					where count=&est_loop.;
		quit;

		%put &month_loop. &year_loop.;

        %if &geographic_level in county zip %then  
            %do;

                %updatefile();
                %exlcusions();

            %end;
        %else %if &geographic_level in national state %then
            %do;

                %updatefile();
                %exlcusions();
                %estimates();

            %end;		
	%end;

	proc datasets library=work nolist kill;
	run;

	quit;

	/*@Action: Halt SAS log output ***/
	ods listing close;

	proc printto;
	Run;

%mend;

%outputloop();
