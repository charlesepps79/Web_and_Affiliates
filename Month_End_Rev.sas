*** CHANGE ONLY WHEN ROSTER FILE CHANGES ------------------------- ***;
%LET ROSTER_LOC =
"\\rmc.local\dfsroot\Dept\Marketing\Analytics\GEO\FOR SAS\BranchRoster.xlsx";

data _null_;
	call symput("importfile",
		"WORK.final_set_restate_202004");
run;

PROC SQL;
   CREATE TABLE WORK.LEADS AS
   SELECT *
      FROM WORK.final_set_restate_202004 t1;
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
			ON t1.ssn = t2.ssn;
QUIT;
         
PROC IMPORT
	DATAFILE =
		"\\mktg-app01\E\cepps\Web_Report\All_Digital\nnc\NNC_2020.xlsx"
		DBMS = XLSX OUT = NetNewCash REPLACE;
	GETNAMES = YES;
RUN;

proc sort
	data = APPS_2 out = APPS;
	by LoanNumber;
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
			ON t1.LoanNumber = t2.loan_number;
QUIT;

PROC IMPORT
	DATAFILE =
		"\\mktg-app01\E\cepps\Web_Report\Reports\Filter_IDs.xlsx"
		DBMS = XLSX OUT = Filter_IDs REPLACE;
	GETNAMES = YES;
RUN;

proc sort
	data = APPS_2 out = APPS;
	by ltFilterRoutingID;
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
			ON t1.ltFilterRoutingID = t2.Filter;
QUIT;

DATA REPORTS_TABLE;
	SET APPS_2;
	TOTALLEADS = 1;
	TOTALLOANCOST = .;
	AMTREQUESTED = 'amt._fin.'n;
	BOOKED = IS_FUNDED;
	IF AFFILIATE = 'LT' THEN DO;
		IF AMTREQUESTED < 5000 THEN COSTPERLEAD = 2;
		ELSE COSTPERLEAD = 3;
		TOTALLEADCOST = COSTPERLEAD * TOTALLEADS;
	END;

	IF BOOKED = 1 AND AFFILIATE = 'LT' THEN DO;
		COSTPERLOAN = 80;
		TOTALLOANCOST = COSTPERLOAN * BOOKED;
	END;

	IF AFFILIATE = 'CK' THEN DO;
		COSTPERLEAD = 0;
		TOTALLEADCOST = COSTPERLEAD * TOTALLEADS;
	END;

	IF BOOKED = 1 AND AFFILIATE = 'CK' THEN DO;
		IF NETLOANAMOUNT > 2500 THEN COSTPERLOAN = 200;
		ELSE COSTPERLOAN = 125;
		TOTALLOANCOST = COSTPERLOAN * BOOKED;
	END;

	IF AFFILIATE = 'SM' THEN DO;
		COSTPERLEAD = 15;
		TOTALLEADCOST = COSTPERLEAD * TOTALLEADS;
	END;

	IF BOOKED = 1 AND AFFILIATE = 'SM' THEN DO;
		COSTPERLOAN = 0;
		TOTALLOANCOST = COSTPERLOAN * BOOKED;
	END;

	TOTALLEADCOST = TOTALLEADS * COSTPERLEAD;
	'Applicant Address Ownership'n = HousingStatus;
	'Loan Request Purpose'n = loan_request_purpose;
	LEADNUMBER = application_number;
	OWNBR = x_branch_i_d;
RUN;

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
	FROM WORK.REPORTS_TABLE t1
		LEFT JOIN WORK.CURRENT_VP_LIST t2 ON t1.OWNBR=t2.OWNBR;
QUIT;

