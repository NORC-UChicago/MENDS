
/* This program generates the ZIP Code-level direct estimates, crude estimates, sample size, and CV */

proc datasets library=work kill;
run;
quit;


libname weights "P:\A154\SensitiveData\Summarized Results\01 - Jan 2025\2_Output\2_Estimates\20250613 Run\weights\state";	
 
/* ZIP direct estimates */

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
	table zip * state_fips * state / list out = crosswalk;
run;
proc freq data = state_weights noprint;
	where htnyn in("0","1");
	table year_month * ZIP * htnyn / list missing outpct out = model1 
						(keep = year_month ZIP htnyn pct_row);
	weight rakewgt;
run;

proc freq data = state_weights noprint;
	where htnc in("0","1");
	table year_month * ZIP * htnc / list missing outpct out = model2 
						(keep = year_month ZIP htnc pct_row);
	weight rakewgt;
run;

proc freq data = state_weights noprint;
	where htnyn in("0","1");
	table year_month * ZIP * htnyn / list missing outpct out = crude1 
						(keep = year_month ZIP htnyn pct_row);
run;

proc freq data = state_weights noprint;
	where htnc in("0","1");
	table year_month * ZIP * htnc / list missing outpct out = crude2
						(keep = year_month ZIP htnc pct_row);
run;

proc summary data = state_weights nway noprint;
	where htnyn in("0","1");
  class year_month ZIP;
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
  class year_month ZIP;
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

proc sort data = htnyn; by year_month est_type ZIP; run;
proc sort data = samp1a; by year_month est_type ZIP; run;

data htnyn;
	merge htnyn samp1a;
by year_month est_type ZIP;

if prevalence = . then prevalence = 0;
if CV = . then CV = 0;

if est_type = "crude" then se = 100*sqrt((prevalence/100)*(1-prevalence/100)/N_SAMP);

run;

proc sort data = htnc; by year_month est_type ZIP; run;
proc sort data = samp2a; by year_month est_type ZIP; run;

data htnc;
	merge htnc samp2a;
by year_month est_type ZIP;

if prevalence = . then prevalence = 0;
if CV = . then CV = 0;

if est_type = "crude" then se = 100*sqrt((prevalence/100)*(1-prevalence/100)/N_SAMP);

run;

data &out;
	set htnyn htnc;
*if N_SAMP >= 5; /* Limit to ZIP Codes with 5+ patients */
run;

proc sort data = &out;	by ZIP; run;

data &out;
	merge &out (in=ina) crosswalk (keep = ZIP state_fips);
by ZIP;
if ina;
run;

proc sort data = &out; by condition est_type ZIP; run;

proc summary data = &out nway print n nmiss sum mean cv min median max;
  class condition est_type;
   var prevalence se CV N_SAMP;
run;

%mend;

%report(ext=wgt_alt2_state_20191, mmyy="2019-01", out=jan_2019);
%report(ext=wgt_alt2_state_20192, mmyy="2019-02", out=feb_2019);
%report(ext=wgt_alt2_state_20193, mmyy="2019-03", out=mar_2019);
%report(ext=wgt_alt2_state_20194, mmyy="2019-04", out=apr_2019);
%report(ext=wgt_alt2_state_20195, mmyy="2019-05", out=may_2019);
%report(ext=wgt_alt2_state_20196, mmyy="2019-06", out=jun_2019);
%report(ext=wgt_alt2_state_20197, mmyy="2019-07", out=jul_2019);
%report(ext=wgt_alt2_state_20198, mmyy="2019-08", out=aug_2019);
%report(ext=wgt_alt2_state_20199, mmyy="2019-09", out=sep_2019);
%report(ext=wgt_alt2_state_201910, mmyy="2019-10", out=oct_2019);
%report(ext=wgt_alt2_state_201911, mmyy="2019-11", out=nov_2019);
%report(ext=wgt_alt2_state_201912, mmyy="2019-12", out=dec_2019);

