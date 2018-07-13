*** Load ALL_APPS_3 as REPORTS_TABLE ----------------------------- ***;
PROC SQL;
   CREATE TABLE WORK.REPORTS_TABLE AS 
   SELECT *
      FROM WORK.ALL_APPS_3 t1;
QUIT;

DATA REPORTS_TABLE;
	SET REPORTS_TABLE;
	TOTALAPPCOST = TOTALAPPS * COSTPERAPP;
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
   SELECT t1.'Application Number'n AS APPNUMBER, 
          t1.'Applicant Address Ownership'n, 
          t1.'Loan Request Purpose'n
      FROM WORK.OWNER_TYPE_1 t1
      ORDER BY t1.'Application Number'n;
QUIT;

PROC SQL;
   CREATE TABLE WORK.OWNER_TYPE_2 AS 
   SELECT t1.'Application Number'n AS APPNUMBER, 
          t1.'Applicant Address Ownership'n, 
          t1.'Loan Request Purpose'n
      FROM WORK.AIP_INPUT t1
      ORDER BY t1.'Application Number'n;
QUIT;

PROC APPEND 
	BASE = OWNER_TYPE DATA = OWNER_TYPE_2;       
RUN;

PROC SORT 
	DATA = OWNER_TYPE NODUPKEY; 
	BY APPNUMBER; 
RUN;

PROC EXPORT 
	DATA = OWNER_TYPE 
	OUTFILE = "\\mktg-app01\E\cepps\Web_Report\Reports\All_Lending_Apps_OwnType_Purpose.xlsx"  
	DBMS = XLSX REPLACE;
RUN;

PROC SQL;
	CREATE TABLE WORK.REPORTS_TABLE_2 AS 
	SELECT t1.*, t2.APPNUMBER, t2.'Applicant Address Ownership'n, 
		   t2.'Loan Request Purpose'n
	FROM WORK.REPORTS_TABLE t1 
		LEFT JOIN WORK.OWNER_TYPE t2 ON t1.APPNUMBER=t2.APPNUMBER;
QUIT;

PROC SQL;
	CREATE TABLE WORK.REPORTS_TABLE_3 AS 
	SELECT t1.*, t2.old_bracctno, t2.old_AmtPaidLast, t2.renew_bracctno
	FROM WORK.REPORTS_TABLE_2 t1 
		LEFT JOIN WORK.ALL_APP9 t2 ON t1.BrAcctNo=t2.renew_bracctno;
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
	RENAME 'branch #'n = OWNBR 
		   'Vice President'n = VP_CURRENT 
		   'SUPERVISOR'n = SUERVISOR_CURRENT;
	KEEP  SUPERVISOR 'branch #'n 'Vice President'n DISTRICT;
RUN;

PROC SQL;
	CREATE TABLE WORK.REPORTS_TABLE_4 AS 
	SELECT t1.*, t2.OWNBR, t2.VP_CURRENT, t2.SUERVISOR_CURRENT, t2.DISTRICT
	FROM WORK.REPORTS_TABLE_3 t1 
		LEFT JOIN WORK.CURRENT_VP_LIST t2 ON t1.OWNBR=t2.OWNBR;
QUIT;
	
DATA REPORTS_TABLE;
	SET REPORTS_TABLE_4;
	APPQUARTER = PUT(APPDATE_SAS, yyq.);
	ENTQUARTER = PUT(ENTDATE_SAS, yyq.);
	old_AmtPaidLast = SUM(old_AmtPaidLast, 0);
	renew_amt = 0;
	IF renew_bracctno NE "" THEN RENEW_FLAG = 1;
	ELSE RENEW_FLAG = 0;
	IF RENEW_FLAG = 1 THEN renew_amt = NetLoanAmount - old_AmtPaidLast;
	NEW_AMT = 0;
	IF RENEW_FLAG = 0 THEN NEW_AMT = NetLoanAmount;
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

	IF APPQUARTER = '2018Q1' THEN DO;
		TOTALAPPS_CURRENT = TOTALAPPS;
		PREAPPROV_CURRENT = PREAPPROVED_FLAG;
		TOTALAPPCOST_CURRENT = TOTALAPPCOST;
	END;

	IF ENTQUARTER = '2018Q1' THEN DO;
		BOOKED_CURRENT = BOOKED;
		NETLOANAMT_CURRENT = NetLoanAmount;
		TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		RENEW_AMT_CURRENT = renew_amt;
		RENEW_FLAG_CURRENT = RENEW_FLAG;
		NEW_AMT_CURRENT = NEW_AMT;
		OLD_AMTPAIDLAST_CURRENT = OLD_AMTPAIDLAST;
	END;
RUN;


