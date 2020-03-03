*** Load ALL_APPS_3 as REPORTS_TABLE ----------------------------- ***;
PROC SQL;
   CREATE TABLE WORK.LEADS AS 
   SELECT *
      FROM WORK.ALL_LEADS_3 t1;
QUIT;

PROC SQL;
   CREATE TABLE WORK.APPS_INPUT AS 
   SELECT *
      FROM DW.AppData t1
	Where BOOKDATE IS NOT NULL;
QUIT;

DATA APPS;
	SET APPS_INPUT;
	LENGTH APPYRMONTH 6.;
	APPDATE_SAS = 'ApplicationEnterDate'N;
	APPMONTH = month(datepart(APPDATE_SAS));
	APPYEAR = year(datepart(APPDATE_SAS));
	IF APPMONTH < 10 THEN APPYRMONTH = CAT(APPYEAR, '0', APPMONTH);
	ELSE APPYRMONTH = CAT(APPYEAR, APPMONTH);
	TOTALAPPS = 1;
RUN;

proc sort 
	data = APPS out = APPS_2;
	by descending ApplicationEnterDate;
RUN;

proc sort 
	data = APPS_2 nodupkey out = APPS;
	by ssn;
RUN;

PROC SQL;
	CREATE TABLE WORK.APPS_2 AS 
	SELECT *
	FROM WORK.LEADS t1
   		LEFT JOIN WORK.APPS t2 
			ON t1.SSNO1 = t2.ssn;
QUIT;

PROC IMPORT 
	DATAFILE = 
		"\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\NNC_20200303.xlsx" 
		DBMS = XLSX OUT = NetNewCash REPLACE;
	GETNAMES = YES;
RUN;

proc sort 
	data = APPS_2 out = APPS;
	by BrAcctNo;
RUN;

proc sort 
	data = NetNewCash nodupkey out = NetNewCash_2;
	by loan_number;
RUN;

PROC SQL;
	CREATE TABLE WORK.APPS_2 AS 
	SELECT *
	FROM WORK.APPS t1
   		LEFT JOIN WORK.NetNewCash_2 t2 
			ON t1.BrAcctNo = t2.loan_number;
QUIT;

PROC IMPORT 
	DATAFILE = 
		"\\mktg-app01\E\cepps\Web_Report\Reports\Filter_IDs.xlsx" 
		DBMS = XLSX OUT = Filter_IDs REPLACE;
	GETNAMES = YES;
RUN;

proc sort 
	data = APPS_2 out = APPS;
	by LTFILTER_ROUTINGID;
RUN;

proc sort 
	data = Filter_IDs nodupkey out = Filter_IDs_2;
	by Filter;
RUN;

PROC SQL;
	CREATE TABLE WORK.APPS_2 AS 
	SELECT *
	FROM WORK.APPS t1
   		LEFT JOIN WORK.Filter_IDs_2 t2 
			ON t1.LTFILTER_ROUTINGID = t2.Filter;
QUIT;

DATA REPORTS_TABLE;
	SET APPS_2;
	TOTALLEADCOST = TOTALLEADS * COSTPERLEAD;
RUN;

PROC IMPORT 
	DATAFILE = "\\mktg-app01\E\cepps\Web_Report\Reports\All_Lending_Apps_OwnType_Purpose.xlsx"
	DBMS = EXCEL 
	OUT = OWNER_TYPE_1 
	REPLACE;
RUN;

PROC IMPORT 
	DATAFILE = 
		"\\mktg-app01\E\cepps\Web_Report\Reports\All_Lending_Apps_OwnType_Purpose.xlsx" 
		DBMS = XLSX OUT = OWNER_TYPE_1 REPLACE;
	GETNAMES = YES;
RUN;

PROC SQL;
   CREATE TABLE WORK.OWNER_TYPE AS 
   SELECT t1.'Application Number'n AS LEADNUMBER, 
          t1.'Applicant Address Ownership'n, 
          t1.'Loan Request Purpose'n
      FROM WORK.OWNER_TYPE_1 t1
      ORDER BY t1.'Application Number'n;
QUIT;

PROC SQL;
   CREATE TABLE WORK.OWNER_TYPE_2 AS 
   SELECT t1.'Application Number'n AS LEADNUMBER, 
          t1.'Applicant Address Ownership'n, 
          t1.'Loan Request Purpose'n
      FROM WORK.AIP_INPUT t1
      ORDER BY t1.'Application Number'n;
QUIT;

PROC APPEND 
	BASE = OWNER_TYPE DATA = OWNER_TYPE_2 force;       
RUN;

PROC SORT 
	DATA = OWNER_TYPE NODUPKEY; 
	BY LEADNUMBER; 
RUN;

PROC EXPORT 
	DATA = OWNER_TYPE 
	OUTFILE = "\\mktg-app01\E\cepps\Web_Report\Reports\All_Lending_Apps_OwnType_Purpose.xlsx"  
	DBMS = XLSX REPLACE;
