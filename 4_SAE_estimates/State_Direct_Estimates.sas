
/* This program generates the state-level direct estimates, crude estimates, sample size, and CV */

proc datasets library=work kill;
run;
quit;

libname weights "P:\A335\SensitiveData\Summarized Results\03 - May 2026\2_Output\2_Estimates\20260508 Run\weights\state\HTN";

data crosswalk;
	set "P:\A335\Common\PUF_Data\Other\state_crosswalk.sas7bdat";
run;

proc sort data = crosswalk;
	by state_fips;
run;
 
/* State direct estimates */

%macro report(ext, mmyy, out);

data state_weights;
	set weights.&ext (keep = aa_seq rakewgt zip state state_fips pph htnyn htnc);
length year_month $7.;
year_month = &mmyy;

run;

proc freq data = state_weights;
	table pph * htnyn * htnc / list missing;
run;

proc freq data = state_weights noprint;
	where htnyn in("0","1");
	table year_month * STATE_FIPS * htnyn / list missing outpct out = model1 
						(keep = year_month STATE_FIPS htnyn pct_row);
	weight rakewgt;
run;

proc freq data = state_weights noprint;
	where htnc in("0","1");
	table year_month * STATE_FIPS * htnc / list missing outpct out = model2 
						(keep = year_month STATE_FIPS htnc pct_row);
	weight rakewgt;
run;

proc freq data = state_weights noprint;
	where htnyn in("0","1");
	table year_month * STATE_FIPS * htnyn / list missing outpct out = crude1 
						(keep = year_month STATE_FIPS htnyn pct_row);
run;

proc freq data = state_weights noprint;
	where htnc in("0","1");
	table year_month * STATE_FIPS * htnc / list missing outpct out = crude2
						(keep = year_month STATE_FIPS htnc pct_row);
run;

proc summary data = state_weights nway noprint;
	where htnyn in("0","1");
  class year_month STATE_FIPS;
   var rakewgt;
   output
      out = samp1 (drop = _:)
      N = N_SAMP CV = CV;
run;

data samp1a;
	set samp1 (in=ina) samp1 (in=inb);

length Condition $5.;
Condition = "HTN";

length est_type $7.;
if ina then est_type = "crude";
else if inb then est_type = "modeled";

run;

proc summary data = state_weights nway noprint;
	where htnc in("0","1");
  class year_month STATE_FIPS;
   var rakewgt;
   output
      out = samp2 (drop = _:)
      N = N_SAMP CV = CV;
run;

data samp2a;
	set samp2 (in=ina) samp2 (in=inb);

length Condition $5.;
Condition = "HTN-C";

length est_type $7.;
if ina then est_type = "crude";
else if inb then est_type = "modeled";

run;

data htnyn;
	set crude1 (in=ina rename=pct_row=prevalence) model1 (in=inb rename=pct_row=prevalence);

if htnyn = "1";
drop htnyn;

length est_type $7.;
if ina then est_type = "crude";
else if inb then est_type = "modeled";
run;

data htnc;
	set crude2 (in=ina rename=pct_row=prevalence) model2 (in=inb rename=pct_row=prevalence);

if htnc = "1";
drop htnc;

length est_type $7.;
if ina then est_type = "crude";
else if inb then est_type = "modeled";
run;

proc sort data = htnyn; by year_month est_type STATE_FIPS; run;
proc sort data = samp1a; by year_month est_type STATE_FIPS; run;

data htnyn;
	merge htnyn samp1a;
by year_month est_type STATE_FIPS;

if prevalence = . then prevalence = 0;
if CV = . then CV = 0;

if est_type = "crude" then se = 100*sqrt((prevalence/100)*(1-prevalence/100)/N_SAMP);

run;

proc sort data = htnc; by year_month est_type STATE_FIPS; run;
proc sort data = samp2a; by year_month est_type STATE_FIPS; run;

data htnc;
	merge htnc samp2a;
by year_month est_type STATE_FIPS;

if prevalence = . then prevalence = 0;
if CV = . then CV = 0;

if est_type = "crude" then se = 100*sqrt((prevalence/100)*(1-prevalence/100)/N_SAMP);

run;

data &out;
	set htnyn htnc;
run;

proc sort data = &out;	by state_fips; run;

data &out;
	merge &out (in=ina) crosswalk;
by state_fips;
if ina;
run;

proc sort data = &out; by condition est_type state_fips; run;

proc summary data = &out nway print n nmiss sum mean cv min median max;
  class condition est_type;
   var prevalence se CV N_SAMP;
run;

