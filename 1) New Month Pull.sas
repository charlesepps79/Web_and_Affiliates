OPTIONS MPRINT MLOGIC SYMBOLGEN; /* SET DEBUGGING OPTIONS */

*** WEB REPORT MAIN DIRECTORY LOCATION --------------------------- ***;
%LET MAIN_DIR = 
	\\mktg-app01\E\cepps\Web_Report\Reports;
*** CHANGE ONLY WHEN ROSTER FILE CHANGES ------------------------- ***;
%LET ROSTER_LOC = 
"\\mktg-app01\E\cepps\Web_Report\BranchRosterFile\Rosters 05-08-18.xlsx";

*** CHANGE MONTH_NAME TO APP MONTH ------------------------------- ***;
%LET NEW_MONTH_FILE = MAY_APPS;
*** CHANGE DATE TO START OF APP MONTH ---------------------------- ***;
%LET LOAN_ENT_DATE_BEGIN = "2018-05-01";
*** CHANGE DATE TO END OF APP MONTH ------------------------------ ***;
%LET LOAN_ENT_DATE_END = "2018-05-31";


*** NO CHANGE - ENSURE CURRENT MONTH APP FILE -------------------- ***;
%LET AIP_REPORT_LOC = 
"\\mktg-app01\E\cepps\Web_Report\Reports\Application_Internet_Report_2018-05-01_2018-05-31.xlsx";
%LET TAB_NAME = Application Internet Report;

*** CHANGE TO LAST MONTH ALL APPS FILENAME ----------------------- ***;
%LET ALL_APPS_HIST_LOC = "&MAIN_DIR\ALL_APPS_APR2018.xlsx";

*** THIS IS FILE NAME OF CURRENT ALL APPS FILE ------------------- ***;
%LET ALL_APPS_2_EXPORT = ALL_APPS_MAY_2018;
%LET VW_L_EXPORT = VW_L_MAY_2018; /* THIS IS FILENAME OF VW_L FILE */

%LET APP_IMPORT_FILE = APP_IMPORT_FILE_2; 
*** CHANGE MONTH NAME TO APP MONTH - 1 MONTH --------------------- ***;
%LET ALL_APPS_FILE = ALL_APPS_APRIL_FINAL;
*** CHANGE MONTH NAME TO APP MONTH - 1 MONTH --------------------- ***;
%LET ALL_APPS_FILE_2 = ALL_APPS_APRIL_FINAL;

%LET RECENT_MONTH_NO = 201805; /* YYYYMM CHANGE TO APP MONTH */
%LET ONE_MO_AGO = 201804; /* YYYYMM CHANGE TO APP MONTH - 1 */
%LET TWO_MO_AGO = 201803;	/* YYYYMM CHANGE TO APP MONTH - 2 */

*** CHANGE MONTH NAME TO APP MONTH - 2 MONTH --------------------- ***;
%LET TWO_MO_BOOKED = MARCH_APPS_B;
%LET TWO_MO_UNBOOKED = MARCH_APPS_UNB;
%LET APPS_MINUS_2_MO_AGO = APPS_EXCEPT_MARCH;

*** CHANGE MONTH NAME TO APP MONTH - 1 MONTH --------------------- ***;
%LET ONE_MO_BOOKED = APRIL_APPS_B;
%LET ONE_MO_UNBOOKED = APRIL_APPS_UNB;
%LET APPS_MINUS_1_MO_AGO = APPS_EXCEPT_APRIL;

*** IMPORT VP ROSTER FILE ---------------------------------------- ***;
PROC IMPORT 
	DATAFILE = &ROSTER_LOC. 
	DBMS = EXCEL 
	OUT = VP_LIST 
	REPLACE;
RUN;

*** RENAME COLUMNS ----------------------------------------------- ***;
DATA VP_LIST;
	SET VP_LIST;
	RENAME 'branch #'n = OWNBR 'Vice President'n = VP;
	KEEP  SUPERVISOR 'branch #'n 'Vice President'n;
RUN;

*** IMPORT CMR FOR WEB ------------------------------------------- ***;
PROC IMPORT
	DATAFILE = &AIP_REPORT_LOC. 
	DBMS = XLSX 
	OUT = AIP_INPUT 
	REPLACE;
	GETNAMES = YES;   
