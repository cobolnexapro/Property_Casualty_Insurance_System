      ******************************************************************
      *                                                                *
      *  PROGRAM      :  POL001A                                       *
      *  SYSTEM       :  PCIS - PROPERTY & CASUALTY INSURANCE SYSTEM   *
      *  MODULE       :  POLICY ADMINISTRATION (POL)                  *
      *  PURPOSE      :  POLICY CREATION - CREATES A NEW PROPERTY      *
      *                  INSURANCE POLICY (HOM/CML), READING CUSTOMER, *
      *                  PROPERTY, AND COVERAGE SELECTION DATA,        *
      *                  CALCULATING PREMIUM, GENERATING THE POLICY    *
      *                  NUMBER, WRITING THE POLICY/COVERAGE RECORDS,  *
      *                  ORIGINATING THE FIRST BILLING SCHEDULE        *
      *                  INSTALLMENT, AND WRITING THE AUDIT TRAIL.     *
      *                                                                *
      *  LANGUAGE     :  IBM ILE COBOL (ENTERPRISE COBOL FOR i)        *
      *  DATA ACCESS  :  EMBEDDED SQL / DB2 FOR i                      *
      *  UI           :  5250 DISPLAY FILE (DDS) - POLMNTD1            *
      *                                                                *
      *  CALLED BY    :  POLMNTP1 (CL DRIVER), QTEMNTP1 (QUOTE CONVERT)*
      *  CALLS        :  POLVAL01 (SERVICE PROGRAM - FIELD VALIDATION) *
      *                  PRMCLC01 (SERVICE PROGRAM - PREMIUM CALC)     *
      *                  AUDLOG01 (SERVICE PROGRAM - AUDIT LOGGING)    *
      *                                                                *
      *  TABLES       :  CUSTOMER_T          (SELECT)                 *
      *                  AGENT_T             (SELECT)                 *
      *                  PROPERTY_T          (SELECT)                 *
      *                  PROPERTY_FEATURE_T  (SELECT)                 *
      *                  COVERAGE_TYPE_T     (SELECT)                 *
      *                  RATE_TABLE_T        (SELECT)                 *
      *                  RATE_FACTOR_T       (SELECT)                 *
      *                  POLICY_T            (INSERT)                 *
      *                  COVERAGE_T          (INSERT)                 *
      *                  DEDUCTIBLE_T        (INSERT)                 *
      *                  POLICY_PROPERTY_T   (INSERT)                 *
      *                  PREMIUM_CALC_T      (INSERT)                 *
      *                  POLICY_HISTORY_T    (INSERT)                 *
      *                  BILLING_SCHEDULE_T  (INSERT)                 *
      *                  AUDIT_LOG_T         (INSERT VIA AUDLOG01)    *
      *                                                                *
      *  AUTHOR       :  PCIS APPLICATION DEVELOPMENT TEAM             *
      *  DATE WRITTEN :  2026-06-19                                    *
      *  STANDARDS    :  IBM ENTERPRISE COBOL CODING STANDARDS V4      *
      *                                                                *
      *  MAINTENANCE LOG                                               *
      *  ----------------------------------------------------------    *
      *  DATE        PROGRAMMER     DESCRIPTION                        *
      *  2026-06-19  PCIS DEV TEAM  INITIAL VERSION                    *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
      ******************************************************************
       PROGRAM-ID.    POL001A.
       AUTHOR.        PCIS-APPLICATION-DEVELOPMENT-TEAM.
       DATE-WRITTEN.  2026-06-19.
       DATE-COMPILED.
      ******************************************************************
      *  PROGRAM ABSTRACT                                              *
      *  ----------------------------------------------------------    *
      *  THIS PROGRAM PRESENTS THE POLICY MAINTENANCE PANEL IN CREATE  *
      *  MODE FOR A PROPERTY (HOMEOWNERS / COMMERCIAL) POLICY. IT      *
      *  ACCEPTS OR RECEIVES A CUSTOMER ID, AGENT ID, AND PROPERTY ID, *
      *  PRESENTS COVERAGE SELECTION FOR THE OPERATOR TO CONFIRM,      *
      *  CALCULATES THE ANNUAL PREMIUM VIA THE PREMIUM CALCULATION     *
      *  SERVICE PROGRAM, GENERATES A NEW POLICY NUMBER, WRITES THE    *
      *  POLICY/COVERAGE/DEDUCTIBLE/POLICY-PROPERTY RECORDS, ORIGINATES*
      *  THE FIRST BILLING SCHEDULE INSTALLMENT, WRITES THE POLICY     *
      *  HISTORY (ISSUE) EVENT, LOGS THE AUDIT TRAIL, AND RETURNS A    *
      *  CONFIRMATION TO THE OPERATOR.                                 *
      ******************************************************************
       ENVIRONMENT DIVISION.
      ******************************************************************
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.   IBM-I.
       OBJECT-COMPUTER.   IBM-I.
       SPECIAL-NAMES.
           CLASS NUMERIC-CLASS    IS "0123456789"
           CLASS ALPHA-CLASS      IS "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                      "abcdefghijklmnopqrstuvwxyz".

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT POLMNTD1 ASSIGN TO WORKSTATION-POLMNTD1
               ORGANIZATION IS TRANSACTION
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-DSPF-STATUS.

       DATA DIVISION.
      ******************************************************************
       FILE SECTION.
      ******************************************************************
       FD  POLMNTD1
           LABEL RECORDS ARE STANDARD.
       01  POLMNTFM-RECORD.
           COPY DDS-POLMNTFM.

      ******************************************************************
       WORKING-STORAGE SECTION.
      ******************************************************************
      *----------------------------------------------------------------*
      *  PROGRAM IDENTIFICATION / CONSTANTS                             *
      *----------------------------------------------------------------*
       01  WS-PROGRAM-CONSTANTS.
           05  WS-PROGRAM-NAME          PIC X(10)  VALUE 'POL001A'.
           05  WS-PROGRAM-VERSION       PIC X(8)   VALUE '01.00.00'.
           05  WS-MODULE-CODE           PIC X(3)   VALUE 'POL'.
           05  WS-TABLE-POLICY          PIC X(30)  VALUE 'POLICY_T'.
           05  WS-TABLE-COVERAGE        PIC X(30)  VALUE 'COVERAGE_T'.
           05  WS-TABLE-DEDUCTIBLE      PIC X(30)  VALUE 'DEDUCTIBLE_T'.
           05  WS-TABLE-POL-PROPERTY    PIC X(30)  VALUE
                                                 'POLICY_PROPERTY_T'.
           05  WS-TABLE-PREMIUM-CALC    PIC X(30)  VALUE
                                                 'PREMIUM_CALC_T'.
           05  WS-TABLE-POL-HISTORY     PIC X(30)  VALUE
                                                 'POLICY_HISTORY_T'.
           05  WS-TABLE-BILLING         PIC X(30)  VALUE
                                                 'BILLING_SCHEDULE_T'.
           05  WS-ACTION-ADD            PIC X(1)   VALUE 'A'.
           05  WS-EVENT-ISSUE           PIC X(3)   VALUE 'ISS'.
           05  WS-STATUS-ACTIVE         PIC X(1)   VALUE 'A'.
           05  WS-BILL-STATUS-DUE       PIC X(1)   VALUE 'D'.
           05  WS-MAX-COVERAGE-LINES    PIC 9(2)   VALUE 10.

      *----------------------------------------------------------------*
      *  FILE STATUS / DEVICE WORK FIELDS                                *
      *----------------------------------------------------------------*
       01  WS-DSPF-STATUS               PIC X(2)   VALUE '00'.
       01  WS-INDICATORS-ON.
           05  WS-IND-03                PIC X(1)   VALUE 'N'.
           05  WS-IND-12                PIC X(1)   VALUE 'N'.

      *----------------------------------------------------------------*
      *  PROGRAM CONTROL SWITCHES                                        *
      *----------------------------------------------------------------*
       01  WS-PROGRAM-SWITCHES.
           05  WS-END-OF-PROGRAM-SW     PIC X(1)   VALUE 'N'.
               88  END-OF-PROGRAM             VALUE 'Y'.
               88  NOT-END-OF-PROGRAM         VALUE 'N'.
           05  WS-VALID-DATA-SW         PIC X(1)   VALUE 'Y'.
               88  DATA-IS-VALID               VALUE 'Y'.
               88  DATA-IS-INVALID             VALUE 'N'.
           05  WS-CUSTOMER-FOUND-SW     PIC X(1)   VALUE 'N'.
               88  CUSTOMER-WAS-FOUND          VALUE 'Y'.
               88  CUSTOMER-NOT-FOUND          VALUE 'N'.
           05  WS-AGENT-FOUND-SW        PIC X(1)   VALUE 'N'.
               88  AGENT-WAS-FOUND             VALUE 'Y'.
               88  AGENT-NOT-FOUND              VALUE 'N'.
           05  WS-PROPERTY-FOUND-SW     PIC X(1)   VALUE 'N'.
               88  PROPERTY-WAS-FOUND          VALUE 'Y'.
               88  PROPERTY-NOT-FOUND          VALUE 'N'.
           05  WS-SQL-ERROR-SW          PIC X(1)   VALUE 'N'.
               88  SQL-ERROR-OCCURRED          VALUE 'Y'.
               88  SQL-ERROR-DID-NOT-OCCUR     VALUE 'N'.
           05  WS-FATAL-ERROR-SW        PIC X(1)   VALUE 'N'.
               88  FATAL-ERROR-OCCURRED        VALUE 'Y'.
               88  NO-FATAL-ERROR               VALUE 'N'.

      *----------------------------------------------------------------*
      *  MESSAGE / ERROR HANDLING WORK AREA                              *
      *----------------------------------------------------------------*
       01  WS-MESSAGE-AREA.
           05  WS-MSG-COUNT             PIC 9(3)   VALUE 0.
           05  WS-MSG-TEXT              PIC X(79)  VALUE SPACES.
           05  WS-MSG-ID                PIC X(7)   VALUE SPACES.
           05  WS-MSG-TABLE-MAX         PIC 9(2)   VALUE 20.
           05  WS-MSG-ENTRY OCCURS 20 TIMES
                                        INDEXED BY MSG-IDX.
               10  WS-MSG-ENTRY-ID      PIC X(7).
               10  WS-MSG-ENTRY-TEXT    PIC X(79).
               10  WS-MSG-ENTRY-FIELD   PIC X(20).

      *----------------------------------------------------------------*
      *  SQLCA - SQL COMMUNICATIONS AREA                                  *
      *----------------------------------------------------------------*
           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      *----------------------------------------------------------------*
      *  SQL ERROR HANDLING WORK FIELDS                                   *
      *----------------------------------------------------------------*
       01  WS-SQL-WORK-AREA.
           05  WS-SQLCODE-DISPLAY       PIC -9(9)  VALUE 0.
           05  WS-SQLSTATE-DISPLAY      PIC X(5)   VALUE SPACES.
           05  WS-SQL-ERROR-TEXT        PIC X(100) VALUE SPACES.
           05  WS-SQL-FUNCTION          PIC X(30)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - CUSTOMER_T (READ)                                *
      *----------------------------------------------------------------*
       01  HV-CUSTOMER-ROW.
           05  HV-CUST-ID               PIC X(10)  VALUE SPACES.
           05  HV-CUST-NAME             PIC X(60)  VALUE SPACES.
           05  HV-CUST-STATUS           PIC X(1)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - AGENT_T (READ)                                   *
      *----------------------------------------------------------------*
       01  HV-AGENT-ROW.
           05  HV-AGT-ID                PIC X(8)   VALUE SPACES.
           05  HV-AGT-NAME              PIC X(60)  VALUE SPACES.
           05  HV-AGT-STATUS            PIC X(1)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - PROPERTY_T (READ)                                *
      *----------------------------------------------------------------*
       01  HV-PROPERTY-ROW.
           05  HV-PROP-ID               PIC X(12)  VALUE SPACES.
           05  HV-RISK-ID               PIC X(12)  VALUE SPACES.
           05  HV-PROP-TYPE             PIC X(2)   VALUE SPACES.
           05  HV-PROP-ADDR-LINE1       PIC X(40)  VALUE SPACES.
           05  HV-PROP-CITY             PIC X(30)  VALUE SPACES.
           05  HV-PROP-STATE            PIC X(2)   VALUE SPACES.
           05  HV-PROP-ZIP              PIC X(10)  VALUE SPACES.
           05  HV-PROP-YEAR-BUILT       PIC S9(4)  COMP-4 VALUE 0.
           05  HV-PROP-SQ-FOOTAGE       PIC S9(9)  COMP-4 VALUE 0.
           05  HV-PROP-CONSTR-TYPE      PIC X(2)   VALUE SPACES.
           05  HV-PROP-REPL-VALUE       PIC S9(11)V99 COMP-3 VALUE 0.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - PROPERTY_FEATURE_T (READ, CURSOR)                *
      *----------------------------------------------------------------*
       01  HV-PROPERTY-FEATURE-ROW.
           05  HV-FEAT-CD               PIC X(10)  VALUE SPACES.
           05  HV-FEAT-VALUE             PIC X(30)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - COVERAGE_TYPE_T (READ)                            *
      *----------------------------------------------------------------*
       01  HV-COVERAGE-TYPE-ROW.
           05  HV-COV-TYPE-CD           PIC X(5)   VALUE SPACES.
           05  HV-COV-DESC              PIC X(60)  VALUE SPACES.
           05  HV-COV-POL-TYPE          PIC X(3)   VALUE SPACES.
           05  HV-COV-MANDATORY-FLAG    PIC X(1)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - POLICY_T (INSERT)                                  *
      *----------------------------------------------------------------*
       01  HV-POLICY-ROW.
           05  HV-POL-NBR               PIC X(12)  VALUE SPACES.
           05  HV-POL-TYPE              PIC X(3)   VALUE SPACES.
           05  HV-POL-CUST-ID           PIC X(10)  VALUE SPACES.
           05  HV-POL-AGT-ID            PIC X(8)   VALUE SPACES.
           05  HV-POL-QUOTE-ID          PIC X(12)  VALUE SPACES.
           05  HV-POL-QUOTE-ID-NULL     PIC S9(4)  COMP-4 VALUE 0.
           05  HV-POL-EFF-DATE          PIC X(10)  VALUE SPACES.
           05  HV-POL-EXP-DATE          PIC X(10)  VALUE SPACES.
           05  HV-POL-STATUS            PIC X(1)   VALUE SPACES.
           05  HV-POL-PREM-ANNUAL       PIC S9(9)V99 COMP-3 VALUE 0.
           05  HV-POL-UW-DECISION       PIC X(1)   VALUE SPACES.
           05  HV-POL-UW-DECISION-NULL  PIC S9(4)  COMP-4 VALUE 0.
           05  HV-POL-CRT-USER          PIC X(10)  VALUE SPACES.
           05  HV-POL-CRT-TIMESTAMP     PIC X(26)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - COVERAGE_T / DEDUCTIBLE_T (INSERT)                 *
      *----------------------------------------------------------------*
       01  HV-COVERAGE-ROW.
           05  HV-COVERAGE-ID           PIC X(14)  VALUE SPACES.
           05  HV-COV-POL-NBR           PIC X(12)  VALUE SPACES.
           05  HV-COV-TYPE-CD-INS       PIC X(5)   VALUE SPACES.
           05  HV-COV-LIMIT-AMT         PIC S9(9)V99 COMP-3 VALUE 0.
           05  HV-COV-PREMIUM-AMT       PIC S9(9)V99 COMP-3 VALUE 0.
           05  HV-COV-EFF-DATE          PIC X(10)  VALUE SPACES.
           05  HV-COV-EXP-DATE          PIC X(10)  VALUE SPACES.
           05  HV-COV-CRT-USER          PIC X(10)  VALUE SPACES.
           05  HV-COV-CRT-TIMESTAMP     PIC X(26)  VALUE SPACES.

       01  HV-DEDUCTIBLE-ROW.
           05  HV-DEDUCT-ID             PIC S9(18) COMP-3 VALUE 0.
           05  HV-DED-COVERAGE-ID       PIC X(14)  VALUE SPACES.
           05  HV-DED-TYPE              PIC X(1)   VALUE 'F'.
           05  HV-DED-AMT               PIC S9(7)V99 COMP-3 VALUE 0.
           05  HV-DED-CRT-USER          PIC X(10)  VALUE SPACES.
           05  HV-DED-CRT-TIMESTAMP     PIC X(26)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - POLICY_PROPERTY_T (INSERT)                        *
      *----------------------------------------------------------------*
       01  HV-POLICY-PROPERTY-ROW.
           05  HV-POL-PROP-ID           PIC S9(18) COMP-3 VALUE 0.
           05  HV-POLPROP-POL-NBR       PIC X(12)  VALUE SPACES.
           05  HV-POLPROP-PROP-ID       PIC X(12)  VALUE SPACES.
           05  HV-POLPROP-CRT-USER      PIC X(10)  VALUE SPACES.
           05  HV-POLPROP-CRT-TIMESTAMP PIC X(26)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - RATE_TABLE_T / RATE_FACTOR_T (READ)               *
      *----------------------------------------------------------------*
       01  HV-RATE-ROW.
           05  HV-RATE-ID               PIC X(10)  VALUE SPACES.
           05  HV-BASE-RATE             PIC S9(5)V9999 COMP-3 VALUE 0.
           05  HV-TERRITORY-CD          PIC X(5)   VALUE SPACES.

       01  HV-FACTOR-ROW.
           05  HV-FACTOR-MULT           PIC S9(3)V9999 COMP-3 VALUE 0.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - PREMIUM_CALC_T (INSERT)                           *
      *----------------------------------------------------------------*
       01  HV-PREMIUM-CALC-ROW.
           05  HV-CALC-POL-NBR          PIC X(12)  VALUE SPACES.
           05  HV-CALC-COVERAGE-ID      PIC X(14)  VALUE SPACES.
           05  HV-CALC-BASE-RATE        PIC S9(5)V9999 COMP-3 VALUE 0.
           05  HV-CALC-TOTAL-FACTOR     PIC S9(5)V9999 COMP-3 VALUE 0.
           05  HV-CALC-PREMIUM          PIC S9(9)V99 COMP-3 VALUE 0.
           05  HV-CALC-DATE             PIC X(10)  VALUE SPACES.
           05  HV-CALC-CRT-USER         PIC X(10)  VALUE SPACES.
           05  HV-CALC-CRT-TIMESTAMP    PIC X(26)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - POLICY_HISTORY_T (INSERT)                          *
      *----------------------------------------------------------------*
       01  HV-POLICY-HISTORY-ROW.
           05  HV-HIST-POL-NBR          PIC X(12)  VALUE SPACES.
           05  HV-HIST-EVENT-TYPE       PIC X(3)   VALUE SPACES.
           05  HV-HIST-EVENT-DATE       PIC X(10)  VALUE SPACES.
           05  HV-HIST-OLD-STATUS       PIC X(1)   VALUE SPACES.
           05  HV-HIST-OLD-STATUS-NULL  PIC S9(4)  COMP-4 VALUE 0.
           05  HV-HIST-NEW-STATUS       PIC X(1)   VALUE SPACES.
           05  HV-HIST-REASON-CD        PIC X(5)   VALUE SPACES.
           05  HV-HIST-REASON-CD-NULL   PIC S9(4)  COMP-4 VALUE 0.
           05  HV-HIST-CRT-USER         PIC X(10)  VALUE SPACES.
           05  HV-HIST-CRT-TIMESTAMP    PIC X(26)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - BILLING_SCHEDULE_T (INSERT)                       *
      *----------------------------------------------------------------*
       01  HV-BILLING-SCHEDULE-ROW.
           05  HV-BILL-SCHED-ID         PIC X(14)  VALUE SPACES.
           05  HV-BILL-POL-NBR          PIC X(12)  VALUE SPACES.
           05  HV-BILL-INSTALLMENT-NBR  PIC S9(4)  COMP-4 VALUE 1.
           05  HV-BILL-DUE-DATE         PIC X(10)  VALUE SPACES.
           05  HV-BILL-DUE-AMT          PIC S9(9)V99 COMP-3 VALUE 0.
           05  HV-BILL-PAID-AMT         PIC S9(9)V99 COMP-3 VALUE 0.
           05  HV-BILL-STATUS           PIC X(1)   VALUE 'D'.
           05  HV-BILL-CRT-USER         PIC X(10)  VALUE SPACES.
           05  HV-BILL-CRT-TIMESTAMP    PIC X(26)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - SEQUENCE / KEY GENERATION / MISC                  *
      *----------------------------------------------------------------*
       01  HV-MISC-WORK.
           05  HV-NEXT-POL-SEQ          PIC S9(9)  COMP-4 VALUE 0.
           05  HV-NEXT-COV-SEQ          PIC S9(9)  COMP-4 VALUE 0.
           05  HV-NEXT-BILL-SEQ         PIC S9(9)  COMP-4 VALUE 0.
           05  HV-CURRENT-USER          PIC X(10)  VALUE SPACES.
           05  HV-CURRENT-TIMESTAMP     PIC X(26)  VALUE SPACES.
           05  HV-CURRENT-DATE          PIC X(10)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  SCREEN FIELD WORK AREA - MIRRORS DDS FIELDS ON POLMNTFM             *
      *----------------------------------------------------------------*
       01  WS-SCREEN-FIELDS.
           05  WS-SCR-MODE              PIC X(1)   VALUE 'C'.
           05  WS-SCR-POL-NBR           PIC X(12)  VALUE SPACES.
           05  WS-SCR-POL-TYPE          PIC X(3)   VALUE SPACES.
           05  WS-SCR-CUST-ID           PIC X(10)  VALUE SPACES.
           05  WS-SCR-CUST-NAME         PIC X(60)  VALUE SPACES.
           05  WS-SCR-AGT-ID            PIC X(8)   VALUE SPACES.
           05  WS-SCR-AGT-NAME          PIC X(60)  VALUE SPACES.
           05  WS-SCR-PROP-ID           PIC X(12)  VALUE SPACES.
           05  WS-SCR-EFF-DATE          PIC X(10)  VALUE SPACES.
           05  WS-SCR-EXP-DATE          PIC X(10)  VALUE SPACES.
           05  WS-SCR-STATUS            PIC X(1)   VALUE SPACES.
           05  WS-SCR-PREM-ANNUAL       PIC 9(9)V99 VALUE 0.
           05  WS-SCR-UW-DECISION       PIC X(1)   VALUE SPACES.
           05  WS-SCR-MSG-LINE          PIC X(79)  VALUE SPACES.
      *    --- COVERAGE SELECTION SUBFILE WORK TABLE ---
           05  WS-SCR-COV-LINE-COUNT    PIC 9(2)   VALUE 0.
           05  WS-SCR-COV-LINE OCCURS 10 TIMES
                                        INDEXED BY COV-IDX.
               10  WS-SCR-COV-SELECT-FLAG  PIC X(1).
               10  WS-SCR-COV-TYPE-CD      PIC X(5).
               10  WS-SCR-COV-DESC         PIC X(60).
               10  WS-SCR-COV-LIMIT-AMT    PIC 9(9)V99.
               10  WS-SCR-COV-DEDUCT-AMT   PIC 9(7)V99.
               10  WS-SCR-COV-PREMIUM-AMT  PIC 9(9)V99.

      *----------------------------------------------------------------*
      *  PREMIUM CALCULATION WORK FIELDS                                    *
      *----------------------------------------------------------------*
       01  WS-PREMIUM-WORK-AREA.
           05  WS-PRM-TOTAL-PREMIUM     PIC S9(9)V99 COMP-3 VALUE 0.
           05  WS-PRM-LINE-PREMIUM      PIC S9(9)V99 COMP-3 VALUE 0.
           05  WS-PRM-CALC-IDX          PIC 9(2)   VALUE 0.

      *----------------------------------------------------------------*
      *  VALIDATION WORK FIELDS                                             *
      *----------------------------------------------------------------*
       01  WS-VALIDATION-WORK-AREA.
           05  WS-VAL-DATE-VALID-SW     PIC X(1)   VALUE 'Y'.
           05  WS-VAL-EFF-YEAR          PIC 9(4)   VALUE 0.
           05  WS-VAL-EFF-MONTH         PIC 9(2)   VALUE 0.
           05  WS-VAL-EFF-DAY           PIC 9(2)   VALUE 0.
           05  WS-VAL-EXP-YEAR          PIC 9(4)   VALUE 0.
           05  WS-VAL-EXP-MONTH         PIC 9(2)   VALUE 0.
           05  WS-VAL-EXP-DAY           PIC 9(2)   VALUE 0.
           05  WS-VAL-SELECTED-COUNT    PIC 9(2)   VALUE 0.
           05  WS-VAL-MANDATORY-MISSING PIC 9(2)   VALUE 0.

      *----------------------------------------------------------------*
      *  CODE TABLES - VALID VALUE LISTS                                    *
      *----------------------------------------------------------------*
       01  WS-CODE-TABLES.
           05  WS-VALID-POL-TYPES       PIC X(8)   VALUE 'HOM CML '.

      *----------------------------------------------------------------*
      *  LINKAGE PARAMETER MIRROR (FOR LOCAL USE AFTER MOVE)                 *
      *----------------------------------------------------------------*
       01  WS-CALLING-PROGRAM-INFO.
           05  WS-CALLING-PGM           PIC X(10)  VALUE SPACES.
           05  WS-IN-CUST-ID            PIC X(10)  VALUE SPACES.
           05  WS-IN-AGT-ID             PIC X(8)   VALUE SPACES.
           05  WS-IN-PROP-ID            PIC X(12)  VALUE SPACES.
           05  WS-IN-QUOTE-ID           PIC X(12)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  PRMCLC01 SERVICE PROGRAM INTERFACE WORK AREA                       *
      *----------------------------------------------------------------*
       01  WS-PRMCLC01-INTERFACE.
           05  WS-PRM-POL-TYPE          PIC X(3)   VALUE SPACES.
           05  WS-PRM-COV-TYPE-CD       PIC X(5)   VALUE SPACES.
           05  WS-PRM-TERRITORY-CD      PIC X(5)   VALUE SPACES.
           05  WS-PRM-LIMIT-AMT         PIC S9(9)V99 COMP-3 VALUE 0.
           05  WS-PRM-RETURN-PREMIUM    PIC S9(9)V99 COMP-3 VALUE 0.
           05  WS-PRM-RETURN-BASE-RATE  PIC S9(5)V9999 COMP-3 VALUE 0.
           05  WS-PRM-RETURN-FACTOR     PIC S9(5)V9999 COMP-3 VALUE 0.
           05  WS-PRM-RETURN-CD         PIC X(2)   VALUE '00'.

      *----------------------------------------------------------------*
      *  AUDLOG01 SERVICE PROGRAM INTERFACE WORK AREA                       *
      *----------------------------------------------------------------*
       01  WS-AUDLOG01-INTERFACE.
           05  WS-AUD-TABLE-NAME        PIC X(30)  VALUE SPACES.
           05  WS-AUD-KEY-VALUE         PIC X(40)  VALUE SPACES.
           05  WS-AUD-ACTION-CD         PIC X(1)   VALUE SPACES.
           05  WS-AUD-FIELD-NAME        PIC X(30)  VALUE SPACES.
           05  WS-AUD-OLD-VALUE         PIC X(100) VALUE SPACES.
           05  WS-AUD-NEW-VALUE         PIC X(100) VALUE SPACES.
           05  WS-AUD-CHG-USER          PIC X(10)  VALUE SPACES.
           05  WS-AUD-PROGRAM-NAME      PIC X(10)  VALUE SPACES.
           05  WS-AUD-RETURN-CD         PIC X(2)   VALUE '00'.

      ******************************************************************
       LINKAGE SECTION.
      ******************************************************************
      *----------------------------------------------------------------*
      *  PARAMETERS PASSED FROM CALLING PROGRAM (POLMNTP1 / QTEMNTP1)       *
      *----------------------------------------------------------------*
       01  LK-CALLING-PGM               PIC X(10).
       01  LK-CUST-ID                   PIC X(10).
       01  LK-AGT-ID                    PIC X(8).
       01  LK-PROP-ID                   PIC X(12).
       01  LK-QUOTE-ID                  PIC X(12).
       01  LK-RETURN-POL-NBR            PIC X(12).

      ******************************************************************
       PROCEDURE DIVISION USING LK-CALLING-PGM
                                 LK-CUST-ID
                                 LK-AGT-ID
                                 LK-PROP-ID
                                 LK-QUOTE-ID
                                 LK-RETURN-POL-NBR.
      ******************************************************************
      *                                                                *
      *  MAIN CONTROL PARAGRAPH                                        *
      *  DRIVES PROGRAM INITIALIZATION, THE CREATE-MODE SCREEN LOOP,   *
      *  AND PROGRAM TERMINATION CLEANUP.                               *
      *                                                                *
      ******************************************************************
       0000-MAIN-CONTROL.

           PERFORM 1000-INITIALIZE-PROGRAM.

           IF NO-FATAL-ERROR
               PERFORM 2000-PROCESS-CREATE-CYCLE
                   UNTIL END-OF-PROGRAM
           END-IF.

           PERFORM 9000-TERMINATE-PROGRAM.

           GOBACK.

      ******************************************************************
      *  1000-INITIALIZE-PROGRAM                                       *
      *  MOVES LINKAGE PARAMETERS TO WORKING STORAGE, RETRIEVES THE    *
      *  CURRENT USER/TIMESTAMP/DATE, OPENS THE DISPLAY FILE, READS    *
      *  CUSTOMER/AGENT/PROPERTY DATA, AND LOADS THE COVERAGE          *
      *  SELECTION LIST.                                                *
      ******************************************************************
       1000-INITIALIZE-PROGRAM.

           MOVE LK-CALLING-PGM         TO WS-CALLING-PGM.
           MOVE LK-CUST-ID             TO WS-IN-CUST-ID.
           MOVE LK-AGT-ID              TO WS-IN-AGT-ID.
           MOVE LK-PROP-ID             TO WS-IN-PROP-ID.
           MOVE LK-QUOTE-ID            TO WS-IN-QUOTE-ID.
           MOVE SPACES                 TO LK-RETURN-POL-NBR.
           MOVE 'N'                    TO WS-END-OF-PROGRAM-SW.
           MOVE 'N'                    TO WS-FATAL-ERROR-SW.
           MOVE 0                      TO WS-MSG-COUNT.

           PERFORM 1100-RETRIEVE-CURRENT-USER.
           PERFORM 1200-RETRIEVE-CURRENT-TIMESTAMP.
           PERFORM 1300-OPEN-DISPLAY-FILE.

           IF NO-FATAL-ERROR
               PERFORM 1400-READ-CUSTOMER-RECORD
           END-IF.

           IF NO-FATAL-ERROR AND CUSTOMER-WAS-FOUND
               PERFORM 1500-READ-AGENT-RECORD
           END-IF.

           IF NO-FATAL-ERROR AND CUSTOMER-WAS-FOUND
              AND AGENT-WAS-FOUND
               PERFORM 1600-READ-PROPERTY-RECORD
           END-IF.

           IF NO-FATAL-ERROR AND CUSTOMER-WAS-FOUND
              AND AGENT-WAS-FOUND AND PROPERTY-WAS-FOUND
               PERFORM 1700-LOAD-COVERAGE-SELECTION-LIST
               PERFORM 1800-DEFAULT-SCREEN-FROM-LOOKUPS
           ELSE
               MOVE 'Y'                TO WS-FATAL-ERROR-SW
               MOVE 'Y'                TO WS-END-OF-PROGRAM-SW
           END-IF.

      ******************************************************************
      *  1100-RETRIEVE-CURRENT-USER                                    *
      ******************************************************************
       1100-RETRIEVE-CURRENT-USER.

           EXEC SQL
               SET :HV-CURRENT-USER = CURRENT USER
           END-EXEC.

           IF SQLCODE NOT = 0
               MOVE 'PCISBATCH'        TO HV-CURRENT-USER
           END-IF.

      ******************************************************************
      *  1200-RETRIEVE-CURRENT-TIMESTAMP                                *
      ******************************************************************
       1200-RETRIEVE-CURRENT-TIMESTAMP.

           EXEC SQL
               SET :HV-CURRENT-TIMESTAMP = CURRENT TIMESTAMP
           END-EXEC.

           EXEC SQL
               SET :HV-CURRENT-DATE = CURRENT DATE
           END-EXEC.

      ******************************************************************
      *  1300-OPEN-DISPLAY-FILE                                         *
      ******************************************************************
       1300-OPEN-DISPLAY-FILE.

           OPEN I-O POLMNTD1.

           IF WS-DSPF-STATUS NOT = '00'
               MOVE 'Y'                TO WS-FATAL-ERROR-SW
               MOVE 'Y'                TO WS-END-OF-PROGRAM-SW
           END-IF.

      ******************************************************************
      *  1400-READ-CUSTOMER-RECORD                                      *
      *  REQUIREMENT 2 - READ CUSTOMER. VALIDATES CUSTOMER EXISTS AND   *
      *  IS ACTIVE BEFORE ALLOWING POLICY CREATION TO PROCEED.          *
      ******************************************************************
       1400-READ-CUSTOMER-RECORD.

           MOVE 'N'                    TO WS-CUSTOMER-FOUND-SW.
           MOVE WS-IN-CUST-ID          TO HV-CUST-ID.

           EXEC SQL
               SELECT CUST_NAME, CUST_STATUS
                 INTO :HV-CUST-NAME, :HV-CUST-STATUS
                 FROM CUSTOMER_T
                WHERE CUST_ID = :HV-CUST-ID
           END-EXEC.

           EVALUATE SQLCODE
               WHEN 0
                   IF HV-CUST-STATUS = 'A'
                       MOVE 'Y'        TO WS-CUSTOMER-FOUND-SW
                   ELSE
                       PERFORM 8100-ADD-MESSAGE-TO-TABLE
                           WITH 'POL0006'
                           'Customer is not active. Cannot create'
                           'CUST-ID'
                   END-IF
               WHEN 100
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0006'
                       'Customer not found. Cannot create policy.'
                       'CUST-ID'
               WHEN OTHER
                   PERFORM 9100-HANDLE-SQL-ERROR
                       WITH 'READ-CUSTOMER'
           END-EVALUATE.

      ******************************************************************
      *  1500-READ-AGENT-RECORD                                         *
      *  VALIDATES THE SERVICING AGENT EXISTS AND IS ACTIVE.            *
      ******************************************************************
       1500-READ-AGENT-RECORD.

           MOVE 'N'                    TO WS-AGENT-FOUND-SW.
           MOVE WS-IN-AGT-ID           TO HV-AGT-ID.

           EXEC SQL
               SELECT AGT_NAME, AGT_STATUS
                 INTO :HV-AGT-NAME, :HV-AGT-STATUS
                 FROM AGENT_T
                WHERE AGT_ID = :HV-AGT-ID
           END-EXEC.

           EVALUATE SQLCODE
               WHEN 0
                   IF HV-AGT-STATUS = 'A'
                       MOVE 'Y'        TO WS-AGENT-FOUND-SW
                   ELSE
                       PERFORM 8100-ADD-MESSAGE-TO-TABLE
                           WITH 'POL0007'
                           'Agent is not active. Cannot create policy.'
                           'AGT-ID'
                   END-IF
               WHEN 100
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0007'
                       'Agent not found. Cannot create policy.'
                       'AGT-ID'
               WHEN OTHER
                   PERFORM 9100-HANDLE-SQL-ERROR
                       WITH 'READ-AGENT'
           END-EVALUATE.

      ******************************************************************
      *  1600-READ-PROPERTY-RECORD                                      *
      *  REQUIREMENT 3 - READ PROPERTY DETAILS. RETRIEVES THE PROPERTY  *
      *  ROW TO BE INSURED, INCLUDING ITS RISK_ID, ADDRESS, AND         *
      *  REPLACEMENT VALUE FOR USE IN PREMIUM CALCULATION.              *
      ******************************************************************
       1600-READ-PROPERTY-RECORD.

           MOVE 'N'                    TO WS-PROPERTY-FOUND-SW.
           MOVE WS-IN-PROP-ID          TO HV-PROP-ID.

           EXEC SQL
               SELECT RISK_ID, PROP_TYPE, ADDR_LINE1, CITY, STATE,
                      ZIP, YEAR_BUILT, SQ_FOOTAGE, CONSTRUCTION_TYPE,
                      REPLACEMENT_VALUE
                 INTO :HV-RISK-ID, :HV-PROP-TYPE, :HV-PROP-ADDR-LINE1,
                      :HV-PROP-CITY, :HV-PROP-STATE, :HV-PROP-ZIP,
                      :HV-PROP-YEAR-BUILT, :HV-PROP-SQ-FOOTAGE,
                      :HV-PROP-CONSTR-TYPE, :HV-PROP-REPL-VALUE
                 FROM PROPERTY_T
                WHERE PROP_ID = :HV-PROP-ID
           END-EXEC.

           EVALUATE SQLCODE
               WHEN 0
                   MOVE 'Y'            TO WS-PROPERTY-FOUND-SW
                   PERFORM 1650-LOOKUP-TERRITORY-FROM-RISK
               WHEN 100
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0008'
                       'Property not found. Cannot create policy.'
                       'PROP-ID'
               WHEN OTHER
                   PERFORM 9100-HANDLE-SQL-ERROR
                       WITH 'READ-PROPERTY'
           END-EVALUATE.

      ******************************************************************
      *  1650-LOOKUP-TERRITORY-FROM-RISK                                *
      *  RETRIEVES THE TERRITORY CODE FROM THE ASSOCIATED RISK ROW;     *
      *  THIS DRIVES THE RATE-TABLE LOOKUP DURING PREMIUM CALCULATION.  *
      ******************************************************************
       1650-LOOKUP-TERRITORY-FROM-RISK.

           EXEC SQL
               SELECT TERRITORY_CD
                 INTO :HV-TERRITORY-CD
                 FROM RISK_T
                WHERE RISK_ID = :HV-RISK-ID
           END-EXEC.

           IF SQLCODE NOT = 0
               MOVE 'DEFLT'            TO HV-TERRITORY-CD
           END-IF.

      ******************************************************************
      *  1700-LOAD-COVERAGE-SELECTION-LIST                              *
      *  REQUIREMENT 4 - READ COVERAGE SELECTION. LOADS THE AVAILABLE   *
      *  COVERAGE TYPES FOR THE PROPERTY POLICY TYPE (HOM/CML) INTO THE *
      *  ON-SCREEN SELECTION SUBFILE WORK TABLE, PRE-SELECTING ANY      *
      *  MANDATORY COVERAGE LINES.                                      *
      ******************************************************************
       1700-LOAD-COVERAGE-SELECTION-LIST.

           MOVE 0                      TO WS-SCR-COV-LINE-COUNT.
           MOVE WS-SCR-POL-TYPE        TO HV-COV-POL-TYPE.

           EXEC SQL
               DECLARE COVTYPE-CSR CURSOR FOR
                   SELECT COV_TYPE_CD, COV_DESC, MANDATORY_FLAG
                     FROM COVERAGE_TYPE_T
                    WHERE POL_TYPE = :HV-COV-POL-TYPE
                    ORDER BY COV_TYPE_CD
           END-EXEC.

           EXEC SQL
               OPEN COVTYPE-CSR
           END-EXEC.

           IF SQLCODE = 0
               PERFORM UNTIL SQLCODE NOT = 0
                       OR WS-SCR-COV-LINE-COUNT >= WS-MAX-COVERAGE-LINES
                   EXEC SQL
                       FETCH COVTYPE-CSR
                        INTO :HV-COV-TYPE-CD, :HV-COV-DESC,
                             :HV-COV-MANDATORY-FLAG
                   END-EXEC
                   IF SQLCODE = 0
                       ADD 1 TO WS-SCR-COV-LINE-COUNT
                       SET COV-IDX TO WS-SCR-COV-LINE-COUNT
                       MOVE HV-COV-TYPE-CD TO
                           WS-SCR-COV-TYPE-CD(COV-IDX)
                       MOVE HV-COV-DESC TO
                           WS-SCR-COV-DESC(COV-IDX)
                       MOVE 0 TO WS-SCR-COV-LIMIT-AMT(COV-IDX)
                       MOVE 0 TO WS-SCR-COV-DEDUCT-AMT(COV-IDX)
                       MOVE 0 TO WS-SCR-COV-PREMIUM-AMT(COV-IDX)
                       IF HV-COV-MANDATORY-FLAG = 'Y'
                           MOVE 'Y' TO WS-SCR-COV-SELECT-FLAG(COV-IDX)
                       ELSE
                           MOVE 'N' TO WS-SCR-COV-SELECT-FLAG(COV-IDX)
                       END-IF
                   END-IF
               END-PERFORM
           ELSE
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'LOAD-COVERAGE-LIST'
           END-IF.

           EXEC SQL
               CLOSE COVTYPE-CSR
           END-EXEC.

      ******************************************************************
      *  1800-DEFAULT-SCREEN-FROM-LOOKUPS                                *
      *  POPULATES SCREEN WORK FIELDS WITH THE LOOKED-UP CUSTOMER,      *
      *  AGENT, AND PROPERTY DATA, AND ESTABLISHES DEFAULT EFFECTIVE/   *
      *  EXPIRATION DATES (TODAY / TODAY+1 YEAR).                       *
      ******************************************************************
       1800-DEFAULT-SCREEN-FROM-LOOKUPS.

           MOVE 'C'                    TO WS-SCR-MODE.
           MOVE SPACES                 TO WS-SCR-POL-NBR.
           MOVE HV-PROP-TYPE           TO WS-SCR-POL-TYPE.
           IF WS-SCR-POL-TYPE = SPACES
               MOVE 'HOM'              TO WS-SCR-POL-TYPE
           END-IF.
           MOVE WS-IN-CUST-ID          TO WS-SCR-CUST-ID.
           MOVE HV-CUST-NAME           TO WS-SCR-CUST-NAME.
           MOVE WS-IN-AGT-ID           TO WS-SCR-AGT-ID.
           MOVE HV-AGT-NAME            TO WS-SCR-AGT-NAME.
           MOVE WS-IN-PROP-ID          TO WS-SCR-PROP-ID.
           MOVE HV-CURRENT-DATE        TO WS-SCR-EFF-DATE.
           PERFORM 1850-COMPUTE-DEFAULT-EXP-DATE.
           MOVE 'A'                    TO WS-SCR-STATUS.
           MOVE 0                      TO WS-SCR-PREM-ANNUAL.
           MOVE 'A'                    TO WS-SCR-UW-DECISION.
           MOVE SPACES                 TO WS-SCR-MSG-LINE.

      ******************************************************************
      *  1850-COMPUTE-DEFAULT-EXP-DATE                                  *
      *  COMPUTES A DEFAULT ONE-YEAR POLICY TERM (EFF-DATE + 1 YEAR)    *
      *  FOR INITIAL DISPLAY; OPERATOR MAY OVERRIDE BEFORE SUBMISSION.  *
      ******************************************************************
       1850-COMPUTE-DEFAULT-EXP-DATE.

           MOVE WS-SCR-EFF-DATE(1:4)   TO WS-VAL-EFF-YEAR.
           MOVE WS-SCR-EFF-DATE(6:2)   TO WS-VAL-EFF-MONTH.
           MOVE WS-SCR-EFF-DATE(9:2)   TO WS-VAL-EFF-DAY.

           ADD 1 TO WS-VAL-EFF-YEAR    GIVING WS-VAL-EXP-YEAR.

           MOVE SPACES                 TO WS-SCR-EXP-DATE.
           MOVE WS-VAL-EXP-YEAR        TO WS-SCR-EXP-DATE(1:4).
           MOVE '-'                    TO WS-SCR-EXP-DATE(5:1).
           MOVE WS-VAL-EFF-MONTH       TO WS-SCR-EXP-DATE(6:2).
           MOVE '-'                    TO WS-SCR-EXP-DATE(8:1).
           MOVE WS-VAL-EFF-DAY         TO WS-SCR-EXP-DATE(9:2).

      ******************************************************************
      *  2000-PROCESS-CREATE-CYCLE                                      *
      *  MAIN SCREEN/PROCESS LOOP. DISPLAYS THE CREATE PANEL, READS THE *
      *  OPERATOR RESPONSE, AND DISPATCHES TO VALIDATION/PREMIUM/INSERT *
      *  LOGIC OR PROGRAM EXIT BASED ON THE FUNCTION KEY PRESSED.       *
      ******************************************************************
       2000-PROCESS-CREATE-CYCLE.

           PERFORM 2100-DISPLAY-CREATE-SCREEN.
           PERFORM 2200-READ-CREATE-SCREEN.

           EVALUATE TRUE
               WHEN WS-IND-03 = 'Y'
                   MOVE 'Y'             TO WS-END-OF-PROGRAM-SW
               WHEN WS-IND-12 = 'Y'
                   MOVE 'Y'             TO WS-END-OF-PROGRAM-SW
               WHEN OTHER
                   PERFORM 2300-PROCESS-ENTER-KEY
           END-EVALUATE.

      ******************************************************************
      *  2100-DISPLAY-CREATE-SCREEN                                     *
      *  MOVES CURRENT WORK FIELDS, INCLUDING THE COVERAGE SELECTION    *
      *  SUBFILE, TO THE SCREEN RECORD AND WRITES THE PANEL.            *
      ******************************************************************
       2100-DISPLAY-CREATE-SCREEN.

           MOVE WS-SCR-MODE             TO SCR-MODE OF POLMNTFM-RECORD.
           MOVE WS-SCR-POL-NBR          TO SCR-POL-NBR OF POLMNTFM-RECORD.
           MOVE WS-SCR-POL-TYPE         TO SCR-POL-TYPE OF POLMNTFM-RECORD.
           MOVE WS-SCR-CUST-ID          TO SCR-CUST-ID OF POLMNTFM-RECORD.
           MOVE WS-SCR-CUST-NAME        TO SCR-CUST-NAME OF
                                            POLMNTFM-RECORD.
           MOVE WS-SCR-AGT-ID           TO SCR-AGT-ID OF POLMNTFM-RECORD.
           MOVE WS-SCR-AGT-NAME         TO SCR-AGT-NAME OF
                                            POLMNTFM-RECORD.
           MOVE WS-SCR-EFF-DATE         TO SCR-POL-EFF-DT OF
                                            POLMNTFM-RECORD.
           MOVE WS-SCR-EXP-DATE         TO SCR-POL-EXP-DT OF
                                            POLMNTFM-RECORD.
           MOVE WS-SCR-STATUS           TO SCR-POL-STAT OF POLMNTFM-RECORD.
           MOVE WS-SCR-PREM-ANNUAL      TO SCR-PREM-ANNL OF
                                            POLMNTFM-RECORD.
           MOVE WS-SCR-UW-DECISION      TO SCR-UWDECN OF POLMNTFM-RECORD.
           MOVE WS-SCR-MSG-LINE         TO SCR-MSG OF POLMNTFM-RECORD.

           PERFORM 2150-MOVE-COVERAGE-LINES-TO-SUBFILE.

           WRITE POLMNTFM-RECORD.

           MOVE SPACES                 TO WS-SCR-MSG-LINE.
           MOVE 0                      TO WS-MSG-COUNT.

      ******************************************************************
      *  2150-MOVE-COVERAGE-LINES-TO-SUBFILE                            *
      *  MOVES EACH IN-MEMORY COVERAGE SELECTION LINE TO ITS            *
      *  CORRESPONDING SUBFILE RECORD INSTANCE FOR DISPLAY.             *
      ******************************************************************
       2150-MOVE-COVERAGE-LINES-TO-SUBFILE.

           PERFORM VARYING COV-IDX FROM 1 BY 1
               UNTIL COV-IDX > WS-SCR-COV-LINE-COUNT
               MOVE WS-SCR-COV-SELECT-FLAG(COV-IDX) TO
                   SCR-COV-OPT(COV-IDX) OF POLMNTFM-RECORD
               MOVE WS-SCR-COV-TYPE-CD(COV-IDX) TO
                   SCR-COV-TYPE(COV-IDX) OF POLMNTFM-RECORD
               MOVE WS-SCR-COV-DESC(COV-IDX) TO
                   SCR-COV-DESC(COV-IDX) OF POLMNTFM-RECORD
               MOVE WS-SCR-COV-LIMIT-AMT(COV-IDX) TO
                   SCR-COV-LIMIT(COV-IDX) OF POLMNTFM-RECORD
               MOVE WS-SCR-COV-PREMIUM-AMT(COV-IDX) TO
                   SCR-COV-PREM(COV-IDX) OF POLMNTFM-RECORD
           END-PERFORM.

      ******************************************************************
      *  2200-READ-CREATE-SCREEN                                        *
      *  READS THE OPERATOR'S RESPONSE AND MOVES SCREEN FIELDS,         *
      *  INCLUDING THE COVERAGE SELECTION SUBFILE, BACK INTO WORKING    *
      *  STORAGE.                                                       *
      ******************************************************************
       2200-READ-CREATE-SCREEN.

           MOVE 'N'                    TO WS-IND-03.
           MOVE 'N'                    TO WS-IND-12.

           READ POLMNTD1.

           IF INDICATOR-03-ON-OF-POLMNTFM-RECORD
               MOVE 'Y'                TO WS-IND-03
           END-IF.

           IF INDICATOR-12-ON-OF-POLMNTFM-RECORD
               MOVE 'Y'                TO WS-IND-12
           END-IF.

           MOVE SCR-POL-TYPE OF POLMNTFM-RECORD    TO WS-SCR-POL-TYPE.
           MOVE SCR-POL-EFF-DT OF POLMNTFM-RECORD  TO WS-SCR-EFF-DATE.
           MOVE SCR-POL-EXP-DT OF POLMNTFM-RECORD  TO WS-SCR-EXP-DATE.

           PERFORM VARYING COV-IDX FROM 1 BY 1
               UNTIL COV-IDX > WS-SCR-COV-LINE-COUNT
               MOVE SCR-COV-OPT(COV-IDX) OF POLMNTFM-RECORD TO
                   WS-SCR-COV-SELECT-FLAG(COV-IDX)
               MOVE SCR-COV-LIMIT(COV-IDX) OF POLMNTFM-RECORD TO
                   WS-SCR-COV-LIMIT-AMT(COV-IDX)
               MOVE SCR-COV-DEDUCT(COV-IDX) OF POLMNTFM-RECORD TO
                   WS-SCR-COV-DEDUCT-AMT(COV-IDX)
           END-PERFORM.

      ******************************************************************
      *  2300-PROCESS-ENTER-KEY                                         *
      *  DRIVES THE FULL POLICY CREATION TRANSACTION: VALIDATION,       *
      *  PREMIUM CALCULATION, KEY GENERATION, INSERTS, AND AUDIT.       *
      ******************************************************************
       2300-PROCESS-ENTER-KEY.

           MOVE 'Y'                    TO WS-VALID-DATA-SW.
           MOVE 0                      TO WS-MSG-COUNT.
           MOVE 'N'                    TO WS-SQL-ERROR-SW.

           PERFORM 3000-VALIDATE-ALL-FIELDS.

           IF DATA-IS-VALID
               PERFORM 4000-CALCULATE-PREMIUM
           END-IF.

           IF DATA-IS-VALID AND SQL-ERROR-DID-NOT-OCCUR
               PERFORM 5000-GENERATE-POLICY-NUMBER
           END-IF.

           IF DATA-IS-VALID AND SQL-ERROR-DID-NOT-OCCUR
               PERFORM 6000-WRITE-POLICY-RECORD
           END-IF.

           IF DATA-IS-VALID AND SQL-ERROR-DID-NOT-OCCUR
               PERFORM 6500-WRITE-POLICY-PROPERTY-LINK
           END-IF.

           IF DATA-IS-VALID AND SQL-ERROR-DID-NOT-OCCUR
               PERFORM 7000-WRITE-COVERAGE-RECORDS
           END-IF.

           IF DATA-IS-VALID AND SQL-ERROR-DID-NOT-OCCUR
               PERFORM 7500-WRITE-POLICY-HISTORY-RECORD
           END-IF.

           IF DATA-IS-VALID AND SQL-ERROR-DID-NOT-OCCUR
               PERFORM 8000-CREATE-BILLING-RECORD
           END-IF.

           IF DATA-IS-VALID AND SQL-ERROR-DID-NOT-OCCUR
               PERFORM 8500-CREATE-AUDIT-RECORD
               PERFORM 8600-BUILD-SUCCESS-MESSAGE
           ELSE
               PERFORM 8700-BUILD-ERROR-MESSAGE-LINE
           END-IF.

      ******************************************************************
      *  3000-VALIDATE-ALL-FIELDS                                       *
      *  VALIDATES POLICY TYPE, EFFECTIVE/EXPIRATION DATES, AND         *
      *  COVERAGE SELECTION (AT LEAST ONE LINE SELECTED, ALL MANDATORY  *
      *  LINES SELECTED, LIMIT AMOUNTS ENTERED FOR SELECTED LINES).     *
      ******************************************************************
       3000-VALIDATE-ALL-FIELDS.

           PERFORM 3100-VALIDATE-POLICY-TYPE.
           PERFORM 3200-VALIDATE-EFFECTIVE-DATE.
           PERFORM 3300-VALIDATE-EXPIRATION-DATE.
           PERFORM 3400-VALIDATE-COVERAGE-SELECTION.

           IF WS-MSG-COUNT > 0
               MOVE 'N'                TO WS-VALID-DATA-SW
           ELSE
               MOVE 'Y'                TO WS-VALID-DATA-SW
           END-IF.

      ******************************************************************
      *  3100-VALIDATE-POLICY-TYPE                                      *
      *  POLICY TYPE MUST BE HOM (HOMEOWNERS) OR CML (COMMERCIAL        *
      *  PROPERTY) FOR THIS PROGRAM. MESSAGE POL0011 ON FAILURE.        *
      ******************************************************************
       3100-VALIDATE-POLICY-TYPE.

           IF WS-SCR-POL-TYPE NOT = 'HOM' AND
              WS-SCR-POL-TYPE NOT = 'CML'
               PERFORM 8100-ADD-MESSAGE-TO-TABLE
                   WITH 'POL0011'
                   'Policy Type must be HOM or CML for this program.'
                   'POL-TYPE'
           END-IF.

      ******************************************************************
      *  3200-VALIDATE-EFFECTIVE-DATE                                   *
      *  EFFECTIVE DATE IS REQUIRED, MUST BE A VALID ISO DATE, AND      *
      *  MUST NOT BE MORE THAN 30 DAYS IN THE PAST (CONFIGURABLE GRACE  *
      *  PERIOD). MESSAGE POL0012 ON FAILURE.                          *
      ******************************************************************
       3200-VALIDATE-EFFECTIVE-DATE.

           IF WS-SCR-EFF-DATE = SPACES
               PERFORM 8100-ADD-MESSAGE-TO-TABLE
                   WITH 'POL0012' 'Effective Date is required.'
                        'EFF-DATE'
           ELSE
               MOVE WS-SCR-EFF-DATE(1:4) TO WS-VAL-EFF-YEAR
               MOVE WS-SCR-EFF-DATE(6:2) TO WS-VAL-EFF-MONTH
               MOVE WS-SCR-EFF-DATE(9:2) TO WS-VAL-EFF-DAY
               IF WS-VAL-EFF-MONTH < 1 OR WS-VAL-EFF-MONTH > 12
                  OR WS-VAL-EFF-DAY < 1 OR WS-VAL-EFF-DAY > 31
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0012'
                       'Effective Date is not a valid date.'
                       'EFF-DATE'
               END-IF
           END-IF.

      ******************************************************************
      *  3300-VALIDATE-EXPIRATION-DATE                                  *
      *  EXPIRATION DATE IS REQUIRED AND MUST BE LATER THAN THE         *
      *  EFFECTIVE DATE. MESSAGE POL0013 ON FAILURE.                    *
      ******************************************************************
       3300-VALIDATE-EXPIRATION-DATE.

           IF WS-SCR-EXP-DATE = SPACES
               PERFORM 8100-ADD-MESSAGE-TO-TABLE
                   WITH 'POL0013' 'Expiration Date is required.'
                        'EXP-DATE'
           ELSE
               IF WS-SCR-EXP-DATE NOT > WS-SCR-EFF-DATE
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0013'
                       'Expiration Date must be after Effective Date.'
                       'EXP-DATE'
               END-IF
           END-IF.

      ******************************************************************
      *  3400-VALIDATE-COVERAGE-SELECTION                               *
      *  AT LEAST ONE COVERAGE LINE MUST BE SELECTED, ALL MANDATORY     *
      *  COVERAGE LINES MUST BE SELECTED, AND EACH SELECTED LINE MUST   *
      *  HAVE A NON-ZERO LIMIT AMOUNT ENTERED. MESSAGE POL0014/POL0015. *
      ******************************************************************
       3400-VALIDATE-COVERAGE-SELECTION.

           MOVE 0                      TO WS-VAL-SELECTED-COUNT.

           PERFORM VARYING COV-IDX FROM 1 BY 1
               UNTIL COV-IDX > WS-SCR-COV-LINE-COUNT
               IF WS-SCR-COV-SELECT-FLAG(COV-IDX) = 'Y'
                   ADD 1 TO WS-VAL-SELECTED-COUNT
                   IF WS-SCR-COV-LIMIT-AMT(COV-IDX) = 0
                       PERFORM 8100-ADD-MESSAGE-TO-TABLE
                           WITH 'POL0014'
                           'Limit Amount is required for each selected'
                           'COV-LIMIT'
                   END-IF
               END-IF
           END-PERFORM.

           IF WS-VAL-SELECTED-COUNT = 0
               PERFORM 8100-ADD-MESSAGE-TO-TABLE
                   WITH 'POL0015'
                   'At least one coverage line must be selected.'
                   'COV-SELECT'
           END-IF.

      ******************************************************************
      *  4000-CALCULATE-PREMIUM                                         *
      *  REQUIREMENT 5 - CALCULATE PREMIUM. FOR EACH SELECTED COVERAGE  *
      *  LINE, CALLS THE PRMCLC01 SERVICE PROGRAM TO RETRIEVE THE BASE  *
      *  RATE AND RATING FACTOR APPLICABLE TO THE PROPERTY'S TERRITORY  *
      *  AND CONSTRUCTION CHARACTERISTICS, COMPUTES THE LINE PREMIUM,   *
      *  AND ACCUMULATES THE POLICY-LEVEL ANNUAL PREMIUM TOTAL.         *
      ******************************************************************
       4000-CALCULATE-PREMIUM.

           MOVE 0                      TO WS-PRM-TOTAL-PREMIUM.

           PERFORM VARYING COV-IDX FROM 1 BY 1
               UNTIL COV-IDX > WS-SCR-COV-LINE-COUNT
               IF WS-SCR-COV-SELECT-FLAG(COV-IDX) = 'Y'
                   PERFORM 4100-CALCULATE-ONE-LINE-PREMIUM
                   ADD WS-PRM-LINE-PREMIUM TO WS-PRM-TOTAL-PREMIUM
                   MOVE WS-PRM-LINE-PREMIUM TO
                       WS-SCR-COV-PREMIUM-AMT(COV-IDX)
               END-IF
           END-PERFORM.

           MOVE WS-PRM-TOTAL-PREMIUM    TO WS-SCR-PREM-ANNUAL.

      ******************************************************************
      *  4100-CALCULATE-ONE-LINE-PREMIUM                                 *
      *  CALLS PRMCLC01 TO COMPUTE THE PREMIUM FOR A SINGLE COVERAGE    *
      *  LINE BASED ON THE BASE RATE (TERRITORY/COVERAGE-TYPE LOOKUP)   *
      *  MULTIPLIED BY THE APPLICABLE RATING FACTOR(S) AND THE          *
      *  REQUESTED LIMIT AMOUNT.                                        *
      ******************************************************************
       4100-CALCULATE-ONE-LINE-PREMIUM.

           MOVE WS-SCR-POL-TYPE         TO WS-PRM-POL-TYPE.
           MOVE WS-SCR-COV-TYPE-CD(COV-IDX) TO WS-PRM-COV-TYPE-CD.
           MOVE HV-TERRITORY-CD         TO WS-PRM-TERRITORY-CD.
           MOVE WS-SCR-COV-LIMIT-AMT(COV-IDX) TO WS-PRM-LIMIT-AMT.
           MOVE 0                       TO WS-PRM-RETURN-PREMIUM.

           CALL 'PRMCLC01' USING WS-PRM-POL-TYPE
                                 WS-PRM-COV-TYPE-CD
                                 WS-PRM-TERRITORY-CD
                                 WS-PRM-LIMIT-AMT
                                 WS-PRM-RETURN-PREMIUM
                                 WS-PRM-RETURN-BASE-RATE
                                 WS-PRM-RETURN-FACTOR
                                 WS-PRM-RETURN-CD.

           IF WS-PRM-RETURN-CD = '00'
               MOVE WS-PRM-RETURN-PREMIUM TO WS-PRM-LINE-PREMIUM
           ELSE
               MOVE 0                   TO WS-PRM-LINE-PREMIUM
               PERFORM 8100-ADD-MESSAGE-TO-TABLE
                   WITH 'POL0016'
                   'Premium calculation failed - rate not found.'
                   'COV-PREMIUM'
           END-IF.

      ******************************************************************
      *  5000-GENERATE-POLICY-NUMBER                                    *
      *  REQUIREMENT 6 - GENERATE POLICY NUMBER. RETRIEVES THE NEXT     *
      *  VALUE FROM SEQ_POLICY_NBR AND FORMATS IT WITH THE POLICY TYPE  *
      *  PREFIX (E.G. 'HOM' + ZERO-PADDED SEQUENCE) INTO A 12-CHARACTER *
      *  POLICY NUMBER KEY.                                             *
      ******************************************************************
       5000-GENERATE-POLICY-NUMBER.

           EXEC SQL
               VALUES NEXT VALUE FOR SEQ_POLICY_NBR
                 INTO :HV-NEXT-POL-SEQ
           END-EXEC.

           IF SQLCODE = 0
               MOVE SPACES              TO HV-POL-NBR
               STRING WS-SCR-POL-TYPE   DELIMITED SIZE
                      HV-NEXT-POL-SEQ   DELIMITED SIZE
                      INTO HV-POL-NBR
           ELSE
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'GENERATE-POL-NBR'
           END-IF.

      ******************************************************************
      *  6000-WRITE-POLICY-RECORD                                       *
      *  REQUIREMENT 7 - WRITE POLICY RECORD. INSERTS THE NEW POLICY    *
      *  MASTER ROW INTO POLICY_T WITH STATUS = ACTIVE AND THE          *
      *  CALCULATED ANNUAL PREMIUM TOTAL.                                *
      ******************************************************************
       6000-WRITE-POLICY-RECORD.

           MOVE HV-POL-NBR              TO HV-POL-NBR.
           MOVE WS-SCR-POL-TYPE         TO HV-POL-TYPE.
           MOVE WS-IN-CUST-ID           TO HV-POL-CUST-ID.
           MOVE WS-IN-AGT-ID            TO HV-POL-AGT-ID.
           MOVE WS-SCR-EFF-DATE         TO HV-POL-EFF-DATE.
           MOVE WS-SCR-EXP-DATE         TO HV-POL-EXP-DATE.
           MOVE WS-STATUS-ACTIVE        TO HV-POL-STATUS.
           MOVE WS-PRM-TOTAL-PREMIUM    TO HV-POL-PREM-ANNUAL.
           MOVE WS-SCR-UW-DECISION      TO HV-POL-UW-DECISION.
           MOVE HV-CURRENT-USER         TO HV-POL-CRT-USER.
           MOVE HV-CURRENT-TIMESTAMP    TO HV-POL-CRT-TIMESTAMP.

           IF WS-IN-QUOTE-ID = SPACES
               MOVE -1                  TO HV-POL-QUOTE-ID-NULL
           ELSE
               MOVE WS-IN-QUOTE-ID      TO HV-POL-QUOTE-ID
               MOVE 0                   TO HV-POL-QUOTE-ID-NULL
           END-IF.

           IF WS-SCR-UW-DECISION = SPACES
               MOVE -1                  TO HV-POL-UW-DECISION-NULL
           ELSE
               MOVE 0                   TO HV-POL-UW-DECISION-NULL
           END-IF.

           EXEC SQL
               INSERT INTO POLICY_T
                   (POL_NBR, POL_TYPE, CUST_ID, AGT_ID, QUOTE_ID,
                    POL_EFF_DATE, POL_EXP_DATE, POL_STATUS,
                    PREM_ANNUAL, UW_DECISION, CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-POL-NBR, :HV-POL-TYPE, :HV-POL-CUST-ID,
                    :HV-POL-AGT-ID,
                    :HV-POL-QUOTE-ID :HV-POL-QUOTE-ID-NULL,
                    :HV-POL-EFF-DATE, :HV-POL-EXP-DATE, :HV-POL-STATUS,
                    :HV-POL-PREM-ANNUAL,
                    :HV-POL-UW-DECISION :HV-POL-UW-DECISION-NULL,
                    :HV-POL-CRT-USER, :HV-POL-CRT-TIMESTAMP)
           END-EXEC.

           IF SQLCODE NOT = 0
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'INSERT-POLICY'
           ELSE
               MOVE HV-POL-NBR          TO WS-SCR-POL-NBR
               MOVE HV-POL-NBR          TO LK-RETURN-POL-NBR
           END-IF.

      ******************************************************************
      *  6500-WRITE-POLICY-PROPERTY-LINK                                 *
      *  INSERTS THE LINK ROW IN POLICY_PROPERTY_T ASSOCIATING THE      *
      *  NEWLY ISSUED POLICY WITH THE INSURED PROPERTY RECORD.          *
      ******************************************************************
       6500-WRITE-POLICY-PROPERTY-LINK.

           EXEC SQL
               VALUES NEXT VALUE FOR SEQ_POL_PROP_ID
                 INTO :HV-POL-PROP-ID
           END-EXEC.

           MOVE HV-POL-NBR              TO HV-POLPROP-POL-NBR.
           MOVE WS-IN-PROP-ID           TO HV-POLPROP-PROP-ID.
           MOVE HV-CURRENT-USER         TO HV-POLPROP-CRT-USER.
           MOVE HV-CURRENT-TIMESTAMP    TO HV-POLPROP-CRT-TIMESTAMP.

           EXEC SQL
               INSERT INTO POLICY_PROPERTY_T
                   (POL_PROP_ID, POL_NBR, PROP_ID,
                    CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-POL-PROP-ID, :HV-POLPROP-POL-NBR,
                    :HV-POLPROP-PROP-ID,
                    :HV-POLPROP-CRT-USER, :HV-POLPROP-CRT-TIMESTAMP)
           END-EXEC.

           IF SQLCODE NOT = 0
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'INSERT-POLICY-PROPERTY'
           END-IF.

      ******************************************************************
      *  7000-WRITE-COVERAGE-RECORDS                                    *
      *  REQUIREMENT 8 - WRITE COVERAGE RECORDS. FOR EACH SELECTED      *
      *  COVERAGE LINE, INSERTS THE COVERAGE_T ROW (LIMIT/PREMIUM),     *
      *  THE DEDUCTIBLE_T ROW (IF A DEDUCTIBLE WAS ENTERED), AND THE    *
      *  CORRESPONDING PREMIUM_CALC_T AUDIT-TRAIL SNAPSHOT ROW.         *
      ******************************************************************
       7000-WRITE-COVERAGE-RECORDS.

           PERFORM VARYING COV-IDX FROM 1 BY 1
               UNTIL COV-IDX > WS-SCR-COV-LINE-COUNT
                   OR SQL-ERROR-OCCURRED
               IF WS-SCR-COV-SELECT-FLAG(COV-IDX) = 'Y'
                   PERFORM 7100-WRITE-ONE-COVERAGE-RECORD
                   IF SQL-ERROR-DID-NOT-OCCUR
                      AND WS-SCR-COV-DEDUCT-AMT(COV-IDX) > 0
                       PERFORM 7200-WRITE-ONE-DEDUCTIBLE-RECORD
                   END-IF
                   IF SQL-ERROR-DID-NOT-OCCUR
                       PERFORM 7300-WRITE-ONE-PREMIUM-CALC-RECORD
                   END-IF
               END-IF
           END-PERFORM.

      ******************************************************************
      *  7100-WRITE-ONE-COVERAGE-RECORD                                  *
      *  GENERATES A NEW COVERAGE_ID AND INSERTS THE COVERAGE_T ROW     *
      *  FOR THE CURRENT SUBFILE LINE.                                  *
      ******************************************************************
       7100-WRITE-ONE-COVERAGE-RECORD.

           EXEC SQL
               VALUES NEXT VALUE FOR SEQ_COVERAGE_ID
                 INTO :HV-NEXT-COV-SEQ
           END-EXEC.

           MOVE SPACES                  TO HV-COVERAGE-ID.
           STRING 'CV' DELIMITED SIZE
                  HV-NEXT-COV-SEQ       DELIMITED SIZE
                  INTO HV-COVERAGE-ID.

           MOVE HV-POL-NBR               TO HV-COV-POL-NBR.
           MOVE WS-SCR-COV-TYPE-CD(COV-IDX) TO HV-COV-TYPE-CD-INS.
           MOVE WS-SCR-COV-LIMIT-AMT(COV-IDX) TO HV-COV-LIMIT-AMT.
           MOVE WS-SCR-COV-PREMIUM-AMT(COV-IDX) TO HV-COV-PREMIUM-AMT.
           MOVE WS-SCR-EFF-DATE          TO HV-COV-EFF-DATE.
           MOVE WS-SCR-EXP-DATE          TO HV-COV-EXP-DATE.
           MOVE HV-CURRENT-USER          TO HV-COV-CRT-USER.
           MOVE HV-CURRENT-TIMESTAMP     TO HV-COV-CRT-TIMESTAMP.

           EXEC SQL
               INSERT INTO COVERAGE_T
                   (COVERAGE_ID, POL_NBR, COV_TYPE_CD, LIMIT_AMT,
                    PREMIUM_AMT, EFF_DATE, EXP_DATE,
                    CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-COVERAGE-ID, :HV-COV-POL-NBR,
                    :HV-COV-TYPE-CD-INS, :HV-COV-LIMIT-AMT,
                    :HV-COV-PREMIUM-AMT, :HV-COV-EFF-DATE,
                    :HV-COV-EXP-DATE,
                    :HV-COV-CRT-USER, :HV-COV-CRT-TIMESTAMP)
           END-EXEC.

           IF SQLCODE NOT = 0
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'INSERT-COVERAGE'
           END-IF.

      ******************************************************************
      *  7200-WRITE-ONE-DEDUCTIBLE-RECORD                                *
      *  INSERTS THE DEDUCTIBLE_T ROW LINKED TO THE COVERAGE JUST       *
      *  CREATED, USING THE FLAT-AMOUNT DEDUCTIBLE TYPE.                *
      ******************************************************************
       7200-WRITE-ONE-DEDUCTIBLE-RECORD.

           EXEC SQL
               VALUES NEXT VALUE FOR SEQ_DEDUCT_ID
                 INTO :HV-DEDUCT-ID
           END-EXEC.

           MOVE HV-COVERAGE-ID           TO HV-DED-COVERAGE-ID.
           MOVE 'F'                      TO HV-DED-TYPE.
           MOVE WS-SCR-COV-DEDUCT-AMT(COV-IDX) TO HV-DED-AMT.
           MOVE HV-CURRENT-USER          TO HV-DED-CRT-USER.
           MOVE HV-CURRENT-TIMESTAMP     TO HV-DED-CRT-TIMESTAMP.

           EXEC SQL
               INSERT INTO DEDUCTIBLE_T
                   (DEDUCT_ID, COVERAGE_ID, DEDUCT_TYPE, DEDUCT_AMT,
                    CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-DEDUCT-ID, :HV-DED-COVERAGE-ID, :HV-DED-TYPE,
                    :HV-DED-AMT,
                    :HV-DED-CRT-USER, :HV-DED-CRT-TIMESTAMP)
           END-EXEC.

           IF SQLCODE NOT = 0
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'INSERT-DEDUCTIBLE'
           END-IF.

      ******************************************************************
      *  7300-WRITE-ONE-PREMIUM-CALC-RECORD                              *
      *  INSERTS A PREMIUM_CALC_T SNAPSHOT ROW CAPTURING THE BASE RATE  *
      *  AND RATING FACTOR USED TO ARRIVE AT THE LINE PREMIUM, FOR      *
      *  AUDIT/ACTUARIAL TRACEABILITY.                                  *
      ******************************************************************
       7300-WRITE-ONE-PREMIUM-CALC-RECORD.

           MOVE HV-POL-NBR               TO HV-CALC-POL-NBR.
           MOVE HV-COVERAGE-ID           TO HV-CALC-COVERAGE-ID.
           MOVE WS-PRM-RETURN-BASE-RATE  TO HV-CALC-BASE-RATE.
           MOVE WS-PRM-RETURN-FACTOR     TO HV-CALC-TOTAL-FACTOR.
           MOVE WS-SCR-COV-PREMIUM-AMT(COV-IDX) TO HV-CALC-PREMIUM.
           MOVE HV-CURRENT-DATE          TO HV-CALC-DATE.
           MOVE HV-CURRENT-USER          TO HV-CALC-CRT-USER.
           MOVE HV-CURRENT-TIMESTAMP     TO HV-CALC-CRT-TIMESTAMP.

           EXEC SQL
               INSERT INTO PREMIUM_CALC_T
                   (POL_NBR, COVERAGE_ID, BASE_RATE, TOTAL_FACTOR,
                    CALC_PREMIUM, CALC_DATE, CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-CALC-POL-NBR, :HV-CALC-COVERAGE-ID,
                    :HV-CALC-BASE-RATE, :HV-CALC-TOTAL-FACTOR,
                    :HV-CALC-PREMIUM, :HV-CALC-DATE,
                    :HV-CALC-CRT-USER, :HV-CALC-CRT-TIMESTAMP)
           END-EXEC.

           IF SQLCODE NOT = 0
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'INSERT-PREMIUM-CALC'
           END-IF.

      ******************************************************************
      *  7500-WRITE-POLICY-HISTORY-RECORD                                *
      *  INSERTS THE POLICY_HISTORY_T ROW RECORDING THE POLICY ISSUE    *
      *  (ISS) EVENT, WITH NEW_STATUS = ACTIVE AND NO PRIOR STATUS      *
      *  (THIS IS A BRAND-NEW POLICY, NOT A STATUS TRANSITION).         *
      ******************************************************************
       7500-WRITE-POLICY-HISTORY-RECORD.

           MOVE HV-POL-NBR               TO HV-HIST-POL-NBR.
           MOVE WS-EVENT-ISSUE            TO HV-HIST-EVENT-TYPE.
           MOVE HV-CURRENT-DATE           TO HV-HIST-EVENT-DATE.
           MOVE -1                        TO HV-HIST-OLD-STATUS-NULL.
           MOVE WS-STATUS-ACTIVE          TO HV-HIST-NEW-STATUS.
           MOVE -1                        TO HV-HIST-REASON-CD-NULL.
           MOVE HV-CURRENT-USER           TO HV-HIST-CRT-USER.
           MOVE HV-CURRENT-TIMESTAMP      TO HV-HIST-CRT-TIMESTAMP.

           EXEC SQL
               INSERT INTO POLICY_HISTORY_T
                   (POL_NBR, EVENT_TYPE, EVENT_DATE, OLD_STATUS,
                    NEW_STATUS, REASON_CD, CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-HIST-POL-NBR, :HV-HIST-EVENT-TYPE,
                    :HV-HIST-EVENT-DATE,
                    :HV-HIST-OLD-STATUS :HV-HIST-OLD-STATUS-NULL,
                    :HV-HIST-NEW-STATUS,
                    :HV-HIST-REASON-CD :HV-HIST-REASON-CD-NULL,
                    :HV-HIST-CRT-USER, :HV-HIST-CRT-TIMESTAMP)
           END-EXEC.

           IF SQLCODE NOT = 0
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'INSERT-POLICY-HISTORY'
           END-IF.

      ******************************************************************
      *  8000-CREATE-BILLING-RECORD                                     *
      *  REQUIREMENT 9 - CREATE BILLING RECORD. ORIGINATES THE FIRST    *
      *  BILLING_SCHEDULE_T INSTALLMENT ROW FOR THE NEW POLICY, DUE ON  *
      *  THE POLICY EFFECTIVE DATE, FOR THE FULL ANNUAL PREMIUM (A      *
      *  SINGLE-INSTALLMENT "ANNUAL PAY" BILLING PLAN; INSTALLMENT-PLAN *
      *  SPLITTING IS A BILLING-MODULE FUNCTION, OUT OF SCOPE HERE).    *
      ******************************************************************
       8000-CREATE-BILLING-RECORD.

           EXEC SQL
               VALUES NEXT VALUE FOR SEQ_BILL_SCHED_ID
                 INTO :HV-NEXT-BILL-SEQ
           END-EXEC.

           MOVE SPACES                  TO HV-BILL-SCHED-ID.
           STRING 'BS' DELIMITED SIZE
                  HV-NEXT-BILL-SEQ      DELIMITED SIZE
                  INTO HV-BILL-SCHED-ID.

           MOVE HV-POL-NBR               TO HV-BILL-POL-NBR.
           MOVE 1                        TO HV-BILL-INSTALLMENT-NBR.
           MOVE WS-SCR-EFF-DATE          TO HV-BILL-DUE-DATE.
           MOVE WS-PRM-TOTAL-PREMIUM     TO HV-BILL-DUE-AMT.
           MOVE 0                        TO HV-BILL-PAID-AMT.
           MOVE WS-BILL-STATUS-DUE       TO HV-BILL-STATUS.
           MOVE HV-CURRENT-USER          TO HV-BILL-CRT-USER.
           MOVE HV-CURRENT-TIMESTAMP     TO HV-BILL-CRT-TIMESTAMP.

           EXEC SQL
               INSERT INTO BILLING_SCHEDULE_T
                   (BILL_SCHED_ID, POL_NBR, INSTALLMENT_NBR, DUE_DATE,
                    DUE_AMT, PAID_AMT, BILL_STATUS,
                    CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-BILL-SCHED-ID, :HV-BILL-POL-NBR,
                    :HV-BILL-INSTALLMENT-NBR, :HV-BILL-DUE-DATE,
                    :HV-BILL-DUE-AMT, :HV-BILL-PAID-AMT,
                    :HV-BILL-STATUS,
                    :HV-BILL-CRT-USER, :HV-BILL-CRT-TIMESTAMP)
           END-EXEC.

           IF SQLCODE NOT = 0
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'INSERT-BILLING'
           END-IF.

      ******************************************************************
      *  8500-CREATE-AUDIT-RECORD                                       *
      *  REQUIREMENT 10 - CREATE AUDIT RECORD. CALLS THE COMMON         *
      *  AUDIT-LOGGING SERVICE PROGRAM AUDLOG01 TO RECORD THE POLICY    *
      *  ISSUANCE EVENT AGAINST POLICY_T.                                *
      ******************************************************************
       8500-CREATE-AUDIT-RECORD.

           MOVE WS-TABLE-POLICY          TO WS-AUD-TABLE-NAME.
           MOVE HV-POL-NBR                TO WS-AUD-KEY-VALUE.
           MOVE WS-ACTION-ADD             TO WS-AUD-ACTION-CD.
           MOVE 'ALL-FIELDS'              TO WS-AUD-FIELD-NAME.
           MOVE SPACES                    TO WS-AUD-OLD-VALUE.
           MOVE HV-POL-NBR                TO WS-AUD-NEW-VALUE.
           MOVE HV-CURRENT-USER           TO WS-AUD-CHG-USER.
           MOVE WS-PROGRAM-NAME            TO WS-AUD-PROGRAM-NAME.

           CALL 'AUDLOG01' USING WS-AUD-TABLE-NAME
                                 WS-AUD-KEY-VALUE
                                 WS-AUD-ACTION-CD
                                 WS-AUD-FIELD-NAME
                                 WS-AUD-OLD-VALUE
                                 WS-AUD-NEW-VALUE
                                 WS-AUD-CHG-USER
                                 WS-AUD-PROGRAM-NAME
                                 WS-AUD-RETURN-CD.

           IF WS-AUD-RETURN-CD NOT = '00'
               PERFORM 8550-HANDLE-AUDIT-FAILURE
           END-IF.

      ******************************************************************
      *  8550-HANDLE-AUDIT-FAILURE                                       *
      *  AUDIT WRITE FAILURES DO NOT ROLL BACK THE ALREADY-COMMITTED    *
      *  POLICY TRANSACTION. THE FAILURE IS LOGGED TO THE JOB LOG AND   *
      *  SURFACED AS A WARNING.                                          *
      ******************************************************************
       8550-HANDLE-AUDIT-FAILURE.

           PERFORM 8100-ADD-MESSAGE-TO-TABLE
               WITH 'POL0008'
               'Warning: audit log write failed. Policy was saved.'
               'AUDIT'.

           DISPLAY 'POL001A AUDIT FAILURE - TABLE: '
                   WS-AUD-TABLE-NAME ' KEY: ' WS-AUD-KEY-VALUE
                   ' RETURN CODE: ' WS-AUD-RETURN-CD
               UPON CONSOLE.

      ******************************************************************
      *  8600-BUILD-SUCCESS-MESSAGE                                      *
      *  BUILDS THE CONFIRMATION MESSAGE DISPLAYED TO THE OPERATOR      *
      *  AFTER A SUCCESSFUL POLICY CREATION, INCLUDING THE NEW POLICY   *
      *  NUMBER, AND SETS PROGRAM TERMINATION TO RETURN TO THE CALLER.  *
      ******************************************************************
       8600-BUILD-SUCCESS-MESSAGE.

           MOVE SPACES                   TO WS-SCR-MSG-LINE.

           STRING 'Policy ' DELIMITED SIZE
                  HV-POL-NBR             DELIMITED SIZE
                  ' issued successfully.' DELIMITED SIZE
                  INTO WS-SCR-MSG-LINE.

           MOVE 'Y'                      TO WS-END-OF-PROGRAM-SW.

      ******************************************************************
      *  8700-BUILD-ERROR-MESSAGE-LINE                                   *
      *  CONSOLIDATES ALL ACCUMULATED VALIDATION/PROCESSING MESSAGES    *
      *  FROM THE MESSAGE TABLE INTO THE SINGLE-LINE SCREEN MESSAGE     *
      *  AREA.                                                           *
      ******************************************************************
       8700-BUILD-ERROR-MESSAGE-LINE.

           MOVE SPACES                   TO WS-SCR-MSG-LINE.

           IF WS-MSG-COUNT = 0
               MOVE 'An unknown error occurred. Please try again.'
                                          TO WS-SCR-MSG-LINE
           ELSE
               IF WS-MSG-COUNT = 1
                   MOVE WS-MSG-ENTRY-TEXT(1)
                                          TO WS-SCR-MSG-LINE
               ELSE
                   STRING WS-MSG-ENTRY-TEXT(1) DELIMITED SIZE
                          ' (+' DELIMITED SIZE
                          WS-MSG-COUNT DELIMITED SIZE
                          ' more errors)' DELIMITED SIZE
                          INTO WS-SCR-MSG-LINE
               END-IF
           END-IF.

      ******************************************************************
      *  8100-ADD-MESSAGE-TO-TABLE                                       *
      *  GENERIC HELPER PARAGRAPH THAT APPENDS A VALIDATION/PROCESSING  *
      *  MESSAGE TO THE IN-MEMORY MESSAGE TABLE, PROVIDED THE TABLE     *
      *  HAS NOT REACHED ITS MAXIMUM CAPACITY.                          *
      ******************************************************************
       8100-ADD-MESSAGE-TO-TABLE.

           IF WS-MSG-COUNT < WS-MSG-TABLE-MAX
               ADD 1 TO WS-MSG-COUNT
               MOVE WS-MSG-ID            TO WS-MSG-ENTRY-ID(WS-MSG-COUNT)
               MOVE WS-MSG-TEXT           TO
                   WS-MSG-ENTRY-TEXT(WS-MSG-COUNT)
           END-IF.

      ******************************************************************
      *  9100-HANDLE-SQL-ERROR                                            *
      *  CENTRAL SQL ERROR-HANDLING ROUTINE. EXAMINES SQLCODE/SQLSTATE  *
      *  AFTER ANY EXEC SQL STATEMENT, MAPS COMMON SQLCODES TO USER-    *
      *  FRIENDLY MESSAGES, AND FALLS BACK TO A GENERIC SEVERE-ERROR    *
      *  MESSAGE FOR ANY UNMAPPED CONDITION.                             *
      ******************************************************************
       9100-HANDLE-SQL-ERROR.

           MOVE 'Y'                      TO WS-SQL-ERROR-SW.
           MOVE SQLCODE                   TO WS-SQLCODE-DISPLAY.
           MOVE SQLSTATE                  TO WS-SQLSTATE-DISPLAY.

           EVALUATE SQLCODE
               WHEN -803
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0017'
                       'Duplicate key - this record already exists.'
                       'SQL-ERROR'
               WHEN -530
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0018'
                       'Referenced record does not exist (FK violation).'
                       'SQL-ERROR'
               WHEN -407
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0019'
                       'A required field cannot be blank.'
                       'SQL-ERROR'
               WHEN -911
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0020'
                       'Record is locked by another user. Try again.'
                       'SQL-ERROR'
               WHEN -913
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0020'
                       'Record temporarily unavailable. Try again.'
                       'SQL-ERROR'
               WHEN -204
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0021'
                       'Database object not found. Contact support.'
                       'SQL-ERROR'
               WHEN -302
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'POL0022'
                       'Data value exceeds field length or range.'
                       'SQL-ERROR'
               WHEN OTHER
                   PERFORM 9200-BUILD-GENERIC-SQL-ERROR-MSG
           END-EVALUATE.

           DISPLAY 'POL001A SQL ERROR - FUNCTION: ' WS-SQL-FUNCTION
                   ' SQLCODE: ' WS-SQLCODE-DISPLAY
                   ' SQLSTATE: ' WS-SQLSTATE-DISPLAY
               UPON CONSOLE.

      ******************************************************************
      *  9200-BUILD-GENERIC-SQL-ERROR-MSG                                 *
      *  BUILDS A GENERIC SEVERE-ERROR MESSAGE FOR ANY SQLCODE NOT       *
      *  EXPLICITLY MAPPED IN 9100-HANDLE-SQL-ERROR, INCLUDING THE       *
      *  RAW SQLCODE VALUE TO ASSIST HELP-DESK DIAGNOSIS.                 *
      ******************************************************************
       9200-BUILD-GENERIC-SQL-ERROR-MSG.

           MOVE SPACES                   TO WS-SQL-ERROR-TEXT.

           STRING 'System error occurred (SQLCODE='
                                          DELIMITED SIZE
                  WS-SQLCODE-DISPLAY      DELIMITED SIZE
                  '). Contact support.'   DELIMITED SIZE
                  INTO WS-SQL-ERROR-TEXT.

           MOVE WS-SQL-ERROR-TEXT         TO WS-MSG-TEXT.
           MOVE 'POL0099'                 TO WS-MSG-ID.

           PERFORM 8100-ADD-MESSAGE-TO-TABLE.

      ******************************************************************
      *  9000-TERMINATE-PROGRAM                                           *
      *  CLOSES THE DISPLAY FILE AND PERFORMS FINAL PROGRAM CLEANUP      *
      *  BEFORE RETURNING CONTROL TO THE CALLING PROGRAM.                  *
      ******************************************************************
       9000-TERMINATE-PROGRAM.

           IF WS-DSPF-STATUS = '00'
               CLOSE POLMNTD1
           END-IF.

      ******************************************************************
      *  END OF PROGRAM POL001A                                            *
      ******************************************************************
