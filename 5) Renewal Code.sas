﻿%LET LOAN_ENTDATE_BEGIN1 = "2010-01-01"; /* DO NOT CHANGE */
%LET LOAN_ENTDATE_END1 = "2018-08-31"; /* CHANGE TO END OF THE MONTH */

*** PULL LOAN TABLE ---------------------------------------------- ***;
DATA VW_LOANTABLE;
	SET DW.VW_LOAN(
		KEEP = SSNO1_RT7 BRACCTNO ID OWNBR SSNO1 SSNO2 LNAMT FINCHG
			   LOANTYPE LOANDATE ENTDATE CLASSID CLASSTRANSLATION
			   NETLOANAMOUNT ORGST APRATE SRCD POCD POFFDATE PLDATE
			   PRLNNO PLAMT BNKRPTDATE CONPROFILE1 CONPROFILE2
			   DATEPAIDLAST PLCD ORGBR AMTPAIDLAST OLDACCTNO LASTPYAMT);
	WHERE &LOAN_ENTDATE_BEGIN1. <= ENTDATE <= &LOAN_ENTDATE_END1.;
	ENTDATE_SAS = INPUT(ENTDATE, yymmdd10.);
	FORMAT ENTDATE_SAS dAte9.;
	IF POCD = "**" THEN DELETE;
	IF POCD = "BT" THEN DELETE;
RUN;

*** SUBSET FOR CURRENT MONTH BOOKINGS ---------------------------- ***;
PROC SQL;
	CREATE TABLE MONTH_BOOK AS
	SELECT * FROM ALL_APPS_3 WHERE ENTYRMONTH IN (201808); /* CHANGE */
QUIT;

*** SUBSET FOR NON 'NB' AND 'FB' CUSTOMER TYPE ------------------- ***;
PROC SQL;
	CREATE TABLE ALL_APP4 AS
	SELECT ENTYRMONTH, 
		   BRACCTNO, 
		   NETLOANAMOUNT, 
		   CLASSTRANSLATION AS CLASSTRANSLATION1 
	FROM MONTH_BOOK 
	WHERE SRCD NOT IN ('NB', 'FB') AND 
		  ENTYRMONTH IN (201808) AND 
		  BOOKED = 1; 
QUIT;

*** CHECKS ------------------------------------------------------- ***;
PROC SQL;
	CREATE TABLE ABC AS 
	SELECT ENTYRMONTH, 
		   COUNT(*) 
	FROM ALL_APP4 
	GROUP BY 1;
QUIT;

*** QC ------------------------------------------------------------ ***;
PROC SQL;
	SELECT ENTYRMONTH, 
		   SUM(BOOKED) 
	FROM MONTH_BOOK 
	WHERE APPYRMONTH IN (201808) GROUP BY 1; /* CHANGE */
QUIT;

*** JOIN WITH LOAN TABLE ----------------------------------------- ***;
PROC SQL;
	CREATE TABLE ALL_APP5 AS 
	SELECT A.*, 
		   B.SSNO1,
		   B.NETLOANAMOUNT AS NETLOANAMOUNT_B, 
		   B.OWNBR, 
		   B.CLASSID, 
		   B.CLASSTRANSLATION, 
		   B.POCD, 
		   B.PLCD, 
		   B.PLDATE, 
		   B.POFFDATE, 
		   B.LNAMT, 
		   B.FINCHG, 
		   B.PRLNNO, 
		   B.AMTPAIDLAST, 
		   B.OLDACCTNO, 
		   B.ORGBR,
		   B.LOANTYPE AS LOANTYPE_PI,
		   B.ORGST 
	FROM ALL_APP4 A 
	LEFT JOIN VW_LOANTABLE B ON A.BRACCTNO = B.BRACCTNO;
QUIT;

*** FINDING OLD BRACCTNO ----------------------------------------- ***;
PROC SQL;
	CREATE TABLE ALL_APP6 AS
	SELECT *,
		   CASE WHEN LENGTH(OWNBR) = 1 THEN '000' || OWNBR
				WHEN LENGTH(OWNBR) = 2 THEN '00' || OWNBR
				WHEN LENGTH(OWNBR) = 3 THEN '0' || OWNBR
				WHEN LENGTH(OWNBR) = 4 THEN OWNBR
				WHEN LENGTH(OWNBR) > 4 THEN OWNBR 
					ELSE OWNBR 
			END AS NEW_OWNBR FROM ALL_APP5; 
QUIT;

