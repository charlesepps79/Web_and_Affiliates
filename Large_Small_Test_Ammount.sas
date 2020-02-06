data _null_;
	call symput("REPORTS_TABLE",
		"WORK.ALL_APPS_DEC2019_0001");
run;

data REPORTS_TABLE_4;
	*** BranchNumber as string, checknumber as string ------------ ***;
	set &REPORTS_TABLE; 
	if length(SSN) lt 7 then SSN = cats(repeat('0',7-1-length(SSN)),SSN);
run;

DATA LOAN;
	SET dw.LOAN(
		KEEP = BRACCTNO NETLOANAMOUNT);
RUN;

PROC SORT 
	DATA = REPORTS_TABLE_4; 
	BY BRACCTNO; 
RUN;

PROC SORT 
	DATA = LOAN; 
	BY BRACCTNO; 
RUN;

DATA REPORTS_TABLE_5;
	MERGE REPORTS_TABLE_4(IN = x) LOAN(IN = y);
	BY BRACCTNO;
	IF x = 1;

	/*OG*/
	*DROP NETLOANAMOUNT;
	*RENAME TILA_LNAMT = NETLOANAMOUNT;
	/*OG*/
RUN;

DATA REPORTS_TABLE;
	SET REPORTS_TABLE_5;
	old_AmtPaidLast = SUM(old_AmtPaidLast, 0);
	renew_amt = 0;
	IF renew_bracctno NE "" THEN RENEW_FLAG = 1;
	ELSE RENEW_FLAG = 0;
	IF RENEW_FLAG = 1 THEN renew_amt = NETLOANAMOUNT - old_AmtPaidLast;
	NEW_AMT = 0;
	IF RENEW_FLAG = 0 THEN NEW_AMT = NETLOANAMOUNT;
	TOTALAPPS_CURRENT = 0;
	PREAPPROV_CURRENT = 0;
	BOOKED_CURRENT = 0;
	NETLOANAMT_CURRENT = 0;
	RENEW_AMT_CURRENT = 0;
	NEW_AMT_CURRENT = 0;
	OLD_AMTPAIDLAST_CURRENT = 0;
	TOTALAPPCOST_CURRENT = 0;
	TOTALLOANCOST_CURRENT = 0;
	RENEW_FLAG_CURRENT = 0;
	LARGE_BOOKED_CURRENT = 0;
	LARGE_NETLOANAMT_CURRENT = 0;
	LARGE_TOTALLOANCOST_CURRENT = 0;
	LARGE_TOTALAPPCOST_CURRENT = 0;
	LARGE_NEW_AMT_CURRENT = 0;
	LARGE_RENEW_AMT_CURRENT = 0;
	SMALL_BOOKED_CURRENT = 0;
	SMALL_NETLOANAMT_CURRENT = 0;
	SMALL_TOTALLOANCOST_CURRENT = 0;
	SMALL_TOTALAPPCOST_CURRENT = 0;
	SMALL_NEW_AMT_CURRENT = 0;
	SMALL_RENEW_AMT_CURRENT = 0;

	IF APPYRMONTH = 201912 THEN DO;
		TOTALAPPS_CURRENT = TOTALAPPS;
		PREAPPROV_CURRENT = PREAPPROVED_FLAG;
		TOTALAPPCOST_CURRENT = TOTALAPPCOST;
	END;

	IF ENTYRMONTH = 201912 THEN DO;
		BOOKED_CURRENT = BOOKED;
		NETLOANAMT_CURRENT = NETLOANAMOUNT;
		TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		RENEW_AMT_CURRENT = renew_amt;
		RENEW_FLAG_CURRENT = RENEW_FLAG;
		NEW_AMT_CURRENT = NEW_AMT;
		OLD_AMTPAIDLAST_CURRENT = OLD_AMTPAIDLAST;
	END;

	IF ENTYRMONTH = 201912 AND NETLOANAMOUNT > 2500 THEN DO;
		LARGE_BOOKED_CURRENT = BOOKED;
		LARGE_NETLOANAMT_CURRENT = NETLOANAMOUNT;
		LARGE_TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		LARGE_TOTALAPPCOST_CURRENT = TOTALAPPCOST_CURRENT;
		LARGE_NEW_AMT_CURRENT = NEW_AMT_CURRENT;
		LARGE_RENEW_AMT_CURRENT = RENEW_AMT_CURRENT;
	END;

	IF ENTYRMONTH = 201912 AND NETLOANAMOUNT <= 2500 THEN DO;
		SMALL_BOOKED_CURRENT = BOOKED;
		SMALL_NETLOANAMT_CURRENT = NETLOANAMOUNT;
		SMALL_TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		SMALL_TOTALAPPCOST_CURRENT = TOTALAPPCOST_CURRENT;
		SMALL_NEW_AMT_CURRENT = NEW_AMT_CURRENT;
		SMALL_RENEW_AMT_CURRENT = RENEW_AMT_CURRENT;
	END;
