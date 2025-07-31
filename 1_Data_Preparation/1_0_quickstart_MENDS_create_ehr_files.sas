/*******************************************************************************************/
/***PROGRAM: 1_0_quickstart_MENDS_create_ehr_files.SAS						 ***/
/***VERSION: 1.0 									 ***/
/***AUTHOR: DEVI CHELLURI (NORC) and NADARAJASUNDARAM GANESH (NORC)				 ***/
/***DATE CREATED: 12/08/2023, DATE LAST MOD: 07/29/2025					 ***/
/***INPUT: ORIGINAL MENDS DATA, ZIP TO COUNTY CROSSWALKS FROM HUD, ZIP TO RUCA CROSSWALK, AND COUNTY TO RUCC CROSSWALK***/
/***OUTPUT: CLEANED MENDS DATA.				 ***/
/***OBJECTIVE: CLEANED AND PROCESS MENDS DATA FOR STATISTICAL WEIGHTING. 	 ***/
/***/UPDATES THAT NEED TO BE COMPLETED: NEED TO UPDATE LIST OF VARIABLES FOR DATASET PROCEDURES IN LINE 47, 57, AND 106/***/
/***/
/*******************************************************************************************/
/***/%LET XWALKFILEPATH = ; /*@NOTE: Location of crosswalk files*/
/***/%LET OUTFILEPATH = ; /*@NOTE: Location of output files*/
/***/%LET START_YEAR = ; /*@NOTE: input should be 4 digit year, e.g., 2019*/
/***/%LET END_YEAR = ; /*@NOTE: input should be 4 digit year, e.g., 2019*/
/***/%LET START_MONTH = ; /*@NOTE: input should be 2 digit month, e.g., 1 or 12*/
/***/%LET END_MONTH = ; /*@NOTE: input should be 2 digit month, e.g., 1 or 12*/
/***/%LET YEARVAR = ; /*@NOTE: name of year variable*/
/***/%LET MONTHVAR = ; /*@NOTE: name of month variable*/
/*************************************************************************************************************************************/
/*@Action: Set SAS options ***/
OPTIONS FULLSTIMER NOFMTERR MLOGIC MPRINT MINOPERATOR SYMBOLGEN COMPRESS=YES;
ods graphics off;
ods listing;
ods html close;

Proc Datasets Library=WORK NOLIST Kill;
Quit;

libname xwalk "&XWALKFILEPATH.";
libname sasout "&OUTFILEPATH.\1_Pre_Processed_MENDS";

/*@Action: Create LOG/PDF output folder and begin SAS log and PDF output ***/
Proc Printto Log="&OUTFILEPATH.\3_SAS LOG\1_Pre_processing&start_year.&start_month._&end_year.&end_month._&DateTime..log" New;
Run;

ods listing file="&OUTFILEPATH.\3_SAS LOG\1_Pre_processing&start_year.&start_month._&end_year.&end_month._&DateTime..lst";

proc import datafile="&XWALKFILEPATH.\zip_county_122024_from_hudq42024.xlsx" 
	out=xwalk.zip_county_122024_from_hudq42024
	dbms=xlsx replace;
	getnames=yes;
	sheet="export worksheet";
run;

proc sort data=xwalk.zip_county_122024_from_hudq42024;
	by zip descending res_ratio;
run;

proc sort data=xwalk.zip_county_122024_from_hudq42024 nodupkey;
	by zip;
run;

proc import datafile="&XWALKFILEPATH.\ruca2010zipcode.xlsx" 
	out=xwalk.ruca2010zipcode
	dbms=xlsx replace;
	getnames=yes;
	sheet="data";
run;

proc sort data=xwalk.ruca2010zipcode (drop=g h i j k l m rename=(zip_code=zip));
	by zip;
run;

data zip_xwalk (rename=(county=fips_state_county state=state_per_zip));
	merge xwalk.zip_county_122024_from_hudq42024 (in=a) xwalk.ruca2010zipcode (in=b);
	by zip;
	
	drop usps_zip_pref_city usps_zip_pref_state res_ratio bus_ratio oth_ratio tot_ratio;
run;

proc import datafile="&XWALKFILEPATH.\ruralurbancontinuumcodes2023.xlsx" 
	out=xwalk.ruralurbancontinuumcodes2023
	dbms=xlsx replace;
	getnames=yes;
	sheet="rural-urban continuum code 2023";
run;

proc sort data=zip_xwalk;
	by fips_state_county;
run;

proc sort data=xwalk.ruralurbancontinuumcodes2023;
	by fips;
run;

data xwalk.zip_xwalk_final;
	retain zip state_per_zip zip_type ruca1 ruca2 ruca_3 fips_state_county state_fips state county_name population_2020 rucc_2023 description fips_state fips_county;
	merge zip_xwalk (in=a) xwalk.ruralurbancontinuumcodes2023 (in=b rename=(fips=fips_state_county));
	by fips_state_county;

	state_fips=substr(fips_state_county,1,2);
	fips_state=substr(fips_state_county,1,2);
	fips_county=substr(fips_state_county,3,3);
