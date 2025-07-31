/************************************************************************************************************************/
/********************************** -- Create National and State estimate files -- **************************************/
/************************************************************************************************************************/
%macro estimates();
	
	/*@Action: declare macros*/
	%if &National_est.=Y %then
		%do;
			%Let ESTIMATE_LEVEL = NATIONAL;
			%LET ACS_FILE = acs_controls_state;
			%let geo_level_var="NATIONAL";
		%end;
	%else %if &STATE_EST. = Y %then 
		%do;
			%Let ESTIMATE_LEVEL = STATE;
			%LET ACS_FILE = acs_controls_state;
			%let geo_level_var=state_fips;
		%end;

	/*@Action: define weighted file*/
	%if &estimate_level.=NATIONAL %then
		%do;
			%let weighted_file=WGTS0_&estimate_level.&year_loop.&month_loop.;
			%put &weighted_file.;				
			
			data &weighted_file.0;
				set sasin.&weighted_file.;
							
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
		%end;
	%else
		%do;
			%if &estimate_level.=STATE %then %do;
				proc sql noprint;
					select cats("&estimate_level.", input(trim(strip(&geo_level_var.)),8.)) into: ondeckname trimmed 
						from &ESTIMATE_LEVEL._freq
							where &geo_level_var.=&ondeck.;
				quit;

				%put &ondeckname.;
				%let weighted_file=WGTS0_&ondeckname._&year_loop.&month_loop.;
				%put &weighted_file.;
				
				data &weighted_file.0;
					set sasin.&weighted_file.;
		
					where &geo_level_var.=&ondeck.;
					
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
			%end;
		%end;

	/*@Note: Prevalence Estimation and Output Routine***/
	/*@Action: Use weighted USER file to produce prevalence estimates ***/
	/*@Action: Estimate Crude Rates ***/
	Proc Means Data=&weighted_file.0  Noprint;
		Var htnyn;
		where htnyn ne .;
		Output Out=htnyn_Crde Mean=Crude_Prev Stderr=Crude_StdErr;
	run;

	Proc Means Data=&weighted_file.0 Noprint;
		Var htnc;
		where htnyn=1;
		Output Out=htnc_Crde Mean=Crude_Prev Stderr=Crude_StdErr;
	run;

	%macro crude(byvar=);

		proc sort data=&weighted_file.0 out=&weighted_file.;
			by &byvar.;
		run;

		Proc Means Data=&weighted_file. Noprint;
			Var htnyn;
			by &byvar.;
			where htnyn ne .;
			Output Out=htnyn_&byvar._Crde Mean=Crude_Prev Stderr=Crude_StdErr;

		Proc Means Data=&weighted_file. Noprint;
			Var htnc;
			where htnyn=1;
			by &byvar.;
			Output Out=htnc_&byvar._Crde Mean=Crude_Prev Stderr=Crude_StdErr;
		run;

	%mend;

	%macro crude2tab(byvar1=, byvar2=);

		proc sort data=&weighted_file.0 out=&weighted_file.;
			by &byvar1. &byvar2.;
		run;

		Proc Means Data=&weighted_file. Noprint;
			Var htnyn;
			by &byvar1. &byvar2.;
			where htnyn ne .;
			Output Out=htnyn_&byvar1._&byvar2._Crde Mean=Crude_Prev Stderr=Crude_StdErr;

		Proc Means Data=&weighted_file. Noprint;
			Var htnc;
			where htnyn=1;
			by &byvar1. &byvar2.;
			Output Out=htnc_&byvar1._&byvar2._Crde Mean=Crude_Prev Stderr=Crude_StdErr;
		run;

	%mend;

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

	Data Crude_Prev_Estimates(Keep=htnyn htnc Group1 Groupvalue1 Group2 Groupvalue2  _FREQ_ Crude_Prev Crude_StdErr);
		Retain Group1 Groupvalue1 Group2 Groupvalue2 htnyn htnc _FREQ_ Crude_Prev Crude_StdErr;
		Length htnyn htnc  8. Group1 Groupvalue1 Group2 Groupvalue2 $200.;
		Set	htnyn_Crde (in=a1) 
				htnc_Crde (in=a3) 
			htnyn_sex_Crde (in=a4 rename=(sex=Groupvalue1)) 
				htnc_sex_Crde (in=a6 rename=(sex=Groupvalue1))
			htnyn_agecat_Crde (in=a7 rename=(agecat=Groupvalue1)) 
				htnc_agecat_Crde (in=a9 rename=(agecat=Groupvalue1))
			htnyn_agec_col_Crde (in=a10 rename=(agec_col=Groupvalue1)) 
				htnc_agec_col_Crde (in=a12 rename=(agec_col=Groupvalue1))
			htnyn_raceeth2_Crde (in=a13 rename=(raceeth2=Groupvalue1)) 
				htnc_raceeth2_Crde (in=a15 rename=(raceeth2=Groupvalue1))
			htnyn_prmpay_Crde (in=a16 rename=(prmpay=Groupvalue1)) 
				htnc_prmpay_Crde (in=a18 rename=(prmpay=Groupvalue1))
			htnyn_ru_Crde (in=a19 rename=(ru=Groupvalue1)) 
				htnc_ru_Crde (in=a21 rename=(ru=Groupvalue1))
			htnyn_agecat_sex_Crde (in=a22 rename=(agecat=Groupvalue1 sex=Groupvalue2)) 
				htnc_agecat_sex_Crde (in=a24 rename=(agecat=Groupvalue1 sex=Groupvalue2))
			htnyn_raceeth2_sex_Crde (in=a25 rename=(raceeth2=Groupvalue1 sex=Groupvalue2)) 
				htnc_raceeth2_sex_Crde (in=a27 rename=(raceeth2=Groupvalue1 sex=Groupvalue2))
			htnyn_ru_sex_Crde (in=a28 rename=(ru=Groupvalue1 sex=Groupvalue2)) 
				htnc_ru_sex_Crde (in=a30 rename=(ru=Groupvalue1 sex=Groupvalue2))
			htnyn_ru_agecat_Crde (in=a31 rename=(ru=Groupvalue1 agecat=Groupvalue2)) 
				htnc_ru_agecat_Crde (in=a33 rename=(ru=Groupvalue1 agecat=Groupvalue2));

		If a1|a4|a7|a10|a13|a16|a19|a22|a25|a28|a31 Then
			htnyn=1;
		else htnyn=0;

		If a3|a6|a9|a12|a15|a18|a21|a24|a27|a30|a33 Then
			htnc=1;
		else htnc=0;			
	
		if a1|a3 then
			Group1="all";
		else if a4|a6 then
			Group1="sex";
		else if a7|a9|a22|a24 then
			Group1="agecat";
		else if a10|a12 then
			Group1="agec_col";
		else if a13|a15|a25|a27 then
			Group1="raceeth2";
		else if a16|a18 then
			Group1="prmpay";
		else if a19|a21|a28|a30|a31|a33 then
			Group1="ru";
			
		if a1|a3|a4|a6|a7|a9|a10|a12|a13|a15|a16|a18|a19|a21 then
			Group2="all";
		else if a22|a24|a25|a27|a28|a30 then
			Group2="sex";
		else if a31|a33 then
			Group2="agecat";
	
		if a1|a3 then
			groupvalue1="all";

		if a1|a3|a4|a6|a7|a9|a10|a12|a13|a15|a16|a18|a19|a21 then
			groupvalue2="all";
	Run;

	/*@Action: Estimate the overall weighted prevalence estimates ***/ 
	%macro est_overall(type=);
		/*@Action: define macros*/
		%if &type.=htnyn %then
			%do;
				%let condition=HTN;
			%end;
		%else %if &type.=htnc %then
			%do;
				%let condition=HTN-C;
			%end;

		/*@Action: weighted prevalance*/
		proc surveyfreq data = &weighted_file.0 ;
	    	table &type./ row;
	    	weight RakeWgt;
	    	where &type. ne .;
	    	ods output oneway=wgt&type.all;
	    run;
	    
	    /*@Action: format prevalance and population/sample count*/
		data PB&type.all (drop=&type.);
			format Pop_Perc STD_Err f10.9;
			set WGT&type.ALL (where=(&type.=1) keep=&type. percent stderr rename=(Percent=Pop_Perc StdErr=STD_Err));
			by &type.;
			Group1="all";
			GroupValue1="all";
			Group2="all";
			GroupValue2="all";
		run;
		
		data n&type.all (drop=&type.);
			set WGT&type.ALL (where=(&type.=.) keep=&type. WgtFreq rename=(WgtFreq=Pop_n));
			Group1="all";
			GroupValue1="all";
			Group2="all";
			GroupValue2="all";
		run;
	
		/*@Action: subset crude prevanalence estimates*/
		Proc Sql;
			create table CPE&type.all as 
				select * 
					from Crude_Prev_Estimates 
						where Group1="all" 
							and &type.=1;
		Quit;

		/*@Action: merge the files together*/
		%if &estimate_level.=NATIONAL %then
			%do;

				Proc Sql;
					Create table PEoverall&type. as
						Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
							, "NATIONAL" as geographic_type length=50
							, "NATIONAL" as geographic_level length=50
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
						where a.Group1=b.Group1 
							and a.Group1=c.Group1
							and a.GroupValue1=b.GroupValue1
							and a.GroupValue1=c.GroupValue1
							and a.Group2=b.Group2
							and a.Group2=c.Group2
							and a.GroupValue2=b.GroupValue2
							and a.GroupValue2=c.GroupValue2
						order by Group1
							, GroupValue1
							, Group2
							, GroupValue2;
				Quit;

			%end;
		%else
			%do;

				Proc Sql;
					Create table PEoverall&type. as
						Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
							, "&estimate_level." as geographic_type length=50
							, &ondeck. as geographic_level length=50
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
						where a.Group1=b.Group1 
							and a.Group1=c.Group1
							and a.GroupValue1=b.GroupValue1
							and a.GroupValue1=c.GroupValue1
							and a.Group2=b.Group2
							and a.Group2=c.Group2
							and a.GroupValue2=b.GroupValue2
							and a.GroupValue2=c.GroupValue2
						order by Group1
							, GroupValue1
							, Group2
							, GroupValue2;
				Quit;

			%end;

		/*@Action: stack files*/
		proc append data=PEoverall&type. base=sasout.Est_wide_&estimate_level. force;
		run;

	%mend;

	/*@Action: Estimate the one way frequency weighted prevalence estimates ***/ 
	%macro est1tab(type=, var=);
		/*@Action: define macros*/
		%if &type.=htnyn %then
			%do;
				%let condition=HTN;
			%end;
		%else %if &type.=htnc %then
			%do;
				%let condition=HTN-C;
			%end;
		
		/*@Action: weighted prevalance*/
		proc surveyfreq data = &weighted_file.0 ;
	    	table &var.*&type./ row;
	    	weight RakeWgt;
	    	where &type. ne . and &var. ne "";
	    	ods output crosstabs=wgt&type.&var.;
	    run;	
		
	    /*@Action: format prevalance and population/sample counts*/
		data PB&type.&var. (drop=&type. &var.);
			format Pop_Perc STD_Err f10.9;
			set WGT&type.&var. (where=(&type.=1 and &var. ne "") keep=&type. &var. rowpercent rowstderr rename=(rowpercent=Pop_Perc rowstderr=STD_Err));
			by &type.;
			Group1="&var.";
			GroupValue1=&var.;
			Group2="all";
			GroupValue2="all";
		run;
		
		data n&type.&var. (drop=&type. &var.);
			set WGT&type.&var. (where=(&type.=. and &var. ne "") keep=&type. &var. WgtFreq rename=(WgtFreq=Pop_n));
			Group1="&var.";
			GroupValue1=&var.;
			Group2="all";
			GroupValue2="all";
		run;
	
		/*@Action: subset crude prevanalence estimates*/
		Proc Sql;
			create table CPE&type.&var. as 
				select * 
					from Crude_Prev_Estimates 
						where Group1="&var."
							and Group2="all"
							and &type.=1;
		Quit;

		/*@Action: merge the files together*/
		%if &estimate_level.=NATIONAL %then
			%do;

				Proc Sql;
					Create table PE&var.&type. as
						Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
							, "NATIONAL" as geographic_type length=50
							, "NATIONAL" as geographic_level length=50
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
						where a.Group1=b.Group1 
							and a.Group1=c.Group1
							and a.GroupValue1=b.GroupValue1
							and a.GroupValue1=c.GroupValue1
							and a.Group2=b.Group2
							and a.Group2=c.Group2
							and a.GroupValue2=b.GroupValue2
							and a.GroupValue2=c.GroupValue2
						order by Group1
							, GroupValue1
							, Group2
							, GroupValue2;
				Quit;

			%end;
		%else
			%do;

				Proc Sql;
					Create table PE&var.&type. as
						Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
							, "&estimate_level." as geographic_type length=50
							, &ondeck. as geographic_level length=50
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
						where a.Group1=b.Group1 
							and a.Group1=c.Group1
							and a.GroupValue1=b.GroupValue1
							and a.GroupValue1=c.GroupValue1
							and a.Group2=b.Group2
							and a.Group2=c.Group2
							and a.GroupValue2=b.GroupValue2
							and a.GroupValue2=c.GroupValue2
						order by Group1
							, GroupValue1
							, Group2
							, GroupValue2;
				Quit;

			%end;

		/*@Action: stack files*/
		proc append data=PE&var.&type. base=sasout.Est_wide_&estimate_level. force;
		run;

	%mend;

	/*@Action: Estimate the two way frequency weighted prevalence estimates ***/ 
	%macro est2tab(type=, var1=, var2=);
		/*@Action: define macros*/
		%if &type.=htnyn %then
			%do;
				%let condition=HTN;
			%end;
		%else %if &type.=htnc %then
			%do;
				%let condition=HTN-C;
			%end;
		
		/*@Action: weighted prevalance*/
		proc surveyfreq data = &weighted_file.0 ;
	    	table &var1.*&var2.*&type./ row;
	    	weight RakeWgt;
	    	where &type. ne . and &var1. ne "" and &var2. ne "";
	    	ods output crosstabs=wgt&type.&var1.&var2.;
	    run;	
	    
	    /*@Action: format prevalance and population/sample counts*/
		data PB&type.&var1.&var2. (drop=&type. &var1. &var2.);
			format Pop_Perc /*Pop_Perc_Age_Adj*/ STD_Err /*STD_Err_Age_Adj*/ f10.9;
			set WGT&type.&var1.&var2. (where=(&type.=1 and &var1. ne "" and &var2. ne "") keep=&type. &var1. &var2. rowpercent rowstderr rename=(rowpercent=Pop_Perc rowstderr=STD_Err));
			by &type.;
			Group1="&var1.";
			GroupValue1=&var1.;
			Group2="&var2.";
			GroupValue2=&var2.;
		run;
		
		data n&type.&var1.&var2. (drop=&type. &var1. &var2.);
			set WGT&type.&var1.&var2. (where=(&type.=. and &var1. ne "" and &var2. ne "") keep=&type. &var1. &var2. WgtFreq rename=(WgtFreq=Pop_n));
			Group1="&var1.";
			GroupValue1=&var1.;
			Group2="&var2.";
			GroupValue2=&var2.;
		run;
	
		*subset crude prevanalence estimates;
		Proc Sql;
			create table CPE&type.&var1.&var2. as 
				select * 
					from Crude_Prev_Estimates 
						where Group1="&var1."
							and Group2="&var2."						
							and &type.=1;
		Quit;

		/*@Action: merge the files together*/
		%if &estimate_level.=NATIONAL %then
			%do;

				Proc Sql;
					Create table PE&var1.&var2.&type. as
						Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
							, "NATIONAL" as geographic_type length=50
							, "NATIONAL" as geographic_level length=50
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
						where a.Group1=b.Group1 
							and a.Group1=c.Group1
							and a.GroupValue1=b.GroupValue1
							and a.GroupValue1=c.GroupValue1
							and a.Group2=b.Group2
							and a.Group2=c.Group2
							and a.GroupValue2=b.GroupValue2
							and a.GroupValue2=c.GroupValue2
						order by Group1
							, GroupValue1
							, Group2
							, GroupValue2;
				Quit;

			%end;
		%else
			%do;

				Proc Sql;
					Create table PE&var1.&var2.&type. as
						Select catx("-", &year_loop., put(&month_loop.,z2.)) as year_month
							, "&estimate_level." as geographic_type length=50
							, &ondeck. as geographic_level length=50
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
						where a.Group1=b.Group1 
							and a.Group1=c.Group1
							and a.GroupValue1=b.GroupValue1
							and a.GroupValue1=c.GroupValue1
							and a.Group2=b.Group2
							and a.Group2=c.Group2
							and a.GroupValue2=b.GroupValue2
							and a.GroupValue2=c.GroupValue2
						order by Group1
							, GroupValue1
							, Group2
							, GroupValue2;
				Quit;

			%end;

		/*@Action: stack files*/
		proc append data=PE&var1.&var2.&type. base=sasout.Est_wide_&estimate_level. force;
		run;

	%mend;

	
	/*@Action: declare macro that will loop through all estimate types*/
	%macro est_loop(type=);
		%est_overall(type=&type.);
	
		%if &estimate_level.=NATIONAL or &estimate_level.=STATE %then %do;
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
		%end;
	%mend;

	/*@Action: run macro that will loop through all estimate types*/
	%est_loop(type=htnyn);
	%est_loop(type=htnc);

%mend;

/*@Program End ***/