RUN;

*** RENAME, CLEAN AND DRESS COLUMNS ------------------------------ ***;
DATA AIP;
	SET AIP_INPUT;
	IF "Loan Type"n = "Lending Tree PQ" THEN AFFILIATE = "Lending Tree";
	ELSE AFFILIATE = "Web";
	IF Irmpname = "CreditKarma" THEN AFFILIATE = "Credit Karma";
	IF Irmpname = "SuperMoney LLC" THEN AFFILIATE = "Super Money";

	SSNO1_RT7 = SUBSTRN('Applicant SSN'n, MAX(1, 
		LENGTH('Applicant SSN'n) - 6), 7);
	OWNBR = PUT(INPUT('X Branch I D'n, 4.), z4.);
	OWNBR = TRANWRD(OWNBR, ".0", "");
	OWNBR = COMPRESS(OWNBR, ".");
	'Application Number'n = STRIP('Application Number'n);
	PHONE = PUT('app. home phone'n, 10.);
	APPMONTH = MONTH('Application Date'N);
	APPYEAR = YEAR('Application Date'N);
	ADR1 = SCAN('applicant address'n, 1, ",");
	RENAME 'loan type'n = LOANTYPE 
		   'Application Number'n = APPNUMBER
		   'Portal App Id'n = PORTALAPPID 
		   'Lt Filter Routing I D'n = LTFILTER_ROUTINGID 
		   'Applicant Credit Score'n = APPFICO 
		   'amt. fin.'n = AMTREQUESTED 
		   'applicant email'n = EMAIL 
		   'Applicant First Name'n = FIRSTNAME 
		   'Applicant Middle Name'n = MIDDLENAME 
		   'Applicant Last Name'n = LASTNAME 
		   'Applicant Address State'N = APPSTATE 
		   'Applicant SSN'n = SSNO1 
		   'Application Date'N = APPDATE 
		   'Applicant Address'n = FULLADDRESS 
		   'Decision Status'n = DECISIONSTATUS 
		   'Applicant Middle Name'n = MIDDLENAME 
		   'App. Cell Phone'n = CELLPHONE 
		   'App. Home Phone'n = HOMEPHONE 
		   'App. Work Phone'n = WORKPHONE 
		   BRANCH = BRANCHNAME 
		   'Applicant Address City'n = CITY 
		   'Applicant Address State'n = APPSTATE 
		   'Applicant Address Zip'n = ZIP
		   'Loan Request Purpose'n = LOAN_REQUEST_PURPOSE 
		   'Applicant Address Ownership'n = APPLICANT_ADDRESS_OWNERSHIP;
	DROP 'x branch i d'n  'Decision Date/Time'n 
		 'Applicant Address Street'n ;
	FORMAT _CHARACTER_;
RUN;

DATA AIP;
	SET AIP;
	LENGTH APPYRMONTH 6.;
	IF APPMONTH < 10 THEN APPYRMONTH = CAT(APPYEAR, '0', APPMONTH);
	ELSE APPYRMONTH = CATX(APPYEAR, APPMONTH);
RUN;

*** CHECK - SHOULD HAVE ONLY ONE APPYRMONTH I.E. CURRENT MONTH --- ***;
PROC SQL;	
	SELECT DISTINCT APPYRMONTH FROM AIP;
QUIT;

DATA AIP2;
	LENGTH APPNUMBER $10 PORTALAPPID $15 LTFILTER_ROUTINGID $15;
	SET AIP;
	WHERE LOANTYPE <> "" AND APPNUMBER <> "";
RUN;

*** PULL IN FROM LOAN TABLE, BORROWER TABLE AND MERGE              ***;
*** EXCLUDE POCD = "**" and BT                                     ***;
*** EXCLUDE CLASSTRANSLATION = "Checks" -------------------------- ***;