run;

*@Action: define file name and file location. FILE NEEDS TO BE A CSV.;
filename EHR00 "";


*@Action: confirm the column names for the data;
data EHR1(label="MENDS");
	infile EHR00 dsd dlm="," lrecl=500 firstobs=1 obs = 10 missover; 
    attrib aa length=$25 format=$25. /*first column*/ 
			...
			...
			...
		   cz length=$25 format=$25.; /*last column*/
	input aa...cz; /*Include all column names here*/
run;

data EHR0_(label="mends");
	infile EHR00 dsd dlm="," lrecl=500 firstobs=2 missover;
    attrib aa length=$25 format=$25. /*first column*/ 
			...
			...
			...
		   cz length=$25 format=$25.; /*last column*/
	input aa...cz;  /*Include all column names here*/
run;

data sasout.ehr0;
	set EHR0_;
run;

%macro subsetyear(yearvar=, monthvar=);
	%do year=&startyear. %to &endyear.;
		data sasout.EHR&year.;
			set sasout.ehr0;
			where &yearvar.=&year.;
		run;

		proc datasets library=sasout;
			modify EHR&year.;
			index create &monthvar.;
		run;
	%end;
%mend;

%subsetyear();

data zip_xwalk_final (rename=(zip=zip_code));	/*includes ruca and rucc codes - merge based on zip only*/
	set xwalk.zip_xwalk_final;
run;

proc sort data = zip_xwalk_final nodupkey;
	by zip_code;
	where zip_code ne "";
run;

