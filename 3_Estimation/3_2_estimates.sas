%macro crude(byvar=);

	proc sort data=&weighted_file.0 out=&weighted_file.;
		by geographic_level &byvar.;
	run;

	*htn flag;
	proc surveyfreq data = &weighted_file.;
		table htnyn/cl;
			by geographic_level &byvar.;
			where htnyn ne .;
			ods output oneway=htnyn_&byvar._Crde0;
	run;

	data htnyn_&byvar._crde1;
		set htnyn_&byvar._crde0;
		where htnyn=1;
		keep geographic_level &byvar. Crude_Prev Crude_StdErr;
		Crude_Prev=percent/100;
		Crude_StdErr=StdErr/100;
	run;

	data htnyn_&byvar._crde2 (rename=(Frequency=_FREQ_));
		set htnyn_&byvar._crde0;
		where htnyn=.;
		keep geographic_level &byvar. Frequency;
	run;

	data htnyn_&byvar._crde;
		merge htnyn_&byvar._crde2 htnyn_&byvar._crde1;
		by geographic_level &byvar.;
	run;

	*controlled htn;
	proc surveyfreq data = &weighted_file.;
		table htnc/cl;
			by geographic_level &byvar.;
			where htnyn=1;
			ods output oneway=htnc_&byvar._Crde0;
	run;

	data htnc_&byvar._crde1;
		set htnc_&byvar._crde0;
		where htnc=1;
		keep geographic_level &byvar. Crude_Prev Crude_StdErr;
		Crude_Prev=percent/100;
		Crude_StdErr=StdErr/100;
	run;

	data htnc_&byvar._crde2 (rename=(Frequency=_FREQ_));
		set htnc_&byvar._crde0;
		where htnc=.;
		keep geographic_level &byvar. Frequency;
	run;

	data htnc_&byvar._crde;
		merge htnc_&byvar._crde2 htnc_&byvar._crde1;
		by geographic_level &byvar.;
	run;

	proc datasets library=work nolist;
		delete htnyn_&byvar._crde0 htnyn_&byvar._crde1 htnyn_&byvar._crde2 htnc_&byvar._crde0 htnc_&byvar._crde1 htnc_&byvar._crde2;
	run;

	quit;

%mend;

%macro crude2tab(byvar1=, byvar2=);

	proc sort data=&weighted_file.0 out=&weighted_file.;
		by geographic_level &byvar1. &byvar2.;
	run;

	*htn flag;
	proc surveyfreq data = &weighted_file.;
		table htnyn/cl;
			by geographic_level &byvar1. &byvar2.;
			where htnyn ne .;
			ods output oneway=htnyn_&byvar1._&byvar2._Crde0;
	run;

	data htnyn_&byvar1._&byvar2._crde1;
		set htnyn_&byvar1._&byvar2._crde0;
		where htnyn=1;
		keep geographic_level &byvar1. &byvar2. Crude_Prev Crude_StdErr;
		Crude_Prev=percent/100;
		Crude_StdErr=StdErr/100;
	run;

	data htnyn_&byvar1._&byvar2._crde2 (rename=(Frequency=_FREQ_));
		set htnyn_&byvar1._&byvar2._crde0;
		where htnyn=.;
		keep geographic_level &byvar1. &byvar2. Frequency;
	run;

	data htnyn_&byvar1._&byvar2._crde;
		merge htnyn_&byvar1._&byvar2._crde2 htnyn_&byvar1._&byvar2._crde1;
		by geographic_level &byvar1. &byvar2.;
	run;

	*controlled htn;
	proc surveyfreq data = &weighted_file.;
		table htnc/cl;
			by geographic_level &byvar1. &byvar2.;
			where htnyn=1;
			ods output oneway=htnc_&byvar1._&byvar2._Crde0;
	run;

	data htnc_&byvar1._&byvar2._crde1;
		set htnc_&byvar1._&byvar2._crde0;
		where htnc=1;
		keep geographic_level &byvar1. &byvar2. Crude_Prev Crude_StdErr;
		Crude_Prev=percent/100;
		Crude_StdErr=StdErr/100;
	run;

	data htnc_&byvar1._&byvar2._crde2 (rename=(Frequency=_FREQ_));
		set htnc_&byvar1._&byvar2._crde0;
		where htnc=.;
		keep geographic_level &byvar1. &byvar2. Frequency;
	run;

	data htnc_&byvar1._&byvar2._crde;
		merge htnc_&byvar1._&byvar2._crde2 htnc_&byvar1._&byvar2._crde1;
		by geographic_level &byvar1. &byvar2.;
	run;

	proc datasets library=work nolist;
		delete htnyn_&byvar1._&byvar2._crde0 htnyn_&byvar1._&byvar2._crde1 htnyn_&byvar1._&byvar2._crde2
			htnc_&byvar1._&byvar2._crde0 htnc_&byvar1._&byvar2._crde1 htnc_&byvar1._&byvar2._crde2;
	run;

	quit;

