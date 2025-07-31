%macro updatefile();
	%if &national_est.=Y %then
		%do;

			Data EHR_for_Excl&year_loop.&month_loop.;
				set orig.all_partner&year_loop.&month_loop. (rename=(zip_code=ae ethnicity=ethnicity0 new_race=race0 age=agenum sex=sex0 age_group=agec0 prmpayer=bz pph=pph0));
				format month_year yymm.;
				month_year=input(catx('-',month,year),ANYDTDTE.);
				length agec agec_col agecat agecat8 agecat3 ru2 sex raceeth raceeth2 raceeth3 raceeth4 raceeth_col prmpay $50. Region $12.;
				state_fips=substr(fips_state_county,1,2);
				state=state_fips;
				COUNTY_FIPS=substr(FIPS_STATE_COUNTY,3,3);
				county=FIPS_STATE_COUNTY;
				zip=substr(ae, 1,5);

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
				/*@Note: update to assume that bp2yr=1 if pph in (0,1,2)***/
				bp2yr = 0;

				if pph0 in (0,1,2) then
					bp2yr = 1;

				/*@Action: chaaracter varabiale for pph*/
				if pph0=. then
					pph="";
				else if pph0=0 then
					pph="0";
				else if pph0=1 then
					pph="1";
				else if pph0=2 then
					pph="2";

				/*@Action: Create 0/1 flag for HTN flag***/
				if pph0=. then
					htnyn="";
				else if pph0=0 then
					htnyn="0";
				else if pph0 in (1, 2) then
					htnyn="1";

				/*@Action: Create 0/1 flag for HTN dx and controlled***/
				if pph0 in (., 0) then
					htnc="";
				else if pph0=1 then
					htnc="1";
				else if pph0=2 then
					htnc="0";

				/*@Action: Create 0/1 flag for HTN flag***/
				if HTN_ESP ne . and HTN_ESP in (1,4,5) then
					htnyn_orig = "1";
				else if HTN_ESP ne . and HTN_ESP in (2,3) then
					htnyn_orig = "0";
				else if HTN_ESP ne . and HTN_ESP=0 then
					htnyn_orig = "";

				/*@Action: Create 0/1 flag for HTN dx and controlled***/
				if htn_dx in (1,2,3) then
					htndx_orig  = "1";
				else if htn_dx = . then
					htndx_orig = "";
				else htndx_orig = "0";

				if htn_dx=1 then
					htnc1_orig = "1";
				else if htn_dx in (.,0) then
					htnc1_orig = "";
				else htnc1_orig = "0";

				/*@Action: Create 0/1 flag for HTN control original***/
				if HTN_ESP ne . and HTN_ESP in (1) then
					htnc_orig= "1";
				else if HTN_ESP ne . and HTN_ESP in (4,5) then
					htnc_orig= "0";
				else if HTN_ESP ne . and HTN_ESP in (0,2,3) then
					htnc_orig= "";
				else htnc_orig= "";

				/*@Action: Update all race ethnicity values for all categories***/
				/*@Action: Update race ethnicity values for report***/
				/*@Action: Update race ethnicity values 4 categories***/
				/*@Action: Update race ethnicity values 3 categories***/
				if ethnicity0=1 then
					do;
						raceeth="Other";
						raceeth2="Hispanic";
						raceeth4="Hispanic";
						raceeth3="Other";
					end;
				else if ethnicity0 in (2,0,.) then
					do;
						if race0=1 then
							do;
								raceeth="White";
								raceeth2="White";
								raceeth4="White";
								raceeth3="White";
							end;
						else if race0=2 then
							do;
								raceeth="Other";
								raceeth2="Asian";
								raceeth4="Other";
								raceeth3="Other";
							end;
						else if race0=3 then
							do;
								raceeth="Black";
								raceeth2="Black";
								raceeth4="Black";
								raceeth3="Black";
							end;
						else if race0=4 then
							do;
								raceeth="Other";
								raceeth2="Other";
								raceeth4="Other";
								raceeth3="Other";
							end;
						else if race0=5 then
							do;
								raceeth="Unspecified";
								raceeth2="Unspecified";
								raceeth4="Unspecified";
								raceeth3="Unspecified";
							end;
						else if race0=6 then
							do;
								raceeth="Other";
								raceeth2="American Indian or Alaska Native";
								raceeth4="Other";
								raceeth3="Other";
							end;
						else if race0=7 then
							do;
								raceeth="Other";
								raceeth2="Native Hawaiian or Other Pacific Islander";
								raceeth4="Other";
								raceeth3="Other";
							end;
						else
							do;
								raceeth="Missing";
								raceeth2="Missing";
								raceeth4="Other";
								raceeth3="Other";
							end;
					end;

				/*@Action: Update collapsed race category***/
				if raceeth="White" then
					raceeth_col="White";

				if raceeth="Unspecified" then
					raceeth_col="Unspecified";

				if raceeth="" then
					raceeth_col="";
				else raceeth_col="Other";

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

				/*@Action: Change primary payer to character***/
				if bz=3 then
					prmpay2="Medicaid";
				else prmpay2="Other";

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

				/*@Action: Change age category to 8 categories***/
				if agec0=5 then
					agecat8="20-24";
				else if agec0=6 then
					agecat8="25-29";
				else if agec0=7 then
					agecat8="30-34";
				else if agec0=8 then
					agecat8="35-44";
				else if agec0=9 then
					agecat8="45-54";
				else if agec0=10 then
					agecat8="55-64";
				else if agec0=11 then
					agecat8="65-74";
				else if agec0=12 then
					agecat8="75-84";

				/*@Action: Change age category to 3 categories***/
				if agec0 in (5, 6, 7, 8) then
					agecat3="20-44";
				else if agec0 in (9, 10) then
					agecat3="45-64";
				else if agec0 in (11, 12) then
					agecat3="65-84";

				/*@Action: Change sex to character***/
				if sex0=1 then
					Sex="Male";
				else if sex0=2 then
					Sex="Female";

				/*@Action: subset to valid states***/
				if State_FIPS in ('01','02','04','05','06','08','09','10','11','12','13','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32','33','34','35','36','37','38','39','40','41','42','44','45','46','47','48','49','50','51','53','54','55','56');

				/*@Action: create NHANES And census region***/
				if State_FIPS in ('09','23','25','33','44','50','34','36','42') then
					region="Northeast";
				else if State_FIPS in ('18','17','26','39','55','19','31','20','38','27','46','29') then
					region="Midwest";
				else if State_FIPS in ('10','11','12','13','24','37','45','51','54','01','21','28','47','05','22','40','48') then
					region="South";
				else if State_FIPS in ('04','08','16','35','30','49','32','56','02','06','15','41','53') then
					region="West";

				if State_FIPS in ('04','06','15','25','33','36','41','49','50','53') then
					nhanes='1';
				else if State_FIPS in ('08','09','10','12','16','23','27','30','32','34','35','42','44') then
					nhanes='2';
				else if State_FIPS in ('02','11','13','17','19','24','26','31','38','40','46','48','51','55','56') then
					nhanes='3';
				else if State_FIPS in ('01','05','18','20','21','22','28','29','37','39','45','47','54') then
					nhanes='4';

				if 1<=ruca1<=3 then
					ru2='Mostly urban';
				else if 4<=ruca1<=10 then
					ru2='Mostly or completely rural';
					
				if region="" then delete;
				if ru2="" then delete;
				if ethnicity0=. then delete;
			run;

			data include_ehr&year_loop.&month_loop.;
				set orig.include_ehr&year_loop.&month_loop.;

				/*@Action: subset to valid states***/
				if State_FIPS in ('01','02','04','05','06','08','09','10','11','12','13','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32','33','34','35','36','37','38','39','40','41','42','44','45','46','47','48','49','50','51','53','54','55','56');
					
				if region="" then delete;
				if ru2="" then delete;
				if ethnicity0=. then delete;
			run;

		%end;
	%else %if &national_est.=N %then
		%do;

			Data EHR_for_Excl&year_loop.&month_loop.;
				set orig.all_partner&year_loop.&month_loop. (rename=(zip_code=ae ethnicity=ethnicity0 new_race=race0 age=agenum sex=sex0 age_group=agec0 prmpayer=bz pph=pph0));
				format month_year yymm.;
				month_year=input(catx('-',month,year),ANYDTDTE.);
				length agec agec_col agecat agecat8 agecat3 ru2 sex raceeth raceeth2 raceeth3 raceeth4 raceeth_col prmpay $50. Region $12.;
				state_fips=substr(fips_state_county,1,2);
				state=state_fips;
				COUNTY_FIPS=substr(FIPS_STATE_COUNTY,3,3);
				county=FIPS_STATE_COUNTY;
				zip=substr(ae, 1,5);

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
				/*@Note: update to assume that bp2yr=1 if pph in (0,1,2)***/
				bp2yr = 0;

				if pph0 in (0,1,2) then
					bp2yr = 1;

				/*@Action: chaaracter varabiale for pph*/
				if pph0=. then
					pph="";
				else if pph0=0 then
					pph="0";
				else if pph0=1 then
					pph="1";
				else if pph0=2 then
					pph="2";

				/*@Action: Create 0/1 flag for HTN flag***/
				if pph0=. then
					htnyn="";
				else if pph0=0 then
					htnyn="0";
				else if pph0 in (1, 2) then
					htnyn="1";

				/*@Action: Create 0/1 flag for HTN dx and controlled***/
				if pph0 in (., 0) then
					htnc="";
				else if pph0=1 then
					htnc="1";
				else if pph0=2 then
					htnc="0";

				/*@Action: Create 0/1 flag for HTN flag***/
				if HTN_ESP ne . and HTN_ESP in (1,4,5) then
					htnyn_orig = "1";
				else if HTN_ESP ne . and HTN_ESP in (2,3) then
					htnyn_orig = "0";
				else if HTN_ESP ne . and HTN_ESP=0 then
					htnyn_orig = "";

				/*@Action: Create 0/1 flag for HTN dx and controlled***/
				if htn_dx in (1,2,3) then
					htndx_orig  = "1";
				else if htn_dx = . then
					htndx_orig = "";
				else htndx_orig = "0";

				if htn_dx=1 then
					htnc1_orig = "1";
				else if htn_dx in (.,0) then
					htnc1_orig = "";
				else htnc1_orig = "0";

				/*@Action: Create 0/1 flag for HTN control original***/
				if HTN_ESP ne . and HTN_ESP in (1) then
					htnc_orig= "1";
				else if HTN_ESP ne . and HTN_ESP in (4,5) then
					htnc_orig= "0";
				else if HTN_ESP ne . and HTN_ESP in (0,2,3) then
					htnc_orig= "";
				else htnc_orig= "";

				/*@Action: Update all race ethnicity values for all categories***/
				/*@Action: Update race ethnicity values for report***/
				/*@Action: Update race ethnicity values 4 categories***/
				/*@Action: Update race ethnicity values 3 categories***/
				if ethnicity0=1 then
					do;
						raceeth="Other";
						raceeth2="Hispanic";
						raceeth4="Hispanic";
						raceeth3="Other";
					end;
				else if ethnicity0 in (2,0,.) then
					do;
						if race0=1 then
							do;
								raceeth="White";
								raceeth2="White";
								raceeth4="White";
								raceeth3="White";
							end;
						else if race0=2 then
							do;
								raceeth="Other";
								raceeth2="Asian";
								raceeth4="Other";
								raceeth3="Other";
							end;
						else if race0=3 then
							do;
								raceeth="Black";
								raceeth2="Black";
								raceeth4="Black";
								raceeth3="Black";
							end;
						else if race0=4 then
							do;
								raceeth="Other";
								raceeth2="Other";
								raceeth4="Other";
								raceeth3="Other";
							end;
						else if race0=5 then
							do;
								raceeth="Unspecified";
								raceeth2="Unspecified";
								raceeth4="Unspecified";
								raceeth3="Unspecified";
							end;
						else if race0=6 then
							do;
								raceeth="Other";
								raceeth2="American Indian or Alaska Native";
								raceeth4="Other";
								raceeth3="Other";
							end;
						else if race0=7 then
							do;
								raceeth="Other";
								raceeth2="Native Hawaiian or Other Pacific Islander";
								raceeth4="Other";
								raceeth3="Other";
							end;
						else
							do;
								raceeth="Missing";
								raceeth2="Missing";
								raceeth4="Other";
								raceeth3="Other";
							end;
					end;

				/*@Action: Update collapsed race category***/
				if raceeth="White" then
					raceeth_col="White";

				if raceeth="Unspecified" then
					raceeth_col="Unspecified";

				if raceeth="" then
					raceeth_col="";
				else raceeth_col="Other";

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

				/*@Action: Change primary payer to character***/
				if bz=3 then
					prmpay2="Medicaid";
				else prmpay2="Other";

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

				/*@Action: Change age category to 8 categories***/
				if agec0=5 then
					agecat8="20-24";
				else if agec0=6 then
					agecat8="25-29";
				else if agec0=7 then
					agecat8="30-34";
				else if agec0=8 then
					agecat8="35-44";
				else if agec0=9 then
					agecat8="45-54";
				else if agec0=10 then
					agecat8="55-64";
				else if agec0=11 then
					agecat8="65-74";
				else if agec0=12 then
					agecat8="75-84";

				/*@Action: Change age category to 3 categories***/
				if agec0 in (5, 6, 7, 8) then
					agecat3="20-44";
				else if agec0 in (9, 10) then
					agecat3="45-64";
				else if agec0 in (11, 12) then
					agecat3="65-84";

				/*@Action: Change sex to character***/
				if sex0=1 then
					Sex="Male";
				else if sex0=2 then
					Sex="Female";

				/*@Action: subset to discussed states***/
				if State_FIPS in (&statelist.);

				/*@Action: create NHANES And census region***/
				if State_FIPS in ('09','23','25','33','44','50','34','36','42') then
					region="Northeast";
				else if State_FIPS in ('18','17','26','39','55','19','31','20','38','27','46','29') then
					region="Midwest";
				else if State_FIPS in ('10','11','12','13','24','37','45','51','54','01','21','28','47','05','22','40','48') then
					region="South";
				else if State_FIPS in ('04','08','16','35','30','49','32','56','02','06','15','41','53') then
					region="West";

				if State_FIPS in ('04','06','15','25','33','36','41','49','50','53') then
					nhanes='1';
				else if State_FIPS in ('08','09','10','12','16','23','27','30','32','34','35','42','44') then
					nhanes='2';
				else if State_FIPS in ('02','11','13','17','19','24','26','31','38','40','46','48','51','55','56') then
					nhanes='3';
				else if State_FIPS in ('01','05','18','20','21','22','28','29','37','39','45','47','54') then
					nhanes='4';

				if 1<=ruca1<=3 then
					ru2='Mostly urban';
				else if 4<=ruca1<=10 then
					ru2='Mostly or completely rural';
					
				if region="" then delete;
				if ru2="" then delete;
				if ethnicity0=. then delete;
			run;

			data include_ehr&year_loop.&month_loop.;
				set orig.include_ehr&year_loop.&month_loop.;

				/*@Action: subset to discussed states***/
				if State_FIPS in (&statelist.);
					
				if region="" then delete;
				if ru2="" then delete;
				if ethnicity0=. then delete;
			run;

		%end;
