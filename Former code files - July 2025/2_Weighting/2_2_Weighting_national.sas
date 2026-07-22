%macro weights_national();
	
	/*@Action: Finish ACS control totals to be used in weighting ***/
	%acs_controls_natl(var=age8);
	%acs_controls_natl(var=raceeth4);
	%acs_controls_natl(var=ru2);
	%acs_controls_natl(var=region);
	%acs_controls_natl(var=age_sex);
	%acs_controls_natl(var=race_sex);
	%acs_controls_natl(var=ins_race);
	%acs_controls_natl(var=ins_age);

	/*@Action: Subset to observations that are relevant to the analysis ***/
	data select_files (rename=(prmpay2=insurance2 agecat8=age8 agecat3=age3));
		set sasin.include_ehr&year_loop.&month_loop. (rename=(region=region_char));
		where month=&month_loop. and year=&year_loop. and region_char is not null and ru2 is not null and ethnicity0 is not null;

		if region_char="Northeast" then region='1';
		else if region_char="Midwest" then region='2';
		else if region_char="South" then region='3';
		else if region_char="West" then region='4';
	run;

	proc sort data=select_files;
		by aa_seq year;
	run;

	%checkfreq(filein=select_files, var=age8);
	%checkfreq(filein=select_files, var=raceeth4);
	%checkfreq(filein=select_files, var=ru2);
	%checkfreq(filein=select_files, var=region);
	%checkfreq2(filein=select_files, var1=age3, var2=sex);
	%checkfreq2(filein=select_files, var1=raceeth4, var2=sex);
	%checkfreq2(filein=select_files, var1=insurance2, var2=age3);
	%checkfreq2(filein=select_files, var1=insurance2, var2=raceeth4);

	data geo_freq;
		format checker_results $100.;
		length factor values1 values2 $100.;
		set geo_age8 (in=in1) geo_raceeth4 (in=in2) geo_ru2 (in=in3)  geo_region (in=in4)
			geo_age3_sex (in=in5) geo_raceeth4_sex (in=in6) geo_insurance2_age3 (in=in7) geo_insurance2_raceeth4 (in=in8);

		if in1 then
			factor='age8';
		else if in2 then
			factor='raceeth4';
		else if in3 then
			factor='ru2';
		else if in4 then
			factor='region';
		else if in5 then
			factor='age3, sex';
		else if in6 then
			factor='raceeth4, sex';
		else if in7 then
			factor='insurance2, age3';
		else if in8 then
			factor='insurance2, raceeth4';

		if count<20 then
			checker_results="sample size is insufficient";
		else checker_results="sample size is sufficient";
	run;

	proc datasets library=work nolist;
		delete geo_age8 geo_raceeth4 geo_ru2 geo_region 
					geo_age3_sex geo_raceeth4_sex geo_insurance2_age3 geo_insurance2_raceeth4;
	run;

	quit;

	proc print data=geo_freq;
		title "sample size checker results for &month_loop-&year_loop. national";
		where checker_results="sample size is insufficient";
	run;

	title;

	/*@Action: Create InitWgt (Initial Weight) in the queried EHR file ***/
	data prepped_file;
		set select_files;
		length initwgt 3.;
		initwgt=1;
		unique_id=cats("id",_N_);
		age_sex=catx("_", age3, sex);
		race_sex=catx("_", raceeth4, sex);
		ins_race=catx("_", insurance2, raceeth4);
		ins_age=catx("_", insurance2, age3);
	run;

	data prepped_file1;
		set prepped_file;
		age8_raking=age8;
		raceeth4_raking=raceeth4;
		ru2_raking=ru2;
		region_raking=region;
		age_sex_raking=age_sex;
		race_sex_raking=race_sex;
		ins_age_raking=ins_age;
		ins_race_raking=ins_race;
		keep unique_id initwgt
			age8_raking raceeth4_raking ru2_raking region_raking
			age_sex_raking race_sex_raking ins_age_raking ins_race_raking;
	run;

	proc freq data=prepped_file1;
		table age8_raking raceeth4_raking ru2_raking region_raking
			age_sex_raking race_sex_raking ins_age_raking ins_race_raking/list missing;
	run;

	*@Action: complete alt 2 raking method without state: 	age8 raceeth4 ru2 region age3 * sex raceeth4 * sex insurance2 * age3 insurance2 * raceeth4;
	%raking(inds=prepped_file1
		, outds=wgt_alt2_natl_&year_loop.&month_loop.
		, inwt=initwgt
		, freqlist=acs_natl_age8 acs_natl_raceeth4 acs_natl_ru2 acs_natl_region acs_natl_age_sex acs_natl_race_sex acs_natl_ins_age acs_natl_ins_race
		, outwt=rakewgt
		, byvar=
		, varlist=age8_raking raceeth4_raking ru2_raking region_raking age_sex_raking race_sex_raking ins_age_raking ins_race_raking 
		, numvar=8
		, trmprec=&tol.
		, numiter=&iter.);
	title;

	proc sort data=prepped_file;
		by unique_id;
	run;

	proc sort data=wgt_alt2_natl_&year_loop.&month_loop. (keep=unique_id rakewgt);
		by unique_id;
	run;

	data sasout.wgt_alt2_natl_&year_loop.&month_loop. (drop=unique_id);
		merge prepped_file wgt_alt2_natl_&year_loop.&month_loop.;
		by unique_id;
	run;
%mend;