%mend;

/*@Action: Estimate the variance for prevalence estimates ***/
%macro est_overall(est_type=);
	/*weighted prevalance*/
	proc surveyfreq data = &weighted_file.0;
		table &est_type./ row;
			weight RakeWgt;
			by geographic_level;
			where &est_type. ne .;
			ods output oneway=wgt&est_type.all;
	run;

	/*format prevalance and population/sample counts*/
	data PB&est_type.all;
		set WGT&est_type.ALL (where=(&est_type. ne .) keep=&est_type. geographic_level percent stderr rename=(Percent=Pop_Perc StdErr=STD_Err));
		Group1="all";
		GroupValue1="all";
		Group2="all";
		GroupValue2="all";
	run;

	data n&est_type.all (drop=&est_type.);
		set WGT&est_type.ALL (where=(&est_type.=.) keep=&est_type. geographic_level WgtFreq rename=(WgtFreq=Pop_n));
		Group1="all";
		GroupValue1="all";
		Group2="all";
		GroupValue2="all";
	run;

	/*subset crude prevanalence estimates*/
	Proc Sql;
		create table CPE&est_type.all as 
			select * 
				from Crude_Prev_Estimates_HTN 
					where Group1="all" 					
						and &est_type. ne .;
	Quit;

	%if &est_type.=htnyn %then
		%do;
			%let condition=PPH HTN;
		%end;
	%else %if &est_type.=htnc %then
		%do;
			%let condition=PPH HTN-C;
		%end;

	/*merge the files together*/
	Proc Sql;
		Create table PEoverall&est_type. as
			Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
				, "&estimate_level." as geographic_type length=50
				, b.geographic_level length=50
				, "&condition." as Condition length=50
				, a.&est_type. as Condition_level
				, a.Group1 length=50
				, a.GroupValue1 length=50
				, a.Group2 length=50
				, a.GroupValue2 length=50
				, c._FREQ_ as Sample_PT
				, b.Pop_n
				, c.Crude_Prev*100 as Crude_Prev
				, c.Crude_StdErr*100 as Crude_StdErr
				, a.Pop_Perc
				, a.STD_Err
			From PB&est_type.all as a
				, n&est_type.all as b
				, CPE&est_type.all as c
			where a.geographic_level=b.geographic_level
				and a.geographic_level=c.geographic_level
				and a.&est_type.=c.&est_type.
				and a.Group1=b.Group1 
				and a.Group1=c.Group1
				and a.GroupValue1=b.GroupValue1
				and a.GroupValue1=c.GroupValue1
				and a.Group2=b.Group2
				and a.Group2=c.Group2
				and a.GroupValue2=b.GroupValue2
				and a.GroupValue2=c.GroupValue2
			order by geographic_level
				, condition_level
				, Group1
				, GroupValue1
				, Group2
				, GroupValue2;
	Quit;

	proc append data=PEoverall&est_type. base=sasout.Est_wide_&abbr_estimate_level._HTN&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. force;
	run;

%mend;