%mend;

%macro exlcusions();
	%if &National_est.=Y %then
		%do;
			%Let ESTIMATE_LEVEL = NATIONAL;
			%let geo_level_var="NATIONAL";
		%end;
	%else %if &STATE_EST. = Y %then
		%do;
			%Let ESTIMATE_LEVEL = STATE;
			%let geo_level_var=state_fips;
		%end;
	%else %if &COUNTY_EST. = Y %then
		%do;
			%Let ESTIMATE_LEVEL = COUNTY;
			%let geo_level_var=FIPS_STATE_COUNTY;
		%end;
	%else %if &ZIP_EST. = Y %then
		%do;
			%Let ESTIMATE_LEVEL = ZIP;
			%let geo_level_var=zip;
		%end;

	/*@Action: exclusion count***/
	proc sql;
		create table excl_&estimate_level._&year_loop.&month_loop. as
			select distinct  "&estimate_level." as geographic_type
				, &geo_level_var. as geographic_level
				, catx("-", year, put(month,z2.)) as year_month
				, 1 as sort
				, "Total number of patients before exclusions" as exclusion length=300
				, count(*) as excl 
			from EHR_for_Excl&year_loop.&month_loop.
				where year=&year_loop.
					and month=&month_loop.
				group by geographic_level
					, year_month
					union
				select "&estimate_level." as geographic_type
					, &geo_level_var. as geographic_level
					, catx("-", year, put(month,z2.)) as year_month
					, 2 as sort
					, "Patients 19 and younger or 85 and older" as exclusion length=300
					, count(*) as excl 
				from EHR_for_Excl&year_loop.&month_loop.
					where year=&year_loop.
						and month=&month_loop.
						and (agec0<5 or agec0>12)
					group by year_month
						, geographic_level
						union
					select "&estimate_level." as geographic_type
						, &geo_level_var. as geographic_level
						, catx("-", year, put(month,z2.)) as year_month
						, 3 as sort
						, "Patients without an encounter in two years" as exclusion length=300
						, count(*) as excl 
					from EHR_for_Excl&year_loop.&month_loop.
						where year=&year_loop.
							and month=&month_loop.
							and no_enctr2yr=1
						group by year_month
							, geographic_level
							union
						select "&estimate_level." as geographic_type
							, &geo_level_var. as geographic_level
							, catx("-", year, put(month,z2.)) as year_month
							, 4 as sort
							, "Patients without an BP measurement in two years" as exclusion length=300
							, count(*) as excl 
						from EHR_for_Excl&year_loop.&month_loop.
							where year=&year_loop.
								and month=&month_loop.
								and bp2yr=0
							group by year_month
								, geographic_level
								union
							select "&estimate_level." as geographic_type
								, &geo_level_var. as geographic_level
								, catx("-", year, put(month,z2.)) as year_month
								, 5 as sort
								, "Patients with missing sex" as exclusion length=300
								, count(*) as excl 
							from EHR_for_Excl&year_loop.&month_loop.
								where year=&year_loop.
									and month=&month_loop.
									and sex0=.
								group by year_month
									, geographic_level
									union
								select "&estimate_level." as geographic_type
									, &geo_level_var. as geographic_level
									, catx("-", year, put(month,z2.)) as year_month
									, 6 as sort
									, "Patients with missing race" as exclusion length=300
									, count(*) as excl 
								from EHR_for_Excl&year_loop.&month_loop.
									where year=&year_loop.
										and month=&month_loop.
										and raceeth in ("Unspecified","Missing")
									group by year_month
										, geographic_level
										union
									select "&estimate_level." as geographic_type
										, &geo_level_var. as geographic_level
										, catx("-", year, put(month,z2.)) as year_month
										, 7 as sort
										, "Pregnant males" as exclusion length=300
										, case
											when count(*)=0 then 0
											else count(*) 
										end as excl 
									from EHR_for_Excl&year_loop.&month_loop.
										where year=&year_loop.
											and month=&month_loop.
											and pregnant=1
											and sex0=1
										group by year_month
											, geographic_level
											union
										select "&estimate_level." as geographic_type
											, &geo_level_var. as geographic_level
											, catx("-", year, put(month,z2.)) as year_month
											, 8 as sort
											, "Pregnant females" as exclusion length=300
											, count(*) as excl 
										from EHR_for_Excl&year_loop.&month_loop.
											where year=&year_loop.
												and month=&month_loop.
												and pregnant=1
												and sex0=2
											group by year_month
												, geographic_level
												union 
											select "&estimate_level." as geographic_type
												, &geo_level_var. as geographic_level
												, catx("-", year, put(month,z2.)) as year_month
												, 9 as sort
												, "Patients with invalid value for period prevalence hypertension algorithm" as exclusion length=300
												, count(*) as excl 
											from EHR_for_Excl&year_loop.&month_loop.
												where year=&year_loop. 
													and month=&month_loop.
													and pph not in ("0", "1", "2")
												group by geographic_level
													, year_month
													union 
												select "&estimate_level." as geographic_type
													, &geo_level_var. as geographic_level
													, catx("-", year, put(month,z2.)) as year_month
													, 10 as sort
													, "Total number of patients after exclusions" as exclusion length=300
													, count(*) as excl 
												from include_ehr&year_loop.&month_loop.
													where year=&year_loop. 
														and month=&month_loop.
													group by year_month
														, geographic_level
														union  
													select "&estimate_level." as geographic_type
														, &geo_level_var. as geographic_level
														, catx("-", year, put(month,z2.)) as year_month
														, 11 as sort
														, "Total number of patients after exclusions (with a value hypertension indicator)" as exclusion length=300
														, count(*) as excl 
													from include_ehr&year_loop.&month_loop.
														where year=&year_loop.
															and month=&month_loop.
															and htnyn ne ""
														group by year_month
															, geographic_level
															union 
														select "&estimate_level." as geographic_type
															, &geo_level_var. as geographic_level
															, catx("-", year, put(month,z2.)) as year_month
															, 12 as sort
															, "Total number of patients after exclusions (with a value hypertension control indicator)" as exclusion length=300
															, count(*) as excl 
														from include_ehr&year_loop.&month_loop.
															where year=&year_loop.
																and month=&month_loop.
																and htnc is not null
															group by year_month
																, geographic_level;
	quit;

	/*@action update the exclusions to include the perscentage of total*/
	proc sql;
		create table excl_denom_&estimate_level._&year_loop.&month_loop. as 
			select distinct year_month
				, geographic_level
				, excl as denom
			from excl_&estimate_level._&year_loop.&month_loop.
				where sort=1
					order by year_month
						, geographic_level;
	quit;

	proc sort data=excl_&estimate_level._&year_loop.&month_loop.;
		by year_month geographic_level;
	run;

	data excl_merge_&estimate_level._&year_loop.&month_loop. (drop=denom);
		merge excl_&estimate_level._&year_loop.&month_loop. excl_denom_&estimate_level._&year_loop.&month_loop.;
		by year_month geographic_level;
		percent=excl/denom;
	run;

	proc append data=excl_merge_&estimate_level._&year_loop.&month_loop. base=sasout.excl_&estimate_level.&START_YEAR.&START_MONTH._&END_YEAR.&END_MONTH. force;
	run;

	proc datasets library=work nolist;
		delete EHR_for_Excl&year_loop.&month_loop. excl_&estimate_level._&year_loop.&month_loop. excl_denom_&estimate_level._&year_loop.&month_loop. excl_merge_&estimate_level._&year_loop.&month_loop.;
	run;

	quit;

%mend;

/*@Program End ***/