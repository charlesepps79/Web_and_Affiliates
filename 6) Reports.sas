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

DATA REPORTS_TABLE;
	SET REPORTS_TABLE_3;
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

	IF APPYRMONTH = 201806 THEN DO;
		TOTALAPPS_CURRENT = TOTALAPPS;
		PREAPPROV_CURRENT = PREAPPROVED_FLAG;
		TOTALAPPCOST_CURRENT = TOTALAPPCOST;
	END;

	IF ENTYRMONTH = 201806 THEN DO;
		BOOKED_CURRENT = BOOKED;
		NETLOANAMT_CURRENT = NetLoanAmount;
		TOTALLOANCOST_CURRENT = TOTALLOANCOST;
		RENEW_AMT_CURRENT = renew_amt;
		RENEW_FLAG_CURRENT = RENEW_FLAG;
		NEW_AMT_CURRENT = NEW_AMT;
		OLD_AMTPAIDLAST_CURRENT = OLD_AMTPAIDLAST;
	END;
RUN;

PROC SQL;
   CREATE TABLE LT_BY_BRANCH AS 
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
      WHERE t1.SOURCE = 'LendingTree'
      GROUP BY t1.VP,
               t1.Supervisor,
               t1.OWNBR;
QUIT;

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
   CREATE TABLE LT_BY_AMTBUCKET AS 
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
   CREATE TABLE LT_BY_STATE_AMTBUCKET AS 
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