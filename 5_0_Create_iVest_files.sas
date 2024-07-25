/*********************************************************/
/***PROGRAM: 5_0_Create_iVest_files.SAS		  		   ***/
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
Proc Printto Log="&OUTFILEPATH.\SAS LOG\&OUTFOLDER.\Create_ivest_files_&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH._&DateTime..log" New;
Run;

/*@Action: declare libname*/
Libname xwalk "P:\9778\Common\PUF_Data\crosswalks" Access=Readonly;
Libname SASOUT "&OUTFILEPATH.\Estimates\&OUTFOLDER.";

/*@Action: create National ivest files*/
data sasout.SUPR_IVEST_NATIONAL (rename=(prevalance0=prevalance se0=se));
	retain Condition year_month Group GroupValue est_type Npats prevalance0 se0;
	set sasout.SUPR_NATIONAL;

	/*@Action: remove crude estimates and cross tab estiamtes*/
	if group2="all" and est_type="modeled" and group1 ne "agecat";
	keep Condition year_month Group GroupValue est_type Npats prevalance0 se0 sort;
	
	/*@Action: redefine group and group values*/
	length Group GroupValue $100.;

	if group1='all' then
		group='overall';
	else if group1='sex' then
		group='sex';
	else if group1='agec_col' then
		group='age_group';
	else if group1='raceeth2' then
		group='race';
	else if group1='prmpay' then
		group='primary_payer';
	else if group1='ru' then
		group='rural_urban';

	if groupvalue1='all' then
		groupvalue='overall';
	else if groupvalue1='Female' then
		groupvalue='Female';
	else if groupvalue1='Male' then
		groupvalue='Male';
	else if groupvalue1='20-44' then
		groupvalue='20-44';
	else if groupvalue1='45-64' then
		groupvalue='45-64';
	else if groupvalue1='65-84' then
		groupvalue='65-84';
	else if groupvalue1='American Indian or Alaska Native' then
		groupvalue='Native_American';
	else if groupvalue1='Asian' then
		groupvalue='Asian';
	else if groupvalue1='Black' then
		groupvalue='Black';
	else if groupvalue1='Hispanic' then
		groupvalue='Hispanic';
	else if groupvalue1='Native Hawaiian or Other Pacific Islander' then
		groupvalue='Pacific_Islander';
	else if groupvalue1='Other' then
		groupvalue='Other';
	else if groupvalue1='White' then
		groupvalue='White';
	else if groupvalue1='Bluecross_Commercial' then
		groupvalue='Bluecross_Commercial';
	else if groupvalue1='Medicaid' then
		groupvalue='Medicaid';
	else if groupvalue1='Medicare' then
		groupvalue='Medicare';
	else if groupvalue1='Unknown_other_self-pay' then
		groupvalue='Unknown_other_self-pay';
	else if groupvalue1='Workers_comp_Auto' then
		groupvalue='Workers_comp_Auto';
	else if groupvalue1='Completely rural' then
		groupvalue='Completely_rural';
	else if groupvalue1='Mostly rural' then
		groupvalue='Mostly_rural';
	else if groupvalue1='Mostly urban' then
		groupvalue='Mostly_urban';
	prevalance0=prevalance/100;
	se0=se/100;
run;

proc sort data=sasout.SUPR_IVEST_NATIONAL;
	by sort;
run;

/*@Action: create State ivest files*/
/*@Action: subset state names*/
proc sql;
	create table state_names as
		select distinct State_FIPS as geographic_level
			, State as state_name
		from xwalk.zip_walk_final
			order by geographic_level;
quit;

proc sort data=sasout.Supr_state out=Supr_state_sorted;
	by geographic_level;
run;