%report(ext=wgt_alt2_state_20201, mmyy="2020-01", out=jan_2020);
%report(ext=wgt_alt2_state_20202, mmyy="2020-02", out=feb_2020);
%report(ext=wgt_alt2_state_20203, mmyy="2020-03", out=mar_2020);
%report(ext=wgt_alt2_state_20204, mmyy="2020-04", out=apr_2020);
%report(ext=wgt_alt2_state_20205, mmyy="2020-05", out=may_2020);
%report(ext=wgt_alt2_state_20206, mmyy="2020-06", out=jun_2020);
%report(ext=wgt_alt2_state_20207, mmyy="2020-07", out=jul_2020);
%report(ext=wgt_alt2_state_20208, mmyy="2020-08", out=aug_2020);
%report(ext=wgt_alt2_state_20209, mmyy="2020-09", out=sep_2020);
%report(ext=wgt_alt2_state_202010, mmyy="2020-10", out=oct_2020);
%report(ext=wgt_alt2_state_202011, mmyy="2020-11", out=nov_2020);
%report(ext=wgt_alt2_state_202012, mmyy="2020-12", out=dec_2020);

%report(ext=wgt_alt2_state_20211, mmyy="2021-01", out=jan_2021);
%report(ext=wgt_alt2_state_20212, mmyy="2021-02", out=feb_2021);
%report(ext=wgt_alt2_state_20213, mmyy="2021-03", out=mar_2021);
%report(ext=wgt_alt2_state_20214, mmyy="2021-04", out=apr_2021);
%report(ext=wgt_alt2_state_20215, mmyy="2021-05", out=may_2021);
%report(ext=wgt_alt2_state_20216, mmyy="2021-06", out=jun_2021);
%report(ext=wgt_alt2_state_20217, mmyy="2021-07", out=jul_2021);
%report(ext=wgt_alt2_state_20218, mmyy="2021-08", out=aug_2021);
%report(ext=wgt_alt2_state_20219, mmyy="2021-09", out=sep_2021);
%report(ext=wgt_alt2_state_202110, mmyy="2021-10", out=oct_2021);
%report(ext=wgt_alt2_state_202111, mmyy="2021-11", out=nov_2021);
%report(ext=wgt_alt2_state_202112, mmyy="2021-12", out=dec_2021);

%report(ext=wgt_alt2_state_20221, mmyy="2022-01", out=jan_2022);
%report(ext=wgt_alt2_state_20222, mmyy="2022-02", out=feb_2022);
%report(ext=wgt_alt2_state_20223, mmyy="2022-03", out=mar_2022);
%report(ext=wgt_alt2_state_20224, mmyy="2022-04", out=apr_2022);
%report(ext=wgt_alt2_state_20225, mmyy="2022-05", out=may_2022);
%report(ext=wgt_alt2_state_20226, mmyy="2022-06", out=jun_2022);
%report(ext=wgt_alt2_state_20227, mmyy="2022-07", out=jul_2022);
%report(ext=wgt_alt2_state_20228, mmyy="2022-08", out=aug_2022);
%report(ext=wgt_alt2_state_20229, mmyy="2022-09", out=sep_2022);
%report(ext=wgt_alt2_state_202210, mmyy="2022-10", out=oct_2022);
%report(ext=wgt_alt2_state_202211, mmyy="2022-11", out=nov_2022);
%report(ext=wgt_alt2_state_202212, mmyy="2022-12", out=dec_2022);

%report(ext=wgt_alt2_state_20231, mmyy="2023-01", out=jan_2023);
%report(ext=wgt_alt2_state_20232, mmyy="2023-02", out=feb_2023);
%report(ext=wgt_alt2_state_20233, mmyy="2023-03", out=mar_2023);
%report(ext=wgt_alt2_state_20234, mmyy="2023-04", out=apr_2023);
%report(ext=wgt_alt2_state_20235, mmyy="2023-05", out=may_2023);
%report(ext=wgt_alt2_state_20236, mmyy="2023-06", out=jun_2023);
%report(ext=wgt_alt2_state_20237, mmyy="2023-07", out=jul_2023);
%report(ext=wgt_alt2_state_20238, mmyy="2023-08", out=aug_2023);
%report(ext=wgt_alt2_state_20239, mmyy="2023-09", out=sep_2023);
%report(ext=wgt_alt2_state_202310, mmyy="2023-10", out=oct_2023);
%report(ext=wgt_alt2_state_202311, mmyy="2023-11", out=nov_2023);
%report(ext=wgt_alt2_state_202312, mmyy="2023-12", out=dec_2023);

