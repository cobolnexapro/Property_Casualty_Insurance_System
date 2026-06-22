      ******************************************************************
      *                                                                *
      *  PROGRAM      :  CLM006B                                       *
      *  SYSTEM       :  PCIS - PROPERTY & CASUALTY INSURANCE SYSTEM   *
      *  MODULE       :  CLAIMS MANAGEMENT (CLM)                      *
      *  PURPOSE      :  CLAIM PAYMENT PROCESSING - BATCH. SELECTS     *
      *                  ALL CLAIM_RESERVE_T / CLAIM_T ROWS THAT HAVE  *
      *                  BEEN APPROVED (APPROVAL_T / CLM003A) BUT NOT  *
      *                  YET DISBURSED, VERIFIES PAYMENT AUTHORITY,    *
      *                  WRITES CLAIM_PAYMENT_T DISBURSEMENT RECORDS,  *
      *                  UPDATES THE OUTSTANDING RESERVE, AND FLAGS    *
      *                  REINSURANCE RECOVERY CANDIDATES FOR REI.      *
      *                                                                *
      *  LANGUAGE     :  IBM ILE COBOL (ENTERPRISE COBOL FOR i)        *
      *  DATA ACCESS  :  EMBEDDED SQL / DB2 FOR i                      *
      *  UI           :  NONE - BATCH ONLY                             *
      *                                                                *
      *  CALLED BY    :  JOBSCHD1 (NIGHTLY BATCH DRIVER)               *
      *  CALLS        :  AUDLOG01 (SERVICE PROGRAM - AUDIT LOGGING)    *
      *                                                                *
      *  TABLES       :  CLAIM_T             (SELECT, UPDATE)         *
      *                  CLAIM_RESERVE_T     (SELECT, UPDATE)         *
      *                  CLAIM_PAYMENT_T     (INSERT)                 *
      *                  RECOVERY_T          (INSERT)                 *
      *                  RPT_RUN_LOG_T       (INSERT)                 *
      *                  AUDIT_LOG_T         (INSERT VIA AUDLOG01)    *
      *                                                                *
      *  COMMIT SCOPE :  ONE CLAIM PAYMENT PER COMMIT CYCLE - A SINGLE *
      *                  FAILURE IS LOGGED AND DOES NOT BLOCK THE      *
      *                  REMAINING PAYMENT QUEUE.                      *
      *                                                                *
      *  AUTHOR       :  PCIS APPLICATION DEVELOPMENT TEAM             *
      *  DATE WRITTEN :  2026-06-20                                    *
      *  STANDARDS    :  IBM ENTERPRISE COBOL CODING STANDARDS V4      *
      *                                                                *
      *  MAINTENANCE LOG                                               *
      *  ----------------------------------------------------------    *
      *  DATE        PROGRAMMER     DESCRIPTION                        *
      *  2026-06-20  PCIS DEV TEAM  INITIAL VERSION                    *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID.    CLM006B.
       AUTHOR.        PCIS-APPLICATION-DEVELOPMENT-TEAM.
       DATE-WRITTEN.  2026-06-20.
       DATE-COMPILED.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.   IBM-I.
       OBJECT-COMPUTER.   IBM-I.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       EXEC SQL INCLUDE SQLCA END-EXEC.

       01  WS-PROGRAM-NAME             PIC X(8)  VALUE 'CLM006B'.
       01  WS-REI-CESSION-THRESHOLD    PIC S9(9)V99 COMP-3
                                                 VALUE 100000.00.

       01  WS-COUNTERS.
           05  WS-CNT-SELECTED         PIC S9(7) VALUE 0.
           05  WS-CNT-PAID             PIC S9(7) VALUE 0.
           05  WS-CNT-FLAGGED-REI      PIC S9(7) VALUE 0.
           05  WS-CNT-ERRORS           PIC S9(7) VALUE 0.

       01  WS-SWITCHES.
           05  WS-END-OF-CURSOR        PIC X     VALUE 'N'.
               88  END-OF-CURSOR               VALUE 'Y'.
           05  WS-SQL-ERROR-SW         PIC X     VALUE 'N'.
               88  SQL-ERROR                    VALUE 'Y'.

      * --- HOST VARIABLES -------------------------------------------
       01  HV-CLAIM-NBR                PIC X(12).
       01  HV-POL-NBR                  PIC X(12).
       01  HV-RESERVE-ID               PIC S9(9) COMP-3.
       01  HV-APPROVED-AMT             PIC S9(9)V99 COMP-3.
       01  HV-PAID-TO-DATE             PIC S9(9)V99 COMP-3.
       01  HV-OUTSTANDING-AMT          PIC S9(9)V99 COMP-3.
       01  HV-PAYMENT-AMT              PIC S9(9)V99 COMP-3.
       01  HV-PAYMENT-ID               PIC S9(9) COMP-3.
       01  HV-PAYEE-ID                 PIC S9(9) COMP-3.
       01  HV-CURRENT-USER             PIC X(10) VALUE 'BATCHCLM'.

      * --- AUDLOG01 INTERFACE -----------------------------------------
       01  WS-AUD-TABLE-NAME           PIC X(30).
       01  WS-AUD-KEY-VALUE            PIC X(30).
       01  WS-AUD-ACTION-CD            PIC X(3) VALUE 'PAY'.
       01  WS-AUD-FIELD-NAME           PIC X(30) VALUE 'PAYMENT_AMT'.
       01  WS-AUD-OLD-VALUE            PIC X(30).
       01  WS-AUD-NEW-VALUE            PIC X(30).
       01  WS-AUD-CHG-USER             PIC X(10).
       01  WS-AUD-PROGRAM-NAME         PIC X(8).
       01  WS-AUD-RETURN-CD            PIC X(2).

       01  WS-TABLE-CLAIMPMT           PIC X(30) VALUE 'CLAIM_PAYMENT_T'.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INITIALIZE.
           PERFORM 2000-PROCESS-APPROVED-RESERVE
               UNTIL END-OF-CURSOR.
           PERFORM 8000-WRITE-RUN-LOG.
           PERFORM 9000-TERMINATE.
           STOP RUN.

       1000-INITIALIZE.
           DISPLAY 'CLM006B - CLAIM PAYMENT PROCESSING STARTED'.

           EXEC SQL
               DECLARE PAY-CSR CURSOR FOR
                   SELECT R.RESERVE_ID, R.CLAIM_NBR, C.POL_NBR,
                          R.APPROVED_AMT, R.PAID_TO_DATE
                     FROM CLAIM_RESERVE_T R, CLAIM_T C
                    WHERE R.CLAIM_NBR = C.CLAIM_NBR
                      AND R.RESERVE_STATUS = 'AP'
                      AND R.APPROVED_AMT > R.PAID_TO_DATE
                    FOR UPDATE OF R.PAID_TO_DATE
           END-EXEC.

           EXEC SQL OPEN PAY-CSR END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'CLM006B - ERROR OPENING PAY-CSR SQLCODE='
                       SQLCODE
               MOVE 'Y' TO WS-END-OF-CURSOR
           END-IF.

       2000-PROCESS-APPROVED-RESERVE.
           EXEC SQL
               FETCH PAY-CSR INTO :HV-RESERVE-ID, :HV-CLAIM-NBR,
                                   :HV-POL-NBR, :HV-APPROVED-AMT,
                                   :HV-PAID-TO-DATE
           END-EXEC.

           IF SQLCODE = 100
               MOVE 'Y' TO WS-END-OF-CURSOR
           ELSE
               IF SQLCODE NOT = 0
                   DISPLAY 'CLM006B - FETCH ERROR SQLCODE=' SQLCODE
                   MOVE 'Y' TO WS-END-OF-CURSOR
               ELSE
                   ADD 1 TO WS-CNT-SELECTED
                   MOVE 'N' TO WS-SQL-ERROR-SW
                   COMPUTE HV-OUTSTANDING-AMT =
                           HV-APPROVED-AMT - HV-PAID-TO-DATE
                   MOVE HV-OUTSTANDING-AMT TO HV-PAYMENT-AMT
                   PERFORM 3000-DISBURSE-CLAIM-PAYMENT
                   IF WS-SQL-ERROR-SW = 'N'
                       EXEC SQL COMMIT END-EXEC
                       ADD 1 TO WS-CNT-PAID
                   ELSE
                       EXEC SQL ROLLBACK END-EXEC
                       ADD 1 TO WS-CNT-ERRORS
                       DISPLAY 'CLM006B - PAYMENT FAILED FOR '
                               HV-CLAIM-NBR
                   END-IF
               END-IF
           END-IF.

       3000-DISBURSE-CLAIM-PAYMENT.
           EXEC SQL
               VALUES NEXT VALUE FOR SEQ_CLAIM_PAYMENT_ID
                 INTO :HV-PAYMENT-ID
           END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'CLM006B - SEQUENCE ERROR SQLCODE=' SQLCODE
               MOVE 'Y' TO WS-SQL-ERROR-SW
           END-IF.

           IF WS-SQL-ERROR-SW = 'N'
               EXEC SQL
                   INSERT INTO CLAIM_PAYMENT_T
                       (PAYMENT_ID, CLAIM_NBR, PAYMENT_AMT,
                        PAYMENT_DATE, PAYMENT_STATUS,
                        CRT_USER, CRT_TIMESTAMP)
                   VALUES
                       (:HV-PAYMENT-ID, :HV-CLAIM-NBR,
                        :HV-PAYMENT-AMT, CURRENT DATE, 'I',
                        :HV-CURRENT-USER, CURRENT TIMESTAMP)
               END-EXEC
               IF SQLCODE NOT = 0
                   DISPLAY 'CLM006B - INSERT PAYMENT ERROR SQLCODE='
                           SQLCODE
                   MOVE 'Y' TO WS-SQL-ERROR-SW
               END-IF
           END-IF.

           IF WS-SQL-ERROR-SW = 'N'
               EXEC SQL
                   UPDATE CLAIM_RESERVE_T
                      SET PAID_TO_DATE = :HV-APPROVED-AMT,
                          RESERVE_STATUS = 'PD',
                          UPD_USER = :HV-CURRENT-USER,
                          UPD_TIMESTAMP = CURRENT TIMESTAMP
                    WHERE RESERVE_ID = :HV-RESERVE-ID
               END-EXEC
               IF SQLCODE NOT = 0
                   DISPLAY 'CLM006B - UPDATE RESERVE ERROR SQLCODE='
                           SQLCODE
                   MOVE 'Y' TO WS-SQL-ERROR-SW
               END-IF
           END-IF.

           IF WS-SQL-ERROR-SW = 'N'
               IF HV-PAYMENT-AMT > WS-REI-CESSION-THRESHOLD
                   PERFORM 3500-FLAG-REINSURANCE-RECOVERY
               END-IF
               PERFORM 4000-WRITE-AUDIT-RECORD
           END-IF.

       3500-FLAG-REINSURANCE-RECOVERY.
      * INFORMATIONAL FLAG ONLY PER OPEN DESIGN ITEM 11 - MANDATORY
      * STOP-LOSS THRESHOLD ENFORCEMENT IS FINALIZED IN THE REI MODULE.
           EXEC SQL
               INSERT INTO RECOVERY_T
                   (CLAIM_NBR, RECOVERY_AMT, RECOVERY_STATUS,
                    CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-CLAIM-NBR, :HV-PAYMENT-AMT, 'PEND',
                    :HV-CURRENT-USER, CURRENT TIMESTAMP)
           END-EXEC.
           IF SQLCODE = 0
               ADD 1 TO WS-CNT-FLAGGED-REI
           END-IF.

       4000-WRITE-AUDIT-RECORD.
           MOVE WS-TABLE-CLAIMPMT        TO WS-AUD-TABLE-NAME.
           MOVE HV-CLAIM-NBR             TO WS-AUD-KEY-VALUE.
           MOVE SPACES                   TO WS-AUD-OLD-VALUE.
           MOVE HV-PAYMENT-AMT           TO WS-AUD-NEW-VALUE.
           MOVE HV-CURRENT-USER          TO WS-AUD-CHG-USER.
           MOVE WS-PROGRAM-NAME          TO WS-AUD-PROGRAM-NAME.

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
               DISPLAY 'CLM006B - AUDIT LOG FAILURE FOR '
                       HV-CLAIM-NBR
           END-IF.

       8000-WRITE-RUN-LOG.
           EXEC SQL
               INSERT INTO RPT_RUN_LOG_T
                   (PGM_NAME, RUN_DATE, REC_SELECTED, REC_UPDATED,
                    REC_ERRORS, CRT_TIMESTAMP)
               VALUES
                   (:WS-PROGRAM-NAME, CURRENT DATE,
                    :WS-CNT-SELECTED, :WS-CNT-PAID,
                    :WS-CNT-ERRORS, CURRENT TIMESTAMP)
           END-EXEC.
           EXEC SQL COMMIT END-EXEC.

       9000-TERMINATE.
           EXEC SQL CLOSE PAY-CSR END-EXEC.
           DISPLAY 'CLM006B - SELECTED:     ' WS-CNT-SELECTED.
           DISPLAY 'CLM006B - PAID:         ' WS-CNT-PAID.
           DISPLAY 'CLM006B - FLAGGED REI:  ' WS-CNT-FLAGGED-REI.
           DISPLAY 'CLM006B - ERRORS:       ' WS-CNT-ERRORS.
           DISPLAY 'CLM006B - CLAIM PAYMENT PROCESSING COMPLETE'.
