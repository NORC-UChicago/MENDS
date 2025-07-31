%macro suppresszip(year=);

	proc import datafile= "P:\A154\Common\SAE\Q1\Model Estimates\ZIP_Estimates_Modeled.xlsx" 
		out= supr_&geographic_level._&year.
		dbms=xlsx
		replace;
		sheet="&year.";
		getnames=yes;
	run;

	proc sort data=supr_&geographic_level._&year.;
		by zip;
	run;

	proc sql;
		create table zip_limit0 as
			select distinct ZIP
				from xwalk.zip_xwalk_final
					where ZIP ne "" 
						and state_fips in ("05","04","06","08","12","15","17","18","21","22","25","24","28","31","34","36","40","41","48","51","53","56")
					order by ZIP;
	quit;

	data sasout.supr_&geographic_level._&year. (rename=(zip=geographic_level year_month0=year_month est_type0=est_type condition0=Condition npats0=npats prevalence0=prevalence se0=se));
		retain geographic_type zip condition0 year_month0 Group1 GroupValue1 Group2 GroupValue2 est_type0 npats0 prevalence0 se0 sort;
		merge supr_&geographic_level._&year. (rename=(year_month=year_month0 est_type=est_type0 condition=condition0 npats=npats0 prevalence=prevalence0 se=se0) in=a) zip_limit0 (in=b);
		by zip;
		if a and b;
		sort=_N_;
		geographic_type="ZIP";
		Group1="all";
		GroupValue1="all";
		Group2="all";
		GroupValue2="all";
	run;

	proc sort data=sasout.supr_&geographic_level._&year. out=Supr_&geographic_level._sorted_&year.;
		by geographic_level;
		where upcase(est_type)="MODELED";
	run;

	data sasout.Supr_ivest_&geographic_level._&year. (rename=(prevalence0=prevalence se0=se geographic_level=zip));
		retain state_name geographic_level Condition year_month est_type rural_urban Npats prevalence0 se0;
		merge Supr_&geographic_level._sorted_&year. (in=a) state_names (in=b);
		by geographic_level;

		if a and b;

		if input(substr(year_month, 1, 4), 8.)=&endyear. and input(substr(year_month, 6, 2), 8.)>&endmonth. then
			delete;

		if condition ne "HTN-C orig" and est_type="modeled";
		keep state_name geographic_level Condition year_month rural_urban est_type Npats prevalence0 se0 sort;
		length rural_urban $100.;

		if ru='Completely rural' then
			rural_urban='Completely_rural';
		else if ru='Mostly rural' then
			rural_urban='Mostly_rural';
		else if ru='Mostly urban' then
			rural_urban='Mostly_urban';

		if geographic_level in ("70187","70044","70429","70664") then
			state_name="LA";

		if geographic_level in ("82717") then
			state_name="WY";
		prevalence0=prevalence/100;
		se0=se/100;
	run;

%mend;

