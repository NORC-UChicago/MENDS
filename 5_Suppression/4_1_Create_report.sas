/*******************************************************************************************/
/***PROGRAM: 3_Create_report.sas                                                         ***/
/***VERSION: 1.0																	     ***/
/***AUTHOR: DEVI CHELLURI (NORC at the University of Chicago)					   	     ***/
/***DATE CREATED: 09/28/2023, DATE LAST MOD: 05/27/2026								     ***/
/***INPUT: WEIGHTED PREVALENCE ESTIMATES												 ***/
/***OUTPUT: PREVALENCE ESTIMATES REPORTS.							 					 ***/
/***PREVALENCE ESTIMATES STORE: IN A COMMA SEPERATED VALUE (CSV) FILE OR EXCEL (XLS) FILE***/
/*******************************************************************************************/
/*************************************************************************************************************************************/
/*************************************************************************************************************************/
/*Suppression macro based on NCHS guidelines ***/
%macro suppresszip(year=);

	data supr_&estimate_level._&year.;
		infile "&SAEPATH.\ZIP_Estimates_Modeled.csv" dsd firstobs=2 truncover;
		length YEAR_MONTH $7 ZIP $7 EST_TYPE $7 CONDITION $5 BMI $3;
		input YEAR_MONTH $ ZIP $ EST_TYPE $ CONDITION $ BMI $ PREVALENCE SE NPATS;
	run;

	proc sort data=supr_&estimate_level._&year.;
		by zip;
	run;

	proc sql;
		create table zip_limit0 as
			select distinct ZIP
				from xwalk.zip_xwalk_final
					where ZIP ne "" 
						order by ZIP;
	quit;

	data sasout.supr_&estimate_level._&year. (rename=(zip=geographic_level year_month0=year_month est_type0=est_type condition0=Condition Npats0=Npats prevalence0=prevalence se0=se));
		retain geographic_type zip condition0 year_month0 Group1 GroupValue1 Group2 GroupValue2 est_type0 Npats0 prevalence0 se0 sort;
		merge supr_&estimate_level._&year. (rename=(year_month=year_month0 est_type=est_type0 condition=condition0 Npats=Npats0 prevalence=prevalence0 se=se0) in=a) zip_limit0 (in=b);
		by zip;

		if a and b;
		sort=_N_;
		geographic_type="ZIP";
		Group1="all";
		GroupValue1="all";
		Group2="all";
		GroupValue2="all";
	run;

	proc sort data=sasout.supr_&estimate_level._&year. out=Supr_&estimate_level._sorted_&year.;
		by geographic_level;
		where upcase(est_type)="MODELED";
	run;

%mend;

