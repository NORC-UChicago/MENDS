/*@Note: Execute Raking macro to perform weighting using ACS as source of control totals 					 ***/
%MACRO RAKING
			(inds=, 	/* input data set */
			outds=, 	/* output data set */
			inwt=, 		/* weight to be raked */
			freqlist=,	/* List of data sets with marginal freqs or marginal control totals	  */
			/* they must contain name of raking variable and either variable 	  */
			/* PERCENT or MRGTOTAL, e.g. direct counts of marginal control totals;*/
			/* by default it is assigned names of raking variables 				  */
			outwt=, 	/* resulting raked weight */
			byvar=, 	/* variable BY which user might want to set up raking. By default, raking is done */
			/* over the whole input data set 												  */
			varlist=, 	/* list of variables to be raked on */
			numvar=, 	/* number of raking variables */
			cntotal=, 	/* general control total; it is required if freqlist data sets contains PERCENT; */
			/* if byvar not empty, cntotal must be present for each byvar 					 */
			trmprec=1,  /* tolerance, default is 1 */
			numiter=50);/* number of iterations, default is 50*/
	/*@Action: Macro to check on required parameters 			   ***/
	/*@Note: If any required are missing, algorithm will terminate ***/
	%macro reqpar (param);
		%if (&&&param eq ) %then
			%do;
				%Let Covergence_Pass=0;
				%put **** Program terminated: Macro parameter %upcase(&PARAM.) missing ****;
				%GOTO exit;
			%end;

	%exit:
	%mend;

	/*@Action: Check each of the required parameters for inputs ***/
	%reqpar(inds) %reqpar(outds) %reqpar (inwt)
	%reqpar(outwt) %reqpar(varlist)
	%reqpar(numvar) %reqpar(trmprec) %reqpar(numiter)

	/*@Action: Create global macro variable CONVERGENCE_PASS ***/
	%Global COVERGENCE_PASS;

	/*@Action: Perform edits on macro inputs (UPCASE and GETOPTION) ***/
	%let varlist=%upcase(&varlist.);
	%let byvar=%upcase(&byvar.);
	%let ls=%sysfunc(getoption(ls,keyword));
	%let ps=%sysfunc(getoption(ps,keyword));

	/*@Action: Check number of raking variables 										 ***/
	/*@Note: If number in the list does not match NUMVAR input, algorithm will terminate ***/
	%if (%scan(&varlist., &numvar.) eq ) or (%scan(&varlist., %eval(&numvar.+1)) ne ) %then
		%do;
			%Let Covergence_Pass=0;
			%put **** Program terminated: Number of variables in the VARLIST ****;
			%put **** does not match NUMVAR ****;
			%GOTO exit;
		%end;

	/*@Action: Copy input dataset and rename intake weight variable to WEIGHT ***/
	data __i0;
		set &inds.;
		weight=&inwt.;
	run;

	/*@Action: Loop through number of desired iterations ***/
	%do i=1 %to &numiter.;

		/*@Action: Set cumuative termination flag to 0 (prior to iterating) ***/
		%let sumterm = 0;

		/*@Action: Loop through each of the raking variables ***/
		%do j=1 %to &numvar.;

			/*@Action: Create new macro variables for raking variable and marginal control total table name ***/
			%let varrake= %scan(&varlist., &j.);

			%if (&freqlist. ne ) %then
				%let dsfreq=%scan(&freqlist., &j.);
			%else %let dsfreq=&varrake.;

			/*@Action: Sort input dataset by raking variable ***/
			proc sort data=__i0;
				by &varrake.;
			run;

			/*@Action: Compute weighted summary totals for current raking variable ***/
			proc summary nway data=__i0;
				class &varrake.;
				var weight;
				output out=__i1(drop=_type_ _freq_) sum=sum&j.;
			run;

			/*@Action: Merge input summary totals with marginal control totals ***/
			/*@Note: Tables are being merged on current raking variable 	   ***/
			data __i0;
				merge __i0(in=_1) __i1 &dsfreq.(in=_2);
				by &varrake.;

				/*@Action: If first iteration, perform additional failure checks ***/
				%if &i.=1 %then
					%do;
						/*@Action: Check for mismatch of variables, set flag=1 if found ***/
						if (_1 and ^_2) or (_2 and ^_1) then
							do;
								call symput('match','1');
								stop;
							end;
						else call symput('match','2');

						/*@Action: If marginal totals are present then set flag=1 ***/
						if mrgtotal ne . then
							call symput('mrg','1');
						else call symput('mrg','2');

						/*@Action: If percentages are present then set flag=1 ***/
						if percent ne . then
							call symput ('pct','1');
						else call symput('pct','2');
					%end;
			run;

			/*@Action: If first iteration, proceed with this section of code ***/
			/*@Note: This section tests input values in the merged table	 ***/
			%if &i.=1 %then
				%do;
					/*@Action: If mismatch found, algorithm will terminate ***/
					%if &match=1 %then
						%do;
							%Let Covergence_Pass=0;
							%put **** Program terminated: levels of variable &varrake. do not match ****;
							%put ****in sample and marginal totals data sets ****;
							%GOTO exit;
						%end;

					/*@Action: If PERCENT=1 and CNTOTAL missing, algorithm will terminate ***/
					%if &pct = 1 and (&cntotal eq ) %then
						%do;
							%Let Covergence_Pass=0;
							%put ** Program terminated: PERCENT is not missing and CNTOTAL is missing **;
							%put ** for raking variable &varrake. **;
							%GOTO exit;
						%end;

					/*@Action: If PERCENT and COUNT totals are not=1, algorithm will terminate ***/
					%else %if &pct=2 and &mrg=2 %then
						%do;
							%Let Covergence_Pass=0;
							%put **** Program terminated: Both PERCENT and MRGTOTAL are missing ****;
							%GOTO exit;
						%end;
				%end;

			/*@Action: Perform raking routine on merged table ***/
			data __i0;
				set __i0;

				/*@Action: If CNTTOTAL is not missing(provided by user) ***/
				%if (&cntotal. ne ) %then
					%do;
						/*@Note: Marginal totals provided as control totals ***/
						if mrgtotal ne . then
							cntmarg=mrgtotal;
					%end;

				/*@Action: If CNTOTAL is missing (not provided by user) ***/
				%else
					%do;
						/*@Note: Marginal totals (counts) provided as control totals ***/
						if mrgtotal ne . then
							cntmarg=mrgtotal;
					%end;

				/*@Action: Update weight (Weight is multiplied by marginal control total divided by weighted sample sum) ***/
				weight=weight*cntmarg/sum&j.;
				drop mrgtotal;
			run;

			/*@Action: Compute the difference between the marginal control total and weighted sample sum ***/
			data __i2(keep=&varrake. sum&j. cntmarg differ);
				set __i0;
				by &varrake;

				if first.&varrake.;
				differ=cntmarg-sum&j.;
			run;

			/*@Action: Print diagnostic results of raking ***/
			proc print label data=__i2;
				/*@Action: Print titles based on whether BYVAR was used ***/
				%if (&byvar. ne) %then
					%do;
						title3 "Raking &byvar - &s by &varrake, iteration - &i";
					%end;
				%else
					%do;
						title3 "Raking by &varrake, iteration - &i ";
					%end;

				/*@Action: Print the following variables and assign corresponding labels ***/
				sum sum&j. cntmarg;
				label sum&j.  ='Calculated margin'
					differ  ='Difference'
					cntmarg ='Margin Control Total';
			run;

			/*@Action: Check differ amount to determine if more iterations needed ***/
			data __i2;
				set __i2 end=eof;

				/*@Action: Set COMM to 0 and retain throughout file ***/
				retain comm 0;

				/*@Action: If absolute value of differ is greater then tolerance, set COMM=1 ***/
				if abs(differ)>&trmprec. then
					comm=1;

				/*@Action: If at end of file COMM=1, continue to next iteration ***/
				if eof and comm=1 then
					call symput("term&j.",'2');

				/*@Action: Otherwise converence has been met and breakout of iteration ***/
				else if eof then
					call symput("term&j.",'1');
			run;

			/*@Action: Update SUMTERM by adding previous SUMTERM with new TERM value ***/
			%let sumterm=%eval(&sumterm.+&&term&j);
		%end;

		/*@Action: Print diagnostic information to log ***/
		data __i0;
			set __i0;
			drop sum1-sum&numvar.;

			/*@Action: Print diagnostics based on whether BYVAR was used ***/
			%if (&byvar ne ) %then
				%put &byvar.=&s. iteration=&i. numvar=&numvar. sumterm=&sumterm.;
			%else %put numvar=&numvar. sumterm=&sumterm.;

			/*@Action: Check whether convergence has been achieved 				***/
			/*@Note: Either at end of current iteration or end of max iteration ***/
			%if &sumterm.=&numvar. or &i.=&numiter. %then
				%do;
					/*@Action: Print statement to log based on whether BYVAR was used ***/
					%if (&byvar. ne ) %then
						%put **** Terminated &byvar &s at &i-th iteration;
					%else %put *** Task terminated at &i-th iteration ****;
					title3 ' ';

					/*@Action: Write additional diagnostics, based on convergence, to listing/log ***/
		data _null_;
			set __i0;

			if _n_=1;
			file print &ps. &ls.;
			put ' ';

			/*@Action: Follow this path when convergence achieved ***/
			%if &sumterm.=&numvar. %then
				%do;
					%Let Covergence_Pass=1;

					/*@Action: Print specific text based on whether BYVAR was used ***/
					%if (&byvar. ne ) %then
						%do;
							put "**** Program for &byvar. &s. terminated at iteration &i. because all calculated margins";
						%end;
					%else
						%do;
							put "**** Program terminated at iteration &i. because all calculated margins";
						%end;

					put "differ from Marginal Control Totals by less than &trmprec.";
		run;

				%end;

			/*@Action: Follow this path when convergence was not achieved ***/
			%else
				%do;
					%Let Covergence_Pass=0;

					/*@Action: Print specific text based on whether BYVAR was used ***/
					%if (&byvar. ne ) %then
						%do;
							put "**** Program for &byvar. &s. terminated at iteration &i.";
						%end;
					%else
						%do;
							put "**** Program terminated at iteration &i.";
						%end;

					put "**** No convergence achieved";
					run;

				%end;

			/*@Action: Write final raking weight to output table ***/
			data &outds(drop=cntmarg);
				set __i0;
				rename weight=&outwt.;
				%let i=&numiter.;
			Run;

				%end;
	%end;

	/*@Action: Delete temporary datasets used in raking process ***/
	proc datasets library=work nolist mt=data;
		delete __i0 __i1 __i2;

		** purge work data;
	quit;

	/*@Action: Jump to EXIT ***/
	%GOTO exit;

	%exit:
%mend;