RUN;

*** Generate ALL_BY_SOURCE report -------------------------------- ***;
PROC SQL;
   CREATE TABLE ALL_BY_SOURCE AS 
   SELECT  
   		  /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* #PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
		  /* Large Booked */
            (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		  /* Small Booked */
            (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) 
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
		  /* $ Large Total Adv */
            (SUM(t1.LARGE_NETLOANAMT_CURRENT)) 
				FORMAT=DOLLAR8. AS '$ Large Total Adv'n,
		  /* $ Small Total Adv */
            (SUM(t1.SMALL_NETLOANAMT_CURRENT)) 
				FORMAT=DOLLAR8. AS '$ Small Total Adv'n,
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) 
				FORMAT=DOLLAR8. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ( (SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))
				FORMAT=DOLLAR8. AS '$ Net Adv'n, 
          /* avg adv */
            (( (SUM(t1.NEW_AMT_CURRENT)) + 
				(SUM(t1.RENEW_AMT_CURRENT))) / 
				(SUM(t1.BOOKED_CURRENT))) 
				FORMAT=DOLLAR8. AS 'avg adv'n,
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
				FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT))
				FORMAT=DOLLAR8. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) 
				FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
				(SUM(t1.TOTALAPPCOST_CURRENT))) 
				FORMAT=DOLLAR8. AS 'Total Cost'n, 
		  /* Large CPK */
            (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
                (SUM(t1.LARGE_TOTALAPPCOST_CURRENT))) / 
                ( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
                (SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
                FORMAT=DOLLAR8. AS Large_CPK,
		  /* Small CPK */
            (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
                (SUM(t1.SMALL_TOTALAPPCOST_CURRENT))) / 
                ( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
                (SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
                FORMAT=DOLLAR8. AS Small_CPK,
		  /* CPK */
            (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
				(SUM(t1.TOTALAPPCOST_CURRENT))) / 
				( (SUM(t1.NEW_AMT_CURRENT)) + 
            	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
				FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1;
QUIT;

PROC SQL;
   CREATE TABLE ALL_BY_ClassTranslation AS 
   SELECT t1.ClassTranslation, 
   		  /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* #PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
		  /* Large Booked */
            (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		  /* Small Booked */
            (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) 
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
		  /* $ Large Total Adv */
            (SUM(t1.LARGE_NETLOANAMT_CURRENT)) 
				FORMAT=DOLLAR8. AS '$ Large Total Adv'n,
		  /* $ Small Total Adv */
            (SUM(t1.SMALL_NETLOANAMT_CURRENT)) 
				FORMAT=DOLLAR8. AS '$ Small Total Adv'n,
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) 
				FORMAT=DOLLAR8. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ( (SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))
				FORMAT=DOLLAR8. AS '$ Net Adv'n, 
          /* avg adv */
            (( (SUM(t1.NEW_AMT_CURRENT)) + 
				(SUM(t1.RENEW_AMT_CURRENT))) / 
				(SUM(t1.BOOKED_CURRENT))) 
				FORMAT=DOLLAR8. AS 'avg adv'n,
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
				FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT))
				FORMAT=DOLLAR8. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) 
				FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
				(SUM(t1.TOTALAPPCOST_CURRENT))) 
				FORMAT=DOLLAR8. AS 'Total Cost'n, 
		  /* Large CPK */
            (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
                (SUM(t1.LARGE_TOTALAPPCOST_CURRENT))) / 
                ( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
                (SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
                FORMAT=DOLLAR8. AS Large_CPK,
		  /* Small CPK */
            (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
                (SUM(t1.SMALL_TOTALAPPCOST_CURRENT))) / 
                ( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
                (SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
                FORMAT=DOLLAR8. AS Small_CPK,
		  /* CPK */
            (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
				(SUM(t1.TOTALAPPCOST_CURRENT))) / 
				( (SUM(t1.NEW_AMT_CURRENT)) + 
            	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
				FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
	  GROUP BY t1.ClassTranslation;
QUIT;