PROC SQL;
	CREATE TABLE ALL_APP7 AS
	SELECT *, 
		   LENGTH(PRLNNO) AS PRLN_LENGTH,
		   CASE WHEN ORGST IN ('OK', 'SC') AND 
					 LENGTH(PRLNNO) = 9 THEN '0' || PRLNNO
				WHEN LENGTH(PRLNNO) = 1 THEN 
					NEW_OWNBR || SUBSTR(('0000000' || PRLNNO), 1, 6)
				WHEN LENGTH(PRLNNO) = 2 THEN 
					NEW_OWNBR || SUBSTR(('000000' || PRLNNO), 1, 6)
				WHEN LENGTH(PRLNNO) = 3 THEN 
					NEW_OWNBR || SUBSTR(('00000' || PRLNNO), 1, 6)
				WHEN LENGTH(PRLNNO) = 4 THEN 
					NEW_OWNBR || SUBSTR(('0000' || PRLNNO), 1, 6)
				WHEN LENGTH(PRLNNO) = 5 THEN 
					NEW_OWNBR || SUBSTR(('000' || PRLNNO), 1, 6)
				WHEN LENGTH(PRLNNO) = 6 THEN 
					NEW_OWNBR || SUBSTR(('00' || PRLNNO), 1, 6)
				WHEN LENGTH(PRLNNO) = 7 THEN 
					NEW_OWNBR || SUBSTR(('0' || PRLNNO), 1, 6)
				WHEN LENGTH(PRLNNO) = 8 THEN 
					NEW_OWNBR || SUBSTR(('' || PRLNNO), 1, 6)
				WHEN LENGTH(PRLNNO) = 9 THEN PRLNNO || '0'
				WHEN LENGTH(PRLNNO) = 10 THEN PRLNNO
				WHEN LENGTH(PRLNNO) = 11 THEN PRLNNO
				WHEN LENGTH(PRLNNO) = 12 THEN PRLNNO
				WHEN LENGTH(PRLNNO) = 22 THEN 
					SUBSTR(PRLNNO, MAX(1, LENGTH(PRLNNO) - 10 + 1), 10)
				WHEN LENGTH(PRLNNO) = 24 THEN 
					SUBSTR(PRLNNO, MAX(1, LENGTH(PRLNNO) - 12 + 1), 12)
				WHEN LENGTH(PRLNNO) = 26 THEN 
					SUBSTR(PRLNNO, MAX(1, LENGTH(PRLNNO) - 12 + 1), 12)
				WHEN LENGTH(PRLNNO) = 28 THEN 
					SUBSTR(PRLNNO, MAX(1, LENGTH(PRLNNO) - 12 + 1), 12)
				WHEN LENGTH(PRLNNO) >= 34 THEN 
					SUBSTR(PRLNNO, MAX(1, LENGTH(PRLNNO) - 10 + 1), 10) 
				ELSE PRLNNO 
			END AS OLD_BRACCTNO 
	FROM ALL_APP6;
QUIT;

*** FINAL DATASET WITH RENEWED LOANS ----------------------------- ***; 
PROC SQL;
	CREATE TABLE ALL_APP8 AS 
	SELECT A.ENTYRMONTH, 
		   A.BRACCTNO AS RENEW_BRACCTNO, 
		   A.NETLOANAMOUNT_B AS RENEW_NETLOANAMOUNT,
		   A.CLASSTRANSLATION,
		   A.AMTPAIDLAST,
		   A.ORGST,
		   A.OLD_BRACCTNO AS OLD_BRACCTNO1,
		   B.BRACCTNO AS OLD_BRACCTNO,
		   B.SRCD AS OLD_SRCD,
		   B.CLASSID  AS OLD_CLASSID,
		   B.AMTPAIDLAST AS OLD_AMTPAIDLAST
	FROM ALL_APP7 A 
	LEFT JOIN VW_LOANTABLE B ON A.OLD_BRACCTNO = B.BRACCTNO; 
QUIT;

DATA ALL_APP9;
	SET ALL_APP8;
	RENEW_AMT = SUM(RENEW_NETLOANAMOUNT, -OLD_AMTPAIDLAST);
RUN;

PROC EXPORT 
	DATA = ALL_APP9 
	OUTFILE = "&MAIN_DIR\ALL_APP9.xlsx" 
	DBMS = EXCEL 
	REPLACE;
RUN;

PROC SQL;
	CREATE TABLE ABC AS 
	SELECT ENTYRMONTH,
		   COUNT(*), 
		   SUM(RENEW_AMT) 
	FROM ALL_APP9 
	WHERE OLD_BRACCTNO IS NOT NULL AND RENEW_AMT > 0
	GROUP BY 1; 
QUIT; 

PROC SQL; 
	SELECT SUM(RENEW_AMT) 
	FROM ALL_APP9 ; 
QUIT;

PROC SQL;
	CREATE TABLE ALL_APP10 AS 
	SELECT A.*, 
		   B.OLD_BRACCTNO1, 
		   B.RENEW_BRACCTNO,
		   B.RENEW_NETLOANAMOUNT,
		   B.OLD_AMTPAIDLAST,
		   B.RENEW_AMT
	FROM ALL_APPS_3 A 
	LEFT JOIN ALL_APP9 B ON A.BRACCTNO = B.RENEW_BRACCTNO; 
QUIT;

PROC SQL;
	CREATE TABLE CHK1 AS 
	SELECT * 
	FROM ALL_APP10 
	WHERE BOOKED = 1 AND 
		  RENEW_BRACCTNO IS NOT NULL AND 
		  APPYRMONTH IN (201808); 
QUIT;