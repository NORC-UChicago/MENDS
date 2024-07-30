/**********************************************************************************************************************************/
/**************************************************** -- Suppression macro -- *****************************************************/
/**********************************************************************************************************************************/
%macro Suppress(National_est=, STATE_EST=);

	/*@Action: declare macros*/
	%if &National_est.=Y %then
		%do;
			%Let ESTIMATE_LEVEL = NATIONAL;
			%LET ACS_FILE = ACS_Controls_Universe_zcta;
			%let geo_level_var="NATIONAL";
		%end;
	%else %if &STATE_EST. = Y %then 
		%do;
			%Let ESTIMATE_LEVEL = STATE;
			%LET ACS_FILE = ACS_Controls_Universe_zcta;
			%let geo_level_var=state_fips;
		%end;

	/*@Action: create suppression flag*/
	data est;
		set sasout.Est_wide_&estimate_level.;
		if Sample_PT<50 or Crude_Prev=0 or ((Crude_StdErr/Crude_Prev) ge .3) or ((STD_Err/Pop_Perc) ge .3) then suppress=1;
		else suppress=0;	
	run;
	
	/*Action: suppress values*/
	data Prev_Est_Supr0 (keep=geographic_type geographic_level year_month Condition Group1 Group2 groupvalue1 groupvalue2 sample_pt crude_prev crude_stderr pop_perc std_err /*pop_perc_age_adj std_err_age_adj*/);
		set est;

		if suppress=1 then
			do;
				Sample_PT=.;
				Pop_n=.;
				Crude_Prev=.;
				Crude_StdErr=.;
				Pop_Perc=.;
				STD_Err=.;
				/*Pop_Perc_Age_Adj=.;*/
				/*STD_Err_Age_Adj=.;*/
			end;
	run;

	/*@Action: create suppressed version*/
	data Prev_Est_Supr_crd (rename=(Sample_PT=Npats Crude_Prev=prevalance Crude_StdErr=se));
		set Prev_Est_Supr0;
		keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Crude_Prev Crude_StdErr;
		length est_type $15.;
		est_type="crude";
	run;

	data Prev_Est_Supr_wgt (rename=(Sample_PT=Npats Pop_Perc=prevalance STD_Err=se));
		set Prev_Est_Supr0;
		keep geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Sample_PT Pop_Perc STD_Err;
		length est_type $15.;
		est_type="modeled";
	run;

	data sasout.Supr_&estimate_level.;
		retain geographic_type geographic_level Condition year_month Group1 GroupValue1 Group2 GroupValue2 est_type Npats prevalance se;
		set Prev_Est_Supr_crd Prev_Est_Supr_wgt /*Prev_Est_Supr_adj*/;
		sort=_N_;
	run;

	proc sort data=sasout.Supr_&estimate_level.;
		by sort;
	run;

	/*@Action: clear work folder*/
	Proc Datasets Library=WORK NOLIST Kill;
	Quit;
%mend;

/*@Program End ***/