*** Generate BY_BRANCH reports ----------------------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_BRANCH AS 
   SELECT t1.VP_CURRENT, 
          t1.SUERVISOR_CURRENT, 
          t1.OWNBR, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* #PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) 
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
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
          /* CPK */
            (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
				(SUM(t1.TOTALAPPCOST_CURRENT))) / 
				( (SUM(t1.NEW_AMT_CURRENT)) + 
            	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
				FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'LendingTree'
      GROUP BY t1.VP_CURRENT,
               t1.SUERVISOR_CURRENT,
               t1.OWNBR;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_BRANCH AS 
   SELECT t1.VP, 
          t1.Supervisor, 
          t1.OWNBR, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* #PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) 
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
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
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ Renew'n 
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'Web Apps'
      GROUP BY t1.VP,
               t1.Supervisor,
               t1.OWNBR;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_BRANCH AS 
   SELECT t1.VP, 
          t1.Supervisor, 
          t1.OWNBR, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* #PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) 
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
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
          /* CPK */
            (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
				(SUM(t1.TOTALAPPCOST_CURRENT))) / 
				( (SUM(t1.NEW_AMT_CURRENT)) + 
            	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
				FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'CreditKarma'
      GROUP BY t1.VP,
               t1.Supervisor,
               t1.OWNBR;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_BRANCH AS 
   SELECT t1.VP, 
          t1.Supervisor, 
          t1.OWNBR, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* #PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) 
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
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
          /* CPK */
            (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
				(SUM(t1.TOTALAPPCOST_CURRENT))) / 
				( (SUM(t1.NEW_AMT_CURRENT)) + 
            	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
				FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'SuperMoney LLC'
      GROUP BY t1.VP,
               t1.Supervisor,
               t1.OWNBR;
QUIT;

*** Generate BY_STATE_R_ID_AMT_BUCKET report --------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_STATE_R_ID_AMT_BUCKET AS 
   SELECT t1.APPSTATE, 
          t1.LTFILTER_ROUTINGID, 
          t1.AMTBUCKET, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT))
				FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))
				FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv. */
            (((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) /
				(SUM(t1.BOOKED_CURRENT)))
				FORMAT=DOLLAR12. AS 'Avg Adv.'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) 
				FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n,
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost per Loan'n,
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT)))
				FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT))) /
				((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) * 1000)
				FORMAT=DOLLAR12. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'LendingTree'
      GROUP BY t1.APPSTATE,
               t1.LTFILTER_ROUTINGID,
               t1.AMTBUCKET
      ORDER BY t1.APPSTATE,
               t1.LTFILTER_ROUTINGID,
               t1.AMTBUCKET;
QUIT;

*** Generate BY_STATE_AMT_BUCKET reports ------------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_STATE_AMT_BUCKET AS 
   SELECT t1.APPSTATE, 
          t1.AMTBUCKET, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'LendingTree'
      GROUP BY t1.APPSTATE,
               t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_STATE_AMT_BUCKET AS 
   SELECT t1.APPSTATE, 
          t1.AMTBUCKET, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'Web Apps'
      GROUP BY t1.APPSTATE,
               t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_STATE_AMT_BUCKET AS 
   SELECT t1.APPSTATE, 
          t1.AMTBUCKET, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT))
				FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))
				FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv. */
            (((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) /
				(SUM(t1.BOOKED_CURRENT)))
				FORMAT=DOLLAR12. AS 'Avg Adv.'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) 
				FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n,
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost per Loan'n,
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT)))
				FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT))) /
				((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) * 1000)
				FORMAT=DOLLAR12. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'CreditKarma'
      GROUP BY t1.APPSTATE,
               t1.AMTBUCKET
      ORDER BY t1.APPSTATE,
               t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_STATE_AMT_BUCKET AS 
   SELECT t1.APPSTATE, 
          t1.AMTBUCKET, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT))
				FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))
				FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv. */
            (((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) /
				(SUM(t1.BOOKED_CURRENT)))
				FORMAT=DOLLAR12. AS 'Avg Adv.'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) 
				FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n,
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost per Loan'n,
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT)))
				FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT))) /
				((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) * 1000)
				FORMAT=DOLLAR12. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'SuperMoney LLC'
      GROUP BY t1.APPSTATE,
               t1.AMTBUCKET
      ORDER BY t1.APPSTATE,
               t1.AMTBUCKET;
QUIT;