DATA VW_L;
	SET dw.vw_loan(
		KEEP = OWNST BRACCTNO CLASSCODE SSNO1 OWNBR SSNO1_RT7 LOANTYPE
			   ENTDATE LOANDATE CLASSID CLASSTRANSLATION NETLOANAMOUNT
			   POCD EFFRATE APRATE ORGTERM SRCD CRSCORE SRCD);
	WHERE &LOAN_ENT_DATE_BEGIN. <= ENTDATE <= &LOAN_ENT_DATE_END.;
	ENTDATE_SAS = INPUT(ENTDATE, yymmdd10.);
	FORMAT ENTDATE_SAS date9.;
	IF POCD = "**" THEN DELETE;
	IF POCD = "BT" THEN DELETE;
	IF CLASSTRANSLATION = "Checks" THEN DELETE;
	RENAME LOANTYPE = DWLOANTYPE OWNBR = DWOWNBR;
RUN;

*** CHECKS ------------------------------------------------------- ***;
PROC SQL;
	SELECT MIN(ENTDATE_SAS) AS MIN_DATE FORMAT date9. FROM VW_L;
	SELECT MAX(ENTDATE_SAS) AS MAX_DATE FORMAT date9. FROM VW_L;
	SELECT COUNT(*) AS ROWS, 
		   COUNT(DISTINCT APPNUMBER) AS ACCOUNTS FROM AIP2;
	SELECT COUNT(*) AS ROWS, 
		   COUNT(DISTINCT BRACCTNO) AS ACCOUNTS FROM VW_L;
QUIT;

DATA VW_L;
	SET VW_L;
	LENGTH ENTYRMONTH 6.;
	ENTDATE_SAS = INPUT(STRIP(TRIM(ENTDATE)), yymmdd10.);
	ENTMONTH = MONTH(ENTDATE_SAS);
	ENTYEAR = YEAR(ENTDATE_SAS);
	IF ENTMONTH < 10 THEN ENTYRMONTH = CAT(ENTYEAR, '0', ENTMONTH);
	ELSE ENTYRMONTH = CAT(ENTYEAR, ENTMONTH);
RUN;

*** CHECK - SHOULD HAVE ONLY ONE APPYRMONTH I.E. CURRENT MONTH --- ***;
PROC SQL;
	SELECT DISTINCT ENTYRMONTH FROM VW_L;
QUIT;

*** EXPORT LOAN FILE FOR FUTURE REFERENCE ------------------------ ***;
PROC EXPORT 
	DATA = VW_L 
	OUTFILE =" &MAIN_DIR\&vw_L_export..xlsx" 
	DBMS = EXCEL 
	REPLACE;
QUIT;

*** DEFINE AMT BUCKET -------------------------------------------- ***;
DATA AIP_FINAL;
	SET AIP2;
	APPDATE_SAS = APPDATE;
	SSNO1 = STRIP(SSNO1);
	PHONE = COMPRESS(PHONE, '()- ', 'i');
	IF 1000 <= AMTREQUESTED <= 2999 THEN AMTBUCKET = "1000-2999";
	IF 3000 <= AMTREQUESTED <= 4999 THEN AMTBUCKET = "3000-4999";
	IF AMTREQUESTED < 1000 THEN AMTBUCKET = "0-999";
	IF 5000 <= AMTREQUESTED <= 7000 THEN AMTBUCKET = "5000-7000";
	IF AMTREQUESTED > 7000 THEN AMTBUCKET = "7001 +";
	FORMAT APPDATE_SAS date9.;
RUN;

*** CHECKS ------------------------------------------------------- ***;
PROC SQL;
	SELECT AMTBUCKET, 
		   MIN(AMTREQUESTED) AS MIN_AMT, 
		   MAX(AMTREQUESTED) AS MAX_AMT FROM AIP_FINAL GROUP BY 1;
	SELECT COUNT(*) AS ROWS_AIP, 
		   COUNT(DISTINCT SSNO1) AS SS7_AIP FROM AIP_FINAL;
	SELECT COUNT(*) AS ROWS_LOAN, 
		   COUNT(DISTINCT SSNO1) AS SS7_LOAN FROM VW_L;
QUIT;

PROC SORT 
	DATA = VW_L; 
	BY SSNO1; 
RUN;

PROC SORT 
	DATA = AIP_FINAL; 
	BY SSNO1; 
RUN;

*** MERGE FROM DW WITH INFO FROM TCI SITES TO IDENTIFY MADES AND   ***;
*** PULL IN UNMADES ---------------------------------------------- ***;
DATA MADES_A;
	MERGE AIP_FINAL(IN = x) VW_L(IN = y);
	BY SSNO1;
	IF x = 1;
