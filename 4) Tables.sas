﻿%LET APPMONTH = 03;
%LET APPYRMONTH = 201903;
%LET BOOK_MONTH = 03;

TITLE;

PROC FORMAT;
	PICTURE PCTPIC(ROUND) LOW - HIGH = '09.00%';
RUN; 

PROC SORT 
	DATA = ALL_APPS_3;
	BY SOURCE;
RUN;

ODS EXCEL OPTIONS(SHEET_INTERVAL = "None");
TITLE "Month Summary";

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE ALL, 
		   TOTALAPPS * F = comma18.0
		   PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		   PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F
			= PCTPIC. / NOCELLMERGE;
	WHERE APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE ALL, 
		   BOOKED = "Booked" * F = comma18.0 
		   NETLOANAMOUNT = "$ Booked" * F = dollar18.0 
		   NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0
			/ NOCELLMERGE;
	WHERE BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

TITLE "Web Apps";

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE ALL, 
		   TOTALAPPS * F = comma18.0 
		   PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		   PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F
			= PCTPIC. / NOCELLMERGE;
	BY SOURCE APPMONTH;
	WHERE SOURCE = 'Web Apps' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE ALL, 
		   BOOKED = "BOOKED" * F = comma18.0 
		   NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		   NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0
			/ NOCELLMERGE;
	WHERE SOURCE = 'Web Apps' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

TITLE "Lending Tree";

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE ALL, 
		   TOTALAPPS * F = comma18.0 
		   PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		   PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F
			= PCTPIC. / NOCELLMERGE;
	BY SOURCE;
	WHERE SOURCE = 'LendingTree' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE ALL, 
		   BOOKED = "BOOKED" * F = comma18.0 
		   NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		   NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0
			/ NOCELLMERGE;
	WHERE SOURCE = 'LendingTree' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

TITLE "Credit Karma";

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE ALL, 
		   TOTALAPPS * F = comma18.0 
		   PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		   PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F
			= PCTPIC. / NOCELLMERGE;
	BY SOURCE;
	WHERE SOURCE = 'CreditKarma' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE ALL, 
		   BOOKED = "BOOKED" * F = comma18.0 
		   NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		   NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0
			/ NOCELLMERGE;
	WHERE SOURCE = 'CreditKarma' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

TITLE "SuperMoney LLC";

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE ALL, 
		   TOTALAPPS * F = comma18.0 
		   PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		   PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F
			= PCTPIC. / NOCELLMERGE;
	BY SOURCE;
	WHERE SOURCE = 'SuperMoney LLC' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE ALL, 
		   BOOKED = "BOOKED" * F = comma18.0 
		   NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		   NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0
			/ NOCELLMERGE;
	WHERE SOURCE = 'SuperMoney LLC' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

ODS EXCEL CLOSE;

*** BY VP AND SUPERVISOR ----------------------------------------- ***;
%LET APPMONTH = 03;
%LET APPYRMONTH = 201903;
%LET BOOK_MONTH = 03;

PROC SORT 
	DATA = ALL_APPS_3;
	BY VP;
RUN;

ODS EXCEL OPTIONS(SHEET_INTERVAL="NONE");

TITLE "Web Apps";

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPYRMONTH, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'Web Apps' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPYRMONTH * SUPERVISOR ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	BY VP;
	WHERE SOURCE = 'Web Apps' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA=ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP BOOKED_MONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES BOOKED_MONTH * SUPERVISOR ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0/NOCELLMERGE;
	BY VP;
	WHERE SOURCE = 'Web Apps' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

ODS EXCEL CLOSE;
ODS EXCEL OPTIONS(SHEET_INTERVAL="NONE");

TITLE "Lending Tree";

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPYRMONTH, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'LendingTree' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPYRMONTH * SUPERVISOR ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	BY VP;
	WHERE SOURCE = 'LendingTree' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP BOOKED_MONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES BOOKED_MONTH * SUPERVISOR ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0/NOCELLMERGE;
	BY VP;
	WHERE SOURCE = 'LendingTree' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

ODS EXCEL CLOSE;
ODS EXCEL OPTIONS(SHEET_INTERVAL="NONE");

TITLE "Credit Karma";

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPYRMONTH, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'CreditKarma' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPYRMONTH * SUPERVISOR ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	BY VP;
	WHERE SOURCE = 'CreditKarma' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP BOOKED_MONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES BOOKED_MONTH * SUPERVISOR ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0/NOCELLMERGE;
	BY VP;
	WHERE SOURCE = 'CreditKarma' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

ODS EXCEL CLOSE;
ODS EXCEL OPTIONS(SHEET_INTERVAL="NONE");

TITLE "SuperMoney LLC";

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPYRMONTH, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'SuperMoney LLC' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP APPYRMONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPYRMONTH * SUPERVISOR ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	BY VP;
	WHERE SOURCE = 'SuperMoney LLC' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3 MISSING;
	CLASS SUPERVISOR VP BOOKED_MONTH APPSTATE;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES BOOKED_MONTH * SUPERVISOR ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0/NOCELLMERGE;
	BY VP;
	WHERE SOURCE = 'SuperMoney LLC' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

ODS EXCEL CLOSE;

*** BY AMTBUCKET ------------------------------------------------- ***;
%LET APPMONTH = 03;
%LET APPYRMONTH = 201903;
%LET BOOK_MONTH = 03;