%mend;

%report(ext=wgt_htn_state_201901, mmyy="2019-01", out=jan_2019);
%report(ext=wgt_htn_state_201902, mmyy="2019-02", out=feb_2019);
%report(ext=wgt_htn_state_201903, mmyy="2019-03", out=mar_2019);
%report(ext=wgt_htn_state_201904, mmyy="2019-04", out=apr_2019);
%report(ext=wgt_htn_state_201905, mmyy="2019-05", out=may_2019);
%report(ext=wgt_htn_state_201906, mmyy="2019-06", out=jun_2019);
%report(ext=wgt_htn_state_201907, mmyy="2019-07", out=jul_2019);
%report(ext=wgt_htn_state_201908, mmyy="2019-08", out=aug_2019);
%report(ext=wgt_htn_state_201909, mmyy="2019-09", out=sep_2019);
%report(ext=wgt_htn_state_201910, mmyy="2019-10", out=oct_2019);
%report(ext=wgt_htn_state_201911, mmyy="2019-11", out=nov_2019);
%report(ext=wgt_htn_state_201912, mmyy="2019-12", out=dec_2019);

%report(ext=wgt_htn_state_202001, mmyy="2020-01", out=jan_2020);
%report(ext=wgt_htn_state_202002, mmyy="2020-02", out=feb_2020);
%report(ext=wgt_htn_state_202003, mmyy="2020-03", out=mar_2020);
%report(ext=wgt_htn_state_202004, mmyy="2020-04", out=apr_2020);
%report(ext=wgt_htn_state_202005, mmyy="2020-05", out=may_2020);
%report(ext=wgt_htn_state_202006, mmyy="2020-06", out=jun_2020);
%report(ext=wgt_htn_state_202007, mmyy="2020-07", out=jul_2020);
%report(ext=wgt_htn_state_202008, mmyy="2020-08", out=aug_2020);
%report(ext=wgt_htn_state_202009, mmyy="2020-09", out=sep_2020);
%report(ext=wgt_htn_state_202010, mmyy="2020-10", out=oct_2020);
%report(ext=wgt_htn_state_202011, mmyy="2020-11", out=nov_2020);
%report(ext=wgt_htn_state_202012, mmyy="2020-12", out=dec_2020);

%report(ext=wgt_htn_state_202101, mmyy="2021-01", out=jan_2021);
%report(ext=wgt_htn_state_202102, mmyy="2021-02", out=feb_2021);
%report(ext=wgt_htn_state_202103, mmyy="2021-03", out=mar_2021);
%report(ext=wgt_htn_state_202104, mmyy="2021-04", out=apr_2021);
%report(ext=wgt_htn_state_202105, mmyy="2021-05", out=may_2021);
%report(ext=wgt_htn_state_202106, mmyy="2021-06", out=jun_2021);
%report(ext=wgt_htn_state_202107, mmyy="2021-07", out=jul_2021);
%report(ext=wgt_htn_state_202108, mmyy="2021-08", out=aug_2021);
%report(ext=wgt_htn_state_202109, mmyy="2021-09", out=sep_2021);
%report(ext=wgt_htn_state_202110, mmyy="2021-10", out=oct_2021);
%report(ext=wgt_htn_state_202111, mmyy="2021-11", out=nov_2021);
%report(ext=wgt_htn_state_202112, mmyy="2021-12", out=dec_2021);

%report(ext=wgt_htn_state_202201, mmyy="2022-01", out=jan_2022);
%report(ext=wgt_htn_state_202202, mmyy="2022-02", out=feb_2022);
%report(ext=wgt_htn_state_202203, mmyy="2022-03", out=mar_2022);
%report(ext=wgt_htn_state_202204, mmyy="2022-04", out=apr_2022);
%report(ext=wgt_htn_state_202205, mmyy="2022-05", out=may_2022);
%report(ext=wgt_htn_state_202206, mmyy="2022-06", out=jun_2022);
%report(ext=wgt_htn_state_202207, mmyy="2022-07", out=jul_2022);
%report(ext=wgt_htn_state_202208, mmyy="2022-08", out=aug_2022);
%report(ext=wgt_htn_state_202209, mmyy="2022-09", out=sep_2022);
%report(ext=wgt_htn_state_202210, mmyy="2022-10", out=oct_2022);
%report(ext=wgt_htn_state_202211, mmyy="2022-11", out=nov_2022);
%report(ext=wgt_htn_state_202212, mmyy="2022-12", out=dec_2022);