%macro Suppress(estimate_level=);
	%if &geographic_level.=national %then
		%do;

			data  f1 (rename=(condition2=Condition));
				set sasin.Est_wide_&geographic_level.: sasin.est_wide_Ru_&estimate_level:;
				retain geographic_type geographic_level Condition2 year_month Group1 GroupValue1 Group2 GroupValue2;
				where substr(Condition, 1, 3)="PPH";

				if input(substr(year_month, 1, 4), 8.)=&endyear. and input(substr(year_month, 6, 2), 8.)>&endmonth. then
					delete;

				if upcase(group1)="RU2" then
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
			run;

			proc freq data=f1;
				table year_month*(Suppress Sample_less15_flag)/list missing;
			run;

			proc sort data=f1;
				by geographic_type geographic_level year_month Condition Group1 Group2 groupvalue1 groupvalue2;
			run;

			proc sql noprint;
				select count(*) into: sample_less15_flag_cnt
					from f1
						where sample_less15_flag=1;
			quit;

			%put &sample_less15_flag_cnt.;

			%if &sample_less15_flag_cnt.=0 %then
				%do;

					data Prev_Est_Supr0 (keep=geographic_type geographic_level year_month Condition Group1 Group2 groupvalue1 groupvalue2 sample_pt crude_prev crude_stderr pop_perc std_err Suppress Sample_less15_flag);
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
					data less15_sex0 (keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2) less15_agecat0 (keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2) ge15;
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

						if year_month=lag_year_month and geographic_type=lag_geographic_type and geographic_level=lag_geographic_level and Condition=lag_condition and Group1=lag_group1 and Group2=lag_group2 and sample_less15_flag0=0 and lag_sample_less15_flag=1 then
							sample_less15_flag=1;
						else sample_less15_flag=sample_less15_flag0;
						drop lag_sample_less15_flag sample_less15_flag0 lag_year_month lag_geographic_type lag_geographic_level lag_condition lag_group1 lag_group2;
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
				keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Crude_Prev Crude_StdErr Suppress Sample_less15_flag;
				length est_type $15.;
				est_type="crude";
			run;

			data Prev_Est_Supr_wgt (rename=(Sample_PT=Npats Pop_Perc=prevalence STD_Err=se));
				set Prev_Est_Supr0;
				keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Pop_Perc STD_Err Suppress Sample_less15_flag;
				length est_type $15.;
				est_type="modeled";
			run;

			data sasout.Supr_&geographic_level.;
				retain geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Npats prevalence se;
				set Prev_Est_Supr_crd Prev_Est_Supr_wgt;
				sort=_N_;
			run;

			proc sort data=sasout.Supr_&geographic_level.;
				by sort;
			run;

			data sasout.Supr_ivest_&geographic_level. (rename=(prevalence0=prevalence se0=se));
				retain Condition year_month Group GroupValue est_type Npats prevalence0 se0;
				set sasout.Supr_&geographic_level.;

				if est_type="modeled" and Group1 ne "agec" and Group1 ne "agecat" and Group2="all" and condition ne "HTN-C orig";
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
				prevalence0=prevalence/100;
				se0=se/100;
				keep Condition year_month Group GroupValue est_type Npats prevalence0 se0 sort;
			run;

			proc sort data=sasout.Supr_ivest_&geographic_level.;
				by sort;
			run;

		%end;
	%else %if &geographic_level.=state %then
		%do; 
			%do year=&startyear. %to &endyear.;

				data subset&year.;
					set sasin.Est_wide_&geographic_level.&year.:;
					where substr(Condition, 1, 3)="PPH";

					if input(substr(year_month, 1, 4), 8.)=&endyear. and input(substr(year_month, 6, 2), 8.)>&endmonth. then
						delete;

					if upcase(group1)="RU2" then
						delete;

					if upcase(group1)="ALL" and upcase(group2)="ALL" then
						delete;

					if geographic_level in ("05","04","06","08","12","15","17","18","21","22","25","24","28","31","34","36","40","41","48","51","53","56");
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

			data ru;
				set sasin.est_wide_Ru_&estimate_level:;
				where substr(Condition, 1, 3)="PPH";

				if input(substr(year_month, 1, 4), 8.)=&endyear. and input(substr(year_month, 6, 2), 8.)>&endmonth. then
					delete;

				if upcase(group1)="RU2" then
					delete;

				if geographic_level in ("05","04","06","08","12","15","17","18","21","22","25","24","28","31","34","36","40","41","48","51","53","56");
			run;

			data f1 (rename=(condition2=Condition));;
				retain geographic_type geographic_level Condition2 year_month Group1 GroupValue1 Group2 GroupValue2;
				set subset ru;

				*@Action: Suppress estimate if sample size < 50 OR CV >= 30%.;
				Suppress=0;

				if crude_prev>0 then
					do;
						if sample_pt<50 or (Crude_StdErr/Crude_Prev) ge .3 or (STD_Err/Pop_Perc) ge .3 then
							Suppress=1;
					end;
				else if crude_prev=0 then
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
				by geographic_type geographic_level year_month Condition Group1 Group2 groupvalue1 groupvalue2;
			run;

			proc sql noprint;
				select count(*) into: sample_less15_flag_cnt
					from f1
						where sample_less15_flag=1;
			quit;

			%put &sample_less15_flag_cnt.;

			%if &sample_less15_flag_cnt.=0 %then
				%do;

					data Prev_Est_Supr0 (keep=geographic_type geographic_level year_month Condition Group1 Group2 groupvalue1 groupvalue2 sample_pt crude_prev crude_stderr pop_perc std_err Suppress Sample_less15_flag);
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
					data less15_sex0 (keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2) less15_agecat0 (keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2);
						set f1;

						if Sample_less15_flag=1 and group2="sex" then
							output less15_sex0;
						else if Sample_less15_flag=1 and group2="agecat" then
							output less15_agecat0;
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

						if year_month=lag_year_month and geographic_type=lag_geographic_type and geographic_level=lag_geographic_level and Condition=lag_condition and Group1=lag_group1 and Group2=lag_group2 and sample_less15_flag0=0 and lag_sample_less15_flag=1 then
							sample_less15_flag=1;
						else sample_less15_flag=sample_less15_flag0;
						drop lag_sample_less15_flag sample_less15_flag0 lag_year_month lag_geographic_type lag_geographic_level lag_condition lag_group1 lag_group2;
					run;

					proc sort data=f1 out=f1_sorted;
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2;
					run;

					data ge15;
						merge f1_sorted (in=a) 
								less15_sex (in=b keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2)
								less15_agecat_p1 (in=c keep=year_month geographic_type geographic_level condition group1 groupvalue1 group2);
						by year_month geographic_type geographic_level condition group1 groupvalue1 group2;
						if a and not b and not c;
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

			/*@Action: updated SAE overall numbers*/
			proc import datafile= "P:\A154\Common\SAE\Q1\Model Estimates\State_Estimates_Modeled.xlsx" 
				out= work.&geographic_level._sae_est0
				dbms=xlsx
				replace;
				sheet="Sheet 1";
				getnames=yes;
			run;

			data &geographic_level._sae_est_crude (rename=(state_fips=geographic_level year_month0=year_month est_type0=est_type condition0=condition));
				retain geographic_type state_fips condition0 year_month0 Group1 GroupValue1 Group2 GroupValue2 est_type0 npats prevalence se;
				set &geographic_level._sae_est0 (rename=(year_month=year_month0 est_type=est_type0 condition=condition0));
				keep year_month0 geographic_type state_fips condition0 Group1 GroupValue1 Group2 GroupValue2 est_type0 npats prevalence se;
				length geographic_type group1 group2 groupvalue1 groupvalue2 $50.;

				if est_type0="crude";
				geographic_type="STATE";
				group1="all";
				groupvalue1="all";
				group2="all";
				groupvalue2="all";
			run;

			data &geographic_level._sae_est_model (rename=(state_fips=geographic_level year_month0=year_month est_type0=est_type condition0=condition));
				retain geographic_type state_fips condition0 year_month0 Group1 GroupValue1 Group2 GroupValue2 est_type0 npats prevalence se;
				set &geographic_level._sae_est0 (rename=(year_month=year_month0 est_type=est_type0 condition=condition0));
				keep year_month0 geographic_type state_fips condition0 Group1 GroupValue1 Group2 GroupValue2 est_type0 npats prevalence se;
				length geographic_type group1 group2 groupvalue1 groupvalue2 $50.;

				if est_type0="modeled";
				geographic_type="STATE";
				group1="all";
				groupvalue1="all";
				group2="all";
				groupvalue2="all";
			run;

			/*@Action: Export suppressed version*/
			data Prev_Est_Supr_crd (rename=(Sample_PT=Npats Crude_Prev=prevalence Crude_StdErr=se));
				set Prev_Est_Supr0;
				keep year_month geographic_type geographic_level Condition Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Crude_Prev Crude_StdErr Suppress Sample_less15_flag;
				length est_type $15.;
				est_type="crude";
			run;

			data Prev_Est_Supr_wgt (rename=(Sample_PT=Npats Pop_Perc=prevalence STD_Err=se));
				set Prev_Est_Supr0;
				keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Pop_Perc STD_Err Suppress Sample_less15_flag;
				length est_type $15.;
				est_type="modeled";
			run;

			data sasout.Supr_&geographic_level.;
				retain geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Npats prevalence se;
				set &geographic_level._sae_est_crude Prev_Est_Supr_crd &geographic_level._sae_est_model Prev_Est_Supr_wgt;
				sort=_N_;
			run;

			proc sql;
				create table state_names as
					select distinct State_FIPS as geographic_level
						, State as state_name
					from xwalk.zip_xwalk_final
						where geographic_level ne ""
							order by geographic_level;
			quit;

			proc sort data=sasout.Supr_&geographic_level. out=Supr_&geographic_level._sorted;
				by geographic_level;
			run;

			data sasout.Supr_ivest_&geographic_level. (rename=(prevalence0=prevalence se0=se));
				retain state_name geographic_level Condition year_month Group GroupValue Group2 GroupValue2 est_type Npats prevalence0 se0;
				merge Supr_&geographic_level._sorted (in=a) state_names;
				by geographic_level;

				if a;

				if est_type="modeled" and Group1 ne "agec" and Group1 ne "agecat" and Group2="all";
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
				prevalence0=prevalence/100;
				se0=se/100;
				drop Group1 GroupValue1 Group2 GroupValue2 geographic_type prevalence se suppress sample_less15_flag;
			run;

			proc sort data=sasout.Supr_ivest_&geographic_level.;
				by sort;
			run;

			proc datasets library=work nolist;
				delete f1 ge15 f1_sex less15_sex0 less15_sex f1_agecat less15_agecat0 less15_agecat less15_agecat_p1 Prev_Est_Supr0 Prev_Est_Supr_crd Prev_Est_Supr_wgt;
			run;

			quit;

		%end;
	%else %if &geographic_level.=county %then
		%do;
			/*@Action: updated SAE overall numbers*/
			proc import datafile= "P:\A154\Common\SAE\Q1\Model Estimates\County_Estimates_Modeled.xlsx" 
				out= supr_&geographic_level.
				dbms=xlsx
				replace;
				sheet="Sheet 1";
				getnames=yes;
			run;

			/*@Action: import zip &geographic_level. xwalk*/
			PROC IMPORT DATAFILE= "P:\A154\Common\PUF_Data\Crosswalks\ZIP_COUNTY_122024_From_HUDQ42024.xlsx" 
				OUT= WORK.zip_county_HUD0
				DBMS=XLSX
				REPLACE;
				SHEET="Export Worksheet";
				GETNAMES=YES;
			RUN;

			proc sort data=zip_&geographic_level._HUD0 out=zip_&geographic_level._HUD (keep=zip &geographic_level. rename=(&geographic_level.=geographic_level));
				by zip;
			run;

			/*includes RUCA and RUCC codes - merge based on ZIP only*/
			data zip_xwalk0;
				set xwalk.zip_xwalk_final;
				where zip ne "";
				keep zip ruca1;
			Run;

			proc sort data=zip_xwalk0;
				by zip;
			run;

			data &geographic_level._state_xwalk;
				merge zip_xwalk0 (in=a) zip_&geographic_level._HUD (in=b);
				by zip;
				length rural_urban $100.;

				if a and b and geographic_level ne "99999";

				if 1<=ruca1<=3 then
					rural_urban='Mostly_urban';
				else if 4<=ruca1<=7 then
					rural_urban='Mostly_rural';
				else if 8<=ruca1<=10 then
					rural_urban='Completely_rural';
				keep geographic_level rural_urban;
			run;

			proc sql;
				create table &geographic_level._state_summary0 as 
					select distinct geographic_level 
						, rural_urban
						, count(*) as rows
					from &geographic_level._state_xwalk
						group by geographic_level
							, rural_urban
						order by geographic_level
							, rows desc;
			quit;

			proc sort data=&geographic_level._state_summary0 out=&geographic_level._state_summary (drop=rows) nodupkey;
				by geographic_level;
			run;

			proc sql;
				create table state_codes as 
					select distinct put(state, z2.) as state
						, statecode
					from sashelp.zipcode
						where state in (5,4,6,8,12,15,17,18,21,22,25,24,28,31,34,36,40,41,48,51,53,56);
			quit;

			/*update variable names in the SAE models*/
			data sasout.supr_&geographic_level. (rename=(FIPS_STATE_COUNTY=geographic_level year_month0=year_month est_type0=est_type condition0=Condition npats0=npats prevalence0=prevalence se0=se));
				retain geographic_type FIPS_STATE_COUNTY condition0 year_month0 Group1 GroupValue1 Group2 GroupValue2 est_type0 npats0 prevalence0 se0 sort;
				set supr_&geographic_level. (rename=(year_month=year_month0 est_type=est_type0 condition=condition0 npats=npats0 prevalence=prevalence0 se=se0));
				sort=_N_;

				if substr(FIPS_STATE_COUNTY,1,2) in ("05","04","06","08","12","15","17","18","21","22","25","24","28","31","34","36","40","41","48","51","53","56");
				geographic_type="COUNTY";
				Group1="all";
				GroupValue1="all";
				Group2="all";
				GroupValue2="all";
			run;

			/*@Action: Sort Crosswalk and EHR datasets and merge, flag counties that dont match or have a residential ratio of 0***/
			proc sql;
				create table Supr_&geographic_level._sorted as 
					select a.*
						, b.rural_urban
						, c.STATECODE as state
					from (sasout.supr_&geographic_level. as a
						left join &geographic_level._state_summary as b
							on a.geographic_level=b.geographic_level)
						left join state_codes as c
							on substr(a.geographic_level,1,2)=c.state;
			quit;

			data sasout.Supr_ivest_&geographic_level. (rename=(prevalence0=prevalence se0=se));
				retain state &geographic_level._fips Condition year_month est_type rural_urban Npats prevalence0 se0;
				set Supr_&geographic_level._sorted;

				if input(substr(year_month, 1, 4), 8.)=&endyear. and input(substr(year_month, 6, 2), 8.)>&endmonth. then
					delete;

				if condition ne "HTN-C orig" and est_type="modeled";
				&geographic_level._fips=input(geographic_level,5.);

				if &geographic_level._fips=99999 then
					delete;
				keep state &geographic_level._fips Condition year_month rural_urban est_type Npats prevalence0 se0 sort;
				prevalence0=prevalence/100;
				se0=se/100;
			run;

			proc sort data=sasout.Supr_ivest_&geographic_level.;
				by sort;
			run;

			Proc Datasets Library=WORK NOLIST Kill;
			Quit;

		%end;
	%else %if &geographic_level.=zip %then
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
						,  case
							when 1<=a.ruca1<=3 then 'Mostly urban'
							when 4<=a.ruca1<=7 then 'Mostly rural'
							when 8<=a.ruca1<=10 then 'Completely rural'
							else ''
						end as ru
					from xwalk.zip_xwalk_final as a
						left join state_names0 as b
							on a.fips_state=put(b.state, z2.)
						where geographic_level ne "" 
							and a.state_fips in ("05","04","06","08","12","15","17","18","21","22","25","24","28","31","34","36","40","41","48","51","53","56")
						order by geographic_level;
			quit;

			%suppresszip(year=2019_2020);
			%suppresszip(year=2021_2022);
			%suppresszip(year=2023_2024);

			Proc Datasets Library=WORK NOLIST Kill;
			Quit;

		%end;
%mend;

/*@Program End ***/