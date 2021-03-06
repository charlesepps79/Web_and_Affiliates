﻿%LET NEW_MONTH_FILE = CURRENT_LEADS;
%LET NEW_MONTH_FILE_2 = CURRENT_LEADS_2;
/*
%LET LEAD_IMPORT_FILE = &ALL_LEADS_2.; 
*/
%LET RECENT_MONTH_NO = 202004;
%LET ONE_MO_AGO = 202003;
%LET TWO_MO_AGO = 202002;
%LET TWO_MO_AGO_LEADS = TWO_MONTH_LEADS;
%LET TWO_MO_AGO_LEADS_NEW = TWO_MONTH_LEADS_NEW;
%LET TWO_MO_BOOKED_2 = BOOKED_TWO_MONTH;
%LET TWO_MO_UNBOOKED_2 = UNBOOKED_TWO_MONTH;
%LET ONE_MO_BOOKED_2 = ONE_MONTH_LEADS_B_2;
%LET ONE_MO_UNBOOKED_2 = ONE_MONTH_LEADS_UNB_2;
%LET ALL_LEADS_FILE_2 = ALL_LEADS_ONE_MONTH_FINAL;
%LET ONE_MO_AGO_LEADS = ONE_MONTH_LEADS;
%LET ONE_MO_AGO_LEADS_NEW = ONE_MONTH_LEADS_NEW;
%LET ONE_MO_AGO_LEADS_2 = ONE_MONTH_LEADS_2;

*** CORRECT BOOKINGS FROM TWO MONTHS AGO ------------------------- ***;
DATA &ALL_LEADS_FILE_2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &ALL_LEADS_FILE_2;
	IF LEADYRMONTH NE &RECENT_MONTH_NO;
RUN;

DATA PRIOR_PLUS_NEW;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &NEW_MONTH_FILE &ALL_LEADS_FILE_2 ;
RUN;

DATA &TWO_MO_AGO_LEADS;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET PRIOR_PLUS_NEW;
	IF LEADYRMONTH = &TWO_MO_AGO;
RUN;

DATA &ONE_MO_AGO_LEADS;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET PRIOR_PLUS_NEW;
	IF LEADYRMONTH = &ONE_MO_AGO;
RUN;

DATA &TWO_MO_UNBOOKED_2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &TWO_MO_AGO_LEADS;
	IF BOOKED = 0 & BRACCTNO = "";
RUN;

DATA &TWO_MO_BOOKED_2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &TWO_MO_AGO_LEADS;
	IF BRACCTNO NE "" & BOOKED = 1;
RUN;

DATA &ONE_MO_AGO_LEADS_2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &ONE_MO_AGO_LEADS;
	NEW = "X";
	KEEP NEW BRACCTNO;
	IF BRACCTNO NE "";
RUN;

PROC SORT 
	DATA = &ONE_MO_AGO_LEADS_2 NODUPKEY;
	BY BRACCTNO;
RUN;

DATA &NEW_MONTH_FILE_2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &NEW_MONTH_FILE;
	NEWEST = "X";
	KEEP NEWEST BRACCTNO;
	IF BRACCTNO NE "";
RUN;

PROC SORT 
	DATA = &TWO_MO_BOOKED_2;
	BY BRACCTNO;
RUN;

PROC SORT 
	DATA = &ONE_MO_AGO_LEADS_2;
	BY BRACCTNO;
RUN;

PROC SORT 
	DATA = &NEW_MONTH_FILE_2;
	BY BRACCTNO;
RUN;

DATA X;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	MERGE &TWO_MO_BOOKED_2(IN = X) 
		  &ONE_MO_AGO_LEADS_2 
		  &NEW_MONTH_FILE_2;
	BY BRACCTNO;
	IF X;
RUN;

DATA X2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET X;
	IF NEW = "X" | NEWEST = "X" THEN BRACCTNO = "";
	IF NEW = "X" | NEWEST = "X" THEN BOOKED = 0;

	IF BOOKED = 0 THEN DO;
		NEWLOANAMOUNT = .;
		ENTDATE_SAS = .;
		BRACCTNO = "";
		BOOKED_MONTH = .;
	END;

RUN;

DATA &TWO_MO_AGO_LEADS_NEW;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &TWO_MO_UNBOOKED_2 X2;
RUN;

DATA ALL_LEADS;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET PRIOR_PLUS_NEW;
	IF LEADYRMONTH = &TWO_MO_AGO THEN DELETE;