RUN;

*** CHECKS ------------------------------------------------------- ***;
PROC SQL;
	SELECT COUNT(*) AS ROWS_MERGE, 
		   COUNT(DISTINCT APPNUMBER) AS APPCOUNT_MERGE FROM MADES_A;
QUIT;

*** CREATE ENTDATEMINUSAPPDATE                                     ***;
*** CREATE BOOKED INDICATOR -------------------------------------- ***;
DATA MADES_A;
	SET MADES_A;
	ENTDATEMINUSAPPDATE = ENTDATE_SAS - APPDATE_SAS;
	IF ENTDATE_SAS >= APPDATE_SAS - 1 AND 
	   ENTDATE_SAS <= APPDATE_SAS + 60 THEN BOOKED = 1;
	ELSE BOOKED = 0;
	IF BOOKED = 0 THEN BRACCTNO = "";
	IF OWNBR = "" THEN OWNBR = DWOWNBR;
RUN;

PROC SORT 
	DATA = MADES_A;
	BY APPNUMBER BOOKED;
RUN;

PROC SORT 
	DATA = MADES_A;
	BY APPNUMBER LOANTYPE APPDATE_SAS;
RUN;

*** REMOVING THE DUPLICATES DUE TO MERGE WITH LOAN FILE ---------- ***;
PROC SORT 
	DATA = MADES_A OUT = MADES_B NODUPKEY;
	BY APPNUMBER;
RUN;

*** CHECKS ------------------------------------------------------- ***;
PROC SQL;
	SELECT COUNT(*) AS ROWS_MERGE, 
		   COUNT(DISTINCT APPNUMBER) AS APPCOUNT_MERGE FROM MADES_B;
QUIT;

*** SUBSET FOR LT, WEB, CK, and SM ------------------------------- ***;
DATA LT_1;
	SET MADES_B;
	IF AFFILIATE = 'Lending Tree';
RUN;

DATA WEB_1;
	SET MADES_B;
	IF AFFILIATE = 'Web';
RUN;

DATA CK_1;
	SET MADES_B;
	IF AFFILIATE = 'Credit Karma';
RUN;

DATA SM_1;
	SET MADES_B;
	IF AFFILIATE = 'Super Money';
RUN;

*** REMOVE DUPLICATES AT SSN01 LEVEL ----------------------------- ***;
PROC SORT 
	DATA = LT_1 NODUPKEY;
	BY SSNO1;
RUN;

PROC SORT 
	DATA = WEB_1 NODUPKEY;
	BY SSNO1;
RUN;

PROC SORT 
	DATA = CK_1 NODUPKEY;
	BY SSNO1;
RUN;

PROC SORT 
	DATA = SM_1 NODUPKEY;
	BY SSNO1;
RUN;

*** APPEND BOTH PQ AND LT ---------------------------------------- ***;
DATA MADES_C;
	SET LT_1 WEB_1 CK_1 SM_1;
RUN;

PROC SORT
	DATA = MADES_C;
	BY BRACCTNO AFFILIATE;
RUN;

**********************************************************************;
*** BOOKED AND UNBOOKED ------------------------------------------ ***;
DATA UNBOOKED BOOKED;
	SET MADES_C;
	IF BRACCTNO = "" THEN OUTPUT UNBOOKED;
	ELSE OUTPUT BOOKED;
RUN;

*** SEPERATE DUPS BY BRACCTNO ------------------------------------ ***;
DATA x y;
	SET BOOKED;
	BY BRACCTNO;
	IF FIRST.BRACCTNO & LAST.BRACCTNO THEN OUTPUT x;
	ELSE OUTPUT y;
RUN;

PROC SORT
	DATA = y;
	BY BRACCTNO APPDATE;
RUN;

*** IF DUPS EXIST ON BRACCTNO, THEN LT TAKES PRIORITY OVER PQ ---- ***;
data y2;
	set y;
	by BRACCTNO APPDATE;
	priority = FIRST.BRACCTNO;
run;

DATA y3;
	SET y2;
	IF priority = 0 THEN BRACCTNO = "";
	IF priority = 0 THEN BOOKED = 0;
RUN;