/*@Action: merge state names to files*/
data sasout.Supr_ivest_state (rename=(state_name=state prevalance0=prevalance se0=se));
	retain state_name Condition year_month Group GroupValue est_type Npats prevalance0 se0;
	merge Supr_state_sorted (in=a) state_names;
	by geographic_level;

	if a;

	/*@Action: remove crude estimates and cross tab estiamtes*/
	if group2="all" and est_type="modeled" and group1 ne "agecat";
	keep state_name Condition year_month Group GroupValue est_type Npats prevalance0 se0 sort;
	
	/*@Action: redefine group and group values*/
	length Group GroupValue $100.;

	if group1='all' then
		group='overall';
	else if group1='sex' then
		group='sex';
	else if group1='agec_col' then
		group='age_group';
	else if group1='raceeth2' then
		group='race';
	else if group1='prmpay' then
		group='primary_payer';
	else if group1='ru' then
		group='rural_urban';

	if groupvalue1='all' then
		groupvalue='overall';
	else if groupvalue1='Female' then
		groupvalue='Female';
	else if groupvalue1='Male' then
		groupvalue='Male';
	else if groupvalue1='20-44' then
		groupvalue='20-44';
	else if groupvalue1='45-64' then
		groupvalue='45-64';
	else if groupvalue1='65-84' then
		groupvalue='65-84';
	else if groupvalue1='American Indian or Alaska Native' then
		groupvalue='Native_American';
	else if groupvalue1='Asian' then
		groupvalue='Asian';
	else if groupvalue1='Black' then
		groupvalue='Black';
	else if groupvalue1='Hispanic' then
		groupvalue='Hispanic';
	else if groupvalue1='Native Hawaiian or Other Pacific Islander' then
		groupvalue='Pacific_Islander';
	else if groupvalue1='Other' then
		groupvalue='Other';
	else if groupvalue1='White' then
		groupvalue='White';
	else if groupvalue1='Bluecross_Commercial' then
		groupvalue='Bluecross_Commercial';
	else if groupvalue1='Medicaid' then
		groupvalue='Medicaid';
	else if groupvalue1='Medicare' then
		groupvalue='Medicare';
	else if groupvalue1='Unknown_other_self-pay' then
		groupvalue='Unknown_other_self-pay';
	else if groupvalue1='Workers_comp_Auto' then
		groupvalue='Workers_comp_Auto';
	else if groupvalue1='Completely rural' then
		groupvalue='Completely_rural';
	else if groupvalue1='Mostly rural' then
		groupvalue='Mostly_rural';
	else if groupvalue1='Mostly urban' then
		groupvalue='Mostly_urban';
	prevalance0=prevalance/100;
	se0=se/100;
run;

proc sort data=sasout.Supr_ivest_state;
	by sort;
run;

/*@Action: create County ivest files*/
/*@Action: import zip county xwalk*/
PROC IMPORT DATAFILE= "P:\9778\Common\PUF_Data\crosswalks\ZIP_COUNTY_032024_From_HUDQ12024.xlsx" 
	OUT= WORK.zip_county_HUD0
	DBMS=XLSX
	REPLACE;
	SHEET="Export Worksheet";
	GETNAMES=YES;
RUN;

proc sort data=zip_county_HUD0 out=zip_county_HUD (keep=zip county rename=(county=geographic_level));
	by zip;
run;

/*@Action: include RUCA and RUCC codes - merge based on ZIP only*/
data zip_xwalk0;
	set xwalk.zip_walk_final;
	where zip ne "";
	keep zip ruca1;
Run;

proc sort data=zip_xwalk0;
	by zip;
run;

data county_state_xwalk (drop=zip); 
	merge zip_xwalk0 (in=a) zip_county_HUD (in=b);
	by zip;

	length rural_urban $100.;

	if a and b and geographic_level ne "99999";

	/*@Action: define urban rural values*/
	if 1<=ruca1<=3 then rural_urban='Mostly_urban';
	else if 4<=ruca1<=7 then rural_urban='Mostly_rural';
	else if 8<=ruca1<=10 then rural_urban='Completely_rural';
	keep geographic_level rural_urban;
run;