RUN;

DATA ALL_LEADS;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET ALL_LEADS &TWO_MO_AGO_LEADS_NEW;
	IF BOOKED = . THEN BOOKED = 0;
RUN;

DATA BOOKED;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET ALL_LEADS;
	IF BOOKED = 1;
RUN;

DATA UNBOOKED;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET ALL_LEADS;
	IF BOOKED = 0;
RUN;

PROC SORT 
	DATA = BOOKED;
	BY BRACCTNO;
RUN;

DATA ALL_LEADS;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET UNBOOKED BOOKED;
	IF BOOKED = 0 THEN BOOKED_MONTH = .;
	DROP NEW NEWEST;
RUN;

*** CORRECT LAST MONTH'S BOOKINGS -------------------------------- ***;
DATA &ONE_MO_AGO_LEADS;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET ALL_LEADS_TWO_MONTH_FINAL;
	IF LEADYRMONTH = &ONE_MO_AGO;
RUN;

DATA &ONE_MO_UNBOOKED_2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &ONE_MO_AGO_LEADS;
	IF BOOKED = 0 & BRACCTNO = "";
RUN;

DATA &ONE_MO_BOOKED_2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &ONE_MO_AGO_LEADS;
	IF BRACCTNO NE "" & BOOKED = 1;
RUN;

DATA &NEW_MONTH_FILE_2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &NEW_MONTH_FILE;
	NEW = "X";
	KEEP NEW BRACCTNO;
	IF BRACCTNO NE "";
RUN;

PROC SORT 
	DATA = &ONE_MO_BOOKED_2;
	BY BRACCTNO;
RUN;

PROC SORT 
	DATA = &NEW_MONTH_FILE_2;
	BY BRACCTNO;
RUN;

DATA X;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	MERGE &ONE_MO_BOOKED_2(IN = X) &NEW_MONTH_FILE_2;
	BY BRACCTNO;
	IF X;
RUN;

DATA X2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET X;
	IF NEW = "X" THEN BRACCTNO = "";
	IF NEW = "X" THEN BOOKED = 0;
	IF BOOKED = 0 THEN do;
		NETLOANAMOUNT = .;
		ENTDATE_SAS = .;
		BRACCTNO = "";
		BOOKED_MONTH = .;
	END;
RUN;

DATA &ONE_MO_AGO_LEADS_NEW;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET &ONE_MO_UNBOOKED_2 X2;
RUN;

DATA ALL_LEADS;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET ALL_LEADS;
	IF LEADYRMONTH = &ONE_MO_AGO THEN DELETE;
RUN;

DATA ALL_LEADS_2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET ALL_LEADS &ONE_MO_AGO_LEADS_NEW;
RUN;

DATA BOOKED;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET ALL_LEADS_2;
	IF BOOKED = 1;
RUN;

DATA UNBOOKED;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET ALL_LEADS_2;
	IF BOOKED = 0;
RUN;

PROC SORT 
	DATA = BOOKED NODUPKEY OUT = DUPECHECK; /* EXPECTED: 0 DELETED */
	BY BRACCTNO;
RUN;

DATA ALL_LEADS_2;
	LENGTH PORTALLEADID $15 LTFILTER_ROUTINGID $15;
	SET UNBOOKED BOOKED;
	KEEP BRACCTNO CLASSID CLASSCODE	CLASSTRANSLATION OWNST SRCD	POCD
		 DWLOANTYPE	ENTDATE	LOANDATE APRATE	EFFRATE	ORGTERM	CRSCORE
		 NETLOANAMOUNT FICO_25PT_LEAD CELLPHONE LEADNUMBER PORTALLEADID
		 LTFILTER_ROUTINGID FIRSTNAME MIDDLENAME LASTNAME FULLADDRESS
		 ADR1 CITY EMAIL BRANCHNAME	LEADDATE_SAS	SSNO1 LEADSTATE PHONE
		 SSNO1_RT7 OWNBR ENTDATE_SAS BOOKED SOURCE PREAPPROVED_FLAG
		 BOOKED_MONTH ENTYRMONTH TOTALLEADS COSTPERLEAD COSTPERLOAN
		 TOTALLOANCOST SUPERVISOR VP FICO_25PT_BOOKED AMTREQUESTED
		 LEADFICO AMTBUCKET LOANTYPE LEADDATE ZIP DECISIONSTATUS
		 HOMEPHONE WORKPHONE LEADMONTH LEADYRMONTH DWOWNBR
		 ENTDATEMINUSLEADDATE AFFILIATE;

	IF BOOKED = 0 THEN do;
		TOTALLOANCOST = .;
		CLASSID = .;
		DWOWNBR = "";
		CLASSCODE = "";
		CLASSTRANSLATION = "";
		OWNST = "";
		POCD = "";
		SRCD = "";
		DWLOANTYPE = "";
		ENTDATE = "";
		LOANDATE = "";
		APRATE = .;
		EFFRATE = .;
		ORGTERM = .;
		CRSCORE = .;
		NETLOANAMOUNT = .;
		ENTDATE_SAS =.;
		ENTDATEMINUSLEADDATE = .;
		BOOKED_MONTH=.;
		ENTYRMONTH=.;
	END;
