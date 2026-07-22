/*%let type=htnyn; %let byvar=sex;*/
%macro crude(byvar=);

	proc sort data=&weighted_file.0 out=&weighted_file.;
		by geographic_level &byvar.;
	run;

	Proc Means Data=&weighted_file. Noprint;
		Var htnyn;
		by geographic_level &byvar.;
		where htnyn ne .;
		Output Out=htnyn_&byvar._Crde Mean=Crude_Prev Stderr=Crude_StdErr;
	run;

	Proc Means Data=&weighted_file. Noprint;
		Var htnc;
		by geographic_level &byvar.;
		where htnyn=1;
		Output Out=htnc_&byvar._Crde Mean=Crude_Prev Stderr=Crude_StdErr;
	run;

%mend;

%macro crude2tab(byvar1=, byvar2=);

	proc sort data=&weighted_file.0 out=&weighted_file.;
		by geographic_level &byvar1. &byvar2.;
	run;

	Proc Means Data=&weighted_file. Noprint;
		Var htnyn;
		by geographic_level &byvar1. &byvar2.;
		where htnyn ne .;
		Output Out=htnyn_&byvar1._&byvar2._Crde Mean=Crude_Prev Stderr=Crude_StdErr;
	run;

	Proc Means Data=&weighted_file. Noprint;
		Var htnc;
		by geographic_level &byvar1. &byvar2.;
		where htnyn=1;
		Output Out=htnc_&byvar1._&byvar2._Crde Mean=Crude_Prev Stderr=Crude_StdErr;
	run;

%mend;

/*@Action: Estimate the variance for prevalence estimates ***/
%macro est_overall(type=);
	/*weighted prevalance*/
	proc surveyfreq data = &weighted_file.0;
		table &type./ row;
			weight RakeWgt;
			by geographic_level;
			where &type. ne .;
			ods output oneway=wgt&type.all;
	run;

	/*format prevalance and population/sample counts*/
	data PB&type.all (drop=&type.);
		format Pop_Perc STD_Err f10.9;
		merge WGT&type.ALL (where=(&type.=1) keep=&type. geographic_level percent stderr rename=(Percent=Pop_Perc StdErr=STD_Err));
		by &type. geographic_level;
		Group1="all";
		GroupValue1="all";
		Group2="all";
		GroupValue2="all";
	run;

	data n&type.all (drop=&type.);
		set WGT&type.ALL (where=(&type.=.) keep=&type. geographic_level WgtFreq rename=(WgtFreq=Pop_n));
		Group1="all";
		GroupValue1="all";
		Group2="all";
		GroupValue2="all";
	run;

	/*subset crude prevanalence estimates*/
	Proc Sql;
		create table CPE&type.all as 
			select * 
				from Crude_Prev_Estimates 
					where Group1="all" 
						and &type.=1;
	Quit;

	%if &type.=htnyn %then
		%do;
			%let condition=PPH HTN;
		%end;
	%else %if &type.=htnc %then
		%do;
			%let condition=PPH HTN-C;
		%end;

	/*merge the files together*/
	Proc Sql;
		Create table PEoverall&type. as
			Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
				, "&estimate_level." as geographic_type length=50
				, b.geographic_level length=50
				, "&condition." as Condition length=50
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
			From PB&type.all as a
				, n&type.all as b
				, CPE&type.all as c
			where a.geographic_level=b.geographic_level
				and a.geographic_level=c.geographic_level
				and a.Group1=b.Group1 
				and a.Group1=c.Group1
				and a.GroupValue1=b.GroupValue1
				and a.GroupValue1=c.GroupValue1
				and a.Group2=b.Group2
				and a.Group2=c.Group2
				and a.GroupValue2=b.GroupValue2
				and a.GroupValue2=c.GroupValue2
			order by geographic_level
				, Group1
				, GroupValue1
				, Group2
				, GroupValue2;
	Quit;

	proc append data=PEoverall&type. base=sasout.Est_wide_&estimate_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. force;
	run;

%mend;