/*@Action: determine which urban rural value is most common for the county and use that to define urban/rural*/
proc sql;
	create table county_state_summary0 as 
		select distinct geographic_level 
			, rural_urban
			, count(*) as rows
		from county_state_xwalk
			group by geographic_level
				, rural_urban
			order by geographic_level
				, rows desc;
quit;

proc sort data=county_state_summary0 out=county_state_summary (drop=rows) nodupkey;
	by geographic_level;
run;

/*@Action: state to state fips crosswalk*/
proc sql;
	create table state_codes as 
		select distinct put(state, z2.) as state
			, statecode
		from sashelp.zipcode;
quit;

/*@Action: Sort Crosswalk and EHR datasets and merge, flag counties that dont match or have a residential ratio of 0***/
proc sql;
	create table Supr_county_sorted as 
		select a.*
			, b.rural_urban
			, c.STATECODE as state
		from (sasout.Supr_county as a
			left join county_state_summary as b
				on a.geographic_level=b.geographic_level)
			left join state_codes as c
				on substr(a.geographic_level,1,2)=c.state;
quit;

/*@Action: Create final ivest file*/
data sasout.Supr_ivest_county (rename=(prevalance0=prevalance se0=se));
	retain state county_fips Condition year_month est_type rural_urban  Npats prevalance0 se0;
	set Supr_county_sorted;

	/*@Action: remove crude estimates and cross tab estiamtes*/
	if est_type="modeled";
	county_fips=input(geographic_level,5.);
	if county_fips=99999 then delete;
	keep state county_fips Condition year_month rural_urban est_type Npats prevalance0 se0 sort;

	prevalance0=prevalance/100;
	se0=se/100;
run;

proc sort data=sasout.Supr_ivest_county;
	by sort;
run;

/*@Action: create ZIP ivest files*/
/*@Action: subset state names and rural urban values*/
proc sql;
	create table state_names as
		select distinct ZIP as geographic_level
			, State as state_name
			, case
				when 1<=ruca1<=3 then 'Mostly urban'
				when 4<=ruca1<=7 then 'Mostly rural'
				when 8<=ruca1<=10 then 'Completely rural'
				else ''
			end as ru
		from xwalk.zip_walk_final
			order by geographic_level;
quit;

proc sort data=sasout.Supr_zip out=Supr_zip_sorted;
	by geographic_level;
run;

/*@Action: merge state names to files*/
data sasout.Supr_ivest_zip (rename=(state_name=State geographic_level=zip prevalance0=prevalance se0=se));
	retain state_name geographic_level Condition year_month est_type rural_urban  Npats prevalance0 se0;
	merge Supr_zip_sorted (in=a) state_names;
	by geographic_level;

	if a;

	/*@Action: remove crude estimates and cross tab estiamtes*/
	if est_type="modeled";
	keep state_name geographic_level Condition year_month rural_urban est_type Npats prevalance0 se0 sort;
	
	/*@Action: redefine rural/urban values*/
	length rural_urban $100.;

	if ru='Completely rural' then
		rural_urban='Completely_rural';
	else if ru='Mostly rural' then
		rural_urban='Mostly_rural';
	else if ru='Mostly urban' then
		rural_urban='Mostly_urban';

	/*@Action: update some state names that are missing*/
	if geographic_level in ("70187","70044","70429","70664") then
		state_name="LA";
	if geographic_level in ("82717") then
		state_name="WY";
		
	prevalance0=prevalance/100;
	se0=se/100;
run;

/*@Action: export files*/
%macro exportme(estimate_level=);
	proc export data=SASOUT.SUPR_IVEST_&estimate_level. (drop=sort)
	  outfile="P:\9778\SensitiveData\Summarized Results\July 2024\2_Output\Estimates\20240607 Run - 012019-092023\ivest files\&estimate_level._level.csv"
	  dbms=csv
	  replace;
	run;
%mend;

%exportme(estimate_level=National);
%exportme(estimate_level=State);
%exportme(estimate_level=County);
%exportme(estimate_level=ZIP);