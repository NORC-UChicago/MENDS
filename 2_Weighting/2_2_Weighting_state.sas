/*@Action: Collapse Raking Levels ***/
%Macro Collapse(FileIn, FileOut, Var, Num_Lvls);

	Data &Filein._precoll;
		Set &FileIn.;
		keep state unique_id &var.;
	Run;

	data acs_state_&var.0_precoll;
		set acs_state_&var.0;
	run;

	%do stateloop=1 %to &maxstate.;

		proc sql noprint;
			select state into: state
				from state_list
					where count=&stateloop.;
		quit;

		data &Filein.&stateloop.;
			set &Filein._precoll;
			where state="&state.";
		run;

		data acs_state&stateloop._&var.0;
			set acs_state_&var.0_precoll;
			state=substr(state_&var._raking,1,2);
			&var.=substr(state_&var._raking, 4, length(state_&var._raking)-3);

			if state="&state.";
		run;

		%Do I=1 %To &Num_Lvls.;

			Proc Freq Data=&Filein.&stateloop. Noprint;
				Table state*&Var. / out=Sample_Joint(Keep=state &Var. Count);
					where state="&state.";
			run;

			Data Sample_Joint(Keep=state &Var. Count Collapse_Flg);
				set Sample_Joint;
				By state &Var.;
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

			%put &Collapse_Flg.;

			%If %Eval(&Collapse_Flg.>0) %Then
				%Do;
					%Let &Var._Collapse=&Var.;

					Data Sample_Joint_Collapse;
						Set Sample_Joint;
						Collapse_Flg = Put(&Var., $&Var._&I._C.);

						If Strip(Collapse_Flg)^="" Then
							New_Level = Put(Collapse_Flg, $Collapse_&Var._.);
						Else New_Level = &Var.;
					Run;

					Proc Sort Data=&filein.&stateloop.;
						By state &Var.;
					Run;

					Proc Sort Data=acs_state&stateloop._&var.0;
						By state &Var.;
					Run;

					Data &Filein.&stateloop.(Rename=(New_Level_fmt = &Var.));
						Merge &Filein.&stateloop.(In=A) Sample_Joint_Collapse(In=B Keep=state &Var. New_Level);
						By state &Var.;

						length New_Level_fmt $50.;
						New_Level_fmt=New_Level;

						If A and b;
						Drop &Var. New_Level;
					Run;

					Data acs_state&stateloop._&var.0 (rename=(New_level=&var.));
						Merge acs_state&stateloop._&var.0(In=A drop=state_&Var._Raking) Sample_Joint_Collapse(In=B Keep=state &Var. New_Level);
						By state &Var.;
						LENGTH state_&Var._Raking $50.;
						state_&Var._Raking=catx("_", state, New_level);

						If A and b;
						Drop &Var.;
					Run;

				%End;

			/*@Action: Update the Collapse Pass macro variable, if failed replace 1 with a 0 ***/
			Proc Freq Data=&Filein.&stateloop. Noprint;
				Table state*&Var. / out=Collapse_Check(Keep=state &Var. Count);
					where state="&state.";
			Run;

			Proc SQL Noprint;
				Select Count(*) into: Collapse_Check_&Var. Trimmed 
					From Collapse_Check 
						Where Count<20;

				%If &&&Collapse_Check_&Var>0 %Then
					%Let Collapse_Pass=0;
			Quit;

		%End;

		proc append data=&Filein.&stateloop. base=&fileout._&var. force;
		run;

		proc append data=acs_state&stateloop._&var.0 base=acs_state_&var.0_presum force;
		run;

		proc datasets library=work nolist;
			delete &Filein.&stateloop. acs_state&stateloop._&var.0;
		run;
		quit;

	%end;

	Proc Freq Data=&fileout._&var.;
		Table state*&Var./list missing;
	Run;
	
	proc sort data=&fileout._&var.;
		by unique_id;
	run;
	
	proc sort data=&FileIn.;
		by unique_id;
	run;
	
	data &fileout.;
		merge &FileIn. (drop=&var.) &fileout._&var.;
		by unique_id;
	run;

	Proc sql;
		create table acs_state_&var. as 
			select distinct state_&var._raking
				, sum(mrgtotal) as mrgtotal
			from acs_state_&var.0_presum
				group by state_&var._raking;
	quit;

%Mend;