%macro est1tab(est_type=, var=);
	/*weighted prevalance*/
	proc surveyfreq data = &weighted_file.0;
		table &var.*&est_type./ row;
			weight RakeWgt;
			by geographic_level;
			where &est_type. ne . and &var. ne "";
			ods output crosstabs=wgt&est_type.&var.;
	run;

	/*format prevalance and population/sample counts*/
	data PB&est_type.&var. (drop=&var.);
		set WGT&est_type.&var. (where=(&est_type. ne . and &var. ne "") keep=&est_type. geographic_level &var. rowpercent rowstderr rename=(rowpercent=Pop_Perc rowstderr=STD_Err));
		Group1="&var.";
		GroupValue1=&var.;
		Group2="all";
		GroupValue2="all";
	run;

	data n&est_type.&var. (drop=&est_type.);
		set WGT&est_type.&var. (where=(&est_type.=. and &var. ne "") keep=&est_type. geographic_level &var. WgtFreq rename=(WgtFreq=Pop_n));
		Group1="&var.";
		GroupValue1=&var.;
		Group2="all";
		GroupValue2="all";
	run;

	/*subset crude prevanalence estimates*/
	Proc Sql;
		create table CPE&est_type.&var. as 
			select * 
				from Crude_Prev_Estimates_HTN 
					where Group1="&var."
						and &est_type. ne .;
	Quit;

	%if &est_type.=htnyn %then
		%do;
			%let condition=PPH HTN;
		%end;
	%else %if &est_type.=htnc %then
		%do;
			%let condition=PPH HTN-C;
		%end;

	/*merge the files together*/
	Proc Sql;
		Create table PE&var.&est_type. as
			Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
				, "&estimate_level." as geographic_type length=50
				, b.geographic_level length=50
				, "&condition." as Condition length=50
				, a.&est_type. as Condition_level
				, a.Group1 length=50
				, a.GroupValue1 length=50
				, a.Group2 length=50
				, a.GroupValue2 length=50
				, c._FREQ_ as Sample_PT
				, b.Pop_n
				, c.Crude_Prev*100 as Crude_Prev
				, c.Crude_StdErr*100 as Crude_StdErr
				, a.Pop_Perc
				, a.STD_Err
			From PB&est_type.&var. as a
				, n&est_type.&var. as b
				, CPE&est_type.&var. as c
			where a.geographic_level=b.geographic_level
				and a.geographic_level=c.geographic_level
				and a.&est_type.=c.&est_type.
				and a.Group1=b.Group1 
				and a.Group1=c.Group1
				and a.GroupValue1=b.GroupValue1
				and a.GroupValue1=c.GroupValue1
				and a.Group2=b.Group2
				and a.Group2=c.Group2
				and a.GroupValue2=b.GroupValue2
				and a.GroupValue2=c.GroupValue2
			order by geographic_level
				, condition_level
				, Group1
				, GroupValue1
				, Group2
				, GroupValue2;
	Quit;

	proc append data=PE&var.&est_type. base=sasout.Est_wide_&abbr_estimate_level._HTN&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. force;
	run;

%mend;