*** MERGE BOOKED AND UNBOOKED ------------------------------------ ***;
DATA MADES_D;
	SET UNBOOKED x y3;
RUN;

DATA FINAL;
	LENGTH FICO_25PT_BOOKED $10 FICO_25PT_APP $15;
	SET MADES_D;
	IF AFFILIATE = 'Super Money' THEN SOURCE = 'SuperMoney LLC';
	IF AFFILIATE = 'Lending Tree' THEN SOURCE = 'LendingTree';
	IF AFFILIATE = 'Web' THEN SOURCE = 'Web Apps';
	IF AFFILIATE = 'Credit Karma' THEN SOURCE = 'CreditKarma';
	IF DECISIONSTATUS = 'Auto Approved' THEN PREAPPROVED_FLAG = 1; 
	ELSE PREAPPROVED_FLAG = 0;
	APPMONTH = MONTH(APPDATE_SAS);
	TOTALAPPS = 1;
	TOTALLOANCOST = .;

	IF BOOKED = 0 THEN DO;
		NETLOANAMOUNT = .;
		ENTDATE_SAS = .;
		BRACCTNO = "";
	END;

	IF BOOKED = 1 THEN BOOKED_MONTH = MONTH(ENTDATE_SAS);

	IF AFFILIATE = 'Lending Tree' THEN DO;
		IF AMTREQUESTED < 5000 THEN COSTPERAPP = 2;
		ELSE COSTPERAPP = 3;
		TOTALAPPCOST = COSTPERAPP * TOTALAPPS;
	END;

	IF BOOKED = 1 AND AFFILIATE = 'Lending Tree' THEN DO;
		COSTPERLOAN = 80;
		TOTALLOANCOST = COSTPERLOAN * BOOKED;
	END;

	*** CK: if amt_financed <= 2500 then costperloan = 125 else    ***;
	*** costperloan = 200 ---------------------------------------- ***;
	IF AFFILIATE = 'Credit Karma' THEN DO;
		COSTPERAPP = 0;
		TOTALAPPCOST = COSTPERAPP * TOTALAPPS;
	END;

	IF BOOKED = 1 AND AFFILIATE = 'Credit Karma' THEN DO;
		IF NETLOANAMOUNT > 2500 THEN COSTPERLOAN = 200;
		ELSE COSTPERLOAN = 125;
		TOTALLOANCOST = COSTPERLOAN * BOOKED;
	END;

	*** SM: $15 for autoapproved --------------------------------- ***;
	IF AFFILIATE = 'Super Money' THEN DO;
		COSTPERAPP = 15;
		TOTALAPPCOST = COSTPERAPP * TOTALAPPS;
	END;

	IF BOOKED = 1 AND AFFILIATE = 'Super Money' THEN DO;
		COSTPERLOAN = 0;
		TOTALLOANCOST = COSTPERLOAN * BOOKED;
	END;

	IF 0 <= CRSCORE <= 499 THEN FICO_25PT_BOOKED = "0-499";
	IF 500 <= CRSCORE <= 524 THEN FICO_25PT_BOOKED = "500-524";
	IF 525 <= CRSCORE <= 549 THEN FICO_25PT_BOOKED = "525-549";
	IF 550 <= CRSCORE <= 574 THEN FICO_25PT_BOOKED = "550-574";
	IF 575 <= CRSCORE <= 599 THEN FICO_25PT_BOOKED = "575-599";
	IF 600 <= CRSCORE <= 624 THEN FICO_25PT_BOOKED = "600-624";
	IF 625 <= CRSCORE <= 649 THEN FICO_25PT_BOOKED = "625-649";
	IF 650 <= CRSCORE <= 674 THEN FICO_25PT_BOOKED = "650-674";
	IF 675 <= CRSCORE <= 699 THEN FICO_25PT_BOOKED = "675-699";
	IF 700 <= CRSCORE <= 724 THEN FICO_25PT_BOOKED = "700-724";
	IF 725 <= CRSCORE <= 749 THEN FICO_25PT_BOOKED = "725-749";
	IF 750 <= CRSCORE <= 774 THEN FICO_25PT_BOOKED = "750-774";
	IF 775 <= CRSCORE <= 799 THEN FICO_25PT_BOOKED = "775-799";
	IF 800 <= CRSCORE <= 824 THEN FICO_25PT_BOOKED = "800-824";
	IF 825 <= CRSCORE <= 849 THEN FICO_25PT_BOOKED = "825-849";
	IF 850 <= CRSCORE <= 874 THEN FICO_25PT_BOOKED = "850-874";
	IF 875 <= CRSCORE <= 899 THEN FICO_25PT_BOOKED = "875-899";
	IF 975 <= CRSCORE <= 999 THEN FICO_25PT_BOOKED = "975-999";
	IF CRSCORE = "" THEN FICO_25PT_BOOKED = "Missing";

	IF 0 <= APPFICO <= 499 THEN FICO_25PT_APP = "0-499";
	IF 500 <= APPFICO <= 524 THEN FICO_25PT_APP = "500-524";
	IF 525 <= APPFICO <= 549 THEN FICO_25PT_APP = "525-549";
	IF 550 <= APPFICO <= 574 THEN FICO_25PT_APP = "550-574";
	IF 575 <= APPFICO <= 599 THEN FICO_25PT_APP = "575-599";
	IF 600 <= APPFICO <= 624 THEN FICO_25PT_APP = "600-624";
	IF 625 <= APPFICO <= 649 THEN FICO_25PT_APP = "625-649";
	IF 650 <= APPFICO <= 674 THEN FICO_25PT_APP = "650-674";
	IF 675 <= APPFICO <= 699 THEN FICO_25PT_APP = "675-699";
	IF 700 <= APPFICO <= 724 THEN FICO_25PT_APP = "700-724";
	IF 725 <= APPFICO <= 749 THEN FICO_25PT_APP = "725-749";
	IF 750 <= APPFICO <= 774 THEN FICO_25PT_APP = "750-774";
	IF 775 <= APPFICO <= 799 THEN FICO_25PT_APP = "775-799";
	IF 800 <= APPFICO <= 824 THEN FICO_25PT_APP = "800-824";
	IF 825 <= APPFICO <= 849 THEN FICO_25PT_APP = "825-849";
	IF 850 <= APPFICO <= 874 THEN FICO_25PT_APP = "850-874";
	IF 875 <= APPFICO <= 899 THEN FICO_25PT_APP = "875-899";
	IF 975 <= APPFICO <= 999 THEN FICO_25PT_APP = "975-999";
	IF APPFICO = "" THEN FICO_25PT_APP = "Missing";
	WORKPHONE = COMPRESS(WORKPHONE, "null");