*** Generate BY_APP_ADD_OWN reports ------------------------------ ***;
PROC SQL;
   CREATE TABLE LT_BY_APP_ADD_OWN AS 
   SELECT t1.'Applicant Address Ownership'n, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8.2 AS 'PQ book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12.2 AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))) FORMAT=DOLLAR12.2 AS '$ Net Adv'n, 
          /* avg adv */
            (((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12.2 AS 
            'avg adv'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12.2 AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12.2 AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12.2 AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12.2 AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12.2 AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT))) * 1000) FORMAT=DOLLAR12.2 AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'LendingTree'
      GROUP BY t1.'Applicant Address Ownership'n;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_APP_ADD_OWN AS 
   SELECT t1.'Applicant Address Ownership'n, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8.2 AS 'PQ book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12.2 AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))) FORMAT=DOLLAR12.2 AS '$ Net Adv'n, 
          /* avg adv */
            (((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12.2 AS 
            'avg adv'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12.2 AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12.2 AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12.2 AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12.2 AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12.2 AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT))) * 1000) FORMAT=DOLLAR12.2 AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'Web Apps'
      GROUP BY t1.'Applicant Address Ownership'n;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_APP_ADD_OWN AS 
   SELECT t1.'Applicant Address Ownership'n, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8.2 AS 'PQ book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12.2 AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))) FORMAT=DOLLAR12.2 AS '$ Net Adv'n, 
          /* avg adv */
            (((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12.2 AS 
            'avg adv'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12.2 AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12.2 AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12.2 AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12.2 AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12.2 AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT))) * 1000) FORMAT=DOLLAR12.2 AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'CreditKarma'
      GROUP BY t1.'Applicant Address Ownership'n;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_APP_ADD_OWN AS 
   SELECT t1.'Applicant Address Ownership'n, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8.2 AS 'PQ book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12.2 AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))) FORMAT=DOLLAR12.2 AS '$ Net Adv'n, 
          /* avg adv */
            (((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12.2 AS 
            'avg adv'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12.2 AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12.2 AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12.2 AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12.2 AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12.2 AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT))) * 1000) FORMAT=DOLLAR12.2 AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'SuperMoney LLC'
      GROUP BY t1.'Applicant Address Ownership'n;
QUIT;