%macro est2tab(est_type=, var1=, var2=);
	/*weighted prevalance*/
	proc surveyfreq data = &weighted_file.0;
		table &var1.*&var2.*&est_type./ row;
			weight RakeWgt;
			by geographic_level;
			where &est_type. ne . and &var1. ne "" and &var2. ne "";
			ods output crosstabs=wgt&est_type.&var1.&var2.;
	run;

	/*format prevalance and population/sample counts*/
	data PB&est_type.&var1.&var2. (drop=&var1. &var2.);
		set WGT&est_type.&var1.&var2. (where=(&est_type. ne . and &var1. ne "" and &var2. ne "") 
			keep=&est_type. geographic_level &var1. &var2. rowpercent rowstderr
			rename=(rowpercent=Pop_Perc rowstderr=STD_Err));
		Group1="&var1.";
		GroupValue1=&var1.;
		Group2="&var2.";
		GroupValue2=&var2.;
	run;

	data n&est_type.&var1.&var2. (drop=&est_type. &var1. &var2.);
		set WGT&est_type.&var1.&var2. (where=(&est_type.=. and &var1. ne "" and &var2. ne "") 
			keep=&est_type. &var1. geographic_level &var2. WgtFreq 
			rename=(WgtFreq=Pop_n));
		Group1="&var1.";
		GroupValue1=&var1.;
		Group2="&var2.";
		GroupValue2=&var2.;
	run;

	/*subset crude prevanalence estimates*/
	Proc Sql;
		create table CPE&est_type.&var1.&var2. as 
			select * 
				from Crude_Prev_Estimates_HTN 
					where Group1="&var1."
						and Group2="&var2."						
						and &est_type. ne .;
	Quit;

	%if &est_type.=htnyn %then
		%do;
			%let condition=PPH HTN;
		%end;
	%else %if &est_type.=htnc %then
		%do;
			%let condition=PPH HTN-C;
		%end;

	/*merge the files together*/
	Proc Sql;
		Create table PE&var1.&var2.&est_type. as
			Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
				, "&estimate_level." as geographic_type length=50
				, b.geographic_level length=50
				, "&condition" as Condition length=50
				, a.&est_type. as Condition_level
				, a.Group1 length=50
				, a.GroupValue1 length=50
				, a.Group2 length=50
				, a.GroupValue2 length=50
				, c._FREQ_ as Sample_PT
				, b.Pop_n
				, c.Crude_Prev*100 as Crude_Prev
				, c.Crude_StdErr*100 as Crude_StdErr
				, a.Pop_Perc
				, a.STD_Err
			From PB&est_type.&var1.&var2. as a
				, n&est_type.&var1.&var2. as b
				, CPE&est_type.&var1.&var2. as c
			where a.geographic_level=b.geographic_level
				and a.geographic_level=c.geographic_level
				and a.&est_type.=c.&est_type.
				and a.Group1=b.Group1 
				and a.Group1=c.Group1
				and a.GroupValue1=b.GroupValue1
				and a.GroupValue1=c.GroupValue1
				and a.Group2=b.Group2
				and a.Group2=c.Group2
				and a.GroupValue2=b.GroupValue2
				and a.GroupValue2=c.GroupValue2
			order by geographic_level
				, condition_level
				, Group1
				, GroupValue1
				, Group2
				, GroupValue2;
	Quit;

	proc append data=PE&var1.&var2.&est_type. base=sasout.Est_wide_&abbr_estimate_level._HTN&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. force;
	run;

%mend;

%macro est_loop(est_type=);
	%if &estimate_level.=NATIONAL %then
		%do;
			%est_overall(est_type=&est_type.);
			%est1tab(var=sex, est_type=&est_type.);
			%est1tab(var=agecat, est_type=&est_type.);
			%est1tab(var=agec_col, est_type=&est_type.);
			%est1tab(var=raceeth2, est_type=&est_type.);
		%end;

	%est1tab(var=prmpay, est_type=&est_type.);
	%est1tab(var=ru, est_type=&est_type.);
	%est2tab(var1=agecat, var2=sex, est_type=&est_type.);
	%est2tab(var1=raceeth2, var2=sex, est_type=&est_type.);
	%est2tab(var1=ru, var2=agecat, est_type=&est_type.);
	%est2tab(var1=ru, var2=sex, est_type=&est_type.);
%mend;