RUN;

PROC SORT 
	DATA = VP_LIST;
	BY OWNBR;
RUN;

PROC SORT 
	DATA = FINAL;
	BY OWNBR;
RUN;

DATA FINAL;
	MERGE FINAL(IN = x) VP_LIST;
	BY OWNBR;
	IF x;
RUN;

DATA &NEW_MONTH_FILE;
	SET FINAL;
	TOTALCOST = TOTALAPPCOST + TOTALLOANCOST;
RUN;

PROC SORT 
	DATA = FINAL;
	BY SOURCE;
RUN;

*** COPY INFORMATION INTO WEB REPORTING WORKBOOK, TABS:            ***;
*** "DUPLICATES" AND "APPLICATIONS" ------------------------------ ***;
ODS EXCEL OPTIONS(SHEET_INTERVAL = 'none');

PROC TABULATE 
	DATA = MADES_B;
	CLASS AFFILIATE;
	TABLES AFFILIATE ALL, n/NOCELLMERGE;
RUN;

PROC TABULATE 
	DATA = MADES_C;
	CLASS AFFILIATE;
	TABLES AFFILIATE ALL, n/NOCELLMERGE;
RUN;

PROC TABULATE 
	DATA = FINAL;
	CLASS APPSTATE;
	TABLES APPSTATE ALL, n/NOCELLMERGE;
	BY SOURCE;
	LABEL APPSTATE = "State";
RUN;

ODS EXCEL CLOSE;

*** CHECK THAT ALL BOOKED LOANS HAVE OWNBR AND VP INFO             ***;
*** CHECK THAT ALL OWNBR HAVE VP INFO                              ***;
*** CHECK THAT ALL OBS WITH VP INFO HAVE OWNBR INFO -------------- ***;