%macro est1tab(type=, var=);
	/*weighted prevalance*/
	proc surveyfreq data = &weighted_file.0;
		table &var.*&type./ row;
			weight RakeWgt;
			by geographic_level;
			where &type. ne . and &var. ne "";
			ods output crosstabs=wgt&type.&var.;
	run;

	/*format prevalance and population/sample counts*/
	data PB&type.&var. (drop=&type. &var.);
		format Pop_Perc STD_Err f10.9;
		merge WGT&type.&var. (where=(&type.=1 and &var. ne "") keep=&type. geographic_level &var. rowpercent rowstderr rename=(rowpercent=Pop_Perc rowstderr=STD_Err));
		by &type.;
		Group1="&var.";
		GroupValue1=&var.;
		Group2="all";
		GroupValue2="all";
	run;

	data n&type.&var. (drop=&type. &var.);
		set WGT&type.&var. (where=(&type.=. and &var. ne "") keep=&type. geographic_level &var. WgtFreq rename=(WgtFreq=Pop_n));
		Group1="&var.";
		GroupValue1=&var.;
		Group2="all";
		GroupValue2="all";
	run;

	/*subset crude prevanalence estimates*/
	Proc Sql;
		create table CPE&type.&var. as 
			select * 
				from Crude_Prev_Estimates 
					where Group1="&var."
						and &type.=1;
	Quit;

	%if &type.=htnyn %then
		%do;
			%let condition=PPH HTN;
		%end;
	%else %if &type.=htnc %then
		%do;
			%let condition=PPH HTN-C;
		%end;

	/*merge the files together*/
	Proc Sql;
		Create table PE&var.&type. as
			Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
				, "&estimate_level." as geographic_type length=50
				, b.geographic_level length=50
				, "&condition." as Condition length=50
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
			From PB&type.&var. as a
				, n&type.&var. as b
				, CPE&type.&var. as c
			where a.geographic_level=b.geographic_level
				and a.geographic_level=c.geographic_level
				and a.Group1=b.Group1 
				and a.Group1=c.Group1
				and a.GroupValue1=b.GroupValue1
				and a.GroupValue1=c.GroupValue1
				and a.Group2=b.Group2
				and a.Group2=c.Group2
				and a.GroupValue2=b.GroupValue2
				and a.GroupValue2=c.GroupValue2
			order by geographic_level
				, Group1
				, GroupValue1
				, Group2
				, GroupValue2;
	Quit;

	proc append data=PE&var.&type. base=sasout.Est_wide_&estimate_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. force;
	run;

%mend;

%macro est2tab(type=, var1=, var2=);
	/*weighted prevalance*/
	proc surveyfreq data = &weighted_file.0;
		table &var1.*&var2.*&type./ row;
			weight RakeWgt;
			by geographic_level;
			where &type. ne . and &var1. ne "" and &var2. ne "";
			ods output crosstabs=wgt&type.&var1.&var2.;
	run;

	/*format prevalance and population/sample counts*/
	data PB&type.&var1.&var2. (drop=&type. &var1. &var2.);
		format Pop_Perc STD_Err f10.9;
		merge WGT&type.&var1.&var2. (where=(&type.=1 and &var1. ne "" and &var2. ne "") keep=&type. geographic_level &var1. &var2. rowpercent rowstderr rename=(rowpercent=Pop_Perc rowstderr=STD_Err));
		by &type.;
		Group1="&var1.";
		GroupValue1=&var1.;
		Group2="&var2.";
		GroupValue2=&var2.;
	run;

	data n&type.&var1.&var2. (drop=&type. &var1. &var2.);
		set WGT&type.&var1.&var2. (where=(&type.=. and &var1. ne "" and &var2. ne "") keep=&type. &var1. geographic_level &var2. WgtFreq rename=(WgtFreq=Pop_n));
		Group1="&var1.";
		GroupValue1=&var1.;
		Group2="&var2.";
		GroupValue2=&var2.;
	run;

	/*subset crude prevanalence estimates*/
	Proc Sql;
		create table CPE&type.&var1.&var2. as 
			select * 
				from Crude_Prev_Estimates 
					where Group1="&var1."
						and Group2="&var2."						
						and &type.=1;
	Quit;

	%if &type.=htnyn %then
		%do;
			%let condition=PPH HTN;
		%end;
	%else %if &type.=htnc %then
		%do;
			%let condition=PPH HTN-C;
		%end;

	/*merge the files together*/
	Proc Sql;
		Create table PE&var1.&var2.&type. as
			Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
				, "&estimate_level." as geographic_type length=50
				, b.geographic_level length=50
				, "&condition" as Condition length=50
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
			From PB&type.&var1.&var2. as a
				, n&type.&var1.&var2. as b
				, CPE&type.&var1.&var2. as c
			where a.geographic_level=b.geographic_level
				and a.geographic_level=c.geographic_level
				and a.Group1=b.Group1 
				and a.Group1=c.Group1
				and a.GroupValue1=b.GroupValue1
				and a.GroupValue1=c.GroupValue1
				and a.Group2=b.Group2
				and a.Group2=c.Group2
				and a.GroupValue2=b.GroupValue2
				and a.GroupValue2=c.GroupValue2
			order by geographic_level
				, Group1
				, GroupValue1
				, Group2
				, GroupValue2;
	Quit;

	proc append data=PE&var1.&var2.&type. base=sasout.Est_wide_&estimate_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. force;
	run;