*** Generate BY_REQUEST_PURPOSE reports ------------------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_REQUEST_PURPOSE AS 
   SELECT t1.'Loan Request Purpose'n, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            (((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / (((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))) * 1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'LendingTree'
      GROUP BY t1.'Loan Request Purpose'n;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_REQUEST_PURPOSE AS 
   SELECT t1.'Loan Request Purpose'n, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            (((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / (((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))) * 1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'Web Apps'
      GROUP BY t1.'Loan Request Purpose'n;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_REQUEST_PURPOSE AS 
   SELECT t1.'Loan Request Purpose'n, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            (((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / (((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))) * 1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'CreditKarma'
      GROUP BY t1.'Loan Request Purpose'n;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_REQUEST_PURPOSE AS 
   SELECT t1.'Loan Request Purpose'n, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            (((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / (((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))) * 1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'SuperMoney LLC'
      GROUP BY t1.'Loan Request Purpose'n;
QUIT;

*** Generate BY_AMT_BUCKET reports ------------------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_AMT_BUCKET AS 
   SELECT t1.AMTBUCKET, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'LendingTree'
      GROUP BY t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_AMT_BUCKET AS 
   SELECT t1.AMTBUCKET, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'Web Apps'
      GROUP BY t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_AMT_BUCKET AS 
   SELECT t1.AMTBUCKET, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'CreditKarma'
      GROUP BY t1.AMTBUCKET;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_AMT_BUCKET AS 
   SELECT t1.AMTBUCKET, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'SuperMoney LLC'
      GROUP BY t1.AMTBUCKET;
QUIT;

*** Generate ALL_BY_SOURCE report -------------------------------- ***;
PROC SQL;
   CREATE TABLE ALL_BY_SOURCE AS 
   SELECT t1.SOURCE, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      GROUP BY t1.SOURCE;
QUIT;

*****************************************;
*****************************************;
*****************************************;

PROC SQL;
   CREATE TABLE LT_BY_DECISION_STATUS AS 
   SELECT t1.DECISIONSTATUS, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'LendingTree'
      GROUP BY t1.DECISIONSTATUS;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_DECISION_STATUS AS 
   SELECT t1.DECISIONSTATUS, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'CreditKarma'
      GROUP BY t1.DECISIONSTATUS;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_DECISION_STATUS AS 
   SELECT t1.DECISIONSTATUS, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'SuperMoney LLC'
      GROUP BY t1.DECISIONSTATUS;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_DECISION_STATUS AS 
   SELECT t1.DECISIONSTATUS, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT))) FORMAT=PERCENT8. AS 'Book Rate'n, 
          /* PQ Book Rt */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) FORMAT=PERCENT8. AS 'PQ Book Rt'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv */
            (((((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT))))) / (SUM(t1.BOOKED_CURRENT))) FORMAT=DOLLAR12. 
            AS 'Avg Adv'n, 
          /* Net Loan Amount Bk Min $ */
            (MIN(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Min $'n, 
          /* Net Loan Amount Bk Max $ */
            (MAX(t1.NETLOANAMT_CURRENT)) FORMAT=DOLLAR12. AS 'Net Loan Amount Bk Max $'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) FORMAT=PERCENT8. AS '% Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n, 
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost Per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost Per Loan'n, 
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT)) FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) + (SUM(t1.TOTALLOANCOST_CURRENT))) / ((((SUM(t1.NEW_AMT_CURRENT)) + 
            (SUM(t1.RENEW_AMT_CURRENT)))))*1000) FORMAT=DOLLAR12. AS CPK
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.SOURCE = 'Web Apps'
      GROUP BY t1.DECISIONSTATUS;
QUIT;

PROC SQL;
   CREATE TABLE LT_BY_SOURCE_STATE AS 
   SELECT t1.SOURCE, 
          t1.APPSTATE, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT))
				FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))
				FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv. */
            (((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) /
				(SUM(t1.BOOKED_CURRENT)))
				FORMAT=DOLLAR12. AS 'Avg Adv.'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) 
				FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n,
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost per Loan'n,
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT)))
				FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT))) /
				((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) * 1000)
				FORMAT=DOLLAR12. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'LendingTree'
      GROUP BY t1.SOURCE,
               t1.APPSTATE
      ORDER BY t1.SOURCE,
               t1.APPSTATE;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_SOURCE_STATE AS 
   SELECT t1.SOURCE, 
          t1.APPSTATE, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT))
				FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))
				FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv. */
            (((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) /
				(SUM(t1.BOOKED_CURRENT)))
				FORMAT=DOLLAR12. AS 'Avg Adv.'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) 
				FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n,
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost per Loan'n,
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT)))
				FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT))) /
				((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) * 1000)
				FORMAT=DOLLAR12. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'Web Apps'
      GROUP BY t1.SOURCE,
               t1.APPSTATE
      ORDER BY t1.SOURCE,
               t1.APPSTATE;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_SOURCE_STATE AS 
   SELECT t1.SOURCE, 
          t1.APPSTATE, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT))
				FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))
				FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv. */
            (((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) /
				(SUM(t1.BOOKED_CURRENT)))
				FORMAT=DOLLAR12. AS 'Avg Adv.'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) 
				FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n,
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost per Loan'n,
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT)))
				FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT))) /
				((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) * 1000)
				FORMAT=DOLLAR12. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'CreditKarma'
      GROUP BY t1.SOURCE,
               t1.APPSTATE
      ORDER BY t1.SOURCE,
               t1.APPSTATE;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_SOURCE_STATE AS 
   SELECT t1.SOURCE, 
          t1.APPSTATE, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* # PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '# PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT)))
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
          /* $ Total Adv */
            (SUM(t1.NETLOANAMT_CURRENT))
				FORMAT=DOLLAR12. AS '$ Total Adv'n, 
          /* $ Net Adv */
            ((SUM(t1.NEW_AMT_CURRENT)) + (SUM(t1.RENEW_AMT_CURRENT)))
				FORMAT=DOLLAR12. AS '$ Net Adv'n, 
          /* Avg Adv. */
            (((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) /
				(SUM(t1.BOOKED_CURRENT)))
				FORMAT=DOLLAR12. AS 'Avg Adv.'n, 
          /* % Renewal */
            ((SUM(t1.RENEW_FLAG_CURRENT)) / (SUM(t1.BOOKED_CURRENT))) 
				FORMAT=PERCENT8.2 AS '% Renewal'n, 
          /* # Renewal */
            (SUM(t1.RENEW_FLAG_CURRENT)) AS '# Renewal'n, 
          /* $ Renew */
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR12. AS '$ Renew'n,
          /* Total App Cost */
            (SUM(t1.TOTALAPPCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total App Cost'n, 
          /* Cost per Loan */
            (AVG(t1.COSTPERLOAN)) FORMAT=DOLLAR12. AS 'Cost per Loan'n,
          /* Total Loan Cost */
            (SUM(t1.TOTALLOANCOST_CURRENT))
				FORMAT=DOLLAR12. AS 'Total Loan Cost'n, 
          /* Total Cost */
            ((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT)))
				FORMAT=DOLLAR12. AS 'Total Cost'n, 
          /* CPK */
            (((SUM(t1.TOTALAPPCOST_CURRENT)) +
				(SUM(t1.TOTALLOANCOST_CURRENT))) /
				((SUM(t1.NEW_AMT_CURRENT)) +
				(SUM(t1.RENEW_AMT_CURRENT))) * 1000)
				FORMAT=DOLLAR12. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'SuperMoney LLC'
      GROUP BY t1.SOURCE,
               t1.APPSTATE
      ORDER BY t1.SOURCE,
               t1.APPSTATE;
QUIT;

*** Generate BY_DISTRICT reports ----------------------------------- ***;
PROC SQL;
   CREATE TABLE LT_BY_DISTRICT AS 
   SELECT t1.VP_CURRENT, 
          t1.SUERVISOR_CURRENT, 
          t1.DISTRICT, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* #PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) 
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
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
          /* CPK */
            (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
				(SUM(t1.TOTALAPPCOST_CURRENT))) / 
				( (SUM(t1.NEW_AMT_CURRENT)) + 
            	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
				FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'LendingTree'
      GROUP BY t1.VP_CURRENT,
               t1.SUERVISOR_CURRENT,
               t1.DISTRICT;
QUIT;

PROC SQL;
   CREATE TABLE WEB_BY_DISTRICT AS 
   SELECT t1.VP, 
          t1.Supervisor, 
          t1.DISTRICT, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* #PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) 
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
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
            (SUM(t1.RENEW_AMT_CURRENT)) FORMAT=DOLLAR8. AS '$ Renew'n 
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'Web Apps'
      GROUP BY t1.VP,
               t1.Supervisor,
               t1.DISTRICT;
QUIT;

PROC SQL;
   CREATE TABLE CK_BY_DISTRICT AS 
   SELECT t1.VP, 
          t1.Supervisor, 
          t1.DISTRICT, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* #PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) 
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
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
          /* CPK */
            (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
				(SUM(t1.TOTALAPPCOST_CURRENT))) / 
				( (SUM(t1.NEW_AMT_CURRENT)) + 
            	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
				FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'CreditKarma'
      GROUP BY t1.VP,
               t1.Supervisor,
               t1.DISTRICT;
QUIT;

PROC SQL;
   CREATE TABLE SM_BY_DISTRICT AS 
   SELECT t1.VP, 
          t1.Supervisor, 
          t1.DISTRICT, 
          /* Total Apps */
            (SUM(t1.TOTALAPPS_CURRENT)) AS 'Total Apps'n, 
          /* #PQ */
            (SUM(t1.PREAPPROV_CURRENT)) AS '#PQ'n, 
          /* % PQ */
            ((SUM(t1.PREAPPROV_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS '% PQ'n, 
          /* Booked */
            (SUM(t1.BOOKED_CURRENT)) AS Booked, 
          /* Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.TOTALAPPS_CURRENT)))
				FORMAT=PERCENT8.2 AS 'Book Rate'n, 
          /* PQ Book Rate */
            ((SUM(t1.BOOKED_CURRENT)) / (SUM(t1.PREAPPROV_CURRENT))) 
				FORMAT=PERCENT8.2 AS 'PQ Book Rate'n, 
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
          /* CPK */
            (((SUM(t1.TOTALLOANCOST_CURRENT)) + 
				(SUM(t1.TOTALAPPCOST_CURRENT))) / 
				( (SUM(t1.NEW_AMT_CURRENT)) + 
            	(SUM(t1.RENEW_AMT_CURRENT))) * 1000) 
				FORMAT=DOLLAR8. AS CPK
      FROM REPORTS_TABLE t1
      WHERE t1.SOURCE = 'SuperMoney LLC'
      GROUP BY t1.VP,
               t1.Supervisor,
               t1.DISTRICT;
QUIT;

PROC SQL;
   CREATE TABLE LT_AUTO_DC_BOOKED AS 
   SELECT t1.PORTALAPPID, t1.LTFILTER_ROUTINGID, t1.FICO_25PT_BOOKED, 
		  t1.FICO_25PT_APP, t1.APPNUMBER, t1.LOANTYPE, t1.APPDATE,
		  t1.FIRSTNAME, t1.LASTNAME, t1.SSNO1, t1.APPSTATE,
		  t1.AMTREQUESTED, t1.FULLADDRESS, t1.CITY, t1.ZIP, t1.EMAIL, 
		  t1.MIDDLENAME, t1.APPFICO, t1.BRANCHNAME, t1.DECISIONSTATUS,
		  t1.CELLPHONE, t1.HOMEPHONE, t1.WORKPHONE, t1.AFFILIATE,
		  t1.SSNO1_RT7, t1.OWNBR, t1.PHONE, t1.APPMONTH, t1.ADR1,
		  t1.APPYRMONTH, t1.APPDATE_SAS, t1.AMTBUCKET, t1.BrAcctNo,
		  t1.DWOWNBR, t1.ClassID, t1.ClassCode, t1.ClassTranslation,
		  t1.OwnSt, t1.SrCD, t1.POCD, t1.DWLOANTYPE, t1.EntDate,
		  t1.LoanDate, t1.APRate, t1.EffRate, t1.OrgTerm, t1.CrScore,
		  t1.NetLoanAmount, t1.ENTDATE_SAS, t1.ENTYRMONTH,
		  t1.ENTDATEMINUSAPPDATE, t1.BOOKED, t1.SOURCE,
		  t1.PREAPPROVED_FLAG, t1.TOTALAPPS, t1.TOTALLOANCOST,
		  t1.BOOKED_MONTH, t1.COSTPERAPP, t1.COSTPERLOAN, 
		  t1.Supervisor, t1.VP, t1.TOTALAPPCOST,
		  t1.'Applicant Address Ownership'n,
		  t1.'Loan Request Purpose'n, t1.OLD_BRACCTNO,
		  t1.OLD_AMTPAIDLAST, t1.RENEW_BRACCTNO, t1.VP_CURRENT,
		  t1.SUERVISOR_CURRENT, t1.renew_amt, t1.RENEW_FLAG,
		  t1.NEW_AMT, t1.TOTALAPPS_CURRENT, t1.PREAPPROV_CURRENT,
		  t1.BOOKED_CURRENT, t1.NETLOANAMT_CURRENT,
		  t1.RENEW_AMT_CURRENT, t1.NEW_AMT_CURRENT,
		  t1.OLD_AMTPAIDLAST_CURRENT, t1.TOTALAPPCOST_CURRENT,
		  t1.TOTALLOANCOST_CURRENT, t1.RENEW_FLAG_CURRENT
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.DECISIONSTATUS IN 
           (
           'Auto Declined',
           'Declined'
           ) AND t1.BOOKED_CURRENT = 1 AND t1.SOURCE = 'LendingTree';
QUIT;

PROC SQL;
   CREATE TABLE WEB_AUTO_DC_BOOKED AS 
   SELECT t1.PORTALAPPID, t1.LTFILTER_ROUTINGID, t1.FICO_25PT_BOOKED, 
		  t1.FICO_25PT_APP, t1.APPNUMBER, t1.LOANTYPE, t1.APPDATE,
		  t1.FIRSTNAME, t1.LASTNAME, t1.SSNO1, t1.APPSTATE,
		  t1.AMTREQUESTED, t1.FULLADDRESS, t1.CITY, t1.ZIP, t1.EMAIL, 
		  t1.MIDDLENAME, t1.APPFICO, t1.BRANCHNAME, t1.DECISIONSTATUS,
		  t1.CELLPHONE, t1.HOMEPHONE, t1.WORKPHONE, t1.AFFILIATE,
		  t1.SSNO1_RT7, t1.OWNBR, t1.PHONE, t1.APPMONTH, t1.ADR1,
		  t1.APPYRMONTH, t1.APPDATE_SAS, t1.AMTBUCKET, t1.BrAcctNo,
		  t1.DWOWNBR, t1.ClassID, t1.ClassCode, t1.ClassTranslation,
		  t1.OwnSt, t1.SrCD, t1.POCD, t1.DWLOANTYPE, t1.EntDate,
		  t1.LoanDate, t1.APRate, t1.EffRate, t1.OrgTerm, t1.CrScore,
		  t1.NetLoanAmount, t1.ENTDATE_SAS, t1.ENTYRMONTH,
		  t1.ENTDATEMINUSAPPDATE, t1.BOOKED, t1.SOURCE,
		  t1.PREAPPROVED_FLAG, t1.TOTALAPPS, t1.TOTALLOANCOST,
		  t1.BOOKED_MONTH, t1.COSTPERAPP, t1.COSTPERLOAN, 
		  t1.Supervisor, t1.VP, t1.TOTALAPPCOST,
		  t1.'Applicant Address Ownership'n,
		  t1.'Loan Request Purpose'n, t1.OLD_BRACCTNO,
		  t1.OLD_AMTPAIDLAST, t1.RENEW_BRACCTNO, t1.VP_CURRENT,
		  t1.SUERVISOR_CURRENT, t1.renew_amt, t1.RENEW_FLAG,
		  t1.NEW_AMT, t1.TOTALAPPS_CURRENT, t1.PREAPPROV_CURRENT,
		  t1.BOOKED_CURRENT, t1.NETLOANAMT_CURRENT,
		  t1.RENEW_AMT_CURRENT, t1.NEW_AMT_CURRENT,
		  t1.OLD_AMTPAIDLAST_CURRENT, t1.TOTALAPPCOST_CURRENT,
		  t1.TOTALLOANCOST_CURRENT, t1.RENEW_FLAG_CURRENT
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.DECISIONSTATUS IN 
           (
           'Auto Declined',
           'Declined'
           ) AND t1.BOOKED_CURRENT = 1 AND t1.SOURCE = 'Web Apps';
QUIT;

PROC SQL;
   CREATE TABLE CK_AUTO_DC_BOOKED AS 
   SELECT t1.PORTALAPPID, t1.LTFILTER_ROUTINGID, t1.FICO_25PT_BOOKED, 
		  t1.FICO_25PT_APP, t1.APPNUMBER, t1.LOANTYPE, t1.APPDATE,
		  t1.FIRSTNAME, t1.LASTNAME, t1.SSNO1, t1.APPSTATE,
		  t1.AMTREQUESTED, t1.FULLADDRESS, t1.CITY, t1.ZIP, t1.EMAIL, 
		  t1.MIDDLENAME, t1.APPFICO, t1.BRANCHNAME, t1.DECISIONSTATUS,
		  t1.CELLPHONE, t1.HOMEPHONE, t1.WORKPHONE, t1.AFFILIATE,
		  t1.SSNO1_RT7, t1.OWNBR, t1.PHONE, t1.APPMONTH, t1.ADR1,
		  t1.APPYRMONTH, t1.APPDATE_SAS, t1.AMTBUCKET, t1.BrAcctNo,
		  t1.DWOWNBR, t1.ClassID, t1.ClassCode, t1.ClassTranslation,
		  t1.OwnSt, t1.SrCD, t1.POCD, t1.DWLOANTYPE, t1.EntDate,
		  t1.LoanDate, t1.APRate, t1.EffRate, t1.OrgTerm, t1.CrScore,
		  t1.NetLoanAmount, t1.ENTDATE_SAS, t1.ENTYRMONTH,
		  t1.ENTDATEMINUSAPPDATE, t1.BOOKED, t1.SOURCE,
		  t1.PREAPPROVED_FLAG, t1.TOTALAPPS, t1.TOTALLOANCOST,
		  t1.BOOKED_MONTH, t1.COSTPERAPP, t1.COSTPERLOAN, 
		  t1.Supervisor, t1.VP, t1.TOTALAPPCOST,
		  t1.'Applicant Address Ownership'n,
		  t1.'Loan Request Purpose'n, t1.OLD_BRACCTNO,
		  t1.OLD_AMTPAIDLAST, t1.RENEW_BRACCTNO, t1.VP_CURRENT,
		  t1.SUERVISOR_CURRENT, t1.renew_amt, t1.RENEW_FLAG,
		  t1.NEW_AMT, t1.TOTALAPPS_CURRENT, t1.PREAPPROV_CURRENT,
		  t1.BOOKED_CURRENT, t1.NETLOANAMT_CURRENT,
		  t1.RENEW_AMT_CURRENT, t1.NEW_AMT_CURRENT,
		  t1.OLD_AMTPAIDLAST_CURRENT, t1.TOTALAPPCOST_CURRENT,
		  t1.TOTALLOANCOST_CURRENT, t1.RENEW_FLAG_CURRENT
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.DECISIONSTATUS IN 
           (
           'Auto Declined',
           'Declined'
           ) AND t1.BOOKED_CURRENT = 1 AND t1.SOURCE = 'CreditKarma';
QUIT;

PROC SQL;
   CREATE TABLE SM_AUTO_DC_BOOKED AS 
   SELECT t1.PORTALAPPID, t1.LTFILTER_ROUTINGID, t1.FICO_25PT_BOOKED, 
		  t1.FICO_25PT_APP, t1.APPNUMBER, t1.LOANTYPE, t1.APPDATE,
		  t1.FIRSTNAME, t1.LASTNAME, t1.SSNO1, t1.APPSTATE,
		  t1.AMTREQUESTED, t1.FULLADDRESS, t1.CITY, t1.ZIP, t1.EMAIL, 
		  t1.MIDDLENAME, t1.APPFICO, t1.BRANCHNAME, t1.DECISIONSTATUS,
		  t1.CELLPHONE, t1.HOMEPHONE, t1.WORKPHONE, t1.AFFILIATE,
		  t1.SSNO1_RT7, t1.OWNBR, t1.PHONE, t1.APPMONTH, t1.ADR1,
		  t1.APPYRMONTH, t1.APPDATE_SAS, t1.AMTBUCKET, t1.BrAcctNo,
		  t1.DWOWNBR, t1.ClassID, t1.ClassCode, t1.ClassTranslation,
		  t1.OwnSt, t1.SrCD, t1.POCD, t1.DWLOANTYPE, t1.EntDate,
		  t1.LoanDate, t1.APRate, t1.EffRate, t1.OrgTerm, t1.CrScore,
		  t1.NetLoanAmount, t1.ENTDATE_SAS, t1.ENTYRMONTH,
		  t1.ENTDATEMINUSAPPDATE, t1.BOOKED, t1.SOURCE,
		  t1.PREAPPROVED_FLAG, t1.TOTALAPPS, t1.TOTALLOANCOST,
		  t1.BOOKED_MONTH, t1.COSTPERAPP, t1.COSTPERLOAN, 
		  t1.Supervisor, t1.VP, t1.TOTALAPPCOST,
		  t1.'Applicant Address Ownership'n,
		  t1.'Loan Request Purpose'n, t1.OLD_BRACCTNO,
		  t1.OLD_AMTPAIDLAST, t1.RENEW_BRACCTNO, t1.VP_CURRENT,
		  t1.SUERVISOR_CURRENT, t1.renew_amt, t1.RENEW_FLAG,
		  t1.NEW_AMT, t1.TOTALAPPS_CURRENT, t1.PREAPPROV_CURRENT,
		  t1.BOOKED_CURRENT, t1.NETLOANAMT_CURRENT,
		  t1.RENEW_AMT_CURRENT, t1.NEW_AMT_CURRENT,
		  t1.OLD_AMTPAIDLAST_CURRENT, t1.TOTALAPPCOST_CURRENT,
		  t1.TOTALLOANCOST_CURRENT, t1.RENEW_FLAG_CURRENT
      FROM WORK.REPORTS_TABLE t1
      WHERE t1.DECISIONSTATUS IN 
           (
           'Auto Declined',
           'Declined'
           ) AND t1.BOOKED_CURRENT = 1 AND t1.SOURCE = 'SuperMoney LLC';
QUIT;

data _null_;
	dt = put(today( ), date9.);
	call symput('dt', dt);
run;

proc export
	data = LT_BY_BRANCH
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Branch_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Lending_Tree";
run;

proc export
	data = WEB_BY_BRANCH
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Branch_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web";
run;

proc export
	data = CK_BY_BRANCH
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Branch_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_BRANCH
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Branch_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney";
run;

proc export
	data = LT_BY_STATE_R_ID_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Lending_Tree_by_Routing_ID_and_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Lending_Tree";
run;

proc export
	data = LT_BY_STATE_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Lending_Tree";
run;

proc export
	data = WEB_BY_STATE_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web";
run;

proc export
	data = CK_BY_STATE_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_STATE_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_State_and_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney";
run;

proc export
	data = LT_BY_APP_ADD_OWN
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Application_Address_Ownership_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Lending_Tree";
run;

proc export
	data = WEB_BY_APP_ADD_OWN
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Application_Address_Ownership_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web";
run;

proc export
	data = CK_BY_APP_ADD_OWN
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Application_Address_Ownership_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_APP_ADD_OWN
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Application_Address_Ownership_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney";
run;

proc export
	data = LT_BY_REQUEST_PURPOSE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Request_Purpose_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Lending_Tree";
run;

proc export
	data = WEB_BY_REQUEST_PURPOSE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Request_Purpose_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web Apps";
run;

proc export
	data = CK_BY_REQUEST_PURPOSE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Request_Purpose_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_REQUEST_PURPOSE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Request_Purpose_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney";
run;

proc export
	data = LT_BY_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "LendingTree";
run;

proc export
	data = WEB_BY_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web Apps";
run;

proc export
	data = CK_BY_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_AMT_BUCKET
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Amount_Bucket_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney LLC";
run;

proc export
	data = ALL_BY_SOURCE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_All_Affiliates_by_Source_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "All Sources";
run;

proc export
	data = LT_BY_SOURCE_STATE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Source_State_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "LendingTree";
run;

proc export
	data = WEB_BY_SOURCE_STATE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Source_State_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web Apps";
run;

proc export
	data = CK_BY_SOURCE_STATE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Source_State_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_SOURCE_STATE
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Source_State_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney LLC";
run;

proc export
	data = LT_BY_DISTRICT
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_District_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "LendingTree";
run;

proc export
	data = WEB_BY_DISTRICT
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_District_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web Apps";
run;

proc export
	data = CK_BY_DISTRICT
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_District_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = SM_BY_DISTRICT
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_District_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney LLC";
run;

proc export
	data = LT_BY_DECISION_STATUS
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "LendingTree";
run;

proc export
	data = LT_AUTO_DC_BOOKED
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "LT_Records";
run;

proc export
	data = WEB_BY_DECISION_STATUS
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "Web Apps";
run;

proc export
	data = WEB_AUTO_DC_BOOKED
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "WEB_Records";
run;

proc export
	data = CK_BY_DECISION_STATUS
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CreditKarma";
run;

proc export
	data = CK_AUTO_DC_BOOKED
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "CK_Records";
run;

proc export
	data = SM_BY_DECISION_STATUS
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SuperMoney LLC";
run;

proc export
	data = SM_AUTO_DC_BOOKED
	outfile = "\\mktg-app01\E\cepps\Web_Report\Reports\2018Q1\Q1_Affiliates_by_Decision_Status_&dt..xlsx"
	dbms = xlsx replace;
	sheet = "SM_Records";
run;