DATA REPORTS_TABLE;
	SET REPORTS_TABLE_4;
	RENAME 'filter def'n = filter_def ;
	renew_amt = 0;

	IF prloan1 NE "" THEN RENEW_FLAG = 1;
	ELSE RENEW_FLAG = 0;

	IF RENEW_FLAG = 1 THEN renew_amt = net_new_cash;

	NEW_AMT = 0;

	IF RENEW_FLAG = 0 THEN NEW_AMT = NetLoanAmount;

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

	IF decision_status = 'Auto Approved' THEN PREAPPROVED_FLAG = 1;
	ELSE PREAPPROVED_FLAG = 0;
	IF decision_status = 'Pending' THEN PREAPPROVED_FLAG = 1;

	IF PREAPPROVED_FLAG = 1 AND TOTALAPPS = 1
		THEN PREAPPROVED_APPS = 1;

	LEADMONTH = month(datepart(application_date));
	LEADYEAR = year(datepart(application_date));
	LENGTH LEADYRMONTH 6.;
	IF LEADMONTH < 10 THEN LEADYRMONTH = CAT(LEADYEAR, '0', LEADMONTH);
	ELSE LEADYRMONTH = CAT(LEADYEAR, LEADMONTH);

	IF LEADYRMONTH = 202004 THEN DO;
		TOTALLEADS_CURRENT = TOTALLEADS;
		PREAPPROV_CURRENT = PREAPPROVED_FLAG;
		TOTALLEADCOST_CURRENT = TOTALLEADCOST;
	END;

	IF APPYRMONTH = 202004 THEN DO;
		TOTALAPPS_CURRENT = TOTALAPPS;
		PQAPPS_CURRENT = PREAPPROVED_APPS;
	END;

	ENTMONTH = month(datepart(BookDate));
	ENTYEAR = year(datepart(BookDate));
	LENGTH ENTYRMONTH 6.;
	IF ENTMONTH < 10 THEN ENTYRMONTH = CAT(ENTYEAR, '0', ENTMONTH);
	ELSE ENTYRMONTH = CAT(ENTYEAR, ENTMONTH);

	IF IS_FUNDED = 1 THEN DO;
		BOOKED_CURRENT = BOOKED;
		NETLOANAMT_CURRENT = NETLOANAMOUNT;
		TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		RENEW_AMT_CURRENT = renew_amt;
		RENEW_FLAG_CURRENT = RENEW_FLAG;
		NEW_AMT_CURRENT = NEW_AMT;
		OLD_AMTPAIDLAST_CURRENT = OLD_AMTPAIDLAST;
		net_new_cash_current = net_new_cash;
	END;

	IF IS_FUNDED = 1 AND ClassTranslation = 'Large' THEN DO;
		LARGE_BOOKED_CURRENT = BOOKED;
		LARGE_NETLOANAMT_CURRENT = NETLOANAMOUNT;
		LARGE_TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		LARGE_TOTALLEADCOST_CURRENT = TOTALLEADCOST_CURRENT;
		LARGE_NEW_AMT_CURRENT = NEW_AMT_CURRENT;
		LARGE_RENEW_AMT_CURRENT = RENEW_AMT_CURRENT;
	END;

	IF IS_FUNDED = 1 AND
		ClassTranslation NOT IN ("Large" "Small") AND
		NETLOANAMOUNT > 2500 THEN DO;
		LARGE_BOOKED_CURRENT = BOOKED;
		LARGE_NETLOANAMT_CURRENT = NETLOANAMOUNT;
		LARGE_TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		LARGE_TOTALLEADCOST_CURRENT = TOTALLEADCOST_CURRENT;
		LARGE_NEW_AMT_CURRENT = NEW_AMT_CURRENT;
		LARGE_RENEW_AMT_CURRENT = RENEW_AMT_CURRENT;
	END;

	IF IS_FUNDED = 1 AND ClassTranslation = 'Small' THEN DO;
		SMALL_BOOKED_CURRENT = BOOKED;
		SMALL_NETLOANAMT_CURRENT = NETLOANAMOUNT;
		SMALL_TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		SMALL_TOTALLEADCOST_CURRENT = TOTALLEADCOST_CURRENT;
		SMALL_NEW_AMT_CURRENT = NEW_AMT_CURRENT;
		SMALL_RENEW_AMT_CURRENT = RENEW_AMT_CURRENT;
	END;

	IF IS_FUNDED = 1 AND
		ClassTranslation NOT IN ("Large" "Small") AND
		NETLOANAMOUNT <= 2500 THEN DO;
		SMALL_BOOKED_CURRENT = BOOKED;
		SMALL_NETLOANAMT_CURRENT = NETLOANAMOUNT;
		SMALL_TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		SMALL_TOTALLEADCOST_CURRENT = TOTALLEADCOST_CURRENT;
		SMALL_NEW_AMT_CURRENT = NEW_AMT_CURRENT;
		SMALL_RENEW_AMT_CURRENT = RENEW_AMT_CURRENT;
	END;

	IF 1000 <= AmountRequested <= 2999 THEN AMTBUCKET = "1000-2999";
	IF 3000 <= AmountRequested <= 4999 THEN AMTBUCKET = "3000-4999";
	IF AmountRequested < 1000 THEN AMTBUCKET = "0-999";
	IF 5000 <= AmountRequested <= 7000 THEN AMTBUCKET = "5000-7000";
	IF AmountRequested > 7000 THEN AMTBUCKET = "7001 +";
RUN;

PROC SQL;
   CREATE TABLE WORK.QUERY_FOR_REPORTS_TABLE AS
      SELECT t1.LEAD_STATE,
          /* Calculation */
            (AVG(t1.APRate)) FORMAT=8.3 AS Calculation
      FROM WORK.REPORTS_TABLE t1
      GROUP BY t1.LEAD_STATE;
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

PROC SQL;
   CREATE TABLE ALL_BY_UTM_Campaign AS
   SELECT t1.UTM_Campaign,
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
      GROUP BY t1.UTM_Campaign;
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
        	WHERE t1.AFFILIATE = 'LT'
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
        	WHERE t1.AFFILIATE = 'WEB'
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
        	WHERE t1.AFFILIATE = 'CK'
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
        	WHERE t1.AFFILIATE = 'SM'
        	GROUP BY t1.OWNBR;
        QUIT;
        
        *** Generate BY_STATE_R_ID_AMT_BUCKET report --------------------- ***;
        PROC SQL;
           CREATE TABLE LT_BY_STATE_R_ID_AMT_BUCKET AS
           SELECT t1.LEAD_STATE,
                  t1.ltfilterroutingid,
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
              WHERE t1.AFFILIATE = 'LT'
              GROUP BY t1.LEAD_STATE,
                  	   t1.ltfilterroutingid,
        		  	   t1.filter_def,
                  	   t1.AMTBUCKET
              ORDER BY t1.LEAD_STATE,
                       t1.ltfilterroutingid,
                       t1.AMTBUCKET;
        QUIT;
        
        *** Generate BY_STATE_AMT_BUCKET reports ------------------------- ***;
        PROC SQL;
           CREATE TABLE LT_BY_STATE_AMT_BUCKET AS
           SELECT t1.LEAD_STATE,
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
             WHERE t1.AFFILIATE = 'LT'
             GROUP BY t1.LEAD_STATE,
                      t1.AMTBUCKET;
       QUIT;
       
       PROC SQL;
          CREATE TABLE WEB_BY_STATE_AMT_BUCKET AS
          SELECT t1.LEAD_STATE,
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
             WHERE t1.AFFILIATE = 'WEB'
             GROUP BY t1.LEAD_STATE,
                      t1.AMTBUCKET;
       QUIT;
       
       PROC SQL;
          CREATE TABLE CK_BY_STATE_AMT_BUCKET AS
          SELECT t1.LEAD_STATE,
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
             WHERE t1.AFFILIATE = 'CK'
             GROUP BY t1.LEAD_STATE,
                      t1.AMTBUCKET
             ORDER BY t1.LEAD_STATE,
                      t1.AMTBUCKET;
       QUIT;
       
       PROC SQL;
          CREATE TABLE SM_BY_STATE_AMT_BUCKET AS
          SELECT t1.LEAD_STATE,
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
             WHERE t1.AFFILIATE = 'SM'
             GROUP BY t1.LEAD_STATE,
                      t1.AMTBUCKET
             ORDER BY t1.LEAD_STATE,
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
             WHERE t1.AFFILIATE = 'LT'
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
             WHERE t1.AFFILIATE = 'WEB'
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
             WHERE t1.AFFILIATE = 'CK'
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
             WHERE t1.AFFILIATE = 'SM'
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
             WHERE t1.AFFILIATE = 'LT'
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
             WHERE t1.AFFILIATE = 'WEB'
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
             WHERE t1.AFFILIATE = 'CK'
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
             WHERE t1.AFFILIATE = 'SM'
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
             WHERE t1.AFFILIATE = 'LT'
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
             WHERE t1.AFFILIATE = 'WEB'
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
             WHERE t1.AFFILIATE = 'CK'
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
             WHERE t1.AFFILIATE = 'SM'
             GROUP BY t1.AMTBUCKET;
       QUIT;
       
       *****************************************;
       *****************************************;
       *****************************************;
       
       PROC SQL;
          CREATE TABLE LT_BY_DECISION_STATUS AS
          SELECT t1.decision_status,
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
             WHERE t1.AFFILIATE = 'LT'
             GROUP BY t1.decision_status;
       QUIT;
       
       PROC SQL;
          CREATE TABLE CK_BY_DECISION_STATUS AS
          SELECT t1.decision_status,
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
             WHERE t1.AFFILIATE = 'CK'
             GROUP BY t1.decision_status;
       QUIT;
       
       PROC SQL;
          CREATE TABLE SM_BY_DECISION_STATUS AS
          SELECT t1.decision_status,
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
             WHERE t1.AFFILIATE = 'SM'
             GROUP BY t1.decision_status;
       QUIT;
       
       PROC SQL;
          CREATE TABLE WEB_BY_DECISION_STATUS AS
          SELECT t1.decision_status,
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
             WHERE t1.AFFILIATE = 'WEB'
             GROUP BY t1.decision_status;
       QUIT;
       
       PROC SQL;
          CREATE TABLE LT_BY_SOURCE_STATE AS
          SELECT t1.AFFILIATE,
                 t1.LEAD_STATE,
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
             WHERE t1.AFFILIATE = 'LT'
             GROUP BY t1.AFFILIATE,
                      t1.LEAD_STATE
             ORDER BY t1.AFFILIATE,
                      t1.LEAD_STATE;
       QUIT;
       
       PROC SQL;
          CREATE TABLE WEB_BY_SOURCE_STATE AS
          SELECT t1.AFFILIATE,
                 t1.LEAD_STATE,
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
             WHERE t1.AFFILIATE = 'WEB'
             GROUP BY t1.AFFILIATE,
                      t1.LEAD_STATE
             ORDER BY t1.AFFILIATE,
                      t1.LEAD_STATE;
       QUIT;
       
       PROC SQL;
          CREATE TABLE CK_BY_SOURCE_STATE AS
          SELECT t1.AFFILIATE,
                 t1.LEAD_STATE,
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
             WHERE t1.AFFILIATE = 'CK'
             GROUP BY t1.AFFILIATE,
                      t1.LEAD_STATE
             ORDER BY t1.AFFILIATE,
                      t1.LEAD_STATE;
       QUIT;
       
       PROC SQL;
          CREATE TABLE SM_BY_SOURCE_STATE AS
          SELECT t1.AFFILIATE,
                 t1.LEAD_STATE,
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
             WHERE t1.AFFILIATE = 'SM'
             GROUP BY t1.AFFILIATE,
                      t1.LEAD_STATE
             ORDER BY t1.AFFILIATE,
                      t1.LEAD_STATE;
       QUIT;
       
       *** Generate BY_DISTRICT reports ----------------------------------- ***;
       PROC SQL;
          CREATE TABLE LT_BY_DISTRICT AS
          SELECT t1.District,
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
             WHERE t1.AFFILIATE = 'LT'
             GROUP BY t1.District;
       QUIT;
       
       PROC SQL;
          CREATE TABLE WEB_BY_DISTRICT AS
          SELECT t1.District,
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
             WHERE t1.AFFILIATE = 'WEB'
             GROUP BY t1.District;
       QUIT;
       
       PROC SQL;
          CREATE TABLE CK_BY_DISTRICT AS
          SELECT t1.District,
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
             WHERE t1.AFFILIATE = 'CK'
             GROUP BY t1.District;
       QUIT;
       
       PROC SQL;
          CREATE TABLE SM_BY_DISTRICT AS
          SELECT t1.District,
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
             WHERE t1.AFFILIATE = 'SM'
             GROUP BY t1.District;
       QUIT;
       
       PROC SQL;
          CREATE TABLE LT_AUTO_DC_BOOKED AS
          SELECT t1.*
             FROM WORK.REPORTS_TABLE t1
             WHERE t1.decision_status IN
                  (
                  'Auto Declined',
                  'Declined'
                  ) AND t1.BOOKED_CURRENT = 1 AND t1.AFFILIATE = 'LT';
       QUIT;
       
       PROC SQL;
          CREATE TABLE WEB_AUTO_DC_BOOKED AS
          SELECT t1.*
             FROM WORK.REPORTS_TABLE t1
             WHERE t1.decision_status IN
                  (
                  'Auto Declined',
                  'Declined'
                  ) AND t1.BOOKED_CURRENT = 1 AND t1.AFFILIATE = 'WEB';
       QUIT;
       
       PROC SQL;
          CREATE TABLE CK_AUTO_DC_BOOKED AS
          SELECT t1.*
             FROM WORK.REPORTS_TABLE t1
             WHERE t1.decision_status IN
                  (
                  'Auto Declined',
                  'Declined'
                  ) AND t1.BOOKED_CURRENT = 1 AND t1.AFFILIATE = 'CK';
       QUIT;
       
       PROC SQL;
          CREATE TABLE SM_AUTO_DC_BOOKED AS
          SELECT t1.*
             FROM WORK.REPORTS_TABLE t1
             WHERE t1.decision_status IN
                  (
                  'Auto Declined',
                  'Declined'
                  ) AND t1.BOOKED_CURRENT = 1 AND t1.AFFILIATE = 'SM';
       QUIT;
       
       data _null_;
       	dt = put(today( ), date9.);
       	call symput('dt', dt);
       run;
       
       proc export
       	data = LT_BY_BRANCH
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Branch_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Lending_Tree";
       run;
       
       proc export
       	data = WEB_BY_BRANCH
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Branch_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Web";
       run;
       
       proc export
       	data = CK_BY_BRANCH
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Branch_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "CreditKarma";
       run;
       
       proc export
       	data = SM_BY_BRANCH
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Branch_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "SuperMoney";
       run;
       
       proc export
       	data = LT_BY_STATE_R_ID_AMT_BUCKET
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Lending_Tree_by_Routing_ID_and_Amount_Bucket_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Lending_Tree";
       run;
       
       proc export
       	data = LT_BY_STATE_AMT_BUCKET
      	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Lending_Tree";
       run;
       
       proc export
       	data = WEB_BY_STATE_AMT_BUCKET
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Web";
       run;

       proc export
       	data = CK_BY_STATE_AMT_BUCKET
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "CreditKarma";
       run;
       
       proc export
       	data = SM_BY_STATE_AMT_BUCKET
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "SuperMoney";
       run;
       
       proc export
       	data = LT_BY_APP_ADD_OWN
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Application_Address_Ownership_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Lending_Tree";
       run;
       
       proc export
       	data = WEB_BY_APP_ADD_OWN
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Application_Address_Ownership_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Web";
       run;
       
       proc export
       	data = CK_BY_APP_ADD_OWN
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Application_Address_Ownership_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "CreditKarma";
       run;
       
       proc export
       	data = SM_BY_APP_ADD_OWN
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Application_Address_Ownership_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "SuperMoney";
       run;
       
       proc export
       	data = LT_BY_REQUEST_PURPOSE
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Request_Purpose_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Lending_Tree";
       run;
       
       proc export
       	data = WEB_BY_REQUEST_PURPOSE
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Request_Purpose_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Web Apps";
       run;
       
       proc export
       	data = CK_BY_REQUEST_PURPOSE
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Request_Purpose_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "CreditKarma";
       run;
       
       proc export
       	data = SM_BY_REQUEST_PURPOSE
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Request_Purpose_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "SuperMoney";
       run;
       
       proc export
       	data = LT_BY_AMT_BUCKET
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Amount_Bucket_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "LendingTree";
       run;
       
       proc export
       	data = WEB_BY_AMT_BUCKET
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Amount_Bucket_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Web Apps";
       run;
       
       proc export
       	data = CK_BY_AMT_BUCKET
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Amount_Bucket_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "CreditKarma";
       run;
       
       proc export
       	data = SM_BY_AMT_BUCKET
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Amount_Bucket_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "SuperMoney LLC";
       run;
       
       proc export
       	data = ALL_BY_SOURCE
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\All_Affiliates_by_Source_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "All Sources";
       run;
       
       proc export
       	data = ALL_BY_UTM_Campaign
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\All_Affiliates_by_UTM_Campaign_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "UTM_Campaign";
       run;
       
       proc export
       	data = LT_BY_SOURCE_STATE
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Source_State_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "LendingTree";
       run;
       
       proc export
       	data = WEB_BY_SOURCE_STATE
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Source_State_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Web Apps";
       run;
       
       proc export
       	data = CK_BY_SOURCE_STATE
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Source_State_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "CreditKarma";
       run;
       
       proc export
       	data = SM_BY_SOURCE_STATE
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Source_State_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "SuperMoney LLC";
       run;
       
       proc export
       	data = LT_BY_DISTRICT
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_District_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "LendingTree";
       run;
       
       proc export
       	data = WEB_BY_DISTRICT
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_District_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Web Apps";
       run;
       
       proc export
       	data = CK_BY_DISTRICT
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_District_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "CreditKarma";
       run;
       
       proc export
       	data = SM_BY_DISTRICT
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_District_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "SuperMoney LLC";
       run;
       
       proc export
       	data = LT_BY_DECISION_STATUS
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "LendingTree";
       run;
       
       proc export
       	data = LT_AUTO_DC_BOOKED
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "LT_Records";
       run;
       
       proc export
       	data = WEB_BY_DECISION_STATUS
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "Web Apps";
       run;
       
       proc export
       	data = WEB_AUTO_DC_BOOKED
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "WEB_Records";
       run;
       
       proc export
       	data = CK_BY_DECISION_STATUS
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "CreditKarma";
       run;
       
       proc export
       	data = CK_AUTO_DC_BOOKED
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "CK_Records";
       run;
       
       proc export
       	data = SM_BY_DECISION_STATUS
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "SuperMoney LLC";
       run;
       
       proc export
       	data = SM_AUTO_DC_BOOKED
       	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\04_2020\April_2020_Web_Reports\Affiliates_by_Decision_Status_&dt..xlsx"
       	dbms = xlsx replace;
       	sheet = "SM_Records";
       run;