RUN;

PROC SQL;
	CREATE TABLE WORK.REPORTS_TABLE_2 AS 
	SELECT t1.*, t2.LEADNUMBER, t2.'Applicant Address Ownership'n, 
		   t2.'Loan Request Purpose'n
	FROM WORK.REPORTS_TABLE t1 
		LEFT JOIN WORK.OWNER_TYPE t2 ON t1.LEADNUMBER=t2.LEADNUMBER;
QUIT;

PROC SQL;
	CREATE TABLE WORK.REPORTS_TABLE_3 AS 
	SELECT t1.*, t2.old_bracctno, t2.old_AmtPaidLast, t2.renew_bracctno
	FROM WORK.REPORTS_TABLE_2 t1 
		LEFT JOIN WORK.ALL_LEAD9 t2 ON t1.BrAcctNo=t2.renew_bracctno;
QUIT;

*** IMPORT VP ROSTER FILE ---------------------------------------- ***;
PROC IMPORT 
	DATAFILE = &ROSTER_LOC. 
	DBMS = EXCEL 
	OUT = VP_LIST 
	REPLACE;
RUN;

*** RENAME COLUMNS ----------------------------------------------- ***;
DATA CURRENT_VP_LIST;
	SET VP_LIST;
	RENAME 'VicePresident'n = VP_CURRENT
		   'SUPERVISOR'n = SUERVISOR_CURRENT;
	OWNBR = put('BRNUM'n,z4.);
 	format 'BRNUM'n z4.;
	KEEP  SUPERVISOR OWNBR 'BRNUM'n 'VicePresident'n ZIP DISTRICT 
		  VP_CURRENT;
RUN;

PROC SQL;
	CREATE TABLE WORK.REPORTS_TABLE_4 AS 
	SELECT t1.*, t2.OWNBR, t2.VP_CURRENT, t2.SUERVISOR_CURRENT, t2.DISTRICT
	FROM WORK.REPORTS_TABLE_3 t1 
		LEFT JOIN WORK.CURRENT_VP_LIST t2 ON t1.OWNBR=t2.OWNBR;
QUIT;

DATA REPORTS_TABLE;
	SET REPORTS_TABLE_4;
	RENAME 'filter def'n = filter_def ;
	old_AmtPaidLast = SUM(old_AmtPaidLast, 0);
	renew_amt = 0;
	IF renew_bracctno NE "" THEN RENEW_FLAG = 1;
	ELSE RENEW_FLAG = 0;
	IF RENEW_FLAG = 1 THEN renew_amt = net_new_cash;
	NEW_AMT = 0;
	IF RENEW_FLAG = 0 THEN NEW_AMT = NETLOANAMT;
	TOTALLEADCOST = COSTPERLEAD * TOTALLEADS;
	TOTALLEADS_CURRENT = 0;
	TOTALAPPS_CURRENT = 0;
	PREAPPROV_CURRENT = 0;
	BOOKED_CURRENT = 0;
	NETLOANAMT_CURRENT = 0;
	RENEW_AMT_CURRENT = 0;
	NEW_AMT_CURRENT = 0;
	OLD_AMTPAIDLAST_CURRENT = 0;
	TOTALLEADCOST_CURRENT = 0;
	TOTALLOANCOST_CURRENT = 0;
	RENEW_FLAG_CURRENT = 0;
	LARGE_BOOKED_CURRENT = 0;
	LARGE_NETLOANAMT_CURRENT = 0;
	LARGE_TOTALLOANCOST_CURRENT = 0;
	LARGE_TOTALLEADCOST_CURRENT = 0;
	LARGE_NEW_AMT_CURRENT = 0;
	LARGE_RENEW_AMT_CURRENT = 0;
	SMALL_BOOKED_CURRENT = 0;
	SMALL_NETLOANAMT_CURRENT = 0;
	SMALL_TOTALLOANCOST_CURRENT = 0;
	SMALL_TOTALLEADCOST_CURRENT = 0;
	SMALL_NEW_AMT_CURRENT = 0;
	SMALL_RENEW_AMT_CURRENT = 0;
	IF BOOKED = 1 THEN TOTALAPPS = 1;
	IF PREAPPROVED_FLAG = 1 AND TOTALAPPS = 1
		THEN PREAPPROVED_APPS = 1;

	IF LEADYRMONTH = 202002 THEN DO;
		TOTALLEADS_CURRENT = TOTALLEADS;
		PREAPPROV_CURRENT = PREAPPROVED_FLAG;
		TOTALLEADCOST_CURRENT = TOTALLEADCOST;
	END;

	IF APPYRMONTH = 202002 THEN DO;
		TOTALAPPS_CURRENT = TOTALAPPS;
		PQAPPS_CURRENT = PREAPPROVED_APPS;
	END;

	IF ENTYRMONTH = 202002 THEN DO;
		BOOKED_CURRENT = BOOKED;
		NETLOANAMT_CURRENT = NETLOANAMOUNT;
		TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		RENEW_AMT_CURRENT = renew_amt;
		RENEW_FLAG_CURRENT = RENEW_FLAG;
		NEW_AMT_CURRENT = NEW_AMT;
		OLD_AMTPAIDLAST_CURRENT = OLD_AMTPAIDLAST;
		net_new_cash_current = net_new_cash;
	END;

	IF ENTYRMONTH = 202002 AND NETLOANAMOUNT > 2500 THEN DO;
		LARGE_BOOKED_CURRENT = BOOKED;
		LARGE_NETLOANAMT_CURRENT = NETLOANAMOUNT;
		LARGE_TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		LARGE_TOTALLEADCOST_CURRENT = TOTALLEADCOST_CURRENT;
		LARGE_NEW_AMT_CURRENT = NEW_AMT_CURRENT;
		LARGE_RENEW_AMT_CURRENT = RENEW_AMT_CURRENT;
	END;

	IF ENTYRMONTH = 202002 AND NETLOANAMOUNT <= 2500 THEN DO;
		SMALL_BOOKED_CURRENT = BOOKED;
		SMALL_NETLOANAMT_CURRENT = NETLOANAMOUNT;
		SMALL_TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		SMALL_TOTALLEADCOST_CURRENT = TOTALLEADCOST_CURRENT;
		SMALL_NEW_AMT_CURRENT = NEW_AMT_CURRENT;
		SMALL_RENEW_AMT_CURRENT = RENEW_AMT_CURRENT;
	END;