%macro estimates();
	%if &National_est.=Y %then
		%do;
			%Let estimate_level = NATIONAL;
			%let abbr_estimate_level = NATL;
			%let weighted_file=wgt_HTN_natl_&year_loop.&month_loop.;
			%let geographic_level="NATIONAL";
			%let input_wgt_file=wgt_HTN_&abbr_estimate_level._&year_loop.&month_loop.;
		%end;
	%else %if &STATE_EST. = Y %then
		%do;
			%Let estimate_level = STATE;
			%let abbr_estimate_level = ST;
			%let weighted_file=wgt_HTN_state_&year_loop.&month_loop.;
			%let geographic_level=&estimate_level.;
			%let input_wgt_file=wgt_HTN_&estimate_level._&year_loop.&month_loop.;
		%end;

	data &weighted_file.0 (rename=(age3=agec_col));
		%if &estimate_level.= STATE %then
			%do;
				set sasin.&input_wgt_file. (keep=htnyn htnc bmi rakewgt sex agec0 age3 raceeth2 prmpay ruca1 &geographic_level. rename=(htnyn=htnyn_old htnc=htnc_old bmi=bmi_old));
			%end;
		%else
			%do;
				set sasin.&input_wgt_file. (keep=htnyn htnc bmi rakewgt sex agec0 age3 raceeth2 prmpay ruca1 rename=(htnyn=htnyn_old htnc=htnc_old bmi=bmi_old));
			%end;

		geographic_level=&geographic_level.;

		/*change pph values to numeric*/
		htnyn=input(htnyn_old, 8.);
		htnc=input(htnc_old, 8.);
		bmi=input(bmi_old, 8.);

		/*create a 3 level rural/urban variable*/
		length ru agecat $50.;

		if 1<=ruca1<=3 then
			ru='Mostly urban';
		else if 4<=ruca1<=7 then
			ru='Mostly rural';
		else if 8<=ruca1<=10 then
			ru='Completely rural';

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

	proc sort data=&weighted_file.0;
		by geographic_level;
	run;

	proc freq data=&weighted_file.0;
		table bmi bmi*(raceeth2 sex agec_col agecat ru prmpay)/list missing;
	run;

	%if &estimate_level.=NATIONAL %then
		%do;
			%if HTN=HTN %then
				%do;
					/*@Note: Prevalence Estimation and Output Routine***/
					/*@Action: Use weighted USER file to produce prevalence estimates ***/
					/*@Action: Estimate Crude Rates ***/
					*htn flag;
					proc surveyfreq data = &weighted_file.0;
						table htnyn/cl;
							by geographic_level;
							where htnyn ne .;
							ods output oneway=htnyn_Crde0;
					run;

					data htnyn_crde1;
						set htnyn_crde0;
						where htnyn=1;
						keep geographic_level Crude_Prev Crude_StdErr;
						Crude_Prev=percent/100;
						Crude_StdErr=StdErr/100;
					run;

					data htnyn_crde2 (rename=(Frequency=_FREQ_));
						set htnyn_crde0;
						where htnyn=.;
						keep geographic_level Frequency;
					run;

					data htnyn_crde;
						merge htnyn_crde2 htnyn_crde1;
						by geographic_level;
					run;

					*controlled htn;
					proc surveyfreq data = &weighted_file.0;
						table htnc/cl;
							by geographic_level;
							where htnyn=1;
							ods output oneway=htnc_Crde0;
					run;

					data htnc_crde1;
						set htnc_crde0;
						where htnc=1;
						keep geographic_level Crude_Prev Crude_StdErr;
						Crude_Prev=percent/100;
						Crude_StdErr=StdErr/100;
					run;

					data htnc_crde2 (rename=(Frequency=_FREQ_));
						set htnc_crde0;
						where htnc=.;
						keep geographic_level Frequency;
					run;

					data htnc_crde;
						merge htnc_crde2 htnc_crde1;
						by geographic_level;
					run;

					proc datasets library=work nolist;
						delete htnyn_crde0 htnyn_crde1 htnyn_crde2 htnc_crde0 htnc_crde1 htnc_crde2;
					run;

					quit;

					%crude(byvar=sex);
					%crude(byvar=agecat);
					%crude(byvar=agec_col);
					%crude(byvar=raceeth2);
				%end;

			%crude(byvar=prmpay);
			%crude(byvar=ru);
			%crude2tab(byvar1=agecat, byvar2=sex);
			%crude2tab(byvar1=raceeth2, byvar2=sex);
			%crude2tab(byvar1=ru, byvar2=sex);
			%crude2tab(byvar1=ru, byvar2=agecat);

			%if &estimate_level.=NATIONAL %then
				%do;
					%if HTN=HTN %then
						%do;

							Data Crude_Prev_Estimates_HTN(Keep=geographic_level htnyn htnc Group1 Groupvalue1 Group2 Groupvalue2 _FREQ_ Crude_Prev Crude_StdErr);
								Retain geographic_level Group1 Groupvalue1 Group2 Groupvalue2 htnyn htnc _FREQ_ Crude_Prev Crude_StdErr;
								Length htnyn htnc 8. Group1 Groupvalue1 Group2 Groupvalue2 $200.;
								Set	htnyn_Crde (in=infile1)
									htnc_Crde (in=infile2)
									htnyn_sex_Crde (in=infile3 rename=(sex=Groupvalue1))
									htnc_sex_Crde (in=infile4 rename=(sex=Groupvalue1))
									htnyn_agecat_Crde (in=infile5 rename=(agecat=Groupvalue1))
									htnc_agecat_Crde (in=infile6 rename=(agecat=Groupvalue1))
									htnyn_agec_col_Crde (in=infile7 rename=(agec_col=Groupvalue1))
									htnc_agec_col_Crde (in=infile8 rename=(agec_col=Groupvalue1))
									htnyn_raceeth2_Crde (in=infile9 rename=(raceeth2=Groupvalue1))
									htnc_raceeth2_Crde (in=infile10 rename=(raceeth2=Groupvalue1))
									htnyn_prmpay_Crde (in=infile11 rename=(prmpay=Groupvalue1))
									htnc_prmpay_Crde (in=infile12 rename=(prmpay=Groupvalue1))
									htnyn_ru_Crde (in=infile13 rename=(ru=Groupvalue1))
									htnc_ru_Crde (in=infile14 rename=(ru=Groupvalue1))
									htnyn_agecat_sex_Crde (in=infile15 rename=(agecat=Groupvalue1 sex=Groupvalue2))
									htnc_agecat_sex_Crde (in=infile16 rename=(agecat=Groupvalue1 sex=Groupvalue2))
									htnyn_raceeth2_sex_Crde (in=infile17 rename=(raceeth2=Groupvalue1 sex=Groupvalue2))
									htnc_raceeth2_sex_Crde (in=infile18 rename=(raceeth2=Groupvalue1 sex=Groupvalue2))
									htnyn_ru_sex_Crde (in=infile19 rename=(ru=Groupvalue1 sex=Groupvalue2))
									htnc_ru_sex_Crde (in=infile20 rename=(ru=Groupvalue1 sex=Groupvalue2))
									htnyn_ru_agecat_Crde (in=infile21 rename=(ru=Groupvalue1 agecat=Groupvalue2))
									htnc_ru_agecat_Crde (in=infile22 rename=(ru=Groupvalue1 agecat=Groupvalue2));

								If infile1|infile3|infile5|infile7|infile9|infile11|infile13|infile15|infile17|infile19|infile21 Then
									htnyn=1;
								else htnyn=0;

								If infile2|infile4|infile6|infile8|infile10|infile12|infile14|infile16|infile18|infile20|infile22 Then
									htnc=1;
								else htnc=0;

								if infile1|infile2 then
									Group1="all";
								else if infile3|infile4 then
									Group1="sex";
								else if infile5|infile6|infile15|infile16 then
									Group1="agecat";
								else if infile7|infile8 then
									Group1="agec_col";
								else if infile9|infile10|infile17|infile18 then
									Group1="raceeth2";
								else if infile11|infile12 then
									Group1="prmpay";
								else if infile13|infile14|infile19|infile20|infile21|infile22 then
									Group1="ru";

								if infile1|infile2|infile3|infile4|infile5|infile6|infile7|infile8|infile9|infile10|infile11|infile12|infile13|infile14 then
									Group2="all";
								else if infile15|infile16|infile17|infile18|infile19|infile20 then
									Group2="sex";
								else if infile21|infile22 then
									Group2="agecat";

								if infile1|infile2 then
									groupvalue1="all";

								if infile1|infile2|infile3|infile4|infile5|infile6|infile7|infile8|infile9|infile10|infile11|infile12|infile13|infile14 then
									groupvalue2="all";
							Run;

						%end;
					%else
						%do;

							Data Crude_Prev_Estimates_HTN(Keep=geographic_level htnyn htnc Group1 Groupvalue1 Group2 Groupvalue2 _FREQ_ Crude_Prev Crude_StdErr);
								Retain geographic_level Group1 Groupvalue1 Group2 Groupvalue2 htnyn htnc _FREQ_ Crude_Prev Crude_StdErr;
								Length htnyn htnc 8. Group1 Groupvalue1 Group2 Groupvalue2 $200.;
								Set	htnyn_prmpay_Crde (in=infile11 rename=(prmpay=Groupvalue1))
									htnc_prmpay_Crde (in=infile12 rename=(prmpay=Groupvalue1))
									htnyn_ru_Crde (in=infile13 rename=(ru=Groupvalue1))
									htnc_ru_Crde (in=infile14 rename=(ru=Groupvalue1))
									htnyn_agecat_sex_Crde (in=infile15 rename=(agecat=Groupvalue1 sex=Groupvalue2))
									htnc_agecat_sex_Crde (in=infile16 rename=(agecat=Groupvalue1 sex=Groupvalue2))
									htnyn_raceeth2_sex_Crde (in=infile17 rename=(raceeth2=Groupvalue1 sex=Groupvalue2))
									htnc_raceeth2_sex_Crde (in=infile18 rename=(raceeth2=Groupvalue1 sex=Groupvalue2))
									htnyn_ru_sex_Crde (in=infile19 rename=(ru=Groupvalue1 sex=Groupvalue2))
									htnc_ru_sex_Crde (in=infile20 rename=(ru=Groupvalue1 sex=Groupvalue2))
									htnyn_ru_agecat_Crde (in=infile21 rename=(ru=Groupvalue1 agecat=Groupvalue2))
									htnc_ru_agecat_Crde (in=infile22 rename=(ru=Groupvalue1 agecat=Groupvalue2));

								If infile11|infile13|infile15|infile17|infile19|infile21 Then
									htnyn=1;
								else htnyn=0;

								If infile12|infile14|infile16|infile18|infile20|infile22 Then
									htnc=1;
								else htnc=0;

								if infile15|infile16 then
									Group1="agecat";
								else if infile17|infile18 then
									Group1="raceeth2";
								else if infile11|infile12 then
									Group1="prmpay";
								else if infile13|infile14|infile19|infile20|infile21|infile22 then
									Group1="ru";

								if infile11|infile12|infile13|infile14 then
									Group2="all";
								else if infile15|infile16|infile17|infile18|infile19|infile20 then
									Group2="sex";
								else if infile21|infile22 then
									Group2="agecat";

								if infile11|infile12|infile13|infile14 then
									groupvalue2="all";
							Run;

						%end;

					%est_loop(est_type=htnyn);
					%est_loop(est_type=htnc);

					/*@Action: Export original version*/
					data Est_crd (rename=(Sample_PT=Npats Crude_Prev=prevalance Crude_StdErr=se));
						set sasout.Est_wide_&abbr_estimate_level._HTN&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.;
						keep geographic_type geographic_level Condition Condition_level year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Crude_Prev Crude_StdErr;
						length est_type $15.;
						est_type="crude";
					run;

					data Est_wgt (rename=(Sample_PT=Npats Pop_Perc=prevalance STD_Err=se));
						set sasout.Est_wide_&abbr_estimate_level._HTN&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.;
						keep geographic_type geographic_level Condition Condition_level year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Pop_Perc STD_Err;
						length est_type $15.;
						est_type="modeled";
					run;

					data sasout.Est_&estimate_level._HTN&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.;
						retain geographic_type geographic_level Condition Condition_level year_month Group1 GroupValue1 Group2 GroupValue2 est_type Npats prevalance se;
						set Est_crd Est_wgt;
					run;

%mend;

/*@Program End ***/