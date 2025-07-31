/*******************************************************************************************************************************************/
/*************************************************** -- Import ACS Data File into SAS -- ***************************************************/
/********************************** -- Reformat and create variables needed for prevalence estimation -- ***********************************/
/*******************************************************************************************************************************************/
/*@Action: import ACS files*/
%macro importme(sheet=);	
	
	PROC IMPORT DATAFILE="&ACSFILEPATH.\&ACSFILE."
		DBMS=XLSX
		OUT=WORK.&sheet. REPLACE;
		SHEET="&sheet.";
		GETNAMES=YES;
	RUN;

	%if &sheet.=AGE %then %do;
		%let var=agec;
	%end;
	%else %do;
		%let var=&sheet.;
	%end;

	/*@Action: checking levels*/
	proc freq data=WORK.&sheet.;
		table &var./list missing;
	run;

%mend;

%importme(sheet=AGE);
%importme(sheet=SEX);
%importme(sheet=RACEETH);
%importme(sheet=RU2);

/*@Action: Stack and drop percentages*/
data ACS_Universe_Controls_State;
	set age (drop=p_acs22) sex (drop=p_acs22) raceeth (drop=p_acs22) ru2 (drop=p_acs22 state);
run;

/*@Action: define collapsed age groups, collapsed race/ethnicty groups, census regions, and NHANES regions. Also, remove invaild states*/
Data sasin.acs_controls_State (rename=(acs22=ACS_Count));
	Set ACS_Universe_Controls_State (rename=(ru2=ru2_orig));
	length ru2 $100.;
	if ru2_orig='Mostly or completely rural' then ru2='Mostly  or completely rural';
	else ru2=ru2_orig;

	if agec in ("20-24", "25-29", "30-34", "35-44") then agec_col="20-44";
	else if agec in ("45-54", "55-64") then agec_col="45-64";
	else if agec in ("65-74", "75-84") then agec_col="65-84";

	if raceeth="Black" then raceeth_Col="Other";
	else raceeth_Col=raceeth;

	if State_FIPS in ('09','23','25','33','44','50','34','36','42') then census_region="Northwest";
	else if State_FIPS in ('18','17','26','39','55','19','31','20','38','27','46','29') then census_region="Midwest";
	else if State_FIPS in ('10','11','12','13','24','37','45','51','54','01','21','28','47','05','22','40','48') then census_region="South";
	else if State_FIPS in ('04','08','16','35','30','49','32','56','02','06','15','41','53') then census_region="West";

	if State_FIPS in ('04','06','15','25','33','36','41','49','50','53') then nhanes='1';
	else if State_FIPS in ('08','09','10','12','16','23','27','30','32','34','35','42','44') then nhanes='2';
	else if State_FIPS in ('02','11','13','17','19','24','26','31','38','40','46','48','51','55','56') then nhanes='3';
	else if State_FIPS in ('01','05','18','20','21','22','28','29','37','39','45','47','54') then nhanes='4';

	if State_FIPS in ('01','02','04','05','06','08','09','10','11','12','13','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32','33','34','35','36','37','38','39','40','41','42','44','45','46','47','48','49','50','51','53','54','55','56');
run;