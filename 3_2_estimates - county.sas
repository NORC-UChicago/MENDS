/******************************************************************************************************/
/********************************** -- Create County estimate files -- ***********************************/
/******************************************************************************************************/
%macro estimates();

	/*@Action: declare macros*/
	%Let ESTIMATE_LEVEL = COUNTY;
	%let geo_level_var=FIPS_STATE_COUNTY;

	/*@Action: Load ZIP to county Crosswalk ***/
	PROC IMPORT DATAFILE= "P:\9778\Common\PUF_Data\crosswalks\ZIP_COUNTY_032024_From_HUDQ12024.xlsx" 
		OUT= WORK.zip_county_HUD0
		DBMS=XLSX
		REPLACE;
		SHEET="Export Worksheet";
		GETNAMES=YES;
	RUN;

	proc sort data=zip_county_HUD0 out=zip_county_HUD (keep=zip county res_ratio rename=(county=&geo_level_var.));
		by zip;
	run;

	/*@Action: include RUCA and RUCC codes - merge based on ZIP only*/
	data zip_xwalk0;
		set xwalk.zip_walk_final;
		where zip ne "";
		keep zip;
	Run;

	proc sort data=zip_xwalk0;
		by zip;
	run;

	data zip_xwalk;
		merge zip_xwalk0 (in=a) zip_county_HUD (in=b);
		by zip;

		if a and b and fips_state_county ne "99999" and res_ratio ne 0;
	run;

	/*@Action: define weighted file*/
	%let weighted_file=WGTS0_&year_loop.&month_loop.;
	%put &weighted_file.;

	/*@Action: create age category, original weight for crude estimates, and rename rake weight***/
	data &weighted_file.00;
		set sasin.&weighted_file. (rename=(RakeWgt=RakeWgt0));
		original_wgt=1;
		length agecat $6.;

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
	run;

	/*@Action: merge zip xwalk to  weighted file*/
	proc sql;
		create table &weighted_file.0 as 
			select a.*
				, &geo_level_var.
				, RakeWgt0*res_ratio as RakeWgt
			from &weighted_file.00 as a
				left join zip_xwalk as b
					on a.zip=b.zip;
	quit;

	/*@Note: Prevalence Estimation and Output Routine***/
	/*@Action: Use weighted USER file to produce prevalence estimates ***/
	/*@Action: Estimate Crude Rates ***/
	Proc SurveyMeans Data=&weighted_file.0;
		Var htnyn;
		where htnyn ne .;
		domain &geo_level_var.;
		weight original_wgt;
		ods output domain=htnyn_Crde;
	run;

	Proc SurveyMeans Data=&weighted_file.0;
		Var htnc;
		where htnyn=1;
		domain &geo_level_var.;
		weight original_wgt;
		ods output domain=htnc_Crde;
	run;

	Data Crude_Prev_Estimates(Keep=&geo_level_var. htnyn htnc Group1 Groupvalue1 Group2 Groupvalue2 N Mean StdErr);
		Retain &geo_level_var. Group1 Groupvalue1 Group2 Groupvalue2 htnyn  htnc N Mean StdErr;
		Length htnyn htnc 8. Group1 Groupvalue1 Group2 Groupvalue2 $200.;
		Set	htnyn_Crde (in=a1) 
			htnc_Crde (in=a3);

		If a1 Then
			htnyn=1;
		else htnyn=0;

		If a3 Then
			htnc=1;
		else htnc=0;

		if a1|a3 then
			Group1="all";

		if a1|a3 then
			groupvalue1="all";

		if a1|a3 then
			Group2="all";

		if a1|a3 then
			groupvalue2="all";
	Run;

	/*@Action: Estimate the overall weighted prevalence estimates ***/
	%macro est_overall(type=);
		%if &type.=htnyn %then
			%do;
				%let condition=HTN;
			%end;
		%else %if &type.=htnc %then
			%do;
				%let condition=HTN-C;
			%end;

		*weighted prevalance;
		proc surveyfreq data = &weighted_file.0;
			table &geo_level_var.*&type./ row;
				where &type. ne .;
				weight RakeWgt;
				ods output crosstabs=wgt&type.all;
		run;

		*format prevalance and population/sample counts;
		data PB&type.all (drop=&type.);
			format Pop_Perc STD_Err f10.9;
			set WGT&type.all (where=(&type.=1 and &geo_level_var. ne "") keep=&type. &geo_level_var. rowpercent rowstderr rename=(rowpercent=Pop_Perc rowstderr=STD_Err));
			by &type.;
			Group1="all";
			GroupValue1="all";
			Group2="all";
			GroupValue2="all";
		run;

		data n&type.all (drop=&type.);
			set WGT&type.ALL (where=(&type.=.) keep=&type. &geo_level_var. WgtFreq rename=(WgtFreq=Pop_n));
			Group1="all";
			GroupValue1="all";
			Group2="all";
			GroupValue2="all";
		run;

		*subset crude prevanalence estimates;
		Proc Sql;
			create table CPE&type.all as 
				select * 
					from Crude_Prev_Estimates 
						where Group1="all" 
							and &type.=1;
		Quit;

		Proc Sql;
			Create table PEoverall&type. as
				Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
					, "&estimate_level." as geographic_type length=50
					, a.&geo_level_var. as geographic_level length=50
					, "&condition." as Condition length=50
					, a.Group1 length=50
					, a.GroupValue1 length=50
					, a.Group2 length=50
					, a.GroupValue2 length=50
					, c.N as Sample_PT
					, b.Pop_n
					, c.Mean*100 as Crude_Prev
					, c.StdErr*100 as Crude_StdErr
					, a.Pop_Perc
					, a.STD_Err
				From PB&type.all as a
					, n&type.all as b
					, CPE&type.all as c
				where a.Group1=b.Group1 
					and a.Group1=c.Group1
					and a.GroupValue1=b.GroupValue1
					and a.GroupValue1=c.GroupValue1
					and a.Group2=b.Group2
					and a.Group2=c.Group2
					and a.GroupValue2=b.GroupValue2
					and a.GroupValue2=c.GroupValue2
					and a.&geo_level_var.=b.&geo_level_var.
					and a.&geo_level_var.=c.&geo_level_var.
					and sample_pt ge 50
				order by Group1
					, GroupValue1
					, Group2
					, GroupValue2;
		Quit;

		/*@Action: stack files*/
		proc append data=PEoverall&type. base=sasout.Est_wide_county_&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. force;
		run;

	%mend;

	/*@Action: run macro that will loop through all estimate types*/
	%est_overall(type=htnyn);
	%est_overall(type=htnc);
%mend;

/*@Program End ***/