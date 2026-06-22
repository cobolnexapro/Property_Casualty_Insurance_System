      ******************************************************************
      *                                                                *
      *  PROGRAM      :  CUS001A                                       *
      *  SYSTEM       :  PCIS - PROPERTY & CASUALTY INSURANCE SYSTEM   *
      *  MODULE       :  CUSTOMER MANAGEMENT (CUS)                     *
      *  PURPOSE      :  CUSTOMER ADD - CREATES A NEW CUSTOMER MASTER  *
      *                  RECORD, ASSOCIATED PRIMARY ADDRESS AND        *
      *                  PRIMARY CONTACT, WITH FULL FIELD VALIDATION,  *
      *                  DUPLICATE CHECKING, AND AUDIT LOGGING.        *
      *                                                                *
      *  LANGUAGE     :  IBM ILE COBOL (ENTERPRISE COBOL FOR i)        *
      *  DATA ACCESS  :  EMBEDDED SQL / DB2 FOR i                      *
      *  UI           :  5250 DISPLAY FILE (DDS) - CUSMNTD1            *
      *                                                                *
      *  CALLED BY    :  CUSMNTP1 (CL DRIVER), CUS004A (SEARCH)        *
      *  CALLS        :  CUSVAL01 (SERVICE PROGRAM - FIELD VALIDATION) *
      *                  AUDLOG01 (SERVICE PROGRAM - AUDIT LOGGING)    *
      *                                                                *
      *  TABLES       :  CUSTOMER_T          (INSERT)                 *
      *                  CUSTOMER_ADDRESS_T  (INSERT)                 *
      *                  CUSTOMER_CONTACT_T  (INSERT)                 *
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
       PROGRAM-ID.    CUS001A.
       AUTHOR.        PCIS-APPLICATION-DEVELOPMENT-TEAM.
       DATE-WRITTEN.  2026-06-19.
       DATE-COMPILED.
      ******************************************************************
      *  PROGRAM ABSTRACT                                              *
      *  ----------------------------------------------------------    *
      *  THIS PROGRAM PRESENTS THE CUSTOMER MAINTENANCE PANEL IN ADD   *
      *  MODE, ACCEPTS NEW CUSTOMER DATA FROM THE OPERATOR, PERFORMS   *
      *  A FULL SUITE OF FIELD-LEVEL AND RELATIONAL VALIDATIONS,       *
      *  CHECKS FOR DUPLICATE SSN/TAX-ID, GENERATES A NEW CUSTOMER ID, *
      *  INSERTS THE CUSTOMER MASTER ROW PLUS OPTIONAL PRIMARY ADDRESS *
      *  AND CONTACT ROWS, WRITES AN AUDIT TRAIL ENTRY, AND RETURNS A  *
      *  SUCCESS CONFIRMATION TO THE OPERATOR. THE OPERATOR MAY THEN   *
      *  ADD ANOTHER CUSTOMER OR EXIT BACK TO THE CALLING PROGRAM.     *
      ******************************************************************
       ENVIRONMENT DIVISION.
      ******************************************************************
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.   IBM-I.
       OBJECT-COMPUTER.   IBM-I.
       SPECIAL-NAMES.
           CLASS NUMERIC-CLASS    IS "0123456789"
           CLASS ALPHA-CLASS      IS "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                      "abcdefghijklmnopqrstuvwxyz"
           CLASS VALID-GENDER     IS "M" "F" "U"
           CLASS VALID-MARITAL    IS "S" "M" "D" "W".

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CUSMNTD1 ASSIGN TO WORKSTATION-CUSMNTD1
               ORGANIZATION IS TRANSACTION
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-DSPF-STATUS.

       DATA DIVISION.
      ******************************************************************
       FILE SECTION.
      ******************************************************************
       FD  CUSMNTD1
           LABEL RECORDS ARE STANDARD.
       01  CUSMNTFM-RECORD.
           COPY DDS-CUSMNTFM.

      ******************************************************************
       WORKING-STORAGE SECTION.
      ******************************************************************
      *----------------------------------------------------------------*
      *  PROGRAM IDENTIFICATION / CONSTANTS                            *
      *----------------------------------------------------------------*
       01  WS-PROGRAM-CONSTANTS.
           05  WS-PROGRAM-NAME         PIC X(10)  VALUE 'CUS001A'.
           05  WS-PROGRAM-VERSION      PIC X(8)   VALUE '01.00.00'.
           05  WS-MODULE-CODE          PIC X(3)   VALUE 'CUS'.
           05  WS-TABLE-CUSTOMER       PIC X(30)  VALUE 'CUSTOMER_T'.
           05  WS-TABLE-CONTACT        PIC X(30)  VALUE
                                                'CUSTOMER_CONTACT_T'.
           05  WS-TABLE-ADDRESS        PIC X(30)  VALUE
                                                'CUSTOMER_ADDRESS_T'.
           05  WS-ACTION-ADD           PIC X(1)   VALUE 'A'.
           05  WS-ACTION-CHANGE        PIC X(1)   VALUE 'C'.
           05  WS-ACTION-DELETE        PIC X(1)   VALUE 'D'.

      *----------------------------------------------------------------*
      *  FILE STATUS / DEVICE WORK FIELDS                               *
      *----------------------------------------------------------------*
       01  WS-DSPF-STATUS              PIC X(2)   VALUE '00'.
       01  WS-INDICATORS-ON.
           05  WS-IND-03               PIC X(1)   VALUE 'N'.
           05  WS-IND-12                PIC X(1)   VALUE 'N'.
           05  WS-IND-30               PIC X(1)   VALUE 'N'.
           05  WS-IND-31               PIC X(1)   VALUE 'N'.
           05  WS-IND-99               PIC X(1)   VALUE 'N'.

      *----------------------------------------------------------------*
      *  PROGRAM CONTROL SWITCHES                                       *
      *----------------------------------------------------------------*
       01  WS-PROGRAM-SWITCHES.
           05  WS-END-OF-PROGRAM-SW    PIC X(1)   VALUE 'N'.
               88  END-OF-PROGRAM            VALUE 'Y'.
               88  NOT-END-OF-PROGRAM        VALUE 'N'.
           05  WS-VALID-DATA-SW        PIC X(1)   VALUE 'Y'.
               88  DATA-IS-VALID              VALUE 'Y'.
               88  DATA-IS-INVALID            VALUE 'N'.
           05  WS-DUPLICATE-FOUND-SW   PIC X(1)   VALUE 'N'.
               88  DUPLICATE-FOUND            VALUE 'Y'.
               88  DUPLICATE-NOT-FOUND        VALUE 'N'.
           05  WS-ADD-ANOTHER-SW       PIC X(1)   VALUE 'N'.
               88  ADD-ANOTHER-CUSTOMER       VALUE 'Y'.
               88  DO-NOT-ADD-ANOTHER         VALUE 'N'.
           05  WS-ADDRESS-ENTERED-SW   PIC X(1)   VALUE 'N'.
               88  ADDRESS-WAS-ENTERED        VALUE 'Y'.
               88  ADDRESS-NOT-ENTERED        VALUE 'N'.
           05  WS-CONTACT-ENTERED-SW   PIC X(1)   VALUE 'N'.
               88  CONTACT-WAS-ENTERED        VALUE 'Y'.
               88  CONTACT-NOT-ENTERED        VALUE 'N'.
           05  WS-SQL-ERROR-SW         PIC X(1)   VALUE 'N'.
               88  SQL-ERROR-OCCURRED         VALUE 'Y'.
               88  SQL-ERROR-DID-NOT-OCCUR    VALUE 'N'.
           05  WS-FATAL-ERROR-SW       PIC X(1)   VALUE 'N'.
               88  FATAL-ERROR-OCCURRED       VALUE 'Y'.
               88  NO-FATAL-ERROR             VALUE 'N'.

      *----------------------------------------------------------------*
      *  MESSAGE / ERROR HANDLING WORK AREA                             *
      *----------------------------------------------------------------*
       01  WS-MESSAGE-AREA.
           05  WS-MSG-COUNT            PIC 9(3)   VALUE 0.
           05  WS-MSG-TEXT             PIC X(79)  VALUE SPACES.
           05  WS-MSG-ID               PIC X(7)   VALUE SPACES.
           05  WS-MSG-SEVERITY         PIC 9(2)   VALUE 0.
           05  WS-MSG-TABLE-MAX        PIC 9(2)   VALUE 20.
           05  WS-MSG-TABLE-IDX        PIC 9(2)   VALUE 0.
           05  WS-MSG-ENTRY OCCURS 20 TIMES
                                       INDEXED BY MSG-IDX.
               10  WS-MSG-ENTRY-ID     PIC X(7).
               10  WS-MSG-ENTRY-TEXT   PIC X(79).
               10  WS-MSG-ENTRY-FIELD  PIC X(20).

      *----------------------------------------------------------------*
      *  SQLCA - SQL COMMUNICATIONS AREA                                 *
      *----------------------------------------------------------------*
           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      *----------------------------------------------------------------*
      *  SQL ERROR HANDLING WORK FIELDS                                  *
      *----------------------------------------------------------------*
       01  WS-SQL-WORK-AREA.
           05  WS-SQLCODE-DISPLAY      PIC -9(9)  VALUE 0.
           05  WS-SQLSTATE-DISPLAY     PIC X(5)   VALUE SPACES.
           05  WS-SQL-ERROR-TEXT       PIC X(100) VALUE SPACES.
           05  WS-SQL-FUNCTION         PIC X(30)  VALUE SPACES.
           05  WS-SQL-ROW-COUNT        PIC S9(9)  COMP-3 VALUE 0.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - CUSTOMER_T                                    *
      *----------------------------------------------------------------*
       01  HV-CUSTOMER-ROW.
           05  HV-CUST-ID              PIC X(10)  VALUE SPACES.
           05  HV-CUST-TYPE            PIC X(1)   VALUE SPACES.
           05  HV-CUST-NAME            PIC X(60)  VALUE SPACES.
           05  HV-CUST-NAME-LEN        PIC S9(4)  COMP-4 VALUE 0.
           05  HV-CUST-DOB             PIC X(10)  VALUE SPACES.
           05  HV-CUST-DOB-NULL        PIC S9(4)  COMP-4 VALUE 0.
           05  HV-CUST-SSN-TAXID       PIC X(11)  VALUE SPACES.
           05  HV-CUST-GENDER          PIC X(1)   VALUE SPACES.
           05  HV-CUST-GENDER-NULL     PIC S9(4)  COMP-4 VALUE 0.
           05  HV-CUST-MARITAL-ST      PIC X(1)   VALUE SPACES.
           05  HV-CUST-MARITAL-NULL    PIC S9(4)  COMP-4 VALUE 0.
           05  HV-CUST-EMAIL           PIC X(60)  VALUE SPACES.
           05  HV-CUST-EMAIL-LEN       PIC S9(4)  COMP-4 VALUE 0.
           05  HV-CUST-EMAIL-NULL      PIC S9(4)  COMP-4 VALUE 0.
           05  HV-CUST-PHONE           PIC X(15)  VALUE SPACES.
           05  HV-CUST-PHONE-NULL      PIC S9(4)  COMP-4 VALUE 0.
           05  HV-CUST-STATUS          PIC X(1)   VALUE 'A'.
           05  HV-CUST-CREDIT-SCORE    PIC S9(4)  COMP-4 VALUE 0.
           05  HV-CUST-CREDIT-NULL     PIC S9(4)  COMP-4 VALUE 0.
           05  HV-CRT-USER             PIC X(10)  VALUE SPACES.
           05  HV-CRT-TIMESTAMP        PIC X(26)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - CUSTOMER_ADDRESS_T                             *
      *----------------------------------------------------------------*
       01  HV-ADDRESS-ROW.
           05  HV-ADDR-ID              PIC S9(18) COMP-3 VALUE 0.
           05  HV-ADDR-CUST-ID         PIC X(10)  VALUE SPACES.
           05  HV-ADDR-TYPE            PIC X(1)   VALUE 'M'.
           05  HV-ADDR-LINE1           PIC X(40)  VALUE SPACES.
           05  HV-ADDR-LINE1-LEN       PIC S9(4)  COMP-4 VALUE 0.
           05  HV-ADDR-LINE2           PIC X(40)  VALUE SPACES.
           05  HV-ADDR-LINE2-LEN       PIC S9(4)  COMP-4 VALUE 0.
           05  HV-ADDR-LINE2-NULL      PIC S9(4)  COMP-4 VALUE 0.
           05  HV-ADDR-CITY            PIC X(30)  VALUE SPACES.
           05  HV-ADDR-CITY-LEN        PIC S9(4)  COMP-4 VALUE 0.
           05  HV-ADDR-STATE           PIC X(2)   VALUE SPACES.
           05  HV-ADDR-ZIP             PIC X(10)  VALUE SPACES.
           05  HV-ADDR-CRT-USER        PIC X(10)  VALUE SPACES.
           05  HV-ADDR-CRT-TIMESTAMP   PIC X(26)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - CUSTOMER_CONTACT_T                             *
      *----------------------------------------------------------------*
       01  HV-CONTACT-ROW.
           05  HV-CONT-ID              PIC S9(18) COMP-3 VALUE 0.
           05  HV-CONT-CUST-ID         PIC X(10)  VALUE SPACES.
           05  HV-CONT-TYPE            PIC X(2)   VALUE SPACES.
           05  HV-CONT-VALUE           PIC X(60)  VALUE SPACES.
           05  HV-CONT-VALUE-LEN       PIC S9(4)  COMP-4 VALUE 0.
           05  HV-CONT-IS-PRIMARY      PIC X(1)   VALUE 'Y'.
           05  HV-CONT-CRT-USER        PIC X(10)  VALUE SPACES.
           05  HV-CONT-CRT-TIMESTAMP   PIC X(26)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  HOST VARIABLES - DUPLICATE CHECK / KEY GENERATION              *
      *----------------------------------------------------------------*
       01  HV-MISC-WORK.
           05  HV-DUP-COUNT            PIC S9(9)  COMP-4 VALUE 0.
           05  HV-NEXT-CUST-ID         PIC X(10)  VALUE SPACES.
           05  HV-NEXT-CUST-SEQ        PIC S9(9)  COMP-4 VALUE 0.
           05  HV-CURRENT-USER         PIC X(10)  VALUE SPACES.
           05  HV-CURRENT-TIMESTAMP    PIC X(26)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  SCREEN FIELD WORK AREA - MIRRORS DDS FIELDS ON CUSMNTFM         *
      *----------------------------------------------------------------*
       01  WS-SCREEN-FIELDS.
           05  WS-SCR-MODE             PIC X(1)   VALUE 'A'.
           05  WS-SCR-CUST-ID          PIC X(10)  VALUE SPACES.
           05  WS-SCR-CUST-TYPE        PIC X(1)   VALUE SPACES.
           05  WS-SCR-CUST-NAME        PIC X(60)  VALUE SPACES.
           05  WS-SCR-CUST-DOB         PIC X(10)  VALUE SPACES.
           05  WS-SCR-CUST-SSN         PIC X(11)  VALUE SPACES.
           05  WS-SCR-CUST-GENDER      PIC X(1)   VALUE SPACES.
           05  WS-SCR-CUST-MARITAL     PIC X(1)   VALUE SPACES.
           05  WS-SCR-CUST-EMAIL       PIC X(60)  VALUE SPACES.
           05  WS-SCR-CUST-PHONE       PIC X(15)  VALUE SPACES.
           05  WS-SCR-CUST-STATUS      PIC X(1)   VALUE SPACES.
           05  WS-SCR-CUST-CREDIT      PIC 9(5)   VALUE 0.
           05  WS-SCR-ADDR-LINE1       PIC X(40)  VALUE SPACES.
           05  WS-SCR-ADDR-LINE2       PIC X(40)  VALUE SPACES.
           05  WS-SCR-ADDR-CITY        PIC X(30)  VALUE SPACES.
           05  WS-SCR-ADDR-STATE       PIC X(2)   VALUE SPACES.
           05  WS-SCR-ADDR-ZIP         PIC X(10)  VALUE SPACES.
           05  WS-SCR-CONT-TYPE        PIC X(2)   VALUE SPACES.
           05  WS-SCR-CONT-VALUE       PIC X(60)  VALUE SPACES.
           05  WS-SCR-MSG-LINE         PIC X(79)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  VALIDATION WORK FIELDS                                         *
      *----------------------------------------------------------------*
       01  WS-VALIDATION-WORK-AREA.
           05  WS-VAL-NAME-LEN         PIC 9(3)   VALUE 0.
           05  WS-VAL-EMAIL-LEN        PIC 9(3)   VALUE 0.
           05  WS-VAL-PHONE-LEN        PIC 9(3)   VALUE 0.
           05  WS-VAL-AT-POS           PIC 9(3)   VALUE 0.
           05  WS-VAL-DOT-POS          PIC 9(3)   VALUE 0.
           05  WS-VAL-CHAR-IDX         PIC 9(3)   VALUE 0.
           05  WS-VAL-ONE-CHAR         PIC X(1)   VALUE SPACE.
           05  WS-VAL-NUMERIC-FLAG     PIC X(1)   VALUE 'Y'.
           05  WS-VAL-AGE-YEARS        PIC S9(4)  VALUE 0.
           05  WS-VAL-CURRENT-DATE     PIC X(10)  VALUE SPACES.
           05  WS-VAL-CURRENT-YEAR     PIC 9(4)   VALUE 0.
           05  WS-VAL-CURRENT-MONTH    PIC 9(2)   VALUE 0.
           05  WS-VAL-CURRENT-DAY      PIC 9(2)   VALUE 0.
           05  WS-VAL-DOB-YEAR         PIC 9(4)   VALUE 0.
           05  WS-VAL-DOB-MONTH        PIC 9(2)   VALUE 0.
           05  WS-VAL-DOB-DAY          PIC 9(2)   VALUE 0.
           05  WS-VAL-ZIP-LEN          PIC 9(3)   VALUE 0.
           05  WS-VAL-PHONE-DIGITS     PIC X(15)  VALUE SPACES.
           05  WS-VAL-PHONE-DIGIT-CNT  PIC 9(3)   VALUE 0.
           05  WS-VAL-ADDRESS-FIELDS-CNT
                                       PIC 9(2)   VALUE 0.

      *----------------------------------------------------------------*
      *  CODE TABLES - VALID VALUE LISTS                                 *
      *----------------------------------------------------------------*
       01  WS-CODE-TABLES.
           05  WS-VALID-CUST-TYPES     PIC X(2)   VALUE 'IB'.
           05  WS-VALID-STATUSES       PIC X(3)   VALUE 'AID'.
           05  WS-VALID-GENDERS        PIC X(3)   VALUE 'MFU'.
           05  WS-VALID-MARITAL-CODES  PIC X(4)   VALUE 'SMDW'.

      *----------------------------------------------------------------*
      *  LINKAGE PARAMETER MIRROR (FOR LOCAL USE AFTER MOVE)             *
      *----------------------------------------------------------------*
       01  WS-CALLING-PROGRAM-INFO.
           05  WS-CALLING-PGM          PIC X(10)  VALUE SPACES.
           05  WS-RETURN-CUST-ID       PIC X(10)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  CUSVAL01 SERVICE PROGRAM INTERFACE WORK AREA                    *
      *----------------------------------------------------------------*
       01  WS-CUSVAL01-INTERFACE.
           05  WS-CUSVAL01-FUNCTION    PIC X(10)  VALUE SPACES.
           05  WS-CUSVAL01-INPUT-DATA  PIC X(60)  VALUE SPACES.
           05  WS-CUSVAL01-RETURN-CD   PIC X(2)   VALUE '00'.
           05  WS-CUSVAL01-RETURN-MSG  PIC X(79)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  AUDLOG01 SERVICE PROGRAM INTERFACE WORK AREA                    *
      *----------------------------------------------------------------*
       01  WS-AUDLOG01-INTERFACE.
           05  WS-AUD-TABLE-NAME       PIC X(30)  VALUE SPACES.
           05  WS-AUD-KEY-VALUE        PIC X(40)  VALUE SPACES.
           05  WS-AUD-ACTION-CD        PIC X(1)   VALUE SPACES.
           05  WS-AUD-FIELD-NAME       PIC X(30)  VALUE SPACES.
           05  WS-AUD-OLD-VALUE        PIC X(100) VALUE SPACES.
           05  WS-AUD-NEW-VALUE        PIC X(100) VALUE SPACES.
           05  WS-AUD-CHG-USER         PIC X(10)  VALUE SPACES.
           05  WS-AUD-PROGRAM-NAME     PIC X(10)  VALUE SPACES.
           05  WS-AUD-RETURN-CD        PIC X(2)   VALUE '00'.

      ******************************************************************
       LINKAGE SECTION.
      ******************************************************************
      *----------------------------------------------------------------*
      *  PARAMETERS PASSED FROM CALLING PROGRAM (CUSMNTP1 / CUS004A)    *
      *----------------------------------------------------------------*
       01  LK-CALLING-PGM              PIC X(10).
       01  LK-RETURN-CUST-ID           PIC X(10).

      ******************************************************************
       PROCEDURE DIVISION USING LK-CALLING-PGM
                                 LK-RETURN-CUST-ID.
      ******************************************************************
      *                                                                *
      *  MAIN CONTROL PARAGRAPH                                        *
      *  THIS IS THE FIRST PARAGRAPH EXECUTED WHEN THE PROGRAM IS      *
      *  CALLED. IT INITIALIZES WORKING STORAGE, DRIVES THE ADD-MODE   *
      *  SCREEN LOOP, AND PERFORMS PROGRAM TERMINATION CLEANUP.        *
      *                                                                *
      ******************************************************************
       0000-MAIN-CONTROL.

           PERFORM 1000-INITIALIZE-PROGRAM.

           PERFORM 2000-PROCESS-ADD-CYCLE
               UNTIL END-OF-PROGRAM.

           PERFORM 9000-TERMINATE-PROGRAM.

           GOBACK.

      ******************************************************************
      *  1000-INITIALIZE-PROGRAM                                       *
      *  PERFORMS ONE-TIME PROGRAM INITIALIZATION INCLUDING MOVING     *
      *  LINKAGE PARAMETERS TO WORKING STORAGE, RETRIEVING THE         *
      *  CURRENT USER PROFILE AND TIMESTAMP, AND OPENING THE DISPLAY   *
      *  FILE.                                                         *
      ******************************************************************
       1000-INITIALIZE-PROGRAM.

           MOVE LK-CALLING-PGM        TO WS-CALLING-PGM.
           MOVE SPACES                TO WS-RETURN-CUST-ID.
           MOVE 'N'                   TO WS-END-OF-PROGRAM-SW.
           MOVE 'Y'                   TO WS-VALID-DATA-SW.
           MOVE 'N'                   TO WS-DUPLICATE-FOUND-SW.
           MOVE 0                     TO WS-MSG-COUNT.

           PERFORM 1100-RETRIEVE-CURRENT-USER.
           PERFORM 1200-RETRIEVE-CURRENT-TIMESTAMP.
           PERFORM 1300-OPEN-DISPLAY-FILE.
           PERFORM 1400-CLEAR-SCREEN-FIELDS.

      ******************************************************************
      *  1100-RETRIEVE-CURRENT-USER                                    *
      *  RETRIEVES THE CURRENT IBM I JOB USER PROFILE VIA EMBEDDED SQL *
      *  SPECIAL REGISTER FOR USE IN CRT-USER / AUDIT STAMPING.        *
      ******************************************************************
       1100-RETRIEVE-CURRENT-USER.

           EXEC SQL
               SET :HV-CURRENT-USER = CURRENT USER
           END-EXEC.

           IF SQLCODE NOT = 0
               MOVE 'PCISBATCH'       TO HV-CURRENT-USER
           END-IF.

      ******************************************************************
      *  1200-RETRIEVE-CURRENT-TIMESTAMP                                *
      *  RETRIEVES THE CURRENT TIMESTAMP FOR USE IN CRT-TIMESTAMP AND  *
      *  ALL RELATED AUDIT/CHANGE-TRACKING COLUMNS.                    *
      ******************************************************************
       1200-RETRIEVE-CURRENT-TIMESTAMP.

           EXEC SQL
               SET :HV-CURRENT-TIMESTAMP = CURRENT TIMESTAMP
           END-EXEC.

      ******************************************************************
      *  1300-OPEN-DISPLAY-FILE                                        *
      *  OPENS THE CUSMNTD1 DISPLAY FILE FOR I-O PROCESSING.           *
      ******************************************************************
       1300-OPEN-DISPLAY-FILE.

           OPEN I-O CUSMNTD1.

           IF WS-DSPF-STATUS NOT = '00'
               MOVE 'Y'               TO WS-FATAL-ERROR-SW
               MOVE 'Y'               TO WS-END-OF-PROGRAM-SW
           END-IF.

      ******************************************************************
      *  1400-CLEAR-SCREEN-FIELDS                                      *
      *  INITIALIZES ALL SCREEN WORK FIELDS TO BLANK/ZERO IN            *
      *  PREPARATION FOR A NEW ADD CYCLE.                               *
      ******************************************************************
       1400-CLEAR-SCREEN-FIELDS.

           MOVE SPACES                TO WS-SCR-CUST-ID.
           MOVE SPACES                TO WS-SCR-CUST-TYPE.
           MOVE SPACES                TO WS-SCR-CUST-NAME.
           MOVE SPACES                TO WS-SCR-CUST-DOB.
           MOVE SPACES                TO WS-SCR-CUST-SSN.
           MOVE SPACES                TO WS-SCR-CUST-GENDER.
           MOVE SPACES                TO WS-SCR-CUST-MARITAL.
           MOVE SPACES                TO WS-SCR-CUST-EMAIL.
           MOVE SPACES                TO WS-SCR-CUST-PHONE.
           MOVE 'A'                   TO WS-SCR-CUST-STATUS.
           MOVE 0                     TO WS-SCR-CUST-CREDIT.
           MOVE SPACES                TO WS-SCR-ADDR-LINE1.
           MOVE SPACES                TO WS-SCR-ADDR-LINE2.
           MOVE SPACES                TO WS-SCR-ADDR-CITY.
           MOVE SPACES                TO WS-SCR-ADDR-STATE.
           MOVE SPACES                TO WS-SCR-ADDR-ZIP.
           MOVE SPACES                TO WS-SCR-CONT-TYPE.
           MOVE SPACES                TO WS-SCR-CONT-VALUE.
           MOVE SPACES                TO WS-SCR-MSG-LINE.
           MOVE 'A'                   TO WS-SCR-MODE.

      ******************************************************************
      *  2000-PROCESS-ADD-CYCLE                                        *
      *  MAIN SCREEN/PROCESS LOOP. DISPLAYS THE ADD PANEL, READS THE   *
      *  OPERATOR RESPONSE, AND DISPATCHES TO VALIDATION/INSERT LOGIC  *
      *  OR PROGRAM EXIT BASED ON THE FUNCTION KEY PRESSED.            *
      ******************************************************************
       2000-PROCESS-ADD-CYCLE.

           PERFORM 2100-DISPLAY-ADD-SCREEN.
           PERFORM 2200-READ-ADD-SCREEN.

           EVALUATE TRUE
               WHEN WS-IND-03 = 'Y'
                   MOVE 'Y'           TO WS-END-OF-PROGRAM-SW
               WHEN WS-IND-12 = 'Y'
                   MOVE 'Y'           TO WS-END-OF-PROGRAM-SW
               WHEN OTHER
                   PERFORM 2300-PROCESS-ENTER-KEY
           END-EVALUATE.

      ******************************************************************
      *  2100-DISPLAY-ADD-SCREEN                                       *
      *  MOVES CURRENT WORK FIELDS TO THE SCREEN RECORD AND WRITES     *
      *  THE PANEL TO THE 5250 DEVICE.                                 *
      ******************************************************************
       2100-DISPLAY-ADD-SCREEN.

           MOVE WS-SCR-MODE            TO SCR-MODE OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-ID         TO SCR-CUST-ID OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-TYPE       TO SCR-CUST-TYPE OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-NAME       TO SCR-CUST-NAME OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-DOB        TO SCR-CUST-DOB OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-SSN        TO SCR-CUST-SSN OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-GENDER     TO SCR-CUST-GENDER OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-MARITAL    TO SCR-CUST-MARITAL OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-EMAIL      TO SCR-CUST-EMAIL OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-PHONE      TO SCR-CUST-PHONE OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-STATUS     TO SCR-CUST-STATUS OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CUST-CREDIT     TO SCR-CUST-CREDIT OF CUSMNTFM-RECORD.
           MOVE WS-SCR-ADDR-LINE1      TO SCR-ADDR-LINE1 OF CUSMNTFM-RECORD.
           MOVE WS-SCR-ADDR-LINE2      TO SCR-ADDR-LINE2 OF CUSMNTFM-RECORD.
           MOVE WS-SCR-ADDR-CITY       TO SCR-ADDR-CITY OF CUSMNTFM-RECORD.
           MOVE WS-SCR-ADDR-STATE      TO SCR-ADDR-STATE OF CUSMNTFM-RECORD.
           MOVE WS-SCR-ADDR-ZIP        TO SCR-ADDR-ZIP OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CONT-TYPE       TO SCR-CONT-TYPE OF CUSMNTFM-RECORD.
           MOVE WS-SCR-CONT-VALUE      TO SCR-CONT-VALUE OF CUSMNTFM-RECORD.
           MOVE WS-SCR-MSG-LINE        TO SCR-MSG OF CUSMNTFM-RECORD.

           WRITE CUSMNTFM-RECORD.

           MOVE SPACES                TO WS-SCR-MSG-LINE.
           MOVE 0                     TO WS-MSG-COUNT.

      ******************************************************************
      *  2200-READ-ADD-SCREEN                                          *
      *  READS THE OPERATOR'S RESPONSE FROM THE 5250 DEVICE AND MOVES  *
      *  EACH SCREEN FIELD INTO THE CORRESPONDING WORKING STORAGE      *
      *  FIELD FOR VALIDATION AND DOWNSTREAM PROCESSING.               *
      ******************************************************************
       2200-READ-ADD-SCREEN.

           MOVE 'N'                   TO WS-IND-03.
           MOVE 'N'                   TO WS-IND-12.

           READ CUSMNTD1.

           IF INDICATOR-03-ON-OF-CUSMNTFM-RECORD
               MOVE 'Y'               TO WS-IND-03
           END-IF.

           IF INDICATOR-12-ON-OF-CUSMNTFM-RECORD
               MOVE 'Y'               TO WS-IND-12
           END-IF.

           MOVE SCR-CUST-TYPE OF CUSMNTFM-RECORD    TO WS-SCR-CUST-TYPE.
           MOVE SCR-CUST-NAME OF CUSMNTFM-RECORD    TO WS-SCR-CUST-NAME.
           MOVE SCR-CUST-DOB OF CUSMNTFM-RECORD     TO WS-SCR-CUST-DOB.
           MOVE SCR-CUST-SSN OF CUSMNTFM-RECORD     TO WS-SCR-CUST-SSN.
           MOVE SCR-CUST-GENDER OF CUSMNTFM-RECORD  TO WS-SCR-CUST-GENDER.
           MOVE SCR-CUST-MARITAL OF CUSMNTFM-RECORD TO WS-SCR-CUST-MARITAL.
           MOVE SCR-CUST-EMAIL OF CUSMNTFM-RECORD   TO WS-SCR-CUST-EMAIL.
           MOVE SCR-CUST-PHONE OF CUSMNTFM-RECORD   TO WS-SCR-CUST-PHONE.
           MOVE SCR-CUST-STATUS OF CUSMNTFM-RECORD  TO WS-SCR-CUST-STATUS.
           MOVE SCR-CUST-CREDIT OF CUSMNTFM-RECORD  TO WS-SCR-CUST-CREDIT.
           MOVE SCR-ADDR-LINE1 OF CUSMNTFM-RECORD   TO WS-SCR-ADDR-LINE1.
           MOVE SCR-ADDR-LINE2 OF CUSMNTFM-RECORD   TO WS-SCR-ADDR-LINE2.
           MOVE SCR-ADDR-CITY OF CUSMNTFM-RECORD    TO WS-SCR-ADDR-CITY.
           MOVE SCR-ADDR-STATE OF CUSMNTFM-RECORD   TO WS-SCR-ADDR-STATE.
           MOVE SCR-ADDR-ZIP OF CUSMNTFM-RECORD     TO WS-SCR-ADDR-ZIP.
           MOVE SCR-CONT-TYPE OF CUSMNTFM-RECORD    TO WS-SCR-CONT-TYPE.
           MOVE SCR-CONT-VALUE OF CUSMNTFM-RECORD   TO WS-SCR-CONT-VALUE.

      ******************************************************************
      *  2300-PROCESS-ENTER-KEY                                        *
      *  DRIVES THE FULL ADD TRANSACTION WHEN THE OPERATOR PRESSES     *
      *  ENTER: VALIDATION, DUPLICATE CHECK, KEY GENERATION, INSERT,   *
      *  AUDIT LOGGING, AND CONFIRMATION MESSAGE / ADD-ANOTHER PROMPT. *
      ******************************************************************
       2300-PROCESS-ENTER-KEY.

           MOVE 'Y'                   TO WS-VALID-DATA-SW.
           MOVE 0                     TO WS-MSG-COUNT.

           PERFORM 3000-VALIDATE-ALL-FIELDS.

           IF DATA-IS-VALID
               PERFORM 4000-CHECK-DUPLICATE-CUSTOMER
           END-IF.

           IF DATA-IS-VALID AND DUPLICATE-NOT-FOUND
               PERFORM 5000-GENERATE-CUSTOMER-ID
               PERFORM 6000-INSERT-CUSTOMER-RECORD
           END-IF.

           IF DATA-IS-VALID AND DUPLICATE-NOT-FOUND
              AND SQL-ERROR-DID-NOT-OCCUR
               PERFORM 6500-INSERT-ADDRESS-IF-ENTERED
               PERFORM 6600-INSERT-CONTACT-IF-ENTERED
           END-IF.

           IF DATA-IS-VALID AND DUPLICATE-NOT-FOUND
              AND SQL-ERROR-DID-NOT-OCCUR
               PERFORM 7000-WRITE-AUDIT-RECORDS
               PERFORM 7500-BUILD-SUCCESS-MESSAGE
               PERFORM 7600-RESET-FOR-NEXT-CUSTOMER
           ELSE
               PERFORM 8000-BUILD-ERROR-MESSAGE-LINE
           END-IF.

      ******************************************************************
      *  3000-VALIDATE-ALL-FIELDS                                      *
      *  TOP-LEVEL VALIDATION DISPATCHER. CALLS EACH FIELD-LEVEL        *
      *  VALIDATION PARAGRAPH IN SCREEN ORDER. ALL FAILURES ARE         *
      *  ACCUMULATED INTO THE MESSAGE TABLE SO THE OPERATOR SEES        *
      *  EVERY PROBLEM IN A SINGLE PASS.                                *
      ******************************************************************
       3000-VALIDATE-ALL-FIELDS.

           PERFORM 3100-VALIDATE-CUST-TYPE.
           PERFORM 3200-VALIDATE-CUST-NAME.
           PERFORM 3300-VALIDATE-CUST-DOB.
           PERFORM 3400-VALIDATE-CUST-SSN.
           PERFORM 3500-VALIDATE-CUST-GENDER.
           PERFORM 3600-VALIDATE-CUST-MARITAL.
           PERFORM 3700-VALIDATE-CUST-EMAIL.
           PERFORM 3800-VALIDATE-CUST-PHONE.
           PERFORM 3900-VALIDATE-CUST-STATUS.
           PERFORM 3950-VALIDATE-CUST-CREDIT-SCORE.
           PERFORM 4100-VALIDATE-ADDRESS-FIELDS.
           PERFORM 4200-VALIDATE-CONTACT-FIELDS.

           IF WS-MSG-COUNT > 0
               MOVE 'N'               TO WS-VALID-DATA-SW
           ELSE
               MOVE 'Y'               TO WS-VALID-DATA-SW
           END-IF.

      ******************************************************************
      *  3100-VALIDATE-CUST-TYPE                                       *
      *  CUSTOMER TYPE IS REQUIRED AND MUST BE 'I' (INDIVIDUAL) OR     *
      *  'B' (BUSINESS). MESSAGE CUS0011 ON FAILURE.                   *
      ******************************************************************
       3100-VALIDATE-CUST-TYPE.

           IF WS-SCR-CUST-TYPE = SPACES
               PERFORM 8100-ADD-MESSAGE-TO-TABLE
                   WITH 'CUS0011' 'Customer Type is required (I/B).'
                        'CUST-TYPE'
           ELSE
               IF WS-SCR-CUST-TYPE NOT = 'I' AND
                  WS-SCR-CUST-TYPE NOT = 'B'
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0011' 'Customer Type must be I or B.'
                            'CUST-TYPE'
               END-IF
           END-IF.

      ******************************************************************
      *  3200-VALIDATE-CUST-NAME                                       *
      *  CUSTOMER NAME IS REQUIRED, NON-BLANK, AND MUST BE AT LEAST    *
      *  TWO CHARACTERS IN LENGTH. MESSAGE CUS0012 ON FAILURE.         *
      ******************************************************************
       3200-VALIDATE-CUST-NAME.

           MOVE 0                     TO WS-VAL-NAME-LEN.

           PERFORM VARYING WS-VAL-CHAR-IDX FROM 60 BY -1
               UNTIL WS-VAL-CHAR-IDX = 0
                  OR WS-SCR-CUST-NAME(WS-VAL-CHAR-IDX:1) NOT = SPACE
               CONTINUE
           END-PERFORM.

           MOVE WS-VAL-CHAR-IDX       TO WS-VAL-NAME-LEN.

           IF WS-VAL-NAME-LEN = 0
               PERFORM 8100-ADD-MESSAGE-TO-TABLE
                   WITH 'CUS0012' 'Customer Name is required.'
                        'CUST-NAME'
           ELSE
               IF WS-VAL-NAME-LEN < 2
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0012'
                       'Customer Name must be at least 2 characters.'
                       'CUST-NAME'
               END-IF
           END-IF.

      ******************************************************************
      *  3300-VALIDATE-CUST-DOB                                        *
      *  DATE OF BIRTH IS REQUIRED FOR INDIVIDUAL CUSTOMERS (TYPE I),  *
      *  MUST BE A VALID DATE, AND MUST RESULT IN AN AGE OF AT LEAST   *
      *  16 YEARS. NOT REQUIRED FOR BUSINESS CUSTOMERS (TYPE B).      *
      *  MESSAGE CUS0013 ON FAILURE.                                   *
      ******************************************************************
       3300-VALIDATE-CUST-DOB.

           IF WS-SCR-CUST-TYPE = 'I'
               IF WS-SCR-CUST-DOB = SPACES
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0013'
                       'Date of Birth is required for individuals.'
                       'CUST-DOB'
               ELSE
                   PERFORM 3310-VALIDATE-DOB-FORMAT
                   IF DATA-IS-VALID OR WS-MSG-COUNT = 0
                       PERFORM 3320-VALIDATE-DOB-AGE
                   END-IF
               END-IF
           END-IF.

      ******************************************************************
      *  3310-VALIDATE-DOB-FORMAT                                      *
      *  VALIDATES THAT THE DATE OF BIRTH FIELD CONFORMS TO THE        *
      *  EXPECTED ISO FORMAT YYYY-MM-DD AND CONTAINS A NUMERICALLY     *
      *  VALID YEAR, MONTH AND DAY COMPONENT.                          *
      ******************************************************************
       3310-VALIDATE-DOB-FORMAT.

           MOVE WS-SCR-CUST-DOB(1:4)  TO WS-VAL-DOB-YEAR.
           MOVE WS-SCR-CUST-DOB(6:2)  TO WS-VAL-DOB-MONTH.
           MOVE WS-SCR-CUST-DOB(9:2)  TO WS-VAL-DOB-DAY.

           IF WS-SCR-CUST-DOB(5:1) NOT = '-' OR
              WS-SCR-CUST-DOB(8:1) NOT = '-'
               PERFORM 8100-ADD-MESSAGE-TO-TABLE
                   WITH 'CUS0013'
                   'Date of Birth must be in YYYY-MM-DD format.'
                   'CUST-DOB'
           ELSE
               IF WS-VAL-DOB-MONTH < 1 OR WS-VAL-DOB-MONTH > 12
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0013' 'Date of Birth month is invalid.'
                            'CUST-DOB'
               END-IF
               IF WS-VAL-DOB-DAY < 1 OR WS-VAL-DOB-DAY > 31
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0013' 'Date of Birth day is invalid.'
                            'CUST-DOB'
               END-IF
               IF WS-VAL-DOB-YEAR < 1900
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0013' 'Date of Birth year is invalid.'
                            'CUST-DOB'
               END-IF
           END-IF.

      ******************************************************************
      *  3320-VALIDATE-DOB-AGE                                          *
      *  COMPUTES APPROXIMATE AGE FROM DATE OF BIRTH AND REJECTS THE   *
      *  ENTRY IF THE COMPUTED AGE IS LESS THAN 16 YEARS.               *
      ******************************************************************
       3320-VALIDATE-DOB-AGE.

           EXEC SQL
               SET :WS-VAL-CURRENT-DATE = CURRENT DATE
           END-EXEC.

           MOVE WS-VAL-CURRENT-DATE(1:4) TO WS-VAL-CURRENT-YEAR.
           MOVE WS-VAL-CURRENT-DATE(6:2) TO WS-VAL-CURRENT-MONTH.
           MOVE WS-VAL-CURRENT-DATE(9:2) TO WS-VAL-CURRENT-DAY.

           COMPUTE WS-VAL-AGE-YEARS =
               WS-VAL-CURRENT-YEAR - WS-VAL-DOB-YEAR.

           IF WS-VAL-CURRENT-MONTH < WS-VAL-DOB-MONTH
               SUBTRACT 1 FROM WS-VAL-AGE-YEARS
           ELSE
               IF WS-VAL-CURRENT-MONTH = WS-VAL-DOB-MONTH AND
                  WS-VAL-CURRENT-DAY < WS-VAL-DOB-DAY
                   SUBTRACT 1 FROM WS-VAL-AGE-YEARS
               END-IF
           END-IF.

           IF WS-VAL-AGE-YEARS < 16
               PERFORM 8100-ADD-MESSAGE-TO-TABLE
                   WITH 'CUS0013'
                   'Customer must be at least 16 years of age.'
                   'CUST-DOB'
           END-IF.

      ******************************************************************
      *  3400-VALIDATE-CUST-SSN                                        *
      *  SSN / TAX ID IS REQUIRED AND MUST CONFORM TO ONE OF TWO       *
      *  FORMATS: 9 NUMERIC DIGITS (PERSONAL SSN) OR A VALID-LOOKING   *
      *  BUSINESS EIN PATTERN. UNIQUENESS IS CHECKED SEPARATELY IN     *
      *  PARAGRAPH 4000. MESSAGE CUS0014 ON FORMAT FAILURE.            *
      ******************************************************************
       3400-VALIDATE-CUST-SSN.

           IF WS-SCR-CUST-SSN = SPACES
               PERFORM 8100-ADD-MESSAGE-TO-TABLE
                   WITH 'CUS0014' 'SSN / Tax ID is required.'
                        'CUST-SSN'
           ELSE
               MOVE 'Y'               TO WS-VAL-NUMERIC-FLAG
               PERFORM VARYING WS-VAL-CHAR-IDX FROM 1 BY 1
                   UNTIL WS-VAL-CHAR-IDX > 11
                   MOVE WS-SCR-CUST-SSN(WS-VAL-CHAR-IDX:1)
                                       TO WS-VAL-ONE-CHAR
                   IF WS-VAL-ONE-CHAR NOT = '-' AND
                      WS-VAL-ONE-CHAR NOT NUMERIC AND
                      WS-VAL-ONE-CHAR NOT = SPACE
                       MOVE 'N'        TO WS-VAL-NUMERIC-FLAG
                   END-IF
               END-PERFORM
               IF WS-VAL-NUMERIC-FLAG = 'N'
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0014'
                       'SSN / Tax ID format is invalid.'
                       'CUST-SSN'
               END-IF
           END-IF.

      ******************************************************************
      *  3500-VALIDATE-CUST-GENDER                                     *
      *  GENDER IS OPTIONAL. IF ENTERED, MUST BE M, F, OR U.           *
      *  MESSAGE CUS0016 ON FAILURE.                                   *
      ******************************************************************
       3500-VALIDATE-CUST-GENDER.

           IF WS-SCR-CUST-GENDER NOT = SPACES
               IF WS-SCR-CUST-GENDER NOT = 'M' AND
                  WS-SCR-CUST-GENDER NOT = 'F' AND
                  WS-SCR-CUST-GENDER NOT = 'U'
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0016' 'Gender must be M, F, or U.'
                            'CUST-GENDER'
               END-IF
           END-IF.

      ******************************************************************
      *  3600-VALIDATE-CUST-MARITAL                                    *
      *  MARITAL STATUS IS OPTIONAL. IF ENTERED, MUST BE ONE OF S, M,  *
      *  D, OR W. MESSAGE CUS0017 ON FAILURE.                          *
      ******************************************************************
       3600-VALIDATE-CUST-MARITAL.

           IF WS-SCR-CUST-MARITAL NOT = SPACES
               IF WS-SCR-CUST-MARITAL NOT = 'S' AND
                  WS-SCR-CUST-MARITAL NOT = 'M' AND
                  WS-SCR-CUST-MARITAL NOT = 'D' AND
                  WS-SCR-CUST-MARITAL NOT = 'W'
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0017'
                       'Marital Status must be S, M, D, or W.'
                       'CUST-MARITAL'
               END-IF
           END-IF.

      ******************************************************************
      *  3700-VALIDATE-CUST-EMAIL                                      *
      *  EMAIL IS OPTIONAL. IF ENTERED, A BASIC PATTERN CHECK IS       *
      *  PERFORMED REQUIRING AN '@' CHARACTER FOLLOWED LATER BY A '.'  *
      *  CHARACTER. MESSAGE CUS0018 ON FAILURE.                        *
      ******************************************************************
       3700-VALIDATE-CUST-EMAIL.

           MOVE 0                     TO WS-VAL-EMAIL-LEN.
           MOVE 0                     TO WS-VAL-AT-POS.
           MOVE 0                     TO WS-VAL-DOT-POS.

           IF WS-SCR-CUST-EMAIL NOT = SPACES

               PERFORM VARYING WS-VAL-CHAR-IDX FROM 60 BY -1
                   UNTIL WS-VAL-CHAR-IDX = 0
                      OR WS-SCR-CUST-EMAIL(WS-VAL-CHAR-IDX:1)
                         NOT = SPACE
                   CONTINUE
               END-PERFORM
               MOVE WS-VAL-CHAR-IDX   TO WS-VAL-EMAIL-LEN

               PERFORM VARYING WS-VAL-CHAR-IDX FROM 1 BY 1
                   UNTIL WS-VAL-CHAR-IDX > WS-VAL-EMAIL-LEN
                   IF WS-SCR-CUST-EMAIL(WS-VAL-CHAR-IDX:1) = '@'
                       MOVE WS-VAL-CHAR-IDX TO WS-VAL-AT-POS
                   END-IF
               END-PERFORM

               IF WS-VAL-AT-POS > 0
                   PERFORM VARYING WS-VAL-CHAR-IDX FROM
                            WS-VAL-AT-POS BY 1
                       UNTIL WS-VAL-CHAR-IDX > WS-VAL-EMAIL-LEN
                       IF WS-SCR-CUST-EMAIL(WS-VAL-CHAR-IDX:1) = '.'
                           MOVE WS-VAL-CHAR-IDX TO WS-VAL-DOT-POS
                       END-IF
                   END-PERFORM
               END-IF

               IF WS-VAL-AT-POS = 0 OR WS-VAL-AT-POS = 1
                  OR WS-VAL-DOT-POS = 0
                  OR WS-VAL-DOT-POS = WS-VAL-AT-POS + 1
                  OR WS-VAL-DOT-POS = WS-VAL-EMAIL-LEN
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0018' 'Email address format is invalid.'
                            'CUST-EMAIL'
               END-IF
           END-IF.

      ******************************************************************
      *  3800-VALIDATE-CUST-PHONE                                      *
      *  PHONE NUMBER IS OPTIONAL. IF ENTERED, MUST CONTAIN ONLY       *
      *  NUMERIC DIGITS AFTER STRIPPING STANDARD PUNCTUATION           *
      *  (HYPHENS, PARENTHESES, SPACES) AND MUST BE BETWEEN 10 AND 15  *
      *  DIGITS LONG. MESSAGE CUS0019 ON FAILURE.                      *
      ******************************************************************
       3800-VALIDATE-CUST-PHONE.

           MOVE SPACES                TO WS-VAL-PHONE-DIGITS.
           MOVE 0                     TO WS-VAL-PHONE-DIGIT-CNT.

           IF WS-SCR-CUST-PHONE NOT = SPACES

               PERFORM VARYING WS-VAL-CHAR-IDX FROM 1 BY 1
                   UNTIL WS-VAL-CHAR-IDX > 15
                   MOVE WS-SCR-CUST-PHONE(WS-VAL-CHAR-IDX:1)
                                       TO WS-VAL-ONE-CHAR
                   IF WS-VAL-ONE-CHAR IS NUMERIC
                       ADD 1 TO WS-VAL-PHONE-DIGIT-CNT
                       MOVE WS-VAL-ONE-CHAR TO
                           WS-VAL-PHONE-DIGITS(WS-VAL-PHONE-DIGIT-CNT:1)
                   ELSE
                       IF WS-VAL-ONE-CHAR NOT = SPACE AND
                          WS-VAL-ONE-CHAR NOT = '-' AND
                          WS-VAL-ONE-CHAR NOT = '(' AND
                          WS-VAL-ONE-CHAR NOT = ')' AND
                          WS-VAL-ONE-CHAR NOT = '.' AND
                          WS-VAL-ONE-CHAR NOT = '+'
                           PERFORM 8100-ADD-MESSAGE-TO-TABLE
                               WITH 'CUS0019'
                               'Phone Number contains invalid characters.'
                               'CUST-PHONE'
                       END-IF
                   END-IF
               END-PERFORM

               IF WS-VAL-PHONE-DIGIT-CNT < 10 OR
                  WS-VAL-PHONE-DIGIT-CNT > 15
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0019'
                       'Phone Number must contain 10-15 digits.'
                       'CUST-PHONE'
               END-IF
           END-IF.

      ******************************************************************
      *  3900-VALIDATE-CUST-STATUS                                     *
      *  STATUS DEFAULTS TO 'A' (ACTIVE) ON ADD AND MAY ONLY BE SET TO *
      *  'A' OR 'I' AT ADD TIME. STATUS 'D' (DELETED) IS RESERVED FOR  *
      *  THE LOGICAL DELETE FUNCTION IN CUS005A AND IS REJECTED HERE.  *
      *  MESSAGE CUS0020 ON FAILURE.                                   *
      ******************************************************************
       3900-VALIDATE-CUST-STATUS.

           IF WS-SCR-CUST-STATUS = SPACES
               MOVE 'A'               TO WS-SCR-CUST-STATUS
           ELSE
               IF WS-SCR-CUST-STATUS NOT = 'A' AND
                  WS-SCR-CUST-STATUS NOT = 'I'
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0020'
                       'Status must be A or I when adding a customer.'
                       'CUST-STATUS'
               END-IF
           END-IF.

      ******************************************************************
      *  3950-VALIDATE-CUST-CREDIT-SCORE                                *
      *  CREDIT SCORE IS OPTIONAL. IF ENTERED (NON-ZERO), MUST FALL    *
      *  WITHIN THE STANDARD RANGE OF 300 TO 850. MESSAGE CUS0021 ON   *
      *  FAILURE.                                                      *
      ******************************************************************
       3950-VALIDATE-CUST-CREDIT-SCORE.

           IF WS-SCR-CUST-CREDIT NOT = 0
               IF WS-SCR-CUST-CREDIT < 300 OR
                  WS-SCR-CUST-CREDIT > 850
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0021'
                       'Credit Score must be between 300 and 850.'
                       'CUST-CREDIT'
               END-IF
           END-IF.

      ******************************************************************
      *  4100-VALIDATE-ADDRESS-FIELDS                                  *
      *  ADDRESS FIELDS ARE OPTIONAL AS A GROUP, BUT IF ANY ADDRESS    *
      *  FIELD IS ENTERED, CITY, STATE, AND ZIP BECOME REQUIRED        *
      *  TOGETHER (ALL-OR-NOTHING RULE). MESSAGE CUS0022 ON A MISSING  *
      *  COMPANION FIELD; ZIP FORMAT IS CHECKED SEPARATELY (CUS0023).  *
      ******************************************************************
       4100-VALIDATE-ADDRESS-FIELDS.

           MOVE 0                     TO WS-VAL-ADDRESS-FIELDS-CNT.
           MOVE 'N'                   TO WS-ADDRESS-ENTERED-SW.

           IF WS-SCR-ADDR-LINE1 NOT = SPACES OR
              WS-SCR-ADDR-LINE2 NOT = SPACES OR
              WS-SCR-ADDR-CITY  NOT = SPACES OR
              WS-SCR-ADDR-STATE NOT = SPACES OR
              WS-SCR-ADDR-ZIP   NOT = SPACES
               MOVE 'Y'               TO WS-ADDRESS-ENTERED-SW
           END-IF.

           IF ADDRESS-WAS-ENTERED
               IF WS-SCR-ADDR-LINE1 = SPACES
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0022'
                       'Address Line 1 is required when entering an'
                       'ADDR-LINE1'
               END-IF
               IF WS-SCR-ADDR-CITY = SPACES
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0022'
                       'City is required when entering an address.'
                       'ADDR-CITY'
               END-IF
               IF WS-SCR-ADDR-STATE = SPACES
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0022'
                       'State is required when entering an address.'
                       'ADDR-STATE'
               END-IF
               IF WS-SCR-ADDR-ZIP = SPACES
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0022'
                       'Zip Code is required when entering an address.'
                       'ADDR-ZIP'
               ELSE
                   PERFORM 4150-VALIDATE-ZIP-FORMAT
               END-IF
           END-IF.

      ******************************************************************
      *  4150-VALIDATE-ZIP-FORMAT                                      *
      *  VALIDATES THAT THE ZIP CODE IS EITHER A 5-DIGIT OR 9-DIGIT    *
      *  (ZIP+4, WITH OPTIONAL HYPHEN) US POSTAL CODE PATTERN.         *
      *  MESSAGE CUS0023 ON FAILURE.                                   *
      ******************************************************************
       4150-VALIDATE-ZIP-FORMAT.

           MOVE 0                     TO WS-VAL-ZIP-LEN.

           PERFORM VARYING WS-VAL-CHAR-IDX FROM 10 BY -1
               UNTIL WS-VAL-CHAR-IDX = 0
                  OR WS-SCR-ADDR-ZIP(WS-VAL-CHAR-IDX:1) NOT = SPACE
               CONTINUE
           END-PERFORM.

           MOVE WS-VAL-CHAR-IDX       TO WS-VAL-ZIP-LEN.

           EVALUATE WS-VAL-ZIP-LEN
               WHEN 5
                   IF WS-SCR-ADDR-ZIP(1:5) NOT NUMERIC
                       PERFORM 8100-ADD-MESSAGE-TO-TABLE
                           WITH 'CUS0023'
                           'Zip Code must be 5 or 9 numeric digits.'
                           'ADDR-ZIP'
                   END-IF
               WHEN 10
                   IF WS-SCR-ADDR-ZIP(1:5) NOT NUMERIC OR
                      WS-SCR-ADDR-ZIP(6:1) NOT = '-' OR
                      WS-SCR-ADDR-ZIP(7:4) NOT NUMERIC
                       PERFORM 8100-ADD-MESSAGE-TO-TABLE
                           WITH 'CUS0023'
                           'Zip+4 format must be NNNNN-NNNN.'
                           'ADDR-ZIP'
                   END-IF
               WHEN OTHER
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0023'
                       'Zip Code must be 5 or 9 digits in length.'
                       'ADDR-ZIP'
           END-EVALUATE.

      ******************************************************************
      *  4200-VALIDATE-CONTACT-FIELDS                                  *
      *  CONTACT FIELDS ARE OPTIONAL AS A GROUP, BUT IF EITHER         *
      *  CONTACT TYPE OR CONTACT VALUE IS ENTERED, BOTH BECOME         *
      *  REQUIRED TOGETHER. MESSAGE CUS0022 (SHARED PATTERN-FAMILY     *
      *  WITH ADDRESS GROUP RULE) ON A MISSING COMPANION FIELD.        *
      ******************************************************************
       4200-VALIDATE-CONTACT-FIELDS.

           MOVE 'N'                   TO WS-CONTACT-ENTERED-SW.

           IF WS-SCR-CONT-TYPE NOT = SPACES OR
              WS-SCR-CONT-VALUE NOT = SPACES
               MOVE 'Y'               TO WS-CONTACT-ENTERED-SW
           END-IF.

           IF CONTACT-WAS-ENTERED
               IF WS-SCR-CONT-TYPE = SPACES
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0022'
                       'Contact Type is required when entering a'
                       'CONT-TYPE'
               END-IF
               IF WS-SCR-CONT-VALUE = SPACES
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0022'
                       'Contact Value is required when entering a'
                       'CONT-VALUE'
               END-IF
               IF WS-SCR-CONT-TYPE NOT = SPACES AND
                  WS-SCR-CONT-TYPE NOT = 'PH' AND
                  WS-SCR-CONT-TYPE NOT = 'EM' AND
                  WS-SCR-CONT-TYPE NOT = 'EC'
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0022'
                       'Contact Type must be PH, EM, or EC.'
                       'CONT-TYPE'
               END-IF
           END-IF.

      ******************************************************************
      *  4000-CHECK-DUPLICATE-CUSTOMER                                 *
      *  PERFORMS A RELATIONAL DUPLICATE CHECK AGAINST THE             *
      *  CUSTOMER_T TABLE TO ENSURE NO EXISTING CUSTOMER SHARES THE    *
      *  SAME SSN / TAX ID. THIS CHECK ONLY EXECUTES IF ALL FIELD-     *
      *  LEVEL VALIDATIONS PASSED, SINCE A RELATIONAL CHECK AGAINST AN *
      *  INVALID SSN VALUE WOULD BE MEANINGLESS.                       *
      ******************************************************************
       4000-CHECK-DUPLICATE-CUSTOMER.

           MOVE WS-SCR-CUST-SSN       TO HV-CUST-SSN-TAXID.
           MOVE 0                     TO HV-DUP-COUNT.
           MOVE 'N'                   TO WS-DUPLICATE-FOUND-SW.

           EXEC SQL
               SELECT COUNT(*)
                 INTO :HV-DUP-COUNT
                 FROM CUSTOMER_T
                WHERE CUST_SSN_TAXID = :HV-CUST-SSN-TAXID
           END-EXEC.

           IF SQLCODE = 0
               IF HV-DUP-COUNT > 0
                   MOVE 'Y'           TO WS-DUPLICATE-FOUND-SW
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0015'
                       'A customer with this SSN / Tax ID already'
                       'CUST-SSN'
               END-IF
           ELSE
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'DUPLICATE-CHECK'
           END-IF.

      ******************************************************************
      *  5000-GENERATE-CUSTOMER-ID                                     *
      *  GENERATES THE NEXT AVAILABLE CUSTOMER ID USING A DATABASE     *
      *  SEQUENCE OBJECT (SEQ_CUSTOMER_ID), FORMATTING THE NUMERIC      *
      *  SEQUENCE VALUE INTO THE 10-CHARACTER CUST_ID KEY WITH A 'C'   *
      *  PREFIX FOLLOWED BY ZERO-PADDED DIGITS.                        *
      ******************************************************************
       5000-GENERATE-CUSTOMER-ID.

           EXEC SQL
               VALUES NEXT VALUE FOR SEQ_CUSTOMER_ID
                 INTO :HV-NEXT-CUST-SEQ
           END-EXEC.

           IF SQLCODE = 0
               MOVE SPACES            TO HV-NEXT-CUST-ID
               STRING 'C'                            DELIMITED SIZE
                      HV-NEXT-CUST-SEQ                DELIMITED SIZE
                      INTO HV-NEXT-CUST-ID
               MOVE HV-NEXT-CUST-ID   TO HV-CUST-ID
           ELSE
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'GENERATE-CUST-ID'
           END-IF.

      ******************************************************************
      *  6000-INSERT-CUSTOMER-RECORD                                   *
      *  MOVES VALIDATED SCREEN FIELDS TO THE CUSTOMER_T HOST          *
      *  VARIABLES AND PERFORMS THE EMBEDDED SQL INSERT. ALL           *
      *  AUDIT-STAMP COLUMNS (CRT_USER / CRT_TIMESTAMP) ARE SET FROM   *
      *  THE VALUES RETRIEVED DURING PROGRAM INITIALIZATION.           *
      ******************************************************************
       6000-INSERT-CUSTOMER-RECORD.

           MOVE 'N'                   TO WS-SQL-ERROR-SW.

           MOVE WS-SCR-CUST-TYPE      TO HV-CUST-TYPE.
           MOVE WS-SCR-CUST-NAME      TO HV-CUST-NAME.
           MOVE WS-SCR-CUST-DOB       TO HV-CUST-DOB.
           MOVE WS-SCR-CUST-GENDER    TO HV-CUST-GENDER.
           MOVE WS-SCR-CUST-MARITAL   TO HV-CUST-MARITAL-ST.
           MOVE WS-SCR-CUST-EMAIL     TO HV-CUST-EMAIL.
           MOVE WS-SCR-CUST-PHONE     TO HV-CUST-PHONE.
           MOVE WS-SCR-CUST-STATUS    TO HV-CUST-STATUS.
           MOVE WS-SCR-CUST-CREDIT    TO HV-CUST-CREDIT-SCORE.
           MOVE HV-CURRENT-USER       TO HV-CRT-USER.
           MOVE HV-CURRENT-TIMESTAMP  TO HV-CRT-TIMESTAMP.

           IF WS-SCR-CUST-DOB = SPACES
               MOVE -1                TO HV-CUST-DOB-NULL
           ELSE
               MOVE 0                 TO HV-CUST-DOB-NULL
           END-IF.

           IF WS-SCR-CUST-GENDER = SPACES
               MOVE -1                TO HV-CUST-GENDER-NULL
           ELSE
               MOVE 0                 TO HV-CUST-GENDER-NULL
           END-IF.

           IF WS-SCR-CUST-MARITAL = SPACES
               MOVE -1                TO HV-CUST-MARITAL-NULL
           ELSE
               MOVE 0                 TO HV-CUST-MARITAL-NULL
           END-IF.

           IF WS-SCR-CUST-EMAIL = SPACES
               MOVE -1                TO HV-CUST-EMAIL-NULL
           ELSE
               MOVE 0                 TO HV-CUST-EMAIL-NULL
           END-IF.

           IF WS-SCR-CUST-PHONE = SPACES
               MOVE -1                TO HV-CUST-PHONE-NULL
           ELSE
               MOVE 0                 TO HV-CUST-PHONE-NULL
           END-IF.

           IF WS-SCR-CUST-CREDIT = 0
               MOVE -1                TO HV-CUST-CREDIT-NULL
           ELSE
               MOVE 0                 TO HV-CUST-CREDIT-NULL
           END-IF.

           EXEC SQL
               INSERT INTO CUSTOMER_T
                   (CUST_ID, CUST_TYPE, CUST_NAME, CUST_DOB,
                    CUST_SSN_TAXID, CUST_GENDER, CUST_MARITAL_ST,
                    CUST_EMAIL, CUST_PHONE, CUST_STATUS,
                    CUST_CREDIT_SCORE, CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-CUST-ID, :HV-CUST-TYPE, :HV-CUST-NAME,
                    :HV-CUST-DOB :HV-CUST-DOB-NULL,
                    :HV-CUST-SSN-TAXID,
                    :HV-CUST-GENDER :HV-CUST-GENDER-NULL,
                    :HV-CUST-MARITAL-ST :HV-CUST-MARITAL-NULL,
                    :HV-CUST-EMAIL :HV-CUST-EMAIL-NULL,
                    :HV-CUST-PHONE :HV-CUST-PHONE-NULL,
                    :HV-CUST-STATUS,
                    :HV-CUST-CREDIT-SCORE :HV-CUST-CREDIT-NULL,
                    :HV-CRT-USER, :HV-CRT-TIMESTAMP)
           END-EXEC.

           IF SQLCODE NOT = 0
               PERFORM 9100-HANDLE-SQL-ERROR
                   WITH 'INSERT-CUSTOMER'
           ELSE
               MOVE HV-CUST-ID        TO WS-SCR-CUST-ID
               MOVE HV-CUST-ID        TO WS-RETURN-CUST-ID
           END-IF.

      ******************************************************************
      *  6500-INSERT-ADDRESS-IF-ENTERED                                *
      *  IF THE OPERATOR SUPPLIED PRIMARY ADDRESS DATA, GENERATES A    *
      *  NEW ADDRESS_ID FROM SEQ_ADDRESS_ID AND INSERTS THE ROW INTO   *
      *  CUSTOMER_ADDRESS_T LINKED TO THE NEWLY CREATED CUSTOMER.       *
      ******************************************************************
       6500-INSERT-ADDRESS-IF-ENTERED.

           IF ADDRESS-WAS-ENTERED

               EXEC SQL
                   VALUES NEXT VALUE FOR SEQ_ADDRESS_ID
                     INTO :HV-ADDR-ID
               END-EXEC

               MOVE HV-CUST-ID        TO HV-ADDR-CUST-ID
               MOVE 'M'               TO HV-ADDR-TYPE
               MOVE WS-SCR-ADDR-LINE1 TO HV-ADDR-LINE1
               MOVE WS-SCR-ADDR-LINE2 TO HV-ADDR-LINE2
               MOVE WS-SCR-ADDR-CITY  TO HV-ADDR-CITY
               MOVE WS-SCR-ADDR-STATE TO HV-ADDR-STATE
               MOVE WS-SCR-ADDR-ZIP   TO HV-ADDR-ZIP
               MOVE HV-CURRENT-USER   TO HV-ADDR-CRT-USER
               MOVE HV-CURRENT-TIMESTAMP
                                       TO HV-ADDR-CRT-TIMESTAMP

               IF WS-SCR-ADDR-LINE2 = SPACES
                   MOVE -1            TO HV-ADDR-LINE2-NULL
               ELSE
                   MOVE 0             TO HV-ADDR-LINE2-NULL
               END-IF

               EXEC SQL
                   INSERT INTO CUSTOMER_ADDRESS_T
                       (ADDR_ID, CUST_ID, ADDR_TYPE, ADDR_LINE1,
                        ADDR_LINE2, CITY, STATE, ZIP,
                        CRT_USER, CRT_TIMESTAMP)
                   VALUES
                       (:HV-ADDR-ID, :HV-ADDR-CUST-ID, :HV-ADDR-TYPE,
                        :HV-ADDR-LINE1,
                        :HV-ADDR-LINE2 :HV-ADDR-LINE2-NULL,
                        :HV-ADDR-CITY, :HV-ADDR-STATE, :HV-ADDR-ZIP,
                        :HV-ADDR-CRT-USER, :HV-ADDR-CRT-TIMESTAMP)
               END-EXEC

               IF SQLCODE NOT = 0
                   PERFORM 9100-HANDLE-SQL-ERROR
                       WITH 'INSERT-ADDRESS'
               END-IF
           END-IF.

      ******************************************************************
      *  6600-INSERT-CONTACT-IF-ENTERED                                *
      *  IF THE OPERATOR SUPPLIED PRIMARY CONTACT DATA, GENERATES A    *
      *  NEW CONTACT_ID FROM SEQ_CONTACT_ID AND INSERTS THE ROW INTO   *
      *  CUSTOMER_CONTACT_T LINKED TO THE NEWLY CREATED CUSTOMER.       *
      ******************************************************************
       6600-INSERT-CONTACT-IF-ENTERED.

           IF CONTACT-WAS-ENTERED

               EXEC SQL
                   VALUES NEXT VALUE FOR SEQ_CONTACT_ID
                     INTO :HV-CONT-ID
               END-EXEC

               MOVE HV-CUST-ID        TO HV-CONT-CUST-ID
               MOVE WS-SCR-CONT-TYPE  TO HV-CONT-TYPE
               MOVE WS-SCR-CONT-VALUE TO HV-CONT-VALUE
               MOVE 'Y'               TO HV-CONT-IS-PRIMARY
               MOVE HV-CURRENT-USER   TO HV-CONT-CRT-USER
               MOVE HV-CURRENT-TIMESTAMP
                                       TO HV-CONT-CRT-TIMESTAMP

               EXEC SQL
                   INSERT INTO CUSTOMER_CONTACT_T
                       (CONTACT_ID, CUST_ID, CONTACT_TYPE,
                        CONTACT_VALUE, IS_PRIMARY,
                        CRT_USER, CRT_TIMESTAMP)
                   VALUES
                       (:HV-CONT-ID, :HV-CONT-CUST-ID, :HV-CONT-TYPE,
                        :HV-CONT-VALUE, :HV-CONT-IS-PRIMARY,
                        :HV-CONT-CRT-USER, :HV-CONT-CRT-TIMESTAMP)
               END-EXEC

               IF SQLCODE NOT = 0
                   PERFORM 9100-HANDLE-SQL-ERROR
                       WITH 'INSERT-CONTACT'
               END-IF
           END-IF.

      ******************************************************************
      *  7000-WRITE-AUDIT-RECORDS                                      *
      *  CALLS THE COMMON AUDIT-LOGGING SERVICE PROGRAM AUDLOG01 TO    *
      *  RECORD THE NEW-CUSTOMER ADD EVENT. SINCE THIS IS AN ADD       *
      *  TRANSACTION, ALL POPULATED FIELDS ARE LOGGED AS NEW VALUES    *
      *  WITH NO PRIOR (OLD) VALUE, CONSISTENT WITH THE AUDIT DESIGN.  *
      ******************************************************************
       7000-WRITE-AUDIT-RECORDS.

           PERFORM 7100-AUDIT-LOG-CUSTOMER-ADD.

           IF ADDRESS-WAS-ENTERED
               PERFORM 7200-AUDIT-LOG-ADDRESS-ADD
           END-IF.

           IF CONTACT-WAS-ENTERED
               PERFORM 7300-AUDIT-LOG-CONTACT-ADD
           END-IF.

      ******************************************************************
      *  7100-AUDIT-LOG-CUSTOMER-ADD                                   *
      *  WRITES THE AUDIT ENTRY FOR THE CUSTOMER_T INSERT.             *
      ******************************************************************
       7100-AUDIT-LOG-CUSTOMER-ADD.

           MOVE WS-TABLE-CUSTOMER     TO WS-AUD-TABLE-NAME.
           MOVE HV-CUST-ID            TO WS-AUD-KEY-VALUE.
           MOVE WS-ACTION-ADD         TO WS-AUD-ACTION-CD.
           MOVE 'ALL-FIELDS'          TO WS-AUD-FIELD-NAME.
           MOVE SPACES                TO WS-AUD-OLD-VALUE.
           MOVE WS-SCR-CUST-NAME      TO WS-AUD-NEW-VALUE.
           MOVE HV-CURRENT-USER       TO WS-AUD-CHG-USER.
           MOVE WS-PROGRAM-NAME       TO WS-AUD-PROGRAM-NAME.

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
               PERFORM 7900-HANDLE-AUDIT-FAILURE
           END-IF.

      ******************************************************************
      *  7200-AUDIT-LOG-ADDRESS-ADD                                    *
      *  WRITES THE AUDIT ENTRY FOR THE CUSTOMER_ADDRESS_T INSERT.     *
      ******************************************************************
       7200-AUDIT-LOG-ADDRESS-ADD.

           MOVE WS-TABLE-ADDRESS      TO WS-AUD-TABLE-NAME.
           MOVE HV-ADDR-ID            TO WS-AUD-KEY-VALUE.
           MOVE WS-ACTION-ADD         TO WS-AUD-ACTION-CD.
           MOVE 'ALL-FIELDS'          TO WS-AUD-FIELD-NAME.
           MOVE SPACES                TO WS-AUD-OLD-VALUE.
           MOVE WS-SCR-ADDR-LINE1     TO WS-AUD-NEW-VALUE.
           MOVE HV-CURRENT-USER       TO WS-AUD-CHG-USER.
           MOVE WS-PROGRAM-NAME       TO WS-AUD-PROGRAM-NAME.

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
               PERFORM 7900-HANDLE-AUDIT-FAILURE
           END-IF.

      ******************************************************************
      *  7300-AUDIT-LOG-CONTACT-ADD                                    *
      *  WRITES THE AUDIT ENTRY FOR THE CUSTOMER_CONTACT_T INSERT.     *
      ******************************************************************
       7300-AUDIT-LOG-CONTACT-ADD.

           MOVE WS-TABLE-CONTACT      TO WS-AUD-TABLE-NAME.
           MOVE HV-CONT-ID            TO WS-AUD-KEY-VALUE.
           MOVE WS-ACTION-ADD         TO WS-AUD-ACTION-CD.
           MOVE 'ALL-FIELDS'          TO WS-AUD-FIELD-NAME.
           MOVE SPACES                TO WS-AUD-OLD-VALUE.
           MOVE WS-SCR-CONT-VALUE     TO WS-AUD-NEW-VALUE.
           MOVE HV-CURRENT-USER       TO WS-AUD-CHG-USER.
           MOVE WS-PROGRAM-NAME       TO WS-AUD-PROGRAM-NAME.

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
               PERFORM 7900-HANDLE-AUDIT-FAILURE
           END-IF.

      ******************************************************************
      *  7500-BUILD-SUCCESS-MESSAGE                                    *
      *  BUILDS THE CONFIRMATION MESSAGE DISPLAYED TO THE OPERATOR     *
      *  AFTER A SUCCESSFUL ADD, INCLUDING THE NEWLY GENERATED         *
      *  CUSTOMER ID.                                                  *
      ******************************************************************
       7500-BUILD-SUCCESS-MESSAGE.

           MOVE SPACES                TO WS-SCR-MSG-LINE.

           STRING 'Customer ' DELIMITED SIZE
                  HV-CUST-ID          DELIMITED SIZE
                  ' added successfully.' DELIMITED SIZE
                  INTO WS-SCR-MSG-LINE.

      ******************************************************************
      *  7600-RESET-FOR-NEXT-CUSTOMER                                  *
      *  CLEARS THE SCREEN INPUT FIELDS WHILE PRESERVING THE SUCCESS   *
      *  MESSAGE, READYING THE PANEL FOR THE NEXT ADD ENTRY.           *
      ******************************************************************
       7600-RESET-FOR-NEXT-CUSTOMER.

           MOVE WS-SCR-MSG-LINE       TO WS-SCR-MSG-LINE.
           MOVE SPACES                TO WS-SCR-CUST-ID.
           MOVE SPACES                TO WS-SCR-CUST-TYPE.
           MOVE SPACES                TO WS-SCR-CUST-NAME.
           MOVE SPACES                TO WS-SCR-CUST-DOB.
           MOVE SPACES                TO WS-SCR-CUST-SSN.
           MOVE SPACES                TO WS-SCR-CUST-GENDER.
           MOVE SPACES                TO WS-SCR-CUST-MARITAL.
           MOVE SPACES                TO WS-SCR-CUST-EMAIL.
           MOVE SPACES                TO WS-SCR-CUST-PHONE.
           MOVE 'A'                   TO WS-SCR-CUST-STATUS.
           MOVE 0                     TO WS-SCR-CUST-CREDIT.
           MOVE SPACES                TO WS-SCR-ADDR-LINE1.
           MOVE SPACES                TO WS-SCR-ADDR-LINE2.
           MOVE SPACES                TO WS-SCR-ADDR-CITY.
           MOVE SPACES                TO WS-SCR-ADDR-STATE.
           MOVE SPACES                TO WS-SCR-ADDR-ZIP.
           MOVE SPACES                TO WS-SCR-CONT-TYPE.
           MOVE SPACES                TO WS-SCR-CONT-VALUE.

      ******************************************************************
      *  7900-HANDLE-AUDIT-FAILURE                                     *
      *  AUDIT WRITE FAILURES DO NOT ROLL BACK THE ALREADY-COMMITTED   *
      *  BUSINESS TRANSACTION. THE FAILURE IS LOGGED TO THE JOB LOG    *
      *  AND SURFACED TO THE OPERATOR AS A WARNING (MESSAGE CUS0008)   *
      *  SO OPERATIONS CAN INVESTIGATE THE AUDIT GAP.                  *
      ******************************************************************
       7900-HANDLE-AUDIT-FAILURE.

           PERFORM 8100-ADD-MESSAGE-TO-TABLE
               WITH 'CUS0008'
               'Warning: audit log write failed. Customer was saved.'
               'AUDIT'.

           DISPLAY 'CUS001A AUDIT FAILURE - TABLE: '
                   WS-AUD-TABLE-NAME ' KEY: ' WS-AUD-KEY-VALUE
                   ' RETURN CODE: ' WS-AUD-RETURN-CD
               UPON CONSOLE.

      ******************************************************************
      *  8000-BUILD-ERROR-MESSAGE-LINE                                 *
      *  CONSOLIDATES ALL ACCUMULATED VALIDATION/PROCESSING MESSAGES   *
      *  FROM THE MESSAGE TABLE INTO THE SINGLE-LINE SCREEN MESSAGE    *
      *  AREA. IF MULTIPLE MESSAGES EXIST, THE FIRST IS SHOWN WITH A   *
      *  COUNT INDICATOR SO THE OPERATOR KNOWS MORE DETAIL EXISTS.     *
      ******************************************************************
       8000-BUILD-ERROR-MESSAGE-LINE.

           MOVE SPACES                TO WS-SCR-MSG-LINE.

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
      *  8100-ADD-MESSAGE-TO-TABLE                                     *
      *  GENERIC HELPER PARAGRAPH THAT APPENDS A VALIDATION/PROCESSING *
      *  MESSAGE TO THE IN-MEMORY MESSAGE TABLE, PROVIDED THE TABLE    *
      *  HAS NOT REACHED ITS MAXIMUM CAPACITY.                        *
      ******************************************************************
       8100-ADD-MESSAGE-TO-TABLE.

           IF WS-MSG-COUNT < WS-MSG-TABLE-MAX
               ADD 1 TO WS-MSG-COUNT
               MOVE WS-MSG-ID         TO WS-MSG-ENTRY-ID(WS-MSG-COUNT)
               MOVE WS-MSG-TEXT       TO WS-MSG-ENTRY-TEXT(WS-MSG-COUNT)
           END-IF.

      ******************************************************************
      *  9100-HANDLE-SQL-ERROR                                         *
      *  CENTRAL SQL ERROR-HANDLING ROUTINE. EXAMINES SQLCODE AND      *
      *  SQLSTATE AFTER ANY EXEC SQL STATEMENT, MAPS COMMON, WELL-     *
      *  KNOWN SQLCODES TO USER-FRIENDLY MESSAGES, AND FALLS BACK TO   *
      *  A GENERIC SEVERE-ERROR MESSAGE (WITH SQLCODE APPENDED FOR     *
      *  HELP-DESK DIAGNOSIS) FOR ANY UNMAPPED CONDITION.              *
      ******************************************************************
       9100-HANDLE-SQL-ERROR.

           MOVE 'Y'                   TO WS-SQL-ERROR-SW.
           MOVE SQLCODE                TO WS-SQLCODE-DISPLAY.
           MOVE SQLSTATE               TO WS-SQLSTATE-DISPLAY.

           EVALUATE SQLCODE
               WHEN -803
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0015'
                       'Duplicate key - this record already exists.'
                       'SQL-ERROR'
               WHEN -530
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0024'
                       'Referenced record does not exist (FK violation).'
                       'SQL-ERROR'
               WHEN -407
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0025'
                       'A required field cannot be blank (NULL not'
                       'SQL-ERROR'
               WHEN -911
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0026'
                       'Record is locked by another user. Try again.'
                       'SQL-ERROR'
               WHEN -913
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0026'
                       'Record temporarily unavailable. Try again.'
                       'SQL-ERROR'
               WHEN -204
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0027'
                       'Database object not found. Contact support.'
                       'SQL-ERROR'
               WHEN -302
                   PERFORM 8100-ADD-MESSAGE-TO-TABLE
                       WITH 'CUS0028'
                       'Data value exceeds field length or range.'
                       'SQL-ERROR'
               WHEN OTHER
                   PERFORM 9200-BUILD-GENERIC-SQL-ERROR-MSG
           END-EVALUATE.

           DISPLAY 'CUS001A SQL ERROR - FUNCTION: ' WS-SQL-FUNCTION
                   ' SQLCODE: ' WS-SQLCODE-DISPLAY
                   ' SQLSTATE: ' WS-SQLSTATE-DISPLAY
               UPON CONSOLE.

      ******************************************************************
      *  9200-BUILD-GENERIC-SQL-ERROR-MSG                              *
      *  BUILDS A GENERIC SEVERE-ERROR MESSAGE FOR ANY SQLCODE NOT     *
      *  EXPLICITLY MAPPED IN 9100-HANDLE-SQL-ERROR, INCLUDING THE     *
      *  RAW SQLCODE VALUE TO ASSIST HELP-DESK DIAGNOSIS.              *
      ******************************************************************
       9200-BUILD-GENERIC-SQL-ERROR-MSG.

           MOVE SPACES                TO WS-SQL-ERROR-TEXT.

           STRING 'System error occurred (SQLCODE='
                                       DELIMITED SIZE
                  WS-SQLCODE-DISPLAY   DELIMITED SIZE
                  '). Contact support.' DELIMITED SIZE
                  INTO WS-SQL-ERROR-TEXT.

           MOVE WS-SQL-ERROR-TEXT     TO WS-MSG-TEXT.
           MOVE 'CUS0099'             TO WS-MSG-ID.

           PERFORM 8100-ADD-MESSAGE-TO-TABLE.

      ******************************************************************
      *  9000-TERMINATE-PROGRAM                                        *
      *  CLOSES THE DISPLAY FILE AND PERFORMS FINAL PROGRAM CLEANUP    *
      *  BEFORE RETURNING CONTROL TO THE CALLING PROGRAM.              *
      ******************************************************************
       9000-TERMINATE-PROGRAM.

           IF WS-DSPF-STATUS = '00'
               CLOSE CUSMNTD1
           END-IF.

      ******************************************************************
      *  END OF PROGRAM CUS001A                                        *
      ******************************************************************