%report(ext=wgt_htn_state_202301, mmyy="2023-01", out=jan_2023);
%report(ext=wgt_htn_state_202302, mmyy="2023-02", out=feb_2023);
%report(ext=wgt_htn_state_202303, mmyy="2023-03", out=mar_2023);
%report(ext=wgt_htn_state_202304, mmyy="2023-04", out=apr_2023);
%report(ext=wgt_htn_state_202305, mmyy="2023-05", out=may_2023);
%report(ext=wgt_htn_state_202306, mmyy="2023-06", out=jun_2023);
%report(ext=wgt_htn_state_202307, mmyy="2023-07", out=jul_2023);
%report(ext=wgt_htn_state_202308, mmyy="2023-08", out=aug_2023);
%report(ext=wgt_htn_state_202309, mmyy="2023-09", out=sep_2023);
%report(ext=wgt_htn_state_202310, mmyy="2023-10", out=oct_2023);
%report(ext=wgt_htn_state_202311, mmyy="2023-11", out=nov_2023);
%report(ext=wgt_htn_state_202312, mmyy="2023-12", out=dec_2023);

%report(ext=wgt_htn_state_202401, mmyy="2024-01", out=jan_2024);
%report(ext=wgt_htn_state_202402, mmyy="2024-02", out=feb_2024);
%report(ext=wgt_htn_state_202403, mmyy="2024-03", out=mar_2024);
%report(ext=wgt_htn_state_202404, mmyy="2024-04", out=apr_2024);
%report(ext=wgt_htn_state_202405, mmyy="2024-05", out=may_2024);
%report(ext=wgt_htn_state_202406, mmyy="2024-06", out=jun_2024);
%report(ext=wgt_htn_state_202407, mmyy="2024-07", out=jul_2024);
%report(ext=wgt_htn_state_202408, mmyy="2024-08", out=aug_2024);
%report(ext=wgt_htn_state_202409, mmyy="2024-09", out=sep_2024);
%report(ext=wgt_htn_state_202410, mmyy="2024-10", out=oct_2024);
%report(ext=wgt_htn_state_202411, mmyy="2024-11", out=nov_2024);
%report(ext=wgt_htn_state_202412, mmyy="2024-12", out=dec_2024);

%report(ext=wgt_htn_state_202501, mmyy="2025-01", out=jan_2025);
%report(ext=wgt_htn_state_202502, mmyy="2025-02", out=feb_2025);
%report(ext=wgt_htn_state_202503, mmyy="2025-03", out=mar_2025);
%report(ext=wgt_htn_state_202504, mmyy="2025-04", out=apr_2025);
%report(ext=wgt_htn_state_202505, mmyy="2025-05", out=may_2025);
%report(ext=wgt_htn_state_202506, mmyy="2025-06", out=jun_2025);
%report(ext=wgt_htn_state_202507, mmyy="2025-07", out=jul_2025);
%report(ext=wgt_htn_state_202508, mmyy="2025-08", out=aug_2025);
%report(ext=wgt_htn_state_202509, mmyy="2025-09", out=sep_2025);
%report(ext=wgt_htn_state_202510, mmyy="2025-10", out=oct_2025);

data estimates;
	set
jan_2019 feb_2019 mar_2019 apr_2019 may_2019 jun_2019 jul_2019 aug_2019 sep_2019 oct_2019 nov_2019 dec_2019
jan_2020 feb_2020 mar_2020 apr_2020 may_2020 jun_2020 jul_2020 aug_2020 sep_2020 oct_2020 nov_2020 dec_2020
jan_2021 feb_2021 mar_2021 apr_2021 may_2021 jun_2021 jul_2021 aug_2021 sep_2021 oct_2021 nov_2021 dec_2021
jan_2022 feb_2022 mar_2022 apr_2022 may_2022 jun_2022 jul_2022 aug_2022 sep_2022 oct_2022 nov_2022 dec_2022
jan_2023 feb_2023 mar_2023 apr_2023 may_2023 jun_2023 jul_2023 aug_2023 sep_2023 oct_2023 nov_2023 dec_2023
jan_2024 feb_2024 mar_2024 apr_2024 may_2024 jun_2024 jul_2024 aug_2024 sep_2024 oct_2024 nov_2024 dec_2024
jan_2025 feb_2025 mar_2025 apr_2025 may_2025 jun_2025 jul_2025 aug_2025 sep_2025 oct_2025
	;
run;

proc export data = estimates
			outfile = "P:\A335\Common\SAE\Q3\HTN\Direct Estimates\State_Direct_Estimates.xlsx"
			dbms = excel replace;
run;