ODS EXCEL;
TITLE "Web Apps";

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES AMTBUCKET ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'Web Apps' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES AMTBUCKET ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0 
		NETLOANAMOUNT * min = "Bk Min $" * F = dollar18.0 
		NETLOANAMOUNT * max = "Bk Max $" * F = dollar18.0/NOCELLMERGE;
	WHERE SOURCE = 'Web Apps' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE * AMTBUCKET ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'Web Apps' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE * AMTBUCKET ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0 
		NETLOANAMOUNT * min = "Bk Min $" * F = dollar18.0 
		NETLOANAMOUNT * max = "Bk Max $" * F = dollar18.0/NOCELLMERGE;
	WHERE SOURCE = 'Web Apps' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

ODS EXCEL CLOSE;

*** BY AMTBUCKET ------------------------------------------------- ***;
%LET APPMONTH = 03;
%LET APPYRMONTH = 201903;
%LET BOOK_MONTH = 03;

ODS EXCEL;
TITLE "Lending Tree";

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES AMTBUCKET ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'LendingTree' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES AMTBUCKET ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0 
		NETLOANAMOUNT * min = "Bk Min $" * F = dollar18.0 
		NETLOANAMOUNT * max = "Bk Max $" * F = dollar18.0/NOCELLMERGE;
	WHERE SOURCE = 'LendingTree' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE * AMTBUCKET ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'LendingTree' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE * AMTBUCKET ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0 
		NETLOANAMOUNT * min = "Bk Min $" * F = dollar18.0 
		NETLOANAMOUNT * max = "Bk Max $" * F = dollar18.0/NOCELLMERGE;
	WHERE SOURCE = 'LendingTree' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

ODS EXCEL CLOSE;

*** BY AMTBUCKET ------------------------------------------------- ***;
%LET APPMONTH = 03;
%LET APPYRMONTH = 201903;
%LET BOOK_MONTH = 03;

ODS EXCEL;
TITLE "Credit Karma";

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES AMTBUCKET ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'CreditKarma' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES AMTBUCKET ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0 
		NETLOANAMOUNT * min = "Bk Min $" * F = dollar18.0 
		NETLOANAMOUNT * max = "Bk Max $" * F = dollar18.0/NOCELLMERGE;
	WHERE SOURCE = 'CreditKarma' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE * AMTBUCKET ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'CreditKarma' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE * AMTBUCKET ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0 
		NETLOANAMOUNT * min = "Bk Min $" * F = dollar18.0 
		NETLOANAMOUNT * max = "Bk Max $" * F = dollar18.0/NOCELLMERGE;
	WHERE SOURCE = 'CreditKarma' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

ODS EXCEL CLOSE;

*** BY AMTBUCKET ------------------------------------------------- ***;
%LET APPMONTH = 03;
%LET APPYRMONTH = 201903;
%LET BOOK_MONTH = 03;

ODS EXCEL;
TITLE "SuperMoney LLC";

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES AMTBUCKET ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'SuperMoney LLC' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES AMTBUCKET ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0 
		NETLOANAMOUNT * min = "Bk Min $" * F = dollar18.0 
		NETLOANAMOUNT * max = "Bk Max $" * F = dollar18.0/NOCELLMERGE;
	WHERE SOURCE = 'SuperMoney LLC' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE * AMTBUCKET ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	WHERE SOURCE = 'SuperMoney LLC' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE AMTBUCKET;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE * AMTBUCKET ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0 
		NETLOANAMOUNT * min = "Bk Min $" * F = dollar18.0 
		NETLOANAMOUNT * max = "Bk Max $" * F = dollar18.0/NOCELLMERGE;
	WHERE SOURCE = 'SuperMoney LLC' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;

ODS EXCEL CLOSE;

*** LT FILTER ROUTING ID ----------------------------------------- ***;
TITLE;

PROC FORMAT;
	PICTURE PCTPIC (ROUND) LOW-HIGH='09.00%';
RUN; 

PROC SORT 
	DATA = ALL_APPS_3;
	BY SOURCE;
RUN;

ODS EXCEL OPTIONS(SHEET_INTERVAL = "NONE");
TITLE "Lending Tree";

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS APPYRMONTH APPSTATE LTFILTER_ROUTINGID;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE * LTFILTER_ROUTINGID ALL, 
		TOTALAPPS * F = comma18.0 
		PREAPPROVED_FLAG = "# Auto Apprv" * F = comma18.0 
		PREAPPROVED_FLAG = "% approve" * ROWPCTSUM < TOTALAPPS > * F = PCTPIC./NOCELLMERGE;
	BY SOURCE;
	WHERE SOURCE = 'LendingTree' & APPYRMONTH = &APPYRMONTH;
RUN;

PROC TABULATE 
	DATA = ALL_APPS_3;
	CLASS BOOKED_MONTH APPSTATE LTFILTER_ROUTINGID;
	VAR TOTALAPPS PREAPPROVED_FLAG BOOKED NETLOANAMOUNT;
	TABLES APPSTATE * LTFILTER_ROUTINGID ALL, 
		BOOKED = "BOOKED" * F = comma18.0 
		NETLOANAMOUNT = "$ BOOKED" * F = dollar18.0 
		NETLOANAMOUNT * MEAN = "avg adv" * F = dollar18.0/NOCELLMERGE;
	WHERE SOURCE = 'LendingTree' & BOOKED_MONTH = &BOOK_MONTH & ENTYRMONTH = &APPYRMONTH;
RUN;
ODS EXCEL CLOSE;