%report(ext=wgt_alt2_state_20241, mmyy="2024-01", out=jan_2024);
%report(ext=wgt_alt2_state_20242, mmyy="2024-02", out=feb_2024);
%report(ext=wgt_alt2_state_20243, mmyy="2024-03", out=mar_2024);

data estimates;
	set
jan_2019 feb_2019 mar_2019 apr_2019 may_2019 jun_2019 jul_2019 aug_2019 sep_2019 oct_2019 nov_2019 dec_2019
jan_2020 feb_2020 mar_2020 apr_2020 may_2020 jun_2020 jul_2020 aug_2020 sep_2020 oct_2020 nov_2020 dec_2020
jan_2021 feb_2021 mar_2021 apr_2021 may_2021 jun_2021 jul_2021 aug_2021 sep_2021 oct_2021 nov_2021 dec_2021
jan_2022 feb_2022 mar_2022 apr_2022 may_2022 jun_2022 jul_2022 aug_2022 sep_2022 oct_2022 nov_2022 dec_2022
jan_2023 feb_2023 mar_2023 apr_2023 may_2023 jun_2023 jul_2023 aug_2023 sep_2023 oct_2023 nov_2023 dec_2023
jan_2024 feb_2024 mar_2024 
	;
if substr(year_month,1,4) in("2019","2020") then file_flag = 1;
else if substr(year_month,1,4) in("2021","2022") then file_flag = 2;
else if substr(year_month,1,4) in("2023","2024") then file_flag = 3;

run;

/* Export as a CSV file */

proc export data=estimates (drop = file_flag)
outfile="P:\A154\Common\SAE\Q1\Direct Estimates\ZIP_Direct_Estimates.csv"
dbms=csv
replace;
run;

/* Export as an excel file */

proc export data = estimates (where=(est_type="modeled" & file_flag = 1))
			outfile = "P:\A154\Common\SAE\Q1\Direct Estimates\ZIP_Direct_Estimates.xlsx"
			dbms = excel replace;
			sheet = "modeled 2019-2020";
run;

proc export data = estimates (where=(est_type="crude" & file_flag = 1))
			outfile = "P:\A154\Common\SAE\Q1\Direct Estimates\ZIP_Direct_Estimates.xlsx"
			dbms = excel replace;
			sheet = "crude 2019-2020";
run;

proc export data = estimates (where=(est_type="modeled" & file_flag = 2))
			outfile = "P:\A154\Common\SAE\Q1\Direct Estimates\ZIP_Direct_Estimates.xlsx"
			dbms = excel replace;
			sheet = "modeled 2021-2022";
run;

proc export data = estimates (where=(est_type="crude" & file_flag = 2))
			outfile = "P:\A154\Common\SAE\Q1\Direct Estimates\ZIP_Direct_Estimates.xlsx"
			dbms = excel replace;
			sheet = "crude 2021-2022";
run;

proc export data = estimates (where=(est_type="modeled" & file_flag = 3))
			outfile = "P:\A154\Common\SAE\Q1\Direct Estimates\ZIP_Direct_Estimates.xlsx"
			dbms = excel replace;
			sheet = "modeled 2023-2024";
run;

proc export data = estimates (where=(est_type="crude" & file_flag = 3))
			outfile = "P:\A154\Common\SAE\Q1\Direct Estimates\ZIP_Direct_Estimates.xlsx"
			dbms = excel replace;
			sheet = "crude 2023-2024";
run;