/*@Action: Sort Crosswalk and EHR datasets and merge, keeping only the matches ***/
%macro create_dat();
	%do month=&start_month. %to &end_month.;

		data preproc_EHR&year.&month.;
			set sasout.EHR&year.;
			where ag=&month.;
		run;

		data EHR&year.&month. (rename=(race_=race));
			set preproc_EHR&year.&month. (in=a rename=(=zip_code &yearvar.=year &monthvar.=month =encnters_last2yr =encts_total =sex =race_ =birthcohort =age_group2 =age_group 
				=prmpayer =bmi =sysbp =dbp =ldl =triglc =hba1c =diab_dx =smoking =htn_esp =htn_dx =prediab =diab_t1 
				=diab_t2 =insulin =metformin =flu_vac =asthma =new_race =census_tract));

			encnters_last1yr=input(ai,8.);
			pregnant=input(am,8.);
			diab_gest=input(an,8.);
			ascvd=input(bx,8.);
			length encnters_last2yr_ 8.;

			if encnters_last2yr =. then
				encnters_last2yr_ = .;
			else if encnters_last2yr=1 then
				encnters_last2yr_ = 1;
			else if encnters_last2yr>=2 and encnters_last2yr<=10 then
				encnters_last2yr_ = 2;
			else if encnters_last2yr>=11 and encnters_last2yr<=20 then
				encnters_last2yr_ = 3;
			else if encnters_last2yr>=21 and encnters_last2yr<=50 then
				encnters_last2yr_ = 4;
			else if encnters_last2yr>50 then
				encnters_last2yr_ = 5;

			if month = 1 then
				m = "01Jan";

			if month = 2 then
				m = "02Feb";

			if month = 3 then
				m = "03Mar";

			if month = 4 then
				m = "04Apr";

			if month = 5 then
				m = "05May";

			if month = 6 then
				m = "06Jun";

			if month = 7 then
				m = "07Jul";

			if month = 8 then
				m = "08Aug";

			if month = 9 then
				m = "09Sep";

			if month = 10 then
				m = "10Oct";

			if month = 11 then
				m = "11Nov";

			if month = 12 then
				m = "12Dec";
			year_month = cat(trim(left(year)),"_",m);
		run;

		proc sort data= zip_xwalk_final;
			by zip_code;
		run;

		proc sort data= EHR&year.&month.;
			by zip_code;
		run;

		data sasout.EHR&year.&month.;
			merge EHR&year.&month. (in=a) zip_xwalk_final;
			by zip_code;

			if a;

			if state="" or state="Di" then
				state="ZZ";
		run;

		Data Include_EHR&year.&month.;
			set sasout.EHR&year.&month. (rename=(zip_code=ae ethnicity=ethnicity0 new_race=race0 age=agenum sex=sex0 age_group=agec0 prmpayer=bz pph=pph0));
			format month_year yymm.;
			month_year=input(catx('-',month,year),ANYDTDTE.);
			length agec agec_col agecat agecat8 agecat3 ru2 sex raceeth raceeth2 raceeth3 raceeth4 raceeth_col prmpay $50. Region $12.;
			state_fips=substr(fips_state_county,1,2);
			state=state_fips;
			COUNTY_FIPS=substr(FIPS_STATE_COUNTY,3,3);
			county=FIPS_STATE_COUNTY;
			zip=substr(ae, 1,5);

			/*@Action: Define no encounters flag ***/
			if encnters_last2yr=. then
				no_enctr2yr=1;
			else no_enctr2yr=0;

			if encnters_last2yr=. then
				_cat_enctr=0;
			else if encnters_last2yr>=1 & encnters_last2yr<=2 then
				_cat_enctr=1;
			else if encnters_last2yr>=3 & encnters_last2yr<=4 then
				_cat_enctr=2;
			else if encnters_last2yr>=5 & encnters_last2yr<=8 then
				_cat_enctr=3;
			else if encnters_last2yr>=9 & encnters_last2yr<=19 then
				_cat_enctr=4;
			else if encnters_last2yr>19 & encnters_last2yr ne . then
				_cat_enctr=5;

			/*@Action: Create 0/1 flag for having a bp in the past2 years***/
			/*@Note: update to assume that bp2yr=1 if pph in (0,1,2)***/
			bp2yr = 0;

			if pph0 in (0,1,2) then
				bp2yr = 1;

			/*@Action: chaaracter varabiale for pph*/
			if pph0=. then
				pph="";
			else if pph0=0 then
				pph="0";
			else if pph0=1 then
				pph="1";
			else if pph0=2 then
				pph="2";

			/*@Action: Create 0/1 flag for HTN flag***/
			if pph0=. then
				htnyn="";
			else if pph0=0 then
				htnyn="0";
			else if pph0 in (1, 2) then
				htnyn="1";

			/*@Action: Create 0/1 flag for HTN dx and controlled***/
			if pph0 in (., 0) then
				htnc="";
			else if pph0=1 then
				htnc="1";
			else if pph0=2 then
				htnc="0";

			/*@Action: Update all race ethnicity values for all categories***/
			/*@Action: Update race ethnicity values for report***/
			/*@Action: Update race ethnicity values 4 categories***/
			/*@Action: Update race ethnicity values 3 categories***/
			if ethnicity0=1 then
				do;
					raceeth="Other";
					raceeth2="Hispanic";
					raceeth4="Hispanic";
					raceeth3="Other";
				end;
			else if ethnicity0 in (2,0,.) then
				do;
					if race0=1 then
						do;
							raceeth="White";
							raceeth2="White";
							raceeth4="White";
							raceeth3="White";
						end;
					else if race0=2 then
						do;
							raceeth="Other";
							raceeth2="Asian";
							raceeth4="Other";
							raceeth3="Other";
						end;
					else if race0=3 then
						do;
							raceeth="Black";
							raceeth2="Black";
							raceeth4="Black";
							raceeth3="Black";
						end;
					else if race0=4 then
						do;
							raceeth="Other";
							raceeth2="Other";
							raceeth4="Other";
							raceeth3="Other";
						end;
					else if race0=5 then
						do;
							raceeth="Unspecified";
							raceeth2="Unspecified";
							raceeth4="Unspecified";
							raceeth3="Unspecified";
						end;
					else if race0=6 then
						do;
							raceeth="Other";
							raceeth2="American Indian or Alaska Native";
							raceeth4="Other";
							raceeth3="Other";
						end;
					else if race0=7 then
						do;
							raceeth="Other";
							raceeth2="Native Hawaiian or Other Pacific Islander";
							raceeth4="Other";
							raceeth3="Other";
						end;
					else
						do;
							raceeth="Missing";
							raceeth2="Missing";
							raceeth4="Other";
							raceeth3="Other";
						end;
				end;

			/*@Action: Update collapsed race category***/
			if raceeth="White" then
				raceeth_col="White";

			if raceeth="Unspecified" then
				raceeth_col="Unspecified";

			if raceeth="" then
				raceeth_col="";
			else raceeth_col="Other";

			/*@Action: Change primary payer to character***/
			if bz=0 then
				prmpay="Unknown_other_self-pay";
			else if bz=1 then
				prmpay="Bluecross_Commercial";
			else if bz=2 then
				prmpay="Workers_comp_Auto";
			else if bz=3 then
				prmpay="Medicaid";
			else if bz=4 then
				prmpay="Medicare";
			else prmpay="Unknown_other_self-pay";

			/*@Action: Change primary payer to character***/
			if bz=3 then
				prmpay2="Medicaid";
			else prmpay2="Other";

			/*@Action: Change age category to character***/
			if agec0=1 then
				agec="0-4";
			else if agec0=2 then
				agec="5-9";
			else if agec0=3 then
				agec="10-14";
			else if agec0=4 then
				agec="15-19";
			else if agec0=5 then
				agec="20-24";
			else if agec0=6 then
				agec="25-29";
			else if agec0=7 then
				agec="30-34";
			else if agec0=8 then
				agec="35-44";
			else if agec0=9 then
				agec="45-54";
			else if agec0=10 then
				agec="55-64";
			else if agec0=11 then
				agec="65-74";
			else if agec0=12 then
				agec="75-84";
			else if agec0=13 then
				agec="85+";

			/*@Action: Change collapsed age category to character***/
			if agec0 in (5,6,7,8) then
				agec_col="20-44";
			else if agec0 in (9,10) then
				agec_col="45-64";
			else if agec0 in (11,12) then
				agec_col="65-84";

			/*@Action: Change age category to character***/
			if agec0=1 then
				agecat="0-4";
			else if agec0=2 then
				agecat="5-9";
			else if agec0=3 then
				agecat="10-14";
			else if agec0=4 then
				agecat="15-19";
			else if agec0=5 then
				agecat="20-24";
			else if agec0=6 then
				agecat="25-29";
			else if agec0=7 then
				agecat="30-34";
			else if agec0=8 then
				agecat="35-44";
			else if agec0=9 then
				agecat="45-54";
			else if agec0=10 then
				agecat="55-64";
			else if agec0=11 then
				agecat="65-74";
			else if agec0=12 then
				agecat="75-84";
			else if agec0=13 then
				agecat="85+";

			/*@Action: Change age category to 8 categories***/
			if agec0=5 then
				agecat8="20-24";
			else if agec0=6 then
				agecat8="25-29";
			else if agec0=7 then
				agecat8="30-34";
			else if agec0=8 then
				agecat8="35-44";
			else if agec0=9 then
				agecat8="45-54";
			else if agec0=10 then
				agecat8="55-64";
			else if agec0=11 then
				agecat8="65-74";
			else if agec0=12 then
				agecat8="75-84";

			/*@Action: Change age category to 3 categories***/
			if agec0 in (5, 6, 7, 8) then
				agecat3="20-44";
			else if agec0 in (9, 10) then
				agecat3="45-64";
			else if agec0 in (11, 12) then
				agecat3="65-84";

			/*@Action: Change sex to character***/
			if sex0=1 then
				Sex="Male";
			else if sex0=2 then
				Sex="Female";

			/*@Action: subset to valid states***/
			if State_FIPS in ('01','02','04','05','06','08','09','10','11','12','13','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32','33','34','35','36','37','38','39','40','41','42','44','45','46','47','48','49','50','51','53','54','55','56');

			/*@Action: create NHANES And census region***/
			if State_FIPS in ('09','23','25','33','44','50','34','36','42') then
				region="Northeast";
			else if State_FIPS in ('18','17','26','39','55','19','31','20','38','27','46','29') then
				region="Midwest";
			else if State_FIPS in ('10','11','12','13','24','37','45','51','54','01','21','28','47','05','22','40','48') then
				region="South";
			else if State_FIPS in ('04','08','16','35','30','49','32','56','02','06','15','41','53') then
				region="West";

			if State_FIPS in ('04','06','15','25','33','36','41','49','50','53') then
				nhanes='1';
			else if State_FIPS in ('08','09','10','12','16','23','27','30','32','34','35','42','44') then
				nhanes='2';
			else if State_FIPS in ('02','11','13','17','19','24','26','31','38','40','46','48','51','55','56') then
				nhanes='3';
			else if State_FIPS in ('01','05','18','20','21','22','28','29','37','39','45','47','54') then
				nhanes='4';

			if 1<=ruca1<=3 then
				ru2='Mostly urban';
			else if 4<=ruca1<=10 then
				ru2='Mostly or completely rural';
		run;

		/*@Action: remove obesrvations based on exclusions*/
		data sasout.Include_EHR&year.&month.;
			set Include_EHR&year.&month.;

			/*@Action: remove missing pph**/
			if pph="" then
				delete;

			/*@Action: Remove >84 and <20 ***/
			if agec0<5 or agec0>12 then
				delete;

			/*@Action: Remove no encounters in 2 years ***/
			if no_enctr2yr=1 then
				delete;

			/*@Action: Remove no BP measurement in 2 years ***/
			if bp2yr=0 then
				delete;

			/*@Action: Remove unknown sex ***/
			if sex0=. then
				delete;

			/*@Action: Remove unknown race **/
			if raceeth in ("Unspecified","Missing","") then
				delete;

			/*@Action: Remove pregnant males ***/
			if pregnant=1 and sex0=1 then
				delete;

			/*@Action: Remove pregnant females ***/
			if pregnant=1 and sex0=2 then
				delete;
		Run;

	%end;
%mend;

%create_dat();

proc datasets library=work kill nolist;
run;

quit;

/*@Action: Halt SAS log output ***/
ods listing close;

proc printto;
Run;
title;