RUN;

PROC SQL;
   CREATE TABLE WORK.QUERY_FOR_REPORTS_TABLE AS 
   SELECT t1.OwnSt, 
          /* Calculation */
            (AVG(t1.APRate)) FORMAT=8.3 AS Calculation
      FROM WORK.REPORTS_TABLE t1
      GROUP BY t1.OwnSt;
QUIT;

*** Generate BY_BRANCH reports ----------------------------------- ***;
PROC SQL;
	CREATE TABLE LT_BY_BRANCH AS 
	SELECT t1.OWNBR, 
		/* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
	FROM REPORTS_TABLE t1
	WHERE t1.AFFILIATE = 'Lending Tree'
	GROUP BY t1.OWNBR;
QUIT;

PROC SQL;
	CREATE TABLE WEB_BY_BRANCH AS 
	SELECT t1.OWNBR, 
		/* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
	FROM REPORTS_TABLE t1
	WHERE t1.AFFILIATE = 'Web'
	GROUP BY t1.OWNBR;
QUIT;

PROC SQL;
	CREATE TABLE CK_BY_BRANCH AS 
	SELECT t1.OWNBR, 
		/* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
	FROM REPORTS_TABLE t1
	WHERE t1.AFFILIATE = 'Credit Karma'
	GROUP BY t1.OWNBR;
QUIT;

PROC SQL;
	CREATE TABLE SM_BY_BRANCH AS 
	SELECT t1.OWNBR, 
		/* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
	FROM REPORTS_TABLE t1
	WHERE t1.AFFILIATE = 'Super Money'
	GROUP BY t1.OWNBR;
QUIT;

*** Generate BY_STATE_R_ID_AMT_BUCKET report --------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_STATE_R_ID_AMT_BUCKET AS 
   SELECT t1.LEADSTATE, 
          t1.LTFILTER_ROUTINGID, 
		  t1.filter_def,
          t1.AMTBUCKET, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Lending Tree'
      GROUP BY t1.LEADSTATE,
               t1.LTFILTER_ROUTINGID,
			   t1.filter_def,
               t1.AMTBUCKET
      ORDER BY t1.LEADSTATE,
               t1.LTFILTER_ROUTINGID,
               t1.AMTBUCKET;
QUIT;

*** Generate BY_STATE_AMT_BUCKET reports ------------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_STATE_AMT_BUCKET AS 
   SELECT t1.LEADSTATE, 
          t1.AMTBUCKET, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Lending Tree'
      GROUP BY t1.LEADSTATE,
               t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_STATE_AMT_BUCKET AS 
   SELECT t1.LEADSTATE, 
          t1.AMTBUCKET, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Web'
      GROUP BY t1.LEADSTATE,
               t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_STATE_AMT_BUCKET AS 
   SELECT t1.LEADSTATE, 
          t1.AMTBUCKET, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Credit Karma'
      GROUP BY t1.LEADSTATE,
               t1.AMTBUCKET
      ORDER BY t1.LEADSTATE,
               t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_STATE_AMT_BUCKET AS 
   SELECT t1.LEADSTATE, 
          t1.AMTBUCKET, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Super Money'
      GROUP BY t1.LEADSTATE,
               t1.AMTBUCKET
      ORDER BY t1.LEADSTATE,
               t1.AMTBUCKET;
QUIT;

*** Generate BY_APP_ADD_OWN reports ------------------------------ ***;
PROC SQL;
   CREATE TABLE LT_BY_APP_ADD_OWN AS 
   SELECT t1.'Applicant Address Ownership'n, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Lending Tree'
      GROUP BY t1.'Applicant Address Ownership'n;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_APP_ADD_OWN AS 
   SELECT t1.'Applicant Address Ownership'n, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Web'
      GROUP BY t1.'Applicant Address Ownership'n;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_APP_ADD_OWN AS 
   SELECT t1.'Applicant Address Ownership'n, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Credit Karma'
      GROUP BY t1.'Applicant Address Ownership'n;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_APP_ADD_OWN AS 
   SELECT t1.'Applicant Address Ownership'n, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Super Money'
      GROUP BY t1.'Applicant Address Ownership'n;
QUIT;

*** Generate BY_REQUEST_PURPOSE reports ------------------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_REQUEST_PURPOSE AS 
   SELECT t1.'Loan Request Purpose'n, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Lending Tree'
      GROUP BY t1.'Loan Request Purpose'n;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_REQUEST_PURPOSE AS 
   SELECT t1.'Loan Request Purpose'n, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Web'
      GROUP BY t1.'Loan Request Purpose'n;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_REQUEST_PURPOSE AS 
   SELECT t1.'Loan Request Purpose'n, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Credit Karma'
      GROUP BY t1.'Loan Request Purpose'n;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_REQUEST_PURPOSE AS 
   SELECT t1.'Loan Request Purpose'n, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Super Money'
      GROUP BY t1.'Loan Request Purpose'n;
QUIT;

*** Generate BY_AMT_BUCKET reports ------------------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_AMT_BUCKET AS 
   SELECT t1.AMTBUCKET, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Lending Tree'
      GROUP BY t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_AMT_BUCKET AS 
   SELECT t1.AMTBUCKET, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Web'
      GROUP BY t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_AMT_BUCKET AS 
   SELECT t1.AMTBUCKET, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Credit Karma'
      GROUP BY t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_AMT_BUCKET AS 
   SELECT t1.AMTBUCKET, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Super Money'
      GROUP BY t1.AMTBUCKET;
QUIT;

*** Generate ALL_BY_SOURCE report -------------------------------- ***;
PROC SQL;
   CREATE TABLE ALL_BY_SOURCE AS 
   SELECT t1.AFFILIATE, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      GROUP BY t1.AFFILIATE;
QUIT;

*****************************************;
*****************************************;
*****************************************;

PROC SQL;
   CREATE TABLE LT_BY_DECISION_STATUS AS 
   SELECT t1.DECISIONSTATUS, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Lending Tree'
      GROUP BY t1.DECISIONSTATUS;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_DECISION_STATUS AS 
   SELECT t1.DECISIONSTATUS, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Credit Karma'
      GROUP BY t1.DECISIONSTATUS;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_DECISION_STATUS AS 
   SELECT t1.DECISIONSTATUS, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Super Money'
      GROUP BY t1.DECISIONSTATUS;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_DECISION_STATUS AS 
   SELECT t1.DECISIONSTATUS, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Web'
      GROUP BY t1.DECISIONSTATUS;
QUIT;

PROC SQL;
   CREATE TABLE LT_BY_SOURCE_STATE AS 
   SELECT t1.AFFILIATE, 
          t1.LEADSTATE, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Lending Tree'
      GROUP BY t1.AFFILIATE,
               t1.LEADSTATE
      ORDER BY t1.AFFILIATE,
               t1.LEADSTATE;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_SOURCE_STATE AS 
   SELECT t1.AFFILIATE, 
          t1.LEADSTATE, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Web'
      GROUP BY t1.AFFILIATE,
               t1.LEADSTATE
      ORDER BY t1.AFFILIATE,
               t1.LEADSTATE;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_SOURCE_STATE AS 
   SELECT t1.AFFILIATE, 
          t1.LEADSTATE, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Credit Karma'
      GROUP BY t1.AFFILIATE,
               t1.LEADSTATE
      ORDER BY t1.AFFILIATE,
               t1.LEADSTATE;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_SOURCE_STATE AS 
   SELECT t1.AFFILIATE, 
          t1.LEADSTATE, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Super Money'
      GROUP BY t1.AFFILIATE,
               t1.LEADSTATE
      ORDER BY t1.AFFILIATE,
               t1.LEADSTATE;
QUIT;

*** Generate BY_DISTRICT reports ----------------------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_DISTRICT AS 
   SELECT t1.DISTRICT, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Lending Tree'
      GROUP BY t1.DISTRICT;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_DISTRICT AS 
   SELECT t1.DISTRICT, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Web'
      GROUP BY t1.DISTRICT;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_DISTRICT AS 
   SELECT t1.DISTRICT, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Credit Karma'
      GROUP BY t1.DISTRICT;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_DISTRICT AS 
   SELECT t1.DISTRICT, 
          /* Total Leads */
		(SUM(t1.TOTALLEADS_CURRENT)) AS 'Leads'n, 
        /* #PQ */
        (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
        /* % PQ */
        ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS '% PQ'n, 
		/* Total Apps */
        (SUM(t1.TOTALAPPS_CURRENT)) AS 'Apps'n,
		/* PQ Apps */
        (SUM(t1.PQAPPS_CURRENT)) AS 'PQ Apps'n,
		/* App Rate */
        ((SUM(t1.TOTALAPPS_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'apps/ leads'n,
		/* PQ App Rate */
        ((SUM(t1.PQAPPS_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
			FORMAT=PERCENT8.2 AS 'PQ Apps/ # PQ'n,
		/* Loans/  Apps */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
			FORMAT=PERCENT8.2 AS 'Loans/  Apps'n,
		/* Large Booked */
        (SUM(t1.LARGE_BOOKED_CURRENT)) AS Large_Booked,
		/* Small Booked */
        (SUM(t1.SMALL_BOOKED_CURRENT)) AS Small_Booked,
        /* Booked */
        (SUM(t1.BOOKED_CURRENT)) AS Booked, 
        /* Book Rate */
        ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALLEADS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Lead Book Rate'n, 
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
			FORMAT=DOLLAR8. AS '$ Total Net Adv'n, 
        /* $ Net Adv */
        (SUM(t1.net_new_cash_current))
			FORMAT=DOLLAR8. AS '$ Net Adv'n, 
        /* avg adv */
        (( (SUM(t1.NEW_AMT_CURRENT)) + 
			(SUM(t1.RENEW_AMT_CURRENT))) / 
			(SUM(t1.BOOKED_CURRENT))) 
			FORMAT=DOLLAR8. AS 'avg adv'n,
        /* % Renewal */
        ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT)))
			FORMAT=PERCENT8.2 AS '% REN'n, 
        /* # Renewal */
        (SUM(t1.RENEW_FLAG_CURRENT)) AS '# REN 'n, 
        /* $ Renew */
        (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ REN NNC'n, 
        /* Total App Cost */
        (SUM(t1.TOTALLEADCOST_CURRENT))
			FORMAT=DOLLAR8. AS 'Total Lead Cost'n, 
        /* Cost Per Loan */
        (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR8. AS 'CPL'n, 
        /* Total Loan Cost */
        (SUM(t1.TOTALLOANCOST_CURRENT)) 
			FORMAT=DOLLAR8. AS 'Total Loan Cost'n, 
        /* Total Cost */
        ((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) 
			FORMAT=DOLLAR8. AS 'Total Cost'n, 
		/* Large CPK */
        (((SUM(t1.LARGE_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.LARGE_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.LARGE_NEW_AMT_CURRENT)) + 
        	(SUM(t1.LARGE_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Large_CPK,
		/* Small CPK */
        (((SUM(t1.SMALL_TOTALLOANCOST_CURRENT)) + 
        	(SUM(t1.SMALL_TOTALLEADCOST_CURRENT))) / 
        	( (SUM(t1.SMALL_NEW_AMT_CURRENT)) + 
        	(SUM(t1.SMALL_RENEW_AMT_CURRENT))) * 1000) 
        	FORMAT=DOLLAR8. AS Small_CPK,
		/* CPK */
        (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
			(SUM(t1.TOTALLEADCOST_CURRENT))) / 
			( (SUM(t1.NEW_AMT_CURRENT)) + 
        	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
			FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.AFFILIATE = 'Super Money'
      GROUP BY t1.DISTRICT;
QUIT;

PROC SQL;
   CREATE TABLE LT_AUTO_DC_BOOKED AS 
   SELECT t1.PORTALLEADID, t1.LTFILTER_ROUTINGID, t1.FICO_25PT_BOOKED, 
		  t1.FICO_25PT_LEAD, t1.LEADNUMBER, t1.LOANTYPE, t1.LEADDATE,
		  t1.FIRSTNAME, t1.LASTNAME, t1.SSNO1, t1.LEADSTATE,
		  t1.AMTREQUESTED, t1.FULLADDRESS, t1.CITY, t1.ZIP, t1.EMAIL, 
		  t1.MIDDLENAME, t1.LEADFICO, t1.BRANCHNAME, t1.DECISIONSTATUS,
		  t1.CELLPHONE, t1.HOMEPHONE, t1.WORKPHONE, t1.AFFILIATE,
		  t1.SSNO1_RT7, t1.OWNBR, t1.PHONE, t1.LEADMONTH, t1.ADR1,
		  t1.LEADYRMONTH, t1.LEADDATE_SAS, t1.AMTBUCKET, t1.BrAcctNo,
		  t1.DWOWNBR, t1.ClassID, t1.ClassCode, t1.ClassTranslation,
		  t1.OwnSt, t1.SrCD, t1.POCD, t1.DWLOANTYPE, t1.EntDate,
		  t1.LoanDate, t1.APRate, t1.EffRate, t1.OrgTerm, t1.CrScore,
		  t1.NETLOANAMOUNT, t1.ENTDATE_SAS, t1.ENTYRMONTH,
		  t1.ENTDATEMINUSLEADDATE, t1.BOOKED, t1.SOURCE,
		  t1.PREAPPROVED_FLAG, t1.TOTALLEADS, t1.TOTALLOANCOST,
		  t1.BOOKED_MONTH, t1.COSTPERLEAD, t1.COSTPERLOAN, 
		  t1.Supervisor, t1.VP, t1.TOTALLEADCOST,
		  t1.'Applicant Address Ownership'n,
		  t1.'Loan Request Purpose'n, t1.OLD_BRACCTNO,
		  t1.OLD_AMTPAIDLAST, t1.RENEW_BRACCTNO, t1.VP_CURRENT,
		  t1.SUERVISOR_CURRENT, t1.renew_amt, t1.RENEW_FLAG,
		  t1.NEW_AMT, t1.TOTALLEADS_CURRENT, t1.PREAPPROV_CURRENT,
		  t1.BOOKED_CURRENT, t1.NETLOANAMT_CURRENT,
		  t1.RENEW_AMT_CURRENT, t1.NEW_AMT_CURRENT,
		  t1.OLD_AMTPAIDLAST_CURRENT, t1.TOTALLEADCOST_CURRENT,
		  t1.TOTALLOANCOST_CURRENT, t1.RENEW_FLAG_CURRENT
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.DECISIONSTATUS IN 
           (
           'Auto Declined',
           'Declined'
           ) AND t1.BOOKED_CURRENT = 1 AND t1.AFFILIATE = 'Lending Tree';
QUIT;

PROC SQL;
   CREATE TABLE WEB_AUTO_DC_BOOKED AS 
   SELECT t1.PORTALLEADID, t1.LTFILTER_ROUTINGID, t1.FICO_25PT_BOOKED, 
		  t1.FICO_25PT_LEAD, t1.LEADNUMBER, t1.LOANTYPE, t1.LEADDATE,
		  t1.FIRSTNAME, t1.LASTNAME, t1.SSNO1, t1.LEADSTATE,
		  t1.AMTREQUESTED, t1.FULLADDRESS, t1.CITY, t1.ZIP, t1.EMAIL, 
		  t1.MIDDLENAME, t1.LEADFICO, t1.BRANCHNAME, t1.DECISIONSTATUS,
		  t1.CELLPHONE, t1.HOMEPHONE, t1.WORKPHONE, t1.AFFILIATE,
		  t1.SSNO1_RT7, t1.OWNBR, t1.PHONE, t1.LEADMONTH, t1.ADR1,
		  t1.LEADYRMONTH, t1.LEADDATE_SAS, t1.AMTBUCKET, t1.BrAcctNo,
		  t1.DWOWNBR, t1.ClassID, t1.ClassCode, t1.ClassTranslation,
		  t1.OwnSt, t1.SrCD, t1.POCD, t1.DWLOANTYPE, t1.EntDate,
		  t1.LoanDate, t1.APRate, t1.EffRate, t1.OrgTerm, t1.CrScore,
		  t1.NETLOANAMOUNT, t1.ENTDATE_SAS, t1.ENTYRMONTH,
		  t1.ENTDATEMINUSLEADDATE, t1.BOOKED, t1.SOURCE,
		  t1.PREAPPROVED_FLAG, t1.TOTALLEADS, t1.TOTALLOANCOST,
		  t1.BOOKED_MONTH, t1.COSTPERLEAD, t1.COSTPERLOAN, 
		  t1.Supervisor, t1.VP, t1.TOTALLEADCOST,
		  t1.'Applicant Address Ownership'n,
		  t1.'Loan Request Purpose'n, t1.OLD_BRACCTNO,
		  t1.OLD_AMTPAIDLAST, t1.RENEW_BRACCTNO, t1.VP_CURRENT,
		  t1.SUERVISOR_CURRENT, t1.renew_amt, t1.RENEW_FLAG,
		  t1.NEW_AMT, t1.TOTALLEADS_CURRENT, t1.PREAPPROV_CURRENT,
		  t1.BOOKED_CURRENT, t1.NETLOANAMT_CURRENT,
		  t1.RENEW_AMT_CURRENT, t1.NEW_AMT_CURRENT,
		  t1.OLD_AMTPAIDLAST_CURRENT, t1.TOTALLEADCOST_CURRENT,
		  t1.TOTALLOANCOST_CURRENT, t1.RENEW_FLAG_CURRENT
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.DECISIONSTATUS IN 
           (
           'Auto Declined',
           'Declined'
           ) AND t1.BOOKED_CURRENT = 1 AND t1.AFFILIATE = 'Web';
QUIT;

PROC SQL;
   CREATE TABLE CK_AUTO_DC_BOOKED AS 
   SELECT t1.PORTALLEADID, t1.LTFILTER_ROUTINGID, t1.FICO_25PT_BOOKED, 
		  t1.FICO_25PT_LEAD, t1.LEADNUMBER, t1.LOANTYPE, t1.LEADDATE,
		  t1.FIRSTNAME, t1.LASTNAME, t1.SSNO1, t1.LEADSTATE,
		  t1.AMTREQUESTED, t1.FULLADDRESS, t1.CITY, t1.ZIP, t1.EMAIL, 
		  t1.MIDDLENAME, t1.LEADFICO, t1.BRANCHNAME, t1.DECISIONSTATUS,
		  t1.CELLPHONE, t1.HOMEPHONE, t1.WORKPHONE, t1.AFFILIATE,
		  t1.SSNO1_RT7, t1.OWNBR, t1.PHONE, t1.LEADMONTH, t1.ADR1,
		  t1.LEADYRMONTH, t1.LEADDATE_SAS, t1.AMTBUCKET, t1.BrAcctNo,
		  t1.DWOWNBR, t1.ClassID, t1.ClassCode, t1.ClassTranslation,
		  t1.OwnSt, t1.SrCD, t1.POCD, t1.DWLOANTYPE, t1.EntDate,
		  t1.LoanDate, t1.APRate, t1.EffRate, t1.OrgTerm, t1.CrScore,
		  t1.NETLOANAMOUNT, t1.ENTDATE_SAS, t1.ENTYRMONTH,
		  t1.ENTDATEMINUSLEADDATE, t1.BOOKED, t1.SOURCE,
		  t1.PREAPPROVED_FLAG, t1.TOTALLEADS, t1.TOTALLOANCOST,
		  t1.BOOKED_MONTH, t1.COSTPERLEAD, t1.COSTPERLOAN, 
		  t1.Supervisor, t1.VP, t1.TOTALLEADCOST,
		  t1.'Applicant Address Ownership'n,
		  t1.'Loan Request Purpose'n, t1.OLD_BRACCTNO,
		  t1.OLD_AMTPAIDLAST, t1.RENEW_BRACCTNO, t1.VP_CURRENT,
		  t1.SUERVISOR_CURRENT, t1.renew_amt, t1.RENEW_FLAG,
		  t1.NEW_AMT, t1.TOTALLEADS_CURRENT, t1.PREAPPROV_CURRENT,
		  t1.BOOKED_CURRENT, t1.NETLOANAMT_CURRENT,
		  t1.RENEW_AMT_CURRENT, t1.NEW_AMT_CURRENT,
		  t1.OLD_AMTPAIDLAST_CURRENT, t1.TOTALLEADCOST_CURRENT,
		  t1.TOTALLOANCOST_CURRENT, t1.RENEW_FLAG_CURRENT
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.DECISIONSTATUS IN 
           (
           'Auto Declined',
           'Declined'
           ) AND t1.BOOKED_CURRENT = 1 AND t1.AFFILIATE = 'Credit Karma';
QUIT;

PROC SQL;
   CREATE TABLE SM_AUTO_DC_BOOKED AS 
   SELECT t1.PORTALLEADID, t1.LTFILTER_ROUTINGID, t1.FICO_25PT_BOOKED, 
		  t1.FICO_25PT_LEAD, t1.LEADNUMBER, t1.LOANTYPE, t1.LEADDATE,
		  t1.FIRSTNAME, t1.LASTNAME, t1.SSNO1, t1.LEADSTATE,
		  t1.AMTREQUESTED, t1.FULLADDRESS, t1.CITY, t1.ZIP, t1.EMAIL, 
		  t1.MIDDLENAME, t1.LEADFICO, t1.BRANCHNAME, t1.DECISIONSTATUS,
		  t1.CELLPHONE, t1.HOMEPHONE, t1.WORKPHONE, t1.AFFILIATE,
		  t1.SSNO1_RT7, t1.OWNBR, t1.PHONE, t1.LEADMONTH, t1.ADR1,
		  t1.LEADYRMONTH, t1.LEADDATE_SAS, t1.AMTBUCKET, t1.BrAcctNo,
		  t1.DWOWNBR, t1.ClassID, t1.ClassCode, t1.ClassTranslation,
		  t1.OwnSt, t1.SrCD, t1.POCD, t1.DWLOANTYPE, t1.EntDate,
		  t1.LoanDate, t1.APRate, t1.EffRate, t1.OrgTerm, t1.CrScore,
		  t1.NETLOANAMOUNT, t1.ENTDATE_SAS, t1.ENTYRMONTH,
		  t1.ENTDATEMINUSLEADDATE, t1.BOOKED, t1.SOURCE,
		  t1.PREAPPROVED_FLAG, t1.TOTALLEADS, t1.TOTALLOANCOST,
		  t1.BOOKED_MONTH, t1.COSTPERLEAD, t1.COSTPERLOAN, 
		  t1.Supervisor, t1.VP, t1.TOTALLEADCOST,
		  t1.'Applicant Address Ownership'n,
		  t1.'Loan Request Purpose'n, t1.OLD_BRACCTNO,
		  t1.OLD_AMTPAIDLAST, t1.RENEW_BRACCTNO, t1.VP_CURRENT,
		  t1.SUERVISOR_CURRENT, t1.renew_amt, t1.RENEW_FLAG,
		  t1.NEW_AMT, t1.TOTALLEADS_CURRENT, t1.PREAPPROV_CURRENT,
		  t1.BOOKED_CURRENT, t1.NETLOANAMT_CURRENT,
		  t1.RENEW_AMT_CURRENT, t1.NEW_AMT_CURRENT,
		  t1.OLD_AMTPAIDLAST_CURRENT, t1.TOTALLEADCOST_CURRENT,
		  t1.TOTALLOANCOST_CURRENT, t1.RENEW_FLAG_CURRENT
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.DECISIONSTATUS IN 
           (
           'Auto Declined',
           'Declined'
           ) AND t1.BOOKED_CURRENT = 1 AND t1.AFFILIATE = 'Super Money';
QUIT;

data _null_;
	dt = put(today( ), date9.);
	call symput('dt', dt);
run;

proc export
	data = LT_BY_BRANCH
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Branch_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Lending_Tree";
run;

proc export
	data = WEB_BY_BRANCH
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Branch_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web";
run;

proc export
	data = CK_BY_BRANCH
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Branch_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_BRANCH
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Branch_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney";
run;

proc export
	data = LT_BY_STATE_R_ID_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Lending_Tree_by_Routing_ID_and_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Lending_Tree";
run;

proc export
	data = LT_BY_STATE_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Lending_Tree";
run;

proc export
	data = WEB_BY_STATE_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web";
run;

proc export
	data = CK_BY_STATE_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_STATE_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney";
run;

proc export
	data = LT_BY_APP_ADD_OWN
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Application_Address_Ownership_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Lending_Tree";
run;

proc export
	data = WEB_BY_APP_ADD_OWN
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Application_Address_Ownership_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web";
run;

proc export
	data = CK_BY_APP_ADD_OWN
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Application_Address_Ownership_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_APP_ADD_OWN
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Application_Address_Ownership_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney";
run;

proc export
	data = LT_BY_REQUEST_PURPOSE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Request_Purpose_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Lending_Tree";
run;

proc export
	data = WEB_BY_REQUEST_PURPOSE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Request_Purpose_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web Apps";
run;

proc export
	data = CK_BY_REQUEST_PURPOSE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Request_Purpose_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_REQUEST_PURPOSE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Request_Purpose_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney";
run;

proc export
	data = LT_BY_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "LendingTree";
run;

proc export
	data = WEB_BY_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web Apps";
run;

proc export
	data = CK_BY_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney LLC";
run;

proc export
	data = ALL_BY_SOURCE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\All_Affiliates_by_Source_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "All Sources";
run;

proc export
	data = LT_BY_SOURCE_STATE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Source_State_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "LendingTree";
run;

proc export
	data = WEB_BY_SOURCE_STATE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Source_State_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web Apps";
run;

proc export
	data = CK_BY_SOURCE_STATE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Source_State_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_SOURCE_STATE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Source_State_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney LLC";
run;

proc export
	data = LT_BY_DISTRICT
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_District_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "LendingTree";
run;

proc export
	data = WEB_BY_DISTRICT
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_District_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web Apps";
run;

proc export
	data = CK_BY_DISTRICT
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_District_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_DISTRICT
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_District_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney LLC";
run;

proc export
	data = LT_BY_DECISION_STATUS
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "LendingTree";
run;

proc export
	data = LT_AUTO_DC_BOOKED
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "LT_Records";
run;

proc export
	data = WEB_BY_DECISION_STATUS
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web Apps";
run;

proc export
	data = WEB_AUTO_DC_BOOKED
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "WEB_Records";
run;

proc export
	data = CK_BY_DECISION_STATUS
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = CK_AUTO_DC_BOOKED
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CK_Records";
run;

proc export
	data = SM_BY_DECISION_STATUS
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney LLC";
run;

proc export
	data = SM_AUTO_DC_BOOKED
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\02_2020\February_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SM_Records";
run;