%macro weights_state();
	*import the acs files;
	%acs_controls_state(var=age8);
	%acs_controls_state(var=raceeth4);
	%acs_controls_state(var=ru2);
	%acs_controls_state(var=age_sex);
	%acs_controls_state(var=race_col_sex);
	%acs_controls_state(var=ins_age);
	%acs_controls_state(var=ins_race_col);

	/*@Action: Create formats for collapsing of groups ***/
	Proc Format;
		Value $age8_1_C "20-24" = "1"
			"25-29" = "1"
			other = " "
		;
		Value $age8_2_C "30-34" = "2"
			"35-44" = "2"
			other   = " "
		;
		Value $age8_3_C "45-54" = "3"
			"55-64" = "3"
			other   = " "
		;
		Value $age8_4_C "65-74" = "4"
			"75-84" = "4"
			other   = " "
		;
		Value $age8_5_C "20-29" = "5"
			"30-44" = "5"
			other   = " "
		;
		Value $collapse_age8_ "1"   = "20-29"
			"2"   = "30-44"
			"3"   = "45-64"
			"4"   = "65-84"
			"5"   = "20-44"
			other = " "
		;
		Value $raceeth4_1_C "Hispanic" = "1"
			"Other" = "1"
			other   = " "
		;
		Value $raceeth4_2_C "Black" = "1"
			"Hispanic" = "1"
			"Other" = "1"
			other   = " "
		;
		Value $raceeth4_3_C "White" = "2"
			other   = " "
		;
		Value $collapse_raceeth4_ "1"   = "Other"
			"2"   = "White"
			other = " "
		;
	Run;

	/*@Action: Subset to observations that are relevant to the analysis ***/
	proc freq data=sasin.include_ehr&year_loop.&month_loop.;
		table state/list missing out=state_freq&year_loop.&month_loop. (where=(count ge 250));
		where month=&month_loop. and year=&year_loop.;
	run;

	proc sort data=sasin.include_ehr&year_loop.&month_loop. out=include_ehr&year_loop.&month_loop.;
		by state;

		where month=&month_loop. and year=&year_loop. and region is not null and ru2 is not null and ethnicity0 is not null;
	run;

	data select_files0 (rename=(prmpay2=insurance2 agecat8=age8 agecat3=age3));
		merge include_ehr&year_loop.&month_loop. (in=a) state_freq&year_loop.&month_loop. (in=b);
		by state;

		if a and b;
		
		unique_id=cats("id",_N_);

		if raceeth4="White" then
			raceeth_col="White";
		else raceeth_col="Other";
		age8_orig=agecat8;
		raceeth4_orig=raceeth4;
		raceeth_col_orig=raceeth_col;
	run;

	proc sort data=select_files0;
		by aa_seq year;
	run;

	%checkfreqstate(filein=select_files0, var=age8);
	%checkfreqstate(filein=select_files0, var=raceeth4);
	%checkfreqstate(filein=select_files0, var=ru2);
	%checkfreqstate2(filein=select_files0, var1=age3, var2=sex);
	%checkfreqstate2(filein=select_files0, var1=raceeth_col, var2=sex);
	%checkfreqstate2(filein=select_files0, var1=insurance2, var2=age3);
	%checkfreqstate2(filein=select_files0, var1=insurance2, var2=raceeth_col);

	data geo_freq;
		format checker_results $100.;
		length factor values1 values2 $100.;
		set geo_state_age8 (in=in1) geo_state_raceeth4 (in=in2) geo_state_ru2 (in=in3)
			geo_state_age3_sex (in=in4) geo_state_raceeth_col_sex (in=in5) geo_state_insurance2_age3 (in=in6) geo_state_insurance2_raceeth_col (in=in7);

		if in1 then
			factor='age8';
		else if in2 then
			factor='raceeth4';
		else if in3 then
			factor='ru2';
		else if in4 then
			factor='age3, sex';
		else if in5 then
			factor='raceeth_col, sex';
		else if in6 then
			factor='insurance2, age3';
		else if in7 then
			factor='insurance2, raceeth_col';

		if count<20 then
			checker_results="sample size is insufficient";
		else checker_results="sample size is sufficient";
	run;

	proc datasets library=work nolist;
		delete geo_state_age8 geo_state_raceeth4 geo_state_ru2
			geo_state_age3_sex geo_state_raceeth_col_sex geo_state_insurance2_age3 geo_state_insurance2_raceeth_col;
	run;

	quit;

	proc print data=geo_freq;
		title "sample size checker results for &year_loop.&month_loop. national";
		where checker_results="sample size is insufficient";
	run;

	title;

	/*@Action: Perform collapsing and/or cell count checks ***/
	proc sql;
		create table state_list as 
			select distinct state 
				from select_files0;
	quit;

	data state_list;
		set state_list;
		count=_N_;
	run;

	proc sql noprint;
		select max(count) into: maxstate
			from state_list;
	quit;

	%Collapse(FileIn=Select_files0, FileOut=Select_files1, Var=raceeth4, Num_Lvls=3);
	%Collapse(FileIn=Select_files1, FileOut=Select_files, Var=age8, Num_Lvls=5);

	proc freq data=Select_files;
		table state*raceeth4_orig*raceeth state*age8_orig*age8/list missing;
	run;

	%checkfreqstate(filein=Select_files, var=age8);
	%checkfreqstate(filein=Select_files, var=raceeth4);
	%checkfreqstate(filein=Select_files, var=ru2);
	%checkfreqstate2(filein=Select_files, var1=age3, var2=sex);
	%checkfreqstate2(filein=Select_files, var1=raceeth_col, var2=sex);
	%checkfreqstate2(filein=Select_files, var1=insurance2, var2=age3);
	%checkfreqstate2(filein=Select_files, var1=insurance2, var2=raceeth_col);

	data geo_freq_update;
		format checker_results $100.;
		length factor values1 values2 $100.;
		set geo_state_age8 (in=in1) geo_state_raceeth4 (in=in2) geo_state_ru2 (in=in3)
			geo_state_age3_sex (in=in4) geo_state_raceeth_col_sex (in=in5) geo_state_insurance2_age3 (in=in6) geo_state_insurance2_raceeth_col (in=in7);

		if in1 then
			factor='age8';
		else if in2 then
			factor='raceeth4';
		else if in3 then
			factor='ru2';
		else if in4 then
			factor='age3, sex';
		else if in5 then
			factor='raceeth_col, sex';
		else if in6 then
			factor='insurance2, age3';
		else if in7 then
			factor='insurance2, raceeth_col';

		if count<20 then
			checker_results="sample size is insufficient";
		else checker_results="sample size is sufficient";
	run;

	proc datasets library=work nolist;
		delete select_files0_precoll select_files1_precoll
			acs_state_age80_precoll acs_state_raceeth40_precoll
			geo_state_age8 geo_state_raceeth4 geo_state_ru2
			geo_state_age3_sex geo_state_raceeth_col_sex geo_state_insurance2_age3 geo_state_insurance2_raceeth_col;
	run;

	quit;

	proc print data=geo_freq_update;
		title "sample size checker results for &year_loop.&month_loop. national";
		where checker_results="sample size is insufficient";
	run;

	title;

	/*@Action: Create InitWgt (Initial Weight) in the queried EHR file ***/
	data prepped_file&year_loop.&month_loop.;
		set select_files;
		length initwgt 3.;
		initwgt=1;

		state_age8=catx("_", state, age8);
		state_raceeth4=catx("_", state, raceeth4);
		state_ru2=catx("_", state, ru2);
		state_age_sex=catx("_", state, age3, sex);
		state_race_col_sex=catx("_", state, raceeth_col, sex);
		state_ins_race_col=catx("_", state, insurance2, raceeth_col);
		state_ins_age=catx("_", state, insurance2, age3);
	run;

	data prepped_file1&year_loop.&month_loop.;
		set prepped_file&year_loop.&month_loop.;
		
		state_age8_raking=state_age8;
		state_raceeth4_raking=state_raceeth4;
		state_ru2_raking=state_ru2;
		state_age_sex_raking=state_age_sex;
		state_race_col_sex_raking=state_race_col_sex;
		state_ins_race_col_raking=state_ins_race_col;
		state_ins_age_raking=state_ins_age;

		keep unique_id initwgt
			state_age8_raking state_raceeth4_raking state_ru2_raking
			state_age_sex_raking state_race_col_sex_raking state_ins_age_raking state_ins_race_col_raking;
	run;

	proc freq data=prepped_file1&year_loop.&month_loop.;
		table state_age8_raking state_raceeth4_raking state_ru2_raking
			state_age_sex_raking state_race_col_sex_raking state_ins_age_raking state_ins_race_col_raking/list missing;
	run;

	%fixacs_state(var=age8);
	%fixacs_state(var=raceeth4);
	%fixacs_state(var=ru2);
	%fixacs_state(var=age_sex);
	%fixacs_state(var=race_col_sex);
	%fixacs_state(var=ins_age);
	%fixacs_state(var=ins_race_col);

	*@Action: complete alt 2 raking method with state: state * age8 state * raceeth4 state * ru2 state * age3 * sex state * raceeth2 * sex state * insurance2 * raceeth2 state * insurance2 * age3;
	%raking(inds=prepped_file1&year_loop.&month_loop.
		, outds=wgt_alt2_state_&year_loop.&month_loop.
		, inwt=initwgt
		, freqlist=acs_state_age8&year_loop.&month_loop. acs_state_raceeth4&year_loop.&month_loop. acs_state_ru2&year_loop.&month_loop. acs_state_age_sex&year_loop.&month_loop. acs_state_race_col_sex&year_loop.&month_loop. acs_state_ins_age&year_loop.&month_loop. acs_state_ins_race_col&year_loop.&month_loop.
		, outwt=rakewgt
		, byvar=
		, varlist=state_age8_raking state_raceeth4_raking state_ru2_raking state_age_sex_raking state_race_col_sex_raking state_ins_age_raking state_ins_race_col_raking 
		, numvar=7
		, trmprec=&tol.
		, numiter=&iter.);
	title;

	proc sort data=prepped_file&year_loop.&month_loop.;
		by unique_id;
	run;

	proc sort data=wgt_alt2_state_&year_loop.&month_loop. (keep=unique_id rakewgt);
		by unique_id;
	run;

	data sasout.wgt_alt2_state_&year_loop.&month_loop. (drop=unique_id);
		merge prepped_file&year_loop.&month_loop. wgt_alt2_state_&year_loop.&month_loop.;
		by unique_id;
	run;

	proc datasets library=work nolist kill;
	run;
	quit;

%mend;