%macro Suppress(estimate_level=);
	%if &estimate_level.=National %then
		%do;
			%let abbr=Natl;

			data f1 (rename=(condition2=Condition) drop=condition_level);
				set sasin.Est_wide_&abbr.:;
				retain geographic_type geographic_level Condition2 year_month Group1 GroupValue1 Group2 GroupValue2;
				where substr(Condition, 1, 3)="PPH";

				if input(substr(year_month, 1, 4), 8.)=&endyear. and input(substr(year_month, 6, 2), 8.)>&endmonth. then
					delete;

				*@Action: Suppress estimate if sample size < 50 OR CV >= 30%.;
				if Crude_Prev=0 or Pop_Perc=0 then
					Suppress=1;
				else if sample_pt<50 or (Crude_StdErr/Crude_Prev) ge .3 or (STD_Err/Pop_Perc) ge .3 then
					Suppress=1;
				else Suppress=0;

				if sample_pt<15 then
					Sample_less15_flag=1;
				else Sample_less15_flag=0;
				length condition2 $10.;

				if condition="PPH HTN" then
					condition2="HTN";
				else if condition="PPH HTN-C" then
					condition2="HTN-C";
				drop condition;

				if condition_level=0 then
					delete;
			run;

			proc sort data=f1 nodupkey;
				by _all_;
			run;

			proc freq data=f1;
				table year_month*(Suppress Sample_less15_flag)/list missing;
			run;

			proc sort data=f1;
				by geographic_type geographic_level year_month condition Group1 Group2 groupvalue1 groupvalue2;
			run;

			proc sql noprint;
				select count(*) into: sample_less15_flag_cnt
					from f1
						where sample_less15_flag=1;
			quit;

			%put &sample_less15_flag_cnt.;

			%if &sample_less15_flag_cnt.=0 %then
				%do;

					data Prev_Est_Supr0 (keep=geographic_type geographic_level year_month condition
						Group1 Group2 groupvalue1 groupvalue2
						sample_pt crude_prev crude_stderr
						pop_perc std_err
						Suppress Sample_less15_flag);
						set f1;

						if Suppress=1 then
							do;
								Sample_PT=.;
								Pop_n=.;
								Crude_Prev=.;
								Crude_StdErr=.;
								Pop_Perc=.;
								STD_Err=.;
							end;
					run;

				%end;
			%else
				%do;
					/***@Action: updated with new rules for sample_pt<15***/
					data less15_sex0 (keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2) 
						less15_agecat0 (keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2) ge15;
						set f1;

						if Sample_less15_flag=1 and group2="sex" then
							output less15_sex0;
						else if Sample_less15_flag=1 and group2="agecat" then
							output less15_agecat0;
						else output ge15;
					run;

					proc sort data=f1 out=f1_sex;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2;
					run;

					proc sort data=less15_sex0;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2;
					run;

					data less15_sex;
						merge f1_sex (in=a) less15_sex0 (in=b);
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2;

						if a and b;
						Sample_PT=.;
						Pop_n=.;
						Crude_Prev=.;
						Crude_StdErr=.;
						Pop_Perc=.;
						STD_Err=.;
					run;

					proc sort data=f1 out=f1_agecat;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2;
					run;

					proc sort data=less15_agecat0 nodupkey;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2;
					run;

					data less15_agecat;
						merge f1_agecat (in=a) less15_agecat0 (in=b);
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2;

						if a and b;
					run;

					proc sort data=less15_agecat;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 sample_pt;
					run;

					data less15_agecat_p1;
						set less15_agecat (rename=(sample_less15_flag=sample_less15_flag0));
						lag_sample_less15_flag=lag(sample_less15_flag0);
						lag_year_month=lag(year_month);
						lag_geographic_type=lag(geographic_type);
						lag_geographic_level=lag(geographic_level);
						lag_condition=lag(condition);
						lag_group1=lag(group1);
						lag_group2=lag(group2);

						if year_month=lag_year_month and geographic_type=lag_geographic_type and geographic_level=lag_geographic_level
							and Condition=lag_condition and Group1=lag_group1 and Group2=lag_group2
							and sample_less15_flag0=0 and lag_sample_less15_flag=1 then
							sample_less15_flag=1;
						else sample_less15_flag=sample_less15_flag0;
						drop lag_sample_less15_flag sample_less15_flag0 lag_year_month 
							lag_geographic_type lag_geographic_level 
							lag_condition
							lag_group1 lag_group2;
					run;

					data Prev_Est_Supr0;
						set ge15 less15_sex less15_agecat_p1;

						if sample_less15_flag=1 or suppress=1 then
							do;
								Sample_PT=.;
								Pop_n=.;
								Crude_Prev=.;
								Crude_StdErr=.;
								Pop_Perc=.;
								STD_Err=.;
							end;
					run;

				%end;

			/*@Action: Export suppressed version*/
			data Prev_Est_Supr_crd (rename=(Sample_PT=Npats Crude_Prev=prevalence Crude_StdErr=se));
				set Prev_Est_Supr0;
				keep geographic_type geographic_level condition year_month
					Group1 GroupValue1 Group2 GroupValue2 est_type
					Sample_PT Crude_Prev Crude_StdErr
					Suppress Sample_less15_flag;
				length est_type $15.;
				est_type="crude";
			run;

			data Prev_Est_Supr_wgt (rename=(Sample_PT=Npats Pop_Perc=prevalence STD_Err=se));
				set Prev_Est_Supr0;
				keep geographic_type geographic_level condition year_month
					Group1 GroupValue1 Group2 GroupValue2 est_type
					Sample_PT Pop_Perc STD_Err
					Suppress Sample_less15_flag;
				length est_type $15.;
				est_type="modeled";
			run;

			data sasout.Supr_&estimate_level.;
				retain geographic_type geographic_level condition year_month
					Group1 GroupValue1 Group2 GroupValue2 est_type
					Npats prevalence se;
				set Prev_Est_Supr_crd Prev_Est_Supr_wgt;
				sort=_N_;
			run;

			proc sort data=sasout.Supr_&estimate_level.;
				by sort;
			run;

		%end;
	%else %if &estimate_level.=State %then
		%do;
			%do year=&startyear. %to &endyear.;
				%let abbr=st;

				data subset&year.;
					set sasin.Est_wide_&abbr._HTN&year.:;

					%if HTN=HTN %then
						%do;
							where substr(Condition, 1, 3)="PPH";
						%end;

					if input(substr(year_month, 1, 4), 8.)=&endyear. and input(substr(year_month, 6, 2), 8.)>&endmonth. then
						delete;

					if groupvalue1='20-' then
						groupvalue1='20-24';
					else if groupvalue1='25-' then
						groupvalue1='25-29';
					else if groupvalue1='30-' then
						groupvalue1='30-34';
					else if groupvalue1='35-' then
						groupvalue1='35-44';
					else if groupvalue1='45-' then
						groupvalue1='45-54';
					else if groupvalue1='55-' then
						groupvalue1='55-64';
					else if groupvalue1='65-' then
						groupvalue1='65-74';
					else if groupvalue1='75-' then
						groupvalue1='75-84';

					if groupvalue2='20-' then
						groupvalue2='20-24';
					else if groupvalue2='25-' then
						groupvalue2='25-29';
					else if groupvalue2='30-' then
						groupvalue2='30-34';
					else if groupvalue2='35-' then
						groupvalue2='35-44';
					else if groupvalue2='45-' then
						groupvalue2='45-54';
					else if groupvalue2='55-' then
						groupvalue2='55-64';
					else if groupvalue2='65-' then
						groupvalue2='65-74';
					else if groupvalue2='75-' then
						groupvalue2='75-84';

					if group1="age3" then
						group1="agec_col";

					if group2="age3" then
						group2="agec_col";
				run;

				%if &year.=&startyear. %then
					%do;

						data subset;
							set subset&year.;
						run;

					%end;
				%else
					%do;

						data subset;
							set subset subset&year.;
						run;

					%end;
			%end;

			proc freq data=subset;
				table group1*group2 group1*groupvalue1 group2*groupvalue2/list missing;
			run;

			proc sort data=subset nodupkey;
				by _all_;
			run;

			data f1 (rename=(condition2=Condition));
				retain geographic_type geographic_level Condition2 year_month Group1 GroupValue1 Group2 GroupValue2;
				set subset;

				*@Action: Suppress estimate if sample size < 50 OR CV >= 30%.;
				Suppress=0;

				if crude_prev>0 then
					do;
						if sample_pt<50 or (Crude_StdErr/Crude_Prev) ge .3 or (STD_Err/Pop_Perc) ge .3 then
							Suppress=1;
					end;
				else if crude_prev=0 or crude_prev=. then
					Suppress=1;

				if sample_pt<15 then
					Sample_less15_flag=1;
				else Sample_less15_flag=0;
				length condition2 $10.;

				if condition="PPH HTN" then
					condition2="HTN";
				else if condition="PPH HTN-C" then
					condition2="HTN-C";
				drop condition;
			run;

			proc freq data=f1;
				table year_month*(Suppress Sample_less15_flag)/list missing;
			run;

			proc sort data=f1;
				by geographic_type geographic_level condition year_month Group1 groupvalue1 Group2 groupvalue2;
			run;

			proc sql noprint;
				select count(*) into: sample_less15_flag_cnt
					from f1
						where sample_less15_flag=1;
			quit;

			%put &sample_less15_flag_cnt.;

			%if &sample_less15_flag_cnt.=0 %then
				%do;

					data Prev_Est_Supr0 (keep=geographic_type geographic_level year_month condition Group1 Group2 groupvalue1 groupvalue2 sample_pt crude_prev crude_stderr pop_perc std_err Suppress Sample_less15_flag);
						set f1;

						if Suppress=1 then
							do;
								Sample_PT=.;
								Pop_n=.;
								Crude_Prev=.;
								Crude_StdErr=.;
								Pop_Perc=.;
								STD_Err=.;
							end;
					run;

				%end;
			%else
				%do;
					/***@Action: updated with new rules for sample_pt<15***/
					data less15_sex0 (keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2) 
						less15_agecat0 (keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2);
						set f1;

						if Sample_less15_flag=1 and group2="sex" then
							output less15_sex0;
						else if Sample_less15_flag=1 and group2="agecat" then
							output less15_agecat0;
					run;

					proc sort data=f1 out=f1_sex;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2;
					run;

					proc sort data=less15_sex0;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2;
					run;

					data less15_sex;
						merge f1_sex (in=a) less15_sex0 (in=b);
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2;

						if a and b;
						Sample_PT=.;
						Pop_n=.;
						Crude_Prev=.;
						Crude_StdErr=.;
						Pop_Perc=.;
						STD_Err=.;
					run;

					proc sort data=f1 out=f1_agecat;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2;
					run;

					proc sort data=less15_agecat0 nodupkey;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2;
					run;

					data less15_agecat;
						merge f1_agecat (in=a) less15_agecat0 (in=b);
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2;

						if a and b;
					run;

					proc sort data=less15_agecat;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 sample_pt;
					run;

					data less15_agecat_p1;
						set less15_agecat (rename=(sample_less15_flag=sample_less15_flag0));
						lag_sample_less15_flag=lag(sample_less15_flag0);
						lag_year_month=lag(year_month);
						lag_geographic_type=lag(geographic_type);
						lag_geographic_level=lag(geographic_level);
						lag_condition=lag(condition);
						lag_group1=lag(group1);
						lag_group2=lag(group2);

						if year_month=lag_year_month and geographic_type=lag_geographic_type and geographic_level=lag_geographic_level
							and Condition=lag_condition and Group1=lag_group1 and Group2=lag_group2
							and sample_less15_flag0=0 and lag_sample_less15_flag=1 then
							sample_less15_flag=1;
						else sample_less15_flag=sample_less15_flag0;
						drop lag_sample_less15_flag sample_less15_flag0 lag_year_month 
							lag_geographic_type lag_geographic_level 
							lag_condition
							lag_group1 lag_group2;
					run;

					proc sort data=less15_agecat_p1;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2;
					run;

					proc sort data=f1 out=f1_sorted;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2;
					run;

					data ge15;
						merge f1_sorted (in=a) 
							less15_sex (in=b keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2)
							less15_agecat_p1 (in=c keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2);
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2 groupvalue2;

						if a and not b and not c;
					run;

					data Prev_Est_Supr0;
						set ge15 less15_sex less15_agecat_p1;
					run;

					proc sql;
						select geographic_type,
							geographic_level,
							condition,
							condition_level,
							year_month,
							group1,
							groupvalue1,
							group2,
							groupvalue2,
							count(*) as dup_count
						from Prev_Est_Supr0
							group by geographic_type,
								geographic_level,
								condition,
								condition_level,
								year_month,
								group1,
								groupvalue1,
								group2,
								groupvalue2
							having count(*) > 1;
					quit;

				%end;

			/*@Action: updated SAE overall numbers*/
			data Prev_Est_Supr_crd_all0 (rename=(Sample_PT=Npats Crude_Prev=prevalence Crude_StdErr=se));
				set Prev_Est_Supr0;
				keep year_month geographic_type geographic_level condition Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Crude_Prev Crude_StdErr Suppress Sample_less15_flag;
				length est_type $15.;
				est_type="crude";
			run;

			proc sort data=&estimate_level._sae_est_crude;
				by year_month geographic_type geographic_level condition Group1 GroupValue1 Group2 GroupValue2 est_type;
			run;

			proc sort data=Prev_Est_Supr_crd_all0;
				by year_month geographic_type geographic_level condition Group1 GroupValue1 Group2 GroupValue2 est_type;
			run;

			data Prev_Est_Supr_crd_all;
				set &estimate_level._sae_est_crude (in=a) Prev_Est_Supr_crd_all0 (in=b);
				by year_month geographic_type geographic_level condition Group1 GroupValue1 Group2 GroupValue2 est_type;

				if sample_less15_flag=1 or suppress=1 then
					do;
						Npats=.;
						prevalence=.;
						se=.;
					end;

				if a then
					sae="Y";
				else if b then
					sae="N";

				if (a and prevalence=.) or (b and Sample_less15_flag=1) then
					suppress=1;
				else if a and prevalence ne . then
					suppress=0;
			run;

			data Prev_Est_Supr_wgt_all0 (rename=(Sample_PT=Npats Pop_Perc=prevalence STD_Err=se));
				set Prev_Est_Supr0;
				keep year_month geographic_type geographic_level condition Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Pop_Perc STD_Err Suppress Sample_less15_flag;
				length est_type $15.;
				est_type="modeled";
			run;

			proc sort data=&estimate_level._sae_est_model;
				by year_month geographic_type geographic_level condition Group1 GroupValue1 Group2 GroupValue2 est_type;
			run;

			proc sort data=Prev_Est_Supr_wgt_all0;
				by year_month geographic_type geographic_level condition Group1 GroupValue1 Group2 GroupValue2 est_type;
			run;

			data Prev_Est_Supr_wgt_all;
				set &estimate_level._sae_est_model (in=a) Prev_Est_Supr_wgt_all0 (in=b);
				by year_month geographic_type geographic_level condition Group1 GroupValue1 Group2 GroupValue2 est_type;

				if sample_less15_flag=1 or suppress=1 then
					do;
						Npats=.;
						prevalence=.;
						se=.;
					end;

				if a then
					sae="Y";
				else if b then
					sae="N";

				if (a and prevalence=.) or (b and Sample_less15_flag=1) then
					suppress=1;
				else if a and prevalence ne . then
					suppress=0;
			run;

			data Supr_&estimate_level.;
				set Prev_Est_Supr_crd_all Prev_Est_Supr_wgt_all;
			run;

			proc sql;
				create table sasout.Supr_&estimate_level. as 
					select a.geographic_type
						, a.geographic_level
						, b.geographic_level_abbr
						, a.Condition
						, a.year_month
						, a.Group1
						, a.GroupValue1
						, a.Group2
						, a.GroupValue2
						, a.est_type
						, a.Npats
						, a.prevalence
						, a.se
						, a.suppress
						, a.sae	
					from Supr_&estimate_level. as a 
						, State_list as b
					where a.geographic_level=b.State
						and a.year_month=b.year_month
						and a.condition=b.condition;
			quit;

			proc sort data=sasout.Supr_&estimate_level. nodupkey;
				by _all_;
			run;

			proc datasets library=work nolist;
				delete f1 ge15 f1_sex less15_sex0 less15_sex f1_agecat less15_agecat0 
					less15_agecat less15_agecat_p1 Prev_Est_Supr0 Prev_Est_Supr_crd_all Prev_Est_Supr_wgt_all Supr_&estimate_level.;
			run;

			quit;

		%end;
	%else %if &estimate_level.=County %then
		%do;
			/*@Action: updated SAE overall numbers*/
			proc import datafile= "&SAEPATH.\County_Estimates_Modeled.xlsx" 
				out= supr_&estimate_level.
				dbms=xlsx
				replace;
				sheet="Sheet 1";
				getnames=yes;
			run;

			/*@Action: import zip &estimate_level. xwalk*/
			PROC IMPORT DATAFILE= "&XWALKPATH.\ZIP_COUNTY_092025_From_HUDQ32025.xlsx" 
				OUT= WORK.zip_county_HUD0
				DBMS=XLSX
				REPLACE;
				SHEET="Export Worksheet";
				GETNAMES=YES;
			RUN;

			proc sort data=zip_&estimate_level._HUD0 out=zip_&estimate_level._HUD (keep=zip &estimate_level. rename=(&estimate_level.=geographic_level));
				by zip;
			run;

			/*includes RUCA and RUCC codes - merge based on ZIP only*/
			data zip_xwalk0;
				set xwalk.zip_xwalk_final;
				where zip ne "";
				keep zip PrimaryRUCA;
			Run;

			proc sort data=zip_xwalk0;
				by zip;
			run;

			data &estimate_level._state_xwalk;
				merge zip_xwalk0 (in=a) zip_&estimate_level._HUD (in=b);
				by zip;
				length rural_urban $100.;

				if a and b and geographic_level ne "99999";

				if 1<=PrimaryRUCA<=3 then
					rural_urban='Mostly_urban';
				else if 4<=PrimaryRUCA<=7 then
					rural_urban='Mostly_rural';
				else if 8<=PrimaryRUCA<=10 then
					rural_urban='Completely_rural';
				keep geographic_level rural_urban;
			run;

			proc sql;
				create table &estimate_level._state_summary0 as 
					select distinct geographic_level 
						, rural_urban
						, count(*) as rows
					from &estimate_level._state_xwalk
						group by geographic_level
							, rural_urban
						order by geographic_level
							, rows desc;
			quit;

			proc sort data=&estimate_level._state_summary0 out=&estimate_level._state_summary (drop=rows) nodupkey;
				by geographic_level;
			run;

			proc sql;
				create table state_codes as 
					select distinct put(state, z2.) as state
						, statecode
					from sashelp.zipcode;
			quit;

			/*update variable names in the SAE models*/
			data supr_&estimate_level._HTN (rename=(FIPS_STATE_COUNTY=geographic_level year_month0=year_month est_type0=est_type condition0=Condition Npats0=Npats prevalence0=prevalence se0=se));
				retain geographic_type FIPS_STATE_COUNTY condition0 year_month0 Group1 GroupValue1 Group2 GroupValue2 est_type0 Npats0 prevalence0 se0 sort;
				set supr_&estimate_level. (rename=(year_month=year_month0 est_type=est_type0 condition=condition0 Npats=Npats0 prevalence=prevalence0 se=se0));
				sort=_N_;
				geographic_type="COUNTY";
				Group1="all";
				GroupValue1="all";
				Group2="all";
				GroupValue2="all";
			run;

			/*@Action: Sort Crosswalk and EHR datasets and merge, flag counties that dont match or have a residential ratio of 0***/
			proc sql;
				create table sasout.Supr_&estimate_level. as 
					select a.*
						, b.rural_urban
						, c.STATECODE as state
					from (sasout.supr_&estimate_level. as a
						left join &estimate_level._state_summary as b
							on a.geographic_level=b.geographic_level)
						left join state_codes as c
							on substr(a.geographic_level,1,2)=c.state
						order by sort;
			quit;

		%end;
	%else %if &estimate_level.=ZIP %then
		%do;

			proc sql;
				create table state_names0 as 
					select distinct statecode
						, state
					from sashelp.zipcode;
			quit;

			proc sql;
				create table state_names as
					select distinct a.ZIP as geographic_level
						, b.statecode as state_name
						, 
					case
						when 1<=a.PrimaryRUCA<=3 then 'Mostly urban'
						when 4<=a.PrimaryRUCA<=7 then 'Mostly rural'
						when 8<=a.PrimaryRUCA<=10 then 'Completely rural'
						else ''
					end 
				as ru
					from xwalk.zip_xwalk_final as a
						left join state_names0 as b
							on a.fips_state=put(b.state, z2.)
						where geographic_level ne "" 
							order by geographic_level;
			quit;

			%if &startyear.=&endyear. %then
				%do;
					%suppresszip(year=&startyear.);
				%end;
			%else
				%do;
					%do year=&startyear. %to &endyear.;
						%suppresszip(year=&startyear.);
					%end;
				%end;
		%end;
%mend;

/*@Program End ***/