RUN;

DATA ALL_LEADS_3;
	SET ALL_LEADS_2;
	IF AMTREQUESTED < 5000 THEN COSTPERLEAD = 2;
	ELSE COSTPERLEAD = 3;

	IF AFFILIATE = 'Lending Tree' THEN DO;
		IF AMTREQUESTED < 5000 THEN COSTPERLEAD = 2;
		ELSE COSTPERLEAD = 3;
	END;

	*** CK: if amt_financed <= 2500 then costperloan = 125 else    ***;
	*** costperloan = 200 ---------------------------------------- ***;
	IF AFFILIATE = 'Credit Karma' THEN DO;
		COSTPERLEAD = 0;
	END;

	*** SM: $15 for autoapproved --------------------------------- ***;
	IF AFFILIATE = 'Super Money' THEN DO;
		IF PREAPPROVED_FLAG = 1 THEN COSTPERLEAD = 15;
		ELSE COSTPERLEAD = 0;
	END;

	IF 1000 <= AMTREQUESTED <= 2999 THEN AMTBUCKET = "1000-2999";
	IF 3000 <= AMTREQUESTED <= 4999 THEN AMTBUCKET = "3000-4999";
	IF AMTREQUESTED < 1000 THEN AMTBUCKET = "0-999";
	IF 5000 <= AMTREQUESTED <= 7000 THEN AMTBUCKET = "5000-7000";
	IF AMTREQUESTED > 7000 THEN AMTBUCKET = "7001 +";
RUN;

*** CHECKS ------------------------------------------------------- ***;
PROC SQL;
	SELECT ENTYRMONTH, SUM(BOOKED) 
	FROM ALL_LEADS_3 
	GROUP BY 1;

	SELECT LEADYRMONTH, COUNT(LEADNUMBER) 
	FROM ALL_LEADS_3 
	GROUP BY 1;
QUIT;

DATA &NEW_MONTH_FILE._FINAL_EXPORT;
	SET ALL_LEADS_3;
	WHERE LEADYRMONTH = &RECENT_MONTH_NO.;
RUN;

PROC EXPORT 
	DATA = &NEW_MONTH_FILE._FINAL_EXPORT 
	OUTFILE = "&MAIN_DIR\&NEW_MONTH_FILE._FINAL.csv" 
	DBMS = csv 
	REPLACE;
RUN;

PROC EXPORT 
	DATA = ALL_LEADS_3 
	OUTFILE = "&MAIN_DIR\ALL_LEADS_APR2020.xlsx" 
	DBMS = EXCEL 
	REPLACE;
RUN;

*** CANOPY BILLINGS ---------------------------------------------- ***;
DATA CANOPYFINAL;
	SET ALL_LEADS_3;
	IF SOURCE = "LendingTree" & ENTYRMONTH = &RECENT_MONTH_NO;
RUN;

DATA CANOPYLOAD;
	SET CANOPYFINAL;
	KEEP PORTALLEADID NETLOANAMOUNT EFFRATE APRATE ORGTERM ENTDATE
		 LEADDATE_SAS BRACCTNO;
RUN;

PROC EXPORT 
	DATA = CANOPYFINAL 
	OUTFILE = "&MAIN_DIR\CANOPY_FINAL_APR2020.xlsx" 
	DBMS = EXCEL 
	REPLACE;
RUN;

PROC EXPORT 
	DATA = CANOPYLOAD 
	OUTFILE="&MAIN_DIR\CANOPY_LOAD_APR
2020.xlsx" 
	DBMS = EXCEL 
	REPLACE;
RUN;