%mend;

%macro est_loop(type=);
	%est_overall(type=&type.);
	%est1tab(var=sex, type=&type.);
	%est1tab(var=agecat, type=&type.);
	%est1tab(var=agec_col, type=&type.);
	%est1tab(var=raceeth2, type=&type.);
	%est1tab(var=prmpay, type=&type.);
	%est1tab(var=ru, type=&type.);
	%est2tab(var1=agecat, var2=sex, type=&type.);
	%est2tab(var1=raceeth2, var2=sex, type=&type.);
	%est2tab(var1=ru, var2=agecat, type=&type.);
	%est2tab(var1=ru, var2=sex, type=&type.);
%mend;

%macro estimates();
	%if &National_est.=Y %then
		%do;
			%Let ESTIMATE_LEVEL = NATIONAL;
			%let weighted_file=wgt_alt2_natl_&year_loop.&month_loop.;
			%let geographic_level="NATIONAL";
		%end;
	%else %if &STATE_EST. = Y %then
		%do;
			%Let ESTIMATE_LEVEL = STATE;
			%let weighted_file=wgt_alt2_state_&year_loop.&month_loop.;
			%let geographic_level=&estimate_level.;
		%end;

	proc sort data=&weighted_file.01;
		by zip;
	run;

	data ru;
		set xwalk.zip_xwalk_final;
		keep ru zip;

		length ru $50.;
		
		if 1<=ruca1<=3 then
			ru='Mostly urban';
		else if 4<=ruca1<=7 then
			ru='Mostly rural';
		else if 8<=ruca1<=10 then
			ru='Completely rural';

		where zip is not null;
	run;

	proc sort data=ru;
		by zip;
	run;

	data &weighted_file.01;
		set sasin.&weighted_file. (rename=(htnyn=htnyn_old htnc=htnc_old));
	run;

	proc sort data=&weighted_file.01;
		by zip;
	run;

	data &weighted_file.0;
		merge &weighted_file.01 (in=a) ru;
		by zip;

		if a;
		geographic_level=&geographic_level.;

		/*change pph values to numeric*/
		htnyn=input(htnyn_old, 8.);
		htnc=input(htnc_old, 8.);

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

	/*@Note: Prevalence Estimation and Output Routine***/
	/*@Action: Use weighted USER file to produce prevalence estimates ***/
	/*@Action: Estimate Crude Rates ***/
	Proc Means Data=&weighted_file.0  Noprint;
		Var htnyn;
		by geographic_level;
		where htnyn ne .;
		Output Out=htnyn_Crde Mean=Crude_Prev Stderr=Crude_StdErr;
	run;

	Proc Means Data=&weighted_file.0 Noprint;
		Var htnc;
		by geographic_level;
		where htnyn=1;
		Output Out=htnc_Crde Mean=Crude_Prev Stderr=Crude_StdErr;
	run;

	%crude(byvar=sex);
	%crude(byvar=agecat);
	%crude(byvar=agec_col);
	%crude(byvar=raceeth2);
	%crude(byvar=prmpay);
	%crude(byvar=ru);
	%crude2tab(byvar1=agecat, byvar2=sex);
	%crude2tab(byvar1=raceeth2, byvar2=sex);
	%crude2tab(byvar1=ru, byvar2=sex);
	%crude2tab(byvar1=ru, byvar2=agecat);

	Data Crude_Prev_Estimates(Keep=geographic_level htnyn htnc Group1 Groupvalue1 Group2 Groupvalue2  _FREQ_ Crude_Prev Crude_StdErr);
		Retain geographic_level Group1 Groupvalue1 Group2 Groupvalue2 htnyn htnc _FREQ_ Crude_Prev Crude_StdErr;
		Length htnyn htnc 8. Group1 Groupvalue1 Group2 Groupvalue2 htn_variable $200.;
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
		htn_variable="PPH";
	Run;

	%est_loop(type=htnyn);
	%est_loop(type=htnc);

	/*@Action: Export original version*/
	data Est_crd (rename=(Sample_PT=Npats Crude_Prev=prevalance Crude_StdErr=se));
		set sasout.Est_wide_&estimate_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.;
		keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Crude_Prev Crude_StdErr;
		length est_type $15.;
		est_type="crude";
	run;

	data Est_wgt (rename=(Sample_PT=Npats Pop_Perc=prevalance STD_Err=se));
		set sasout.Est_wide_&estimate_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.;
		keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Pop_Perc STD_Err;
		length est_type $15.;
		est_type="modeled";
	run;

	data sasout.Est_&estimate_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH.;
		retain geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Npats prevalance se;
		set Est_crd Est_wgt;
	run;

%mend;

/*@Program End ***/