/*******************************************************************************************************************************************/
/************************************************** -- Calculated statistical weights -- ***************************************************/
/***************************************** -- Declare weighting macro to create statistical weights  -- *************************************/
/*******************************************************************************************************************************************/
%macro weights();
	/*@Action: Create formats for collapsing of groups ***/
	Proc Format;
		Value $agec_1_C "20-24" = "1"
			"25-29" = "1"
			other = " "
		;
		Value $agec_2_C "30-34" = "2"
			"35-44" = "2"
			other   = " "
		;
		Value $agec_3_C "45-54" = "3"
			"55-64" = "3"
			other   = " "
		;
		Value $agec_4_C "65-74" = "4"
			"75-84" = "4"
			other   = " "
		;
		Value $agec_5_C "20-29" = "5"
			"30-44" = "5"
			other   = " "
		;
		Value $collapse_agec "1"   = "20-29"
			"2"   = "30-44"
			"3"   = "45-64"
			"4"   = "65-84"
			"5"   = "20-44"
			other = " "
		;
		Value $raceeth_1_C "Black" = "1"
			"Other" = "1"
			other   = " "
		;
		Value $raceeth_2_C "White" = "2"
			other   = " "
		;
		Value $collapse_raceeth "1"   = "Other"
			"2"   = "White"
			other = " "
		;
	Run;
	
	/*@Action: create macro variables for each geographic levels ***/
	%if &National_wgt. = Y %then
		%do;
			%Let ESTIMATE_LEVEL = NATIONAL;
		%end;
	%else %if &state_wgt. = Y %then 
		%do;
			%Let ESTIMATE_LEVEL = STATE;
		%end;
		
	%if &estimate_level.=NATIONAL %then
		%do;
			/*@Action: Finish ACS control totals to be used in weighting ***/
			%macro acs_controls_natl(var=);

				Proc Sql;
					Create table ACS_&var._Controls as
						Select &var. as &var._Raking
							, Sum(ACS_Count) as mrgtotal 
						From sasin.acs_controls_State
							where &var. is not null
								Group by &var.;
				Quit;

			%mend;

			%acs_controls_natl(var=agec);
			%acs_controls_natl(var=agec_col);
			%acs_controls_natl(var=Sex);
			%acs_controls_natl(var=raceeth);
			%acs_controls_natl(var=raceeth_col);
			%acs_controls_natl(var=census_region);
			%acs_controls_natl(var=ru2);

			Proc Sql;
				Create table Select_files0 as
					Select *
					From sasin.PRE_PROCESSED_MENDS_ZIP&year_loop.&month_loop.
						where month=&month_loop.
							and year=&year_loop.
							and census_region is not null
							and ru2 is not null
						Order by aa_seq
							, Year;
			Quit;

		/*@Action: Execute sample size check  ***/
			Proc Freq Data=Select_files0 noprint;
				Table agec/list missing Out=Geo_agec (Drop=Percent Rename=(agec=Values));

					Table agec_col/list missing Out=Geo_agec_col (Drop=Percent Rename=(agec_col=Values));

						Table raceeth/list missing Out=Geo_raceeth (Drop=Percent Rename=(raceeth=Values));

							Table raceeth_col/list missing Out=Geo_raceeth_col (Drop=Percent Rename=(raceeth_col=Values));

								Table Sex/list missing Out=Geo_sex (Drop=Percent Rename=(Sex=Values));

									Table census_region/list missing Out=geo_census_region (Drop=Percent Rename=(census_region=Values));
										
										Table ru2/list missing Out=geo_ru2 (Drop=Percent Rename=(ru2=Values));
			Run;

			Data Geo_freq;
				format Checker_Results $100.;
				Length Factor Values $100.;
				Set Geo_agec (in=a) Geo_agec_col (in=c) Geo_raceeth (in=d) 
					Geo_raceeth_col (in=e) Geo_sex (in=f) geo_census_region (in=g) 
					geo_ru2 (in=h);

				If a then
					Factor="Age Categories";
				Else if c then
					Factor="Age Categories Collapsed";
				Else if d then
					Factor="raceeth";
				Else if e then
					Factor="raceeth Collapsed";
				Else if f then
					Factor="Sex";
				Else if g then
					Factor="census_region";
				Else if h then
					Factor="ru2";

				If count<20 then
					Checker_Results="Sample Size Is Insufficient";
				Else Checker_Results="Sample Size Is Sufficient";
			Run;

			Proc Print data=Geo_freq;
				title "National Sample Size Checker Results for &month_loop. &year_loop.";
			Run;

			title;

		%end;
	%else
		%do;
			/*@Action: Finish ACS control totals to be used in weighting ***/
			%macro acs_controls_other(var=);

				Proc Sql;
					Create table ACS_&var._Controls as
						Select &var. as &var._Raking
							, Sum(ACS_Count) as mrgtotal 
						From sasin.acs_controls_State
							where state_fips=&ondeck.
								and &var. is not null
							Group by &var.;
				Quit;

			%mend;

			%acs_controls_other(var=agec);
			%acs_controls_other(var=agec_col);
			%acs_controls_other(var=Sex);
			%acs_controls_other(var=raceeth);
			%acs_controls_other(var=raceeth_col);
			%acs_controls_other(var=ru2);

			Proc Sql;
				Create table Select_files0 as
					Select distinct *
					From sasin.PRE_PROCESSED_MENDS_ZIP&year_loop.&month_loop.
						where month=&month_loop.
							and year=&year_loop.
							and census_region is not null
							and ru2 is not null
							and state_fips=&ondeck.
						Order by aa_seq
							, Year;
			Quit;

	/*@Action: Execute sample size check  ***/
		Proc Freq Data=Select_files0 noprint;
			Table agec/list missing Out=Geo_agec (Drop=Percent Rename=(agec=Values));

				Table agec_col/list missing Out=Geo_agec_col (Drop=Percent Rename=(agec_col=Values));

					Table raceeth/list missing Out=Geo_raceeth (Drop=Percent Rename=(raceeth=Values));

						Table raceeth_col/list missing Out=Geo_raceeth_col (Drop=Percent Rename=(raceeth_col=Values));

							Table Sex/list missing Out=Geo_sex (Drop=Percent Rename=(Sex=Values));

								Table ru2/list missing Out=geo_ru2 (Drop=Percent Rename=(ru2=Values));
		Run;

		Data Geo_freq;
			format Checker_Results $100.;
			Length Factor Values $100.;
			Set Geo_agec (in=a) Geo_agec_col (in=c) Geo_raceeth (in=d) Geo_raceeth_col (in=e) Geo_sex (in=f) geo_ru2 (in=g);

			If a then
				Factor="Age Categories";
			Else if c then
				Factor="Age Categories Collapsed";
			Else if d then
				Factor="raceeth";
			Else if e then
				Factor="raceeth Collapsed";
			Else if f then
				Factor="Sex";
			Else if g then
				Factor="ru2";

			If count<20 then
				Checker_Results="Sample Size Is Insufficient";
			Else Checker_Results="Sample Size Is Sufficient";
		Run;

		Proc Print data=Geo_freq;
			title "state_fips=&ondeck. Sample Size Checker Results for &month_loop. &year_loop.";
		Run;

		title;
	%end;

	/*@Action: Collapse Raking Levels ***/
	%Macro Collapse(FileIn, FileOut, Var, Num_Lvls);

		Data &FileOut.;
			Set &FileIn.;
		Run;

		%Do I=1 %To &Num_Lvls.;

			Proc Freq Data=&FileOut. Noprint;
				Table &Var. / out=Sample_Joint(Keep=&Var. Count);
			run;

			Data Sample_Joint(Keep=&Var. Count Collapse_Flg);
				set Sample_Joint;
				By &Var.;
				Array Change _NUMERIC_;

				Do Over Change;
					If Change=. Then
						Change=0;
				End;

				If Count<20 Then
					Collapse_Flg = Put(&Var., $&Var._&I._C.);
				Else Collapse_Flg="";
			Run;

			Proc Sql Noprint;
				Select Count(*) into :Collapse_Flg Trimmed 
					From Sample_Joint
						Where Collapse_Flg = "&I.";
			Quit;
			
			%If %Eval(&Collapse_Flg.>0) %Then
				%Do;
					%Let &Var._Collapse=&Var.;

					Data Sample_Joint_Collapse;
						Set Sample_Joint;
						Collapse_Flg = Put(&Var., $&Var._&I._C.);
						If Strip(Collapse_Flg)^="" Then
						New_Level = Put(Collapse_Flg, $Collapse_&Var..);
						Else New_Level = &Var.;
					Run;

					Proc Sort Data=&FileOut.;
						By &Var.;

					Proc Sort Data=ACS_&Var._Controls (rename=(&var._raking=&var.));
						By &Var.;
					Run;

					Data &FileOut.(Rename=(New_Level = &Var.));
						Merge &FileOut.(In=A) Sample_Joint_Collapse(In=B Keep=&Var. New_Level);
						By &Var.;

						If A;
						Drop &Var.;
					Run;

					Data ACS_&Var._Controls(Rename=(New_Level = &Var._Raking));
						Merge ACS_&Var._Controls(In=A) Sample_Joint_Collapse(In=B Keep=&Var. New_Level);
						By &Var.;

						If A;
						Drop &Var.;
					Run;

					Proc Freq Data=&FileOut.;
						Table &Var.;

					Proc Freq Data=ACS_&Var._Controls;
						Table &Var._Raking;
					Run;

				%End;

				/*@Action: Update the Collapse Pass macro variable, if failed replace 1 with a 0 ***/
				Proc Freq Data=&FileOut. Noprint;
					Table &Var. / out=Collapse_Check(Keep=&Var. Count);
				Run;

				Proc SQL Noprint;
					Select Count(*) into: Collapse_Check_&Var. Trimmed 
						From Collapse_Check 
							Where Count<20;

					%If &&&Collapse_Check_&Var>0 %Then
						%Let Collapse_Pass=0;
				Quit;

			%End;
		%Mend;
		
		/*@Action: Perform collapsing and/or cell count checks ***/
		%Collapse(FileIn=Select_files0, FileOut=Select_files1, Var=agec, Num_Lvls=5);
		%Collapse(FileIn=Select_files1, FileOut=Select_files, Var=raceeth, Num_Lvls=2);
		
		%if &ESTIMATE_LEVEL. = NATIONAL %then %do;
			/*@Action: Execute sample size check  ***/
			Proc Freq Data=Select_files noprint;
				Table agec/list missing Out=Geo_agec_update (Drop=Percent Rename=(agec=Values));

					Table raceeth/list missing Out=Geo_raceeth_update (Drop=Percent Rename=(raceeth=Values));

						Table Sex/list missing Out=Geo_sex_update (Drop=Percent Rename=(Sex=Values));

							Table census_region/list missing Out=geo_census_region_update (Drop=Percent Rename=(census_region=Values));
								
								Table ru2/list missing Out=geo_ru2_update (Drop=Percent Rename=(ru2=Values));
			Run;

			Data Geo_freq_update;
				format Checker_Results $100.;
				Length Factor Values $100.;
				Set Geo_agec_update (in=a) Geo_raceeth_update (in=d) Geo_sex_update (in=f) 
					geo_census_region_update (in=g) geo_ru2_update (in=h);

				If a then
					Factor="Age Categories";
				Else if d then
					Factor="raceeth";
				Else if f then
					Factor="Sex";
				Else if g then
					Factor="census_region";
				Else if h then
					Factor="ru2";

				If count<20 then
					Checker_Results="Sample Size Is Insufficient";
				Else Checker_Results="Sample Size Is Sufficient";
			Run;
		%end;
		%else %do;
			/*@Action: Execute sample size check  ***/
			Proc Freq Data=Select_files noprint;
				Table agec/list missing Out=Geo_agec_update (Drop=Percent Rename=(agec=Values));

					Table raceeth/list missing Out=Geo_raceeth_update (Drop=Percent Rename=(raceeth=Values));

						Table Sex/list missing Out=Geo_sex_update (Drop=Percent Rename=(Sex=Values));

							Table ru2/list missing Out=geo_ru2_update (Drop=Percent Rename=(ru2=Values));
			Run;

			Data Geo_freq_update;
				format Checker_Results $100.;
				Length Factor Values $100.;
				Set Geo_agec_update (in=a) Geo_raceeth_update (in=d) Geo_sex_update (in=f) geo_ru2_update (in=h);

				If a then
					Factor="Age Categories";
				Else if d then
					Factor="raceeth";
				Else if f then
					Factor="Sex";
				Else if h then
					Factor="ru2";

				If count<20 then
					Checker_Results="Sample Size Is Insufficient";
				Else Checker_Results="Sample Size Is Sufficient";
			Run;
		%end;

		Proc Print data=Geo_freq_update;
			title "Updated Sample Size Checker Results for &month_loop. &year_loop.";
		Run;

		title;

		/*@Action: check to make sure we have enough levels and sample for the raking variables*/
		/*@Note: if we do not have enough sample, the code will abort*/
		data _null_;
			set Geo_freq_update;

			if (upcase(factor)="SEX" and upcase(values)="FEMALE" and count<20) 
				or (upcase(factor)="SEX" and upcase(values)="MALE" and count<20) then
				call symput("sex_proceed", "N");
			else call symput("sex_proceed", "Y");
		run;
		
		%if &ESTIMATE_LEVEL. = NATIONAL %then %do;
			data _null_;
				set Geo_freq_update;

				if (upcase(factor)="census_region" and upcase(values)="NORTHWEST" and count<20) 
					or (upcase(factor)="census_region" and upcase(values)="MIDWEST" and count<20)
					or (upcase(factor)="census_region" and upcase(values)="SOUTH" and count<20)
					or (upcase(factor)="census_region" and upcase(values)="WEST" and count<20) then
					call symput("census_region_proceed", "N");
				else call symput("census_region_proceed", "Y");
			run;
			
			%put &census_region_proceed.;
		%end;
		%else %do;
			%let census_region_proceed="N";
			
			%put &census_region_proceed.;
		%end;

		data _null_;
			set Geo_freq_update;

			if (upcase(factor)="RU2" and upcase(values)="MOSTLY  OR COMPLETELY RURAL" and count<20) 
				or (upcase(factor)="RU2" and upcase(values)="MOSTLY URBAN" and count<20) then
				call symput("ru2_proceed", "N");
			else call symput("ru2_proceed", "Y");
		run;
			
		%put &ru2_proceed.;

		proc sql noprint;
			select count(distinct agec) into: agec 
				from Select_files;
			select count(distinct raceeth) into: raceeth_cat
				from Select_files;
		quit;

		%put &sex_proceed. &agec. &raceeth_cat.;

		%if &agec.=3 %then
			%do;

				data _null_;
					set Geo_freq_update;

					if ((upcase(factor)="AGE CATEGORIES" and upcase(values)="20-44" and count<20) 
						or (upcase(factor)="AGE CATEGORIES" and upcase(values)="45-64" and count<20) 
						or (upcase(factor)="AGE CATEGORIES" and upcase(values)="65-84" and count<20)) then
						call symput("age_proceed", "N");
					else call symput("age_proceed", "Y");
				run;

			%end;
		%else %if &agec.<3 %then
			%do;
				
				%let age_proceed=N;
			%end;
		%else
			%do;
				%let age_proceed=Y;
			%end;

		%if &raceeth_cat.=2 %then
			%do;

				data _null_;
					set Geo_freq_update;

					if ((upcase(factor)="RACEETH" and upcase(values)="OTHER" and count<20) 
						or (upcase(factor)="RACEETH" and upcase(values)="WHITE" and count<20)) then
						call symput("raceeth_proceed", "N");
					else call symput("raceeth_proceed", "Y");
				run;

			%end;
		%else %if &raceeth_cat.<2 %then
			%do;
				
				%let raceeth_proceed=N;
			%end;
		%else
			%do;
				%let raceeth_proceed=Y;
			%end;

		%put &sex_proceed. &age_proceed. &raceeth_proceed.;

		%if &sex_proceed.=Y and &age_proceed.=N and &raceeth_proceed.=N %then
			%do;
				%put "Not enough sample for age and race/ethnicity";

				%abort;
			%end;
		%else %if &sex_proceed.=Y and &age_proceed.=Y and &raceeth_proceed.=N %then
			%do;
				%put "Not enough sample for race/ethnicity";

				%abort;
			%end;
		%else %if &sex_proceed.=Y and &age_proceed.=N and &raceeth_proceed.=Y %then
			%do;
				%put "Not enough sample for age";

				%abort;
			%end;
		%else %if &sex_proceed.=N and &age_proceed.=Y and &raceeth_proceed.=N %then
			%do;
				%put "Not enough sample for sex and race/ethnicity";

				%abort;
			%end;
		%else %if &sex_proceed.=N and &age_proceed.=Y and &raceeth_proceed.=Y %then
			%do;
				%put "Not enough sample for sex";

				%abort;
			%end;
		%else %if &sex_proceed.=N and &age_proceed.=N and &raceeth_proceed.=Y %then
			%do;
				%put "Not enough sample for sex and age";

				%abort;
			%end;
		%else %if &sex_proceed.=N and &age_proceed.=N and &raceeth_proceed.=N %then
			%do;
				%put "Not enough sample for sex, age, and race/ethnicity";

				%abort;
			%end;
		%else
			%do;
				/*@Action: Create InitWgt (Initial Weight) in the queried EHR file ***/
				Data Prepped_File;
					Set Select_files;
					Length InitWgt 3.;
					InitWgt=1;
				Run;

				/*@Action: Update Census controls with new raking levels (post-collapse) ***/
				%macro update_acs(var=);

					Proc Sql;
						Create table ACS_&var. as
							Select &var._Raking
								, sum(mrgtotal) as mrgtotal
							From ACS_&var._Controls
								Group by &var._Raking;
					Quit;

				%mend;

				/*********************************************************************************************************************/
				/**************************** -- VALIDATION CHECK TO PROCEED TO PREVALENCE COMPUTATION -- ****************************/
				/************** -- ALGORITHM WILL EXIT IF COLLAPSING HAS FAILED TO CORRECT SMALL WEIGHTING CELL SIZE  -- *************/
				/*********************************************************************************************************************/
				/*Action: Perform weighting using raking method on the fllowing SDOH***/
				/*ADDED to make raking run*/
				%update_acs(var=agec);
				%update_acs(var=agec_col);
				%update_acs(var=raceeth);
				%update_acs(var=raceeth_col);
				%update_acs(var=sex);	
				%update_acs(var=ru2);
				
				%if &ESTIMATE_LEVEL. = NATIONAL %then %do;
					%update_acs(var=census_region);	

					data prepped_file1;
						set prepped_file;
						AGEC_Raking = agec;
						age_col_raking = agec_col;
						raceeth_raking = raceeth;
						raceeth_col_raking = raceeth_col;
						sex_raking = sex;
						census_region_Raking = census_region;
						ru2_Raking = ru2;
					run;
				%end;
				%else %do;
					data prepped_file1;
						set prepped_file;
						AGEC_Raking = agec;
						age_col_raking = agec_col;
						raceeth_raking = raceeth;
						raceeth_col_raking = raceeth_col;
						sex_raking = sex;
						ru2_Raking = ru2;
					run;
				%end;

				/*@Action: complete raking macro by geography*/
				%if &estimate_level.=NATIONAL %then
					%do;
					/*@Action: rake using age, sex, race, census and rural/urban dichotomy*/
					%if &census_region_proceed.=Y and &ru2_proceed.=Y %then
						%do;
							%RAKING(inds=Prepped_File1, outds=Weighted_File0, inwt=InitWgt, freqlist=ACS_ru2 ACS_census_region ACS_AGEC ACS_raceeth ACS_Sex, outwt=RakeWgt, byvar=, varlist=ru2_Raking census_region_Raking AGEC_Raking raceeth_Raking Sex_Raking, numvar=5, trmprec=1, numiter=50);
							title;
						%end;
					/*@Action: rake using age, sex, race, and rural/urban dichotomy*/
					%else %if &census_region_proceed.=N and &ru2_proceed.=Y %then
						%do;
							%RAKING(inds=Prepped_File1, outds=Weighted_File0, inwt=InitWgt, freqlist=ACS_ru2 ACS_AGEC ACS_raceeth ACS_Sex, outwt=RakeWgt, byvar=, varlist=ru2_Raking AGEC_Raking raceeth_Raking Sex_Raking, numvar=4, trmprec=1, numiter=50);
							title;
						%end;
					/*@Action: rake using age, sex, race, and census*/
					%else %if &census_region_proceed.=Y and &ru2_proceed.=N %then
						%do;
							%RAKING(inds=Prepped_File1, outds=Weighted_File0, inwt=InitWgt, freqlist=ACS_census_region ACS_AGEC ACS_raceeth ACS_Sex, outwt=RakeWgt, byvar=, varlist=census_region_Raking AGEC_Raking raceeth_Raking Sex_Raking, numvar=4, trmprec=1, numiter=50);
							title;
						%end;
					/*@Action: rake using age, sex, and race*/
					%else
						%do;
							%RAKING(inds=Prepped_File1, outds=Weighted_File0, inwt=InitWgt, freqlist=ACS_AGEC ACS_raceeth ACS_Sex, outwt=RakeWgt, byvar=, varlist=AGEC_Raking raceeth_Raking Sex_Raking, numvar=3, trmprec=1, numiter=50);
							title;
						%end;
					%end;
				%else %do;
					/*@Action: rake using age, sex, race, and rural/urban dichotomy*/
					%if &ru2_proceed.=Y %then
						%do;
							%RAKING(inds=Prepped_File1, outds=Weighted_File0, inwt=InitWgt, freqlist=ACS_ru2 ACS_AGEC ACS_raceeth ACS_Sex, outwt=RakeWgt, byvar=, varlist=ru2_Raking AGEC_Raking raceeth_Raking Sex_Raking, numvar=4, trmprec=1, numiter=50);
							title;
						%end;
					/*@Action: rake using age, sex, and race*/
					%else
						%do;
							%RAKING(inds=Prepped_File1, outds=Weighted_File0, inwt=InitWgt, freqlist=ACS_AGEC ACS_raceeth ACS_Sex, outwt=RakeWgt, byvar=, varlist=AGEC_Raking raceeth_Raking Sex_Raking, numvar=3, trmprec=1, numiter=50);
							title;
						%end;
					%end;

				/*@Action: save pre age-adjusted weighted file to output folder***/
				%if &estimate_level.=NATIONAL %then
					%do;

						data sasin.WGTS0_&estimate_level.&year_loop.&month_loop.;
							set Weighted_File0;
						run;

					%end;
				%else
					%do;

						proc sql noprint;
							select cats("&estimate_level.", input(trim(strip(state_fips)),8.)) into: ondeckname trimmed 
								from &ESTIMATE_LEVEL._freq
									where state_fips=&ondeck.;
						quit;

						%put &ondeckname.;

						data sasin.WGTS0_&ondeckname._&year_loop.&month_loop.;
							set Weighted_File0;
						run;

						proc append data=sasin.WGTS0_&ondeckname._&year_loop.&month_loop. base=sasin.WGTS0_&year_loop.&month_loop.;
						run;

					%end;

				title;
			%end;
%mend;

/*@Program End ***/