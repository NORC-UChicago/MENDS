/*******************************************************************************************************************************************/
/*************************************************** -- Import EHR Data File into SAS -- ***************************************************/
/********************************** -- Reformat and create variables needed for prevalence estimation -- ***********************************/
/*******************************************************************************************************************************************/
%macro prep();

	/*@Action: create AC file*/
	data Include_EHR_AC&year_loop.&month_loop.;
		set orig.AC_EHR0 (rename=(age=age_num af=year ag=month aj=encnters_last2yr cb=census_tract bs=encts_total ab=Sex0 ad=birthcohort
			ah=age ah_alt=agec0 ak=bmi ao=sysbp aq=dbp as=LDL at=triglc au=HbA1c ca=diab_dx bb=smoking bk=HTN_ESP
			by=HTN_dx av=prediab aw=diab_t1 ax=diab_t2 ay=insulin az=metformin ba=flu_vac bc=asthma
			ethnicity=ethnicity0 race=race0));

		/*@Action: subset to specific month and year*/
		where year=&year_loop. and month=&month_loop.;
		
		/*@Action: create a contatonated month and year;*/
		format month_year yymm.;
		month_year=input(catx('-',month,year),ANYDTDTE.);
		
		/*@Action: create formatted variables and convert some variables from character to numeric or vice versa*/
		length partner $4. agec agec_col sex raceeth raceeth2 raceeth_col prmpay $50.;
		partner="AC";
		encnters_last1yr=input(ai,8.);
		pregnant=input(am,8.);
		diab_gest=input(an,8.);
		ASCVD=input(bx,8.);
		zip=substr(ae, 1,5);

		/*Action: create a hypertension flag*/
		If HTN_ESP = . Then
			FLG_HTN=0;
		Else FLG_HTN=1;

		/*@Action: Define no encounters flag ***/
		if encnters_last2yr=. then
			no_enctr2yr=1;
		else no_enctr2yr=0;

		if encnters_last2yr=. then
			_cat_enctr=0;
		else if encnters_last2yr>=1 & encnters_last2yr<=2 then
			_cat_enctr=1;
		else if encnters_last2yr>=3 & encnters_last2yr<=4 then
			_cat_enctr=2;
		else if encnters_last2yr>=5 & encnters_last2yr<=8 then
			_cat_enctr=3;
		else if encnters_last2yr>=9 & encnters_last2yr<=19 then
			_cat_enctr=4;
		else if encnters_last2yr>19 & encnters_last2yr ne . then
			_cat_enctr=5;

		/*@Action: Create 0/1 flag for having a bp in the past2 years***/
		bp2yr = 0;

		if prior1bp > 0 then
			bp2yr = 1;
		else  if prior2bp > 0 then
			bp2yr = 1;

		/*@Action: Create 0/1 flag for HTN flag***/
		if HTN_ESP ne . and HTN_ESP in (1,4,5) then
			htnyn = 1;
		else if HTN_ESP ne . and HTN_ESP in (2,3) then
			htnyn = 0;
		else if HTN_ESP ne . and HTN_ESP=0 then
			htnyn = .;

		/*@Action: Create 0/1 flag for HTN dx and controlled original***/
		if htn_dx in (1,2,3) then
			htndx = 1;
		else if htn_dx = . then
			htndx = .;
		else htndx = 0;

		if htn_dx=1 then
			htnc1 = 1;
		else if htn_dx in (.,0) then
			htnc1 = .;
		else htnc1 = 0;

		/*@Action: Create 0/1 flag for HTN controll original***/
		if HTN_ESP ne . and HTN_ESP in (1) then
			htnc= 1;
		else if HTN_ESP ne . and HTN_ESP in (4,5) then
			htnc= 0;
		else if HTN_ESP ne . and HTN_ESP in (0,2,3) then
			htnc= .;
		else htnc= .;

		/*@Action: Update race ethnicity values for raking***/
		if ethnicity0=1 then
			raceeth="Other";
		else if ethnicity0=2 and race0=1 then
			raceeth="White";
		else if ethnicity0=2 and race0=2 then
			raceeth="Other";
		else if ethnicity0=2 and race0=3 then
			raceeth="Black";
		else if ethnicity0=2 and race0=4 then
			raceeth="Other";
		else if ethnicity0=2 and race0=5 then
			raceeth="Unspecified";
		else if ethnicity0=2 and race0=6 then
			raceeth="Other";
		else if ethnicity0=2 and race0=7 then
			raceeth="Other";
		else raceeth="Missing";

		/*@Action: Update race ethnicity values for report***/
		if ethnicity0=1 then
			raceeth2="Hispanic";
		else if ethnicity0=2 and race0=1 then
			raceeth2="White";
		else if ethnicity0=2 and race0=2 then
			raceeth2="Asian";
		else if ethnicity0=2 and race0=3 then
			raceeth2="Black";
		else if ethnicity0=2 and race0=4 then
			raceeth2="Other";
		else if ethnicity0=2 and race0=5 then
			raceeth2="Unspecified";
		else if ethnicity0=2 and race0=6 then
			raceeth2="American Indian or Alaska Native";
		else if ethnicity0=2 and race0=7 then
			raceeth2="Native Hawaiian or Other Pacific Islander";
		else raceeth2="Missing";

		/*@Action: Change primary payer to character***/
		if bz=0 then
			prmpay="Unknown_other_self-pay";
		else if bz=1 then
			prmpay="Bluecross_Commercial";
		else if bz=2 then
			prmpay="Workers_comp_Auto";
		else if bz=3 then
			prmpay="Medicaid";
		else if bz=4 then
			prmpay="Medicare";
		else prmpay="Unknown_other_self-pay";

		/*@Action: Change age category to character***/
		if agec0=1 then
			agec="0-4";
		else if agec0=2 then
			agec="5-9";
		else if agec0=3 then
			agec="10-14";
		else if agec0=4 then
			agec="15-19";
		else if agec0=5 then
			agec="20-24";
		else if agec0=6 then
			agec="25-29";
		else if agec0=7 then
			agec="30-34";
		else if agec0=8 then
			agec="35-44";
		else if agec0=9 then
			agec="45-54";
		else if agec0=10 then
			agec="55-64";
		else if agec0=11 then
			agec="65-74";
		else if agec0=12 then
			agec="75-84";
		else if agec0=13 then
			agec="85+";

		/*@Action: Change collapsed age category to character***/
		if agec0 in (5,6,7,8) then
			agec_col="20-44";
		else if agec0 in (9,10) then
			agec_col="45-64";
		else if agec0 in (11,12) then
			agec_col="65-84";

		/*@Action: Change sex to character***/
		if sex0=1 then
			Sex="Male";
		else if sex0=2 then
			Sex="Female";

		/*@Action: Update collapsed race category***/
		if raceeth="White" then
			raceeth_col="White";
		else raceeth_col="Other";
	Run;
		
	/*@Action: create HDC file*/
	Data Include_EHR_HDC&year_loop.&month_loop.;
		set orig.HDC_EHR0 (rename=(age=age_num af=year ag=month aj=encnters_last2yr cb=census_tract bs=encts_total ab=Sex0 ad=birthcohort
			ah=age ah_alt=agec0 ak=bmi ao=sysbp aq=dbp as=LDL at=triglc au=HbA1c ca=diab_dx bb=smoking bk=HTN_ESP
			by=HTN_dx av=prediab aw=diab_t1 ax=diab_t2 ay=insulin az=metformin ba=flu_vac bc=asthma
			ethnicity=ethnicity0 race=race0));

		/*@Action: subset to specific month and year*/
		where year=&year_loop. and month=&month_loop.;
		
		/*@Action: create a contatonated month and year;*/
		format month_year yymm.;
		month_year=input(catx('-',month,year),ANYDTDTE.);
		
		/*@Action: create formatted variables and convert some variables from character to numeric or vice versa*/
		length partner $4. agec agec_col sex raceeth raceeth2 raceeth_col prmpay $50.;
		partner="HDC";
		encnters_last1yr=input(ai,8.);
		pregnant=input(am,8.);
		diab_gest=input(an,8.);
		ASCVD=input(bx,8.);
		zip=substr(ae, 1,5);

		/*Action: create a hypertension flag*/
		If HTN_ESP = . Then
			FLG_HTN=0;
		Else FLG_HTN=1;

		/*@Action: Define no encounters flag ***/
		if encnters_last2yr=. then
			no_enctr2yr=1;
		else no_enctr2yr=0;

		if encnters_last2yr=. then
			_cat_enctr=0;
		else if encnters_last2yr>=1 & encnters_last2yr<=2 then
			_cat_enctr=1;
		else if encnters_last2yr>=3 & encnters_last2yr<=4 then
			_cat_enctr=2;
		else if encnters_last2yr>=5 & encnters_last2yr<=8 then
			_cat_enctr=3;
		else if encnters_last2yr>=9 & encnters_last2yr<=19 then
			_cat_enctr=4;
		else if encnters_last2yr>19 & encnters_last2yr ne . then
			_cat_enctr=5;

		/*@Action: Create 0/1 flag for having a bp in the past2 years***/
		bp2yr = 0;

		if prior1bp > 0 then
			bp2yr = 1;
		else  if prior2bp > 0 then
			bp2yr = 1;

		/*@Action: Create 0/1 flag for HTN flag***/
		if HTN_ESP ne . and HTN_ESP in (1,4,5) then
			htnyn = 1;
		else if HTN_ESP ne . and HTN_ESP in (2,3) then
			htnyn = 0;
		else if HTN_ESP ne . and HTN_ESP=0 then
			htnyn = .;

		/*@Action: Create 0/1 flag for HTN dx and controlled***/
		if htn_dx in (1,2,3) then
			htndx = 1;
		else if htn_dx = . then
			htndx = .;
		else htndx = 0;

		if htn_dx=1 then
			htnc1 = 1;
		else if htn_dx in (.,0) then
			htnc1 = .;
		else htnc1 = 0;

		/*@Action: Create 0/1 flag for HTN controll original***/
		if HTN_ESP ne . and HTN_ESP in (1) then
			htnc= 1;
		else if HTN_ESP ne . and HTN_ESP in (4,5) then
			htnc= 0;
		else if HTN_ESP ne . and HTN_ESP in (0,2,3) then
			htnc= .;
		else htnc= .;

		/*@Action: Update race ethnicity values for raking***/
		if ethnicity0=1 then
			raceeth="Other";
		else if ethnicity0=2 and race0=1 then
			raceeth="White";
		else if ethnicity0=2 and race0=2 then
			raceeth="Other";
		else if ethnicity0=2 and race0=3 then
			raceeth="Black";
		else if ethnicity0=2 and race0=4 then
			raceeth="Other";
		else if ethnicity0=2 and race0=5 then
			raceeth="Unspecified";
		else if ethnicity0=2 and race0=6 then
			raceeth="Other";
		else if ethnicity0=2 and race0=7 then
			raceeth="Other";
		else raceeth="Missing";

		/*@Action: Update race ethnicity values for report***/
		if ethnicity0=1 then
			raceeth2="Hispanic";
		else if ethnicity0=2 and race0=1 then
			raceeth2="White";
		else if ethnicity0=2 and race0=2 then
			raceeth2="Asian";
		else if ethnicity0=2 and race0=3 then
			raceeth2="Black";
		else if ethnicity0=2 and race0=4 then
			raceeth2="Other";
		else if ethnicity0=2 and race0=5 then
			raceeth2="Unspecified";
		else if ethnicity0=2 and race0=6 then
			raceeth2="American Indian or Alaska Native";
		else if ethnicity0=2 and race0=7 then
			raceeth2="Native Hawaiian or Other Pacific Islander";
		else raceeth2="Missing";

		/*@Action: Change primary payer to character***/
		if bz=0 then
			prmpay="Unknown_other_self-pay";
		else if bz=1 then
			prmpay="Bluecross_Commercial";
		else if bz=2 then
			prmpay="Workers_comp_Auto";
		else if bz=3 then
			prmpay="Medicaid";
		else if bz=4 then
			prmpay="Medicare";
		else prmpay="Unknown_other_self-pay";

		/*@Action: Change age category to character***/
		if agec0=1 then
			agec="0-4";
		else if agec0=2 then
			agec="5-9";
		else if agec0=3 then
			agec="10-14";
		else if agec0=4 then
			agec="15-19";
		else if agec0=5 then
			agec="20-24";
		else if agec0=6 then
			agec="25-29";
		else if agec0=7 then
			agec="30-34";
		else if agec0=8 then
			agec="35-44";
		else if agec0=9 then
			agec="45-54";
		else if agec0=10 then
			agec="55-64";
		else if agec0=11 then
			agec="65-74";
		else if agec0=12 then
			agec="75-84";
		else if agec0=13 then
			agec="85+";

		/*@Action: Change collapsed age category to character***/
		if agec0 in (5,6,7,8) then
			agec_col="20-44";
		else if agec0 in (9,10) then
			agec_col="45-64";
		else if agec0 in (11,12) then
			agec_col="65-84";

		/*@Action: Change sex to character***/
		if sex0=1 then
			Sex="Male";
		else if sex0=2 then
			Sex="Female";

		/*@Action: Update collapsed race category***/
		if raceeth="White" then
			raceeth_col="White";
		else raceeth_col="Other";
	Run;

	/*@Action: create RSF file*/
	Data Include_EHR_RSF&year_loop.&month_loop.;
		set orig.RSF_EHR0 (rename=(age=age_num af=year ag=month aj=encnters_last2yr cb=census_tract bs=encts_total ab=Sex0 ad=birthcohort
			ah=age ah_alt=agec0 ak=bmi ao=sysbp aq=dbp as=LDL at=triglc au=HbA1c ca=diab_dx bb=smoking bk=HTN_ESP
			by=HTN_dx av=prediab aw=diab_t1 ax=diab_t2 ay=insulin az=metformin ba=flu_vac bc=asthma
			ethnicity=ethnicity0 race=race0));
			
		/*@Action: subset to specific month and year*/
		where year=&year_loop. and month=&month_loop.;
		
		/*@Action: create a contatonated month and year;*/
		format month_year yymm.;
		month_year=input(catx('-',month,year),ANYDTDTE.);
		
		/*@Action: create formatted variables and convert some variables from character to numeric or vice versa*/
		length partner $4. agec agec_col sex raceeth raceeth2 raceeth_col prmpay $50.;
		partner="RSF";
		encnters_last1yr=input(ai,8.);
		pregnant=input(am,8.);
		diab_gest=input(an,8.);
		ASCVD=input(bx,8.);
		zip=substr(ae, 1,5);

		/*Action: create a hypertension flag*/
		If HTN_ESP = . Then
			FLG_HTN=0;
		Else FLG_HTN=1;

		/*@Action: Define no encounters flag ***/
		if encnters_last2yr=. then
			no_enctr2yr=1;
		else no_enctr2yr=0;

		if encnters_last2yr=. then
			_cat_enctr=0;
		else if encnters_last2yr>=1 & encnters_last2yr<=2 then
			_cat_enctr=1;
		else if encnters_last2yr>=3 & encnters_last2yr<=4 then
			_cat_enctr=2;
		else if encnters_last2yr>=5 & encnters_last2yr<=8 then
			_cat_enctr=3;
		else if encnters_last2yr>=9 & encnters_last2yr<=19 then
			_cat_enctr=4;
		else if encnters_last2yr>19 & encnters_last2yr ne . then
			_cat_enctr=5;

		/*@Action: Create 0/1 flag for having a bp in the past2 years***/
		bp2yr = 0;

		if prior1bp > 0 then
			bp2yr = 1;
		else  if prior2bp > 0 then
			bp2yr = 1;

		/*@Action: Create 0/1 flag for HTN flag***/
		if HTN_ESP ne . and HTN_ESP in (1,4,5) then
			htnyn = 1;
		else if HTN_ESP ne . and HTN_ESP in (2,3) then
			htnyn = 0;
		else if HTN_ESP ne . and HTN_ESP=0 then
			htnyn = .;

		/*@Action: Create 0/1 flag for HTN dx and controlled***/
		if htn_dx in (1,2,3) then
			htndx = 1;
		else if htn_dx = . then
			htndx = .;
		else htndx = 0;

		if htn_dx=1 then
			htnc1 = 1;
		else if htn_dx in (.,0) then
			htnc1 = .;
		else htnc1 = 0;

		/*@Action: Create 0/1 flag for HTN controll original***/
		if HTN_ESP ne . and HTN_ESP in (1) then
			htnc= 1;
		else if HTN_ESP ne . and HTN_ESP in (4,5) then
			htnc= 0;
		else if HTN_ESP ne . and HTN_ESP in (0,2,3) then
			htnc= .;
		else htnc= .;

		/*@Action: Update race ethnicity values for raking***/
		if ethnicity0=1 then
			raceeth="Other";
		else if ethnicity0=2 and race0=1 then
			raceeth="White";
		else if ethnicity0=2 and race0=2 then
			raceeth="Other";
		else if ethnicity0=2 and race0=3 then
			raceeth="Black";
		else if ethnicity0=2 and race0=4 then
			raceeth="Other";
		else if ethnicity0=2 and race0=5 then
			raceeth="Unspecified";
		else if ethnicity0=2 and race0=6 then
			raceeth="Other";
		else if ethnicity0=2 and race0=7 then
			raceeth="Other";
		else raceeth="Missing";

		/*@Action: Update race ethnicity values for report***/
		if ethnicity0=1 then
			raceeth2="Hispanic";
		else if ethnicity0=2 and race0=1 then
			raceeth2="White";
		else if ethnicity0=2 and race0=2 then
			raceeth2="Asian";
		else if ethnicity0=2 and race0=3 then
			raceeth2="Black";
		else if ethnicity0=2 and race0=4 then
			raceeth2="Other";
		else if ethnicity0=2 and race0=5 then
			raceeth2="Unspecified";
		else if ethnicity0=2 and race0=6 then
			raceeth2="American Indian or Alaska Native";
		else if ethnicity0=2 and race0=7 then
			raceeth2="Native Hawaiian or Other Pacific Islander";
		else raceeth2="Missing";

		/*@Action: Change primary payer to character***/
		if bz=0 then
			prmpay="Unknown_other_self-pay";
		else if bz=1 then
			prmpay="Bluecross_Commercial";
		else if bz=2 then
			prmpay="Workers_comp_Auto";
		else if bz=3 then
			prmpay="Medicaid";
		else if bz=4 then
			prmpay="Medicare";
		else prmpay="Unknown_other_self-pay";

		/*@Action: Change age category to character***/
		if agec0=1 then
			agec="0-4";
		else if agec0=2 then
			agec="5-9";
		else if agec0=3 then
			agec="10-14";
		else if agec0=4 then
			agec="15-19";
		else if agec0=5 then
			agec="20-24";
		else if agec0=6 then
			agec="25-29";
		else if agec0=7 then
			agec="30-34";
		else if agec0=8 then
			agec="35-44";
		else if agec0=9 then
			agec="45-54";
		else if agec0=10 then
			agec="55-64";
		else if agec0=11 then
			agec="65-74";
		else if agec0=12 then
			agec="75-84";
		else if agec0=13 then
			agec="85+";

		/*@Action: Change collapsed age category to character***/
		if agec0 in (5,6,7,8) then
			agec_col="20-44";
		else if agec0 in (9,10) then
			agec_col="45-64";
		else if agec0 in (11,12) then
			agec_col="65-84";

		/*@Action: Change sex to character***/
		if sex0=1 then
			Sex="Male";
		else if sex0=2 then
			Sex="Female";

		/*@Action: Update collapsed race category***/
		if raceeth="White" then
			raceeth_col="White";
		else raceeth_col="Other";
	Run;

	/*@Action: create LPHI file*/
	Data Include_EHR_LPHI&year_loop.&month_loop.;
		set orig.LPHI_EHR0&year_loop._&month_loop. (rename=(zip=ae ethnicity=ethnicity0 new_race=race0 age=agenum sex=sex0 age_group2=agec0 prmpayer=bz));
		
		/*@Action: subset to specific month and year*/
		where year=&year_loop. and month=&month_loop.;
		
		/*@Action: create a contatonated month and year;*/
		format month_year yymm.;
		month_year=input(catx('-',month,year),ANYDTDTE.);
		
		/*@Action: create formatted variables and convert some variables from character to numeric or vice versa*/
		length partner $4. agec agec_col sex raceeth raceeth2 raceeth_col prmpay $50.;
		partner="LPHI";
		encnters_last1yr=input(ai,8.);
		pregnant=input(am,8.);
		diab_gest=input(an,8.);
		ASCVD=input(bx,8.);
		zip=substr(ae, 1,5);

		/*Action: create a hypertension flag*/
		If HTN_ESP = . Then
			FLG_HTN=0;
		Else FLG_HTN=1;

		/*@Action: Define no encounters flag ***/
		if encnters_last2yr=. then
			no_enctr2yr=1;
		else no_enctr2yr=0;

		if encnters_last2yr=. then
			_cat_enctr=0;
		else if encnters_last2yr>=1 & encnters_last2yr<=2 then
			_cat_enctr=1;
		else if encnters_last2yr>=3 & encnters_last2yr<=4 then
			_cat_enctr=2;
		else if encnters_last2yr>=5 & encnters_last2yr<=8 then
			_cat_enctr=3;
		else if encnters_last2yr>=9 & encnters_last2yr<=19 then
			_cat_enctr=4;
		else if encnters_last2yr>19 & encnters_last2yr ne . then
			_cat_enctr=5;

		/*@Action: Create 0/1 flag for having a bp in the past2 years***/
		bp2yr = 0;

		if prior1bp > 0 then
			bp2yr = 1;
		else  if prior2bp > 0 then
			bp2yr = 1;

		/*@Action: Create 0/1 flag for HTN flag***/
		if HTN_ESP ne . and HTN_ESP in (1,4,5) then
			htnyn = 1;
		else if HTN_ESP ne . and HTN_ESP in (2,3) then
			htnyn = 0;
		else if HTN_ESP ne . and HTN_ESP=0 then
			htnyn = .;

		/*@Action: Create 0/1 flag for HTN dx and controlled***/
		if htn_dx in (1,2,3) then
			htndx = 1;
		else if htn_dx = . then
			htndx = .;
		else htndx = 0;

		if htn_dx=1 then
			htnc1 = 1;
		else if htn_dx in (.,0) then
			htnc1 = .;
		else htnc1 = 0;

		/*@Action: Create 0/1 flag for HTN controll original***/
		if HTN_ESP ne . and HTN_ESP in (1) then
			htnc= 1;
		else if HTN_ESP ne . and HTN_ESP in (4,5) then
			htnc= 0;
		else if HTN_ESP ne . and HTN_ESP in (0,2,3) then
			htnc= .;
		else htnc= .;

		/*@Action: Update race ethnicity values for raking***/
		if ethnicity0=1 then
			raceeth="Other";
		else if ethnicity0=2 and race0=1 then
			raceeth="White";
		else if ethnicity0=2 and race0=2 then
			raceeth="Other";
		else if ethnicity0=2 and race0=3 then
			raceeth="Black";
		else if ethnicity0=2 and race0=4 then
			raceeth="Other";
		else if ethnicity0=2 and race0=5 then
			raceeth="Unspecified";
		else if ethnicity0=2 and race0=6 then
			raceeth="Other";
		else if ethnicity0=2 and race0=7 then
			raceeth="Other";
		else raceeth="Missing";

		/*@Action: Update race ethnicity values for report***/
		if ethnicity0=1 then
			raceeth2="Hispanic";
		else if ethnicity0=2 and race0=1 then
			raceeth2="White";
		else if ethnicity0=2 and race0=2 then
			raceeth2="Asian";
		else if ethnicity0=2 and race0=3 then
			raceeth2="Black";
		else if ethnicity0=2 and race0=4 then
			raceeth2="Other";
		else if ethnicity0=2 and race0=5 then
			raceeth2="Unspecified";
		else if ethnicity0=2 and race0=6 then
			raceeth2="American Indian or Alaska Native";
		else if ethnicity0=2 and race0=7 then
			raceeth2="Native Hawaiian or Other Pacific Islander";
		else raceeth2="Missing";

		/*@Action: Change primary payer to character***/
		if bz=0 then
			prmpay="Unknown_other_self-pay";
		else if bz=1 then
			prmpay="Bluecross_Commercial";
		else if bz=2 then
			prmpay="Workers_comp_Auto";
		else if bz=3 then
			prmpay="Medicaid";
		else if bz=4 then
			prmpay="Medicare";
		else prmpay="Unknown_other_self-pay";

		/*@Action: Change age category to character***/
		if agec0=1 then
			agec="0-4";
		else if agec0=2 then
			agec="5-9";
		else if agec0=3 then
			agec="10-14";
		else if agec0=4 then
			agec="15-19";
		else if agec0=5 then
			agec="20-24";
		else if agec0=6 then
			agec="25-29";
		else if agec0=7 then
			agec="30-34";
		else if agec0=8 then
			agec="35-44";
		else if agec0=9 then
			agec="45-54";
		else if agec0=10 then
			agec="55-64";
		else if agec0=11 then
			agec="65-74";
		else if agec0=12 then
			agec="75-84";
		else if agec0=13 then
			agec="85+";

		/*@Action: Change collapsed age category to character***/
		if agec0 in (5,6,7,8) then
			agec_col="20-44";
		else if agec0 in (9,10) then
			agec_col="45-64";
		else if agec0 in (11,12) then
			agec_col="65-84";

		/*@Action: Change sex to character***/
		if sex0=1 then
			Sex="Male";
		else if sex0=2 then
			Sex="Female";

		/*@Action: Update collapsed race category***/
		if raceeth="White" then
			raceeth_col="White";
		else raceeth_col="Other";
		drop encnters_last2yr_ m year_month all ai;
	Run;

	/*@Action: check variables*/
	proc freq data=Include_EHR_AC&year_loop.&month_loop.;
		table year*month*partner
			race0*ethnicity0*raceeth*raceeth2*raceeth_col
			sex0*Sex
			agec0*agec/list missing;
	run;

	proc freq data=Include_EHR_RSF&year_loop.&month_loop.;
		table year*month*partner
			race0*ethnicity0*raceeth*raceeth2*raceeth_col
			sex0*Sex
			agec0*agec/list missing;
	run;

	proc freq data=Include_EHR_HDC&year_loop.&month_loop.;
		table year*month*partner
			race0*ethnicity0*raceeth*raceeth2*raceeth_col
			sex0*Sex
			agec0*agec/list missing;
	run;

	proc freq data=Include_EHR_LPHI&year_loop.&month_loop.;
		table year*month*partner
			race0*ethnicity0*raceeth*raceeth2*raceeth_col
			sex0*Sex
			agec0*agec/list missing;
	run;

	/*@Action: Perform various clean-up to the EHR file ***/
	data include_ehr&year_loop.&month_loop.01;
		set Include_EHR_AC&year_loop.&month_loop. (keep=partner aa_seq ZIP month_year year month encnters_last2yr encts_total census_tract 
													allpriorbp prior2bp prior1bp encnters_last1yr FLG_HTN pregnant 
													diab_gest prediab diab_t1 diab_t2 insulin metformin 
													flu_vac asthma
													agec0 agec agec_col sex0 Sex race0 ethnicity0 raceeth raceeth2 raceeth_col
													birthcohort bmi LDL triglc HbA1c smoking ASCVD diab_dx dbp sysbp prmpay
													HTN_ESP HTN_dx no_enctr2yr _cat_enctr bp2yr htnyn htndx htnc1 htnc)
			Include_EHR_RSF&year_loop.&month_loop. (keep=partner aa_seq ZIP month_year year month encnters_last2yr encts_total census_tract 
													allpriorbp prior2bp prior1bp encnters_last1yr FLG_HTN pregnant 
													diab_gest prediab diab_t1 diab_t2 insulin metformin 
													flu_vac asthma
													agec0 agec agec_col sex0 Sex race0 ethnicity0 raceeth raceeth2 raceeth_col
													birthcohort bmi LDL triglc HbA1c smoking ASCVD diab_dx dbp sysbp prmpay
													HTN_ESP HTN_dx no_enctr2yr _cat_enctr bp2yr htnyn htndx htnc1 htnc)
			Include_EHR_HDC&year_loop.&month_loop. (keep=partner aa_seq ZIP month_year year month encnters_last2yr encts_total census_tract 
													allpriorbp prior2bp prior1bp encnters_last1yr FLG_HTN pregnant 
													diab_gest prediab diab_t1 diab_t2 insulin metformin 
													flu_vac asthma
													agec0 agec agec_col sex0 Sex race0 ethnicity0 raceeth raceeth2 raceeth_col
													birthcohort bmi LDL triglc HbA1c smoking ASCVD diab_dx dbp sysbp prmpay
													HTN_ESP HTN_dx no_enctr2yr _cat_enctr bp2yr htnyn htndx htnc1 htnc)
			Include_EHR_LPHI&year_loop.&month_loop. (keep=partner aa_seq ZIP month_year year month encnters_last2yr encts_total census_tract 
													allpriorbp prior2bp prior1bp encnters_last1yr FLG_HTN pregnant 
													diab_gest prediab diab_t1 diab_t2 insulin metformin 
													flu_vac asthma
													agec0 agec agec_col sex0 Sex race0 ethnicity0 raceeth raceeth2 raceeth_col
													birthcohort bmi LDL triglc HbA1c smoking ASCVD diab_dx dbp sysbp prmpay
													HTN_ESP HTN_dx no_enctr2yr _cat_enctr bp2yr htnyn htndx htnc1 htnc);
	Run;

	/*@Action: Sort Crosswalk and EHR datasets and merge, flag counties that don't match or have a residential ratio of 0***/
	proc sql;
		create table Include_EHR&year_loop.&month_loop.02 as 
			select a.*
				, b.ru
				, b.ru2
				, b.FIPS_STATE_COUNTY
				, b.RES_RATIO
				, case
					when b.FIPS_STATE_COUNTY is null or b.RES_RATIO in (.,0) then 1
					else 0
				end as bad_geo_county
			from include_ehr&year_loop.&month_loop.01 as a 
				left join zip_xwalk as b
					on a.zip=b.zip;
	quit;

	/*@Action: Create new state variables*/
	Data Include_EHR_Pre&year_loop.&month_loop.0;
		set include_ehr&year_loop.&month_loop.02;
		Length census_Region $12.;
		
		state_fips=substr(fips_state_county,1,2);
		COUNTY_FIPS=substr(FIPS_STATE_COUNTY,3,3);

		if State_FIPS in ('01','02','04','05','06','08','09','10','11','12','13','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32','33','34','35','36','37','38','39','40','41','42','44','45','46','47','48','49','50','51','53','54','55','56');

		/*@Action: create NHANES And census region***/
		if State_FIPS in ('09','23','25','33','44','50','34','36','42') then
			census_region="Northwest";
		else if State_FIPS in ('18','17','26','39','55','19','31','20','38','27','46','29') then
			census_region="Midwest";
		else if State_FIPS in ('10','11','12','13','24','37','45','51','54','01','21','28','47','05','22','40','48') then
			census_region="South";
		else if State_FIPS in ('04','08','16','35','30','49','32','56','02','06','15','41','53') then
			census_region="West";

		if State_FIPS in ('04','06','15','25','33','36','41','49','50','53') then
			nhanes='1';
		else if State_FIPS in ('08','09','10','12','16','23','27','30','32','34','35','42','44') then
			nhanes='2';
		else if State_FIPS in ('02','11','13','17','19','24','26','31','38','40','46','48','51','55','56') then
			nhanes='3';
		else if State_FIPS in ('01','05','18','20','21','22','28','29','37','39','45','47','54') then
			nhanes='4';
	run;

	/*@Action: check additional variables*/
	proc freq data=Include_EHR_Pre&year_loop.&month_loop.0;
		table year*month*partner partner*state_fips/list missing;
	run;

	/*@Action: clean work folder*/
	proc datasets library=work nolist;
		delete Include_EHR_AC&year_loop.&month_loop. Include_EHR_RSF&year_loop.&month_loop. Include_EHR_LPHI&year_loop.&month_loop. include_ehr&year_loop.&month_loop.01 Include_EHR&year_loop.&month_loop.02;
	run;

	quit;

	/*@Action: Check for bad geography in EHR data, defined valid ZIP codes ***/
	/*@Action: import ZIP to ZCTA crosswalk***/
	PROC IMPORT DATAFILE= "P:\9778\Common\PUF_Data\crosswalks\ZIP_ZCTA_Crosswalk_2023.xlsx" 
		OUT= WORK.ZiptoZCTA0
		DBMS=XLSX
		REPLACE;
		SHEET="Sheet1";
		GETNAMES=YES;
	RUN;

	proc sort data=ziptozcta0 out=zip_list (keep=zip);
		by zip;
		where zip ne "";
	run;

	Proc Sort data=Include_EHR_Pre&year_loop.&month_loop.0;
		by zip;
	Quit;

	Data sasin.EHR_for_Excl&year_loop.&month_loop.;
		Merge Include_EHR_Pre&year_loop.&month_loop.0(In=A) zip_list(In=B);
		By zip;

		If A;

		If A and ^(B) then
			Bad_Geo=1;
		Else Bad_Geo=0;

		if ru="" then
			delete;
	Run;

	/*@Action: check variables*/
	proc freq data=sasin.EHR_for_Excl&year_loop.&month_loop.;
		table partner*(agec0 no_enctr2yr bp2yr sex0 race0 pregnant bad_geo) year*month*partner/list missing;
	run;

	/*@Action: Exclude records with bad geography or out of scope (i.e. younger than 20 or older than 84, or missing HTN information for all years) ***/
	data Pre_Processed_MENDS&year_loop.&month_loop.;
		set sasin.EHR_for_Excl&year_loop.&month_loop.;

		/*@Action: Remove >84 and <20 ***/
		if agec0<5 or agec0>12 then
			delete;

		/*@Action: Remove no encounters in 2 years ***/
		if no_enctr2yr=1 then
			delete;

		/*@Action: Remove no BP measurement in 2 years ***/
		if bp2yr=0 then
			delete;

		/*@Action: Remove unknown sex ***/
		if sex0=. then
			delete;

		/*@Action: Remove unknown race **/
		if raceeth in ("Unspecified","Missing") then
			delete;

		/*@Action: Remove pregnant males ***/
		if pregnant=1 and sex0=1 then
			delete;

		/*@Action: Remove pregnant females ***/
		if pregnant=1 and sex0=2 then
			delete;

		/*@Action: remove bad geographies***/
		if bad_geo=1 then
			delete;
	run;

	/*@Action: check variables*/
	proc freq data=Pre_Processed_MENDS&year_loop.&month_loop.;
		table year*month*partner/list missing;
	run;
	
	/*@Action: create the distinct variables by zip*/
	proc sql;
		create table sasin.Pre_Processed_MENDS_ZIP&year_loop.&month_loop. as
			select distinct partner
				, aa_seq
				, State_FIPS
				, census_region
				, nhanes
				, ru
				, ru2
				, ZIP
				, month_year
				, year
				, month
				, encnters_last2yr
				, encts_total
				, census_tract
				, allpriorbp
				, prior2bp
				, prior1bp
				, encnters_last1yr
				, FLG_HTN
				, pregnant
				, diab_gest
				, prediab
				, diab_t1
				, diab_t2
				, insulin
				, metformin
				, flu_vac
				, asthma
				, agec0
				, agec
				, agec_col
				, sex0
				, Sex
				, race0
				, ethnicity0
				, raceeth
				, raceeth2
				, raceeth_col
				, birthcohort
				, bmi
				, LDL
				, triglc
				, HbA1c
				, smoking
				, ASCVD
				, diab_dx
				, dbp
				, sysbp
				, prmpay
				, HTN_ESP
				, HTN_dx
				, no_enctr2yr
				, _cat_enctr
				, bp2yr
				, htnyn
				, htndx
				, htnc1
				, htnc
				, Bad_Geo
			from Pre_Processed_MENDS&year_loop.&month_loop.;
	quit;

	/*@Action: clean work folder*/
	Proc Datasets Library=WORK NOLIST;
		delete Sorted_ACS_zcta Include_EHR_Pre&year_loop.&month_loop.0 
				Include_EHR_Pre&year_loop.&month_loop.1 Pre_Processed_MENDS&year_loop.&month_loop.;
		run;
	Quit;

%mend;

/*@Program End ***/