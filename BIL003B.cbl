      ******************************************************************
      *                                                                *
      *  PROGRAM      :  BIL003B                                       *
      *  SYSTEM       :  PCIS - PROPERTY & CASUALTY INSURANCE SYSTEM   *
      *  MODULE       :  BILLING (BIL)                                *
      *  PURPOSE      :  BILLING GENERATION - BATCH. SELECTS ACTIVE    *
      *                  POLICIES WHOSE NEXT INSTALLMENT IS DUE TO BE  *
      *                  GENERATED (BASED ON BILLING_PLAN_T FREQUENCY  *
      *                  AND THE LAST INSTALLMENT ON FILE), CREATES    *
      *                  THE NEXT BILLING_SCHEDULE_T INSTALLMENT ROW,  *
      *                  GENERATES THE CORRESPONDING INVOICE_T HEADER, *
      *                  AND WRITES THE AUDIT TRAIL.                   *
      *                                                                *
      *  LANGUAGE     :  IBM ILE COBOL (ENTERPRISE COBOL FOR i)        *
      *  DATA ACCESS  :  EMBEDDED SQL / DB2 FOR i                      *
      *  UI           :  NONE - BATCH ONLY                             *
      *                                                                *
      *  CALLED BY    :  JOBSCHD3 (MONTHLY BILLING/STATEMENT DRIVER)   *
      *  CALLS        :  AUDLOG01 (SERVICE PROGRAM - AUDIT LOGGING)    *
      *                                                                *
      *  TABLES       :  POLICY_T            (SELECT)                 *
      *                  BILLING_PLAN_T      (SELECT)                 *
      *                  BILLING_SCHEDULE_T  (SELECT, INSERT)         *
      *                  INVOICE_T           (INSERT)                 *
      *                  RPT_RUN_LOG_T       (INSERT)                 *
      *                  AUDIT_LOG_T         (INSERT VIA AUDLOG01)    *
      *                                                                *
      *  COMMIT SCOPE :  ONE POLICY/INSTALLMENT PER COMMIT CYCLE - A   *
      *                  SINGLE FAILURE IS LOGGED AND DOES NOT BLOCK   *
      *                  THE REMAINING BILLING POPULATION.             *
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
       PROGRAM-ID.    BIL003B.
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

       01  WS-PROGRAM-NAME             PIC X(8)  VALUE 'BIL003B'.
       01  WS-LEAD-DAYS                PIC S9(3) VALUE +15.

       01  WS-COUNTERS.
           05  WS-CNT-ELIGIBLE         PIC S9(7) VALUE 0.
           05  WS-CNT-GENERATED        PIC S9(7) VALUE 0.
           05  WS-CNT-ERRORS           PIC S9(7) VALUE 0.

       01  WS-SWITCHES.
           05  WS-END-OF-CURSOR        PIC X     VALUE 'N'.
               88  END-OF-CURSOR               VALUE 'Y'.
           05  WS-SQL-ERROR-SW         PIC X     VALUE 'N'.
               88  SQL-ERROR                    VALUE 'Y'.

      * --- HOST VARIABLES -------------------------------------------
       01  HV-POL-NBR                  PIC X(12).
       01  HV-PREM-ANNUAL              PIC S9(9)V99 COMP-3.
       01  HV-BILL-FREQ                PIC X(1).
       01  HV-INSTALLMENT-CNT          PIC S9(3) COMP-3.
       01  HV-LAST-INSTALLMENT-NBR     PIC S9(3) COMP-3.
       01  HV-LAST-DUE-DATE            PIC X(10).
       01  HV-NEXT-INSTALLMENT-NBR     PIC S9(3) COMP-3.
       01  HV-NEXT-DUE-DATE            PIC X(10).
       01  HV-INSTALLMENT-AMT          PIC S9(9)V99 COMP-3.
       01  HV-BILL-SCHED-ID            PIC S9(9) COMP-3.
       01  HV-INVOICE-ID               PIC S9(9) COMP-3.
       01  HV-CURRENT-USER             PIC X(10) VALUE 'BATCHBIL'.

      * --- AUDLOG01 INTERFACE -----------------------------------------
       01  WS-AUD-TABLE-NAME           PIC X(30).
       01  WS-AUD-KEY-VALUE            PIC X(30).
       01  WS-AUD-ACTION-CD            PIC X(3) VALUE 'ADD'.
       01  WS-AUD-FIELD-NAME           PIC X(30) VALUE 'DUE_AMT'.
       01  WS-AUD-OLD-VALUE            PIC X(30) VALUE SPACES.
       01  WS-AUD-NEW-VALUE            PIC X(30).
       01  WS-AUD-CHG-USER             PIC X(10).
       01  WS-AUD-PROGRAM-NAME         PIC X(8).
       01  WS-AUD-RETURN-CD            PIC X(2).

       01  WS-TABLE-BILLSCHED          PIC X(30) VALUE 'BILLING_SCHEDULE_T'.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INITIALIZE.
           PERFORM 2000-PROCESS-BILLING-CANDIDATE
               UNTIL END-OF-CURSOR.
           PERFORM 8000-WRITE-RUN-LOG.
           PERFORM 9000-TERMINATE.
           STOP RUN.

       1000-INITIALIZE.
           DISPLAY 'BIL003B - BILLING GENERATION STARTED'.

      * SELECTS ACTIVE POLICIES WHOSE MOST RECENT INSTALLMENT'S NEXT
      * DUE DATE (PER BILLING_PLAN_T FREQUENCY) FALLS WITHIN THE
      * GENERATION LEAD WINDOW AND FOR WHICH THE INSTALLMENT COUNT
      * HAS NOT YET BEEN EXHAUSTED.
           EXEC SQL
               DECLARE BIL-CSR CURSOR FOR
                   SELECT P.POL_NBR, P.PREM_ANNUAL,
                          BP.BILL_FREQ, BP.INSTALLMENT_CNT,
                          MAX(BS.INSTALLMENT_NBR), MAX(BS.DUE_DATE)
                     FROM POLICY_T P, BILLING_PLAN_T BP,
                          BILLING_SCHEDULE_T BS
                    WHERE P.POL_NBR = BP.POL_NBR
                      AND BP.POL_NBR = BS.POL_NBR
                      AND P.POL_STATUS = 'A'
                    GROUP BY P.POL_NBR, P.PREM_ANNUAL,
                             BP.BILL_FREQ, BP.INSTALLMENT_CNT
                   HAVING MAX(BS.INSTALLMENT_NBR) < BP.INSTALLMENT_CNT
           END-EXEC.

           EXEC SQL OPEN BIL-CSR END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'BIL003B - ERROR OPENING BIL-CSR SQLCODE='
                       SQLCODE
               MOVE 'Y' TO WS-END-OF-CURSOR
           END-IF.

       2000-PROCESS-BILLING-CANDIDATE.
           EXEC SQL
               FETCH BIL-CSR INTO :HV-POL-NBR, :HV-PREM-ANNUAL,
                                   :HV-BILL-FREQ,
                                   :HV-INSTALLMENT-CNT,
                                   :HV-LAST-INSTALLMENT-NBR,
                                   :HV-LAST-DUE-DATE
           END-EXEC.

           IF SQLCODE = 100
               MOVE 'Y' TO WS-END-OF-CURSOR
           ELSE
               IF SQLCODE NOT = 0
                   DISPLAY 'BIL003B - FETCH ERROR SQLCODE=' SQLCODE
                   MOVE 'Y' TO WS-END-OF-CURSOR
               ELSE
                   ADD 1 TO WS-CNT-ELIGIBLE
                   PERFORM 2100-EVALUATE-NEXT-DUE-DATE
               END-IF
           END-IF.

       2100-EVALUATE-NEXT-DUE-DATE.
           EVALUATE HV-BILL-FREQ
               WHEN 'M'
                   EXEC SQL
                       VALUES (:HV-LAST-DUE-DATE + 1 MONTH)
                         INTO :HV-NEXT-DUE-DATE
                   END-EXEC
               WHEN 'Q'
                   EXEC SQL
                       VALUES (:HV-LAST-DUE-DATE + 3 MONTHS)
                         INTO :HV-NEXT-DUE-DATE
                   END-EXEC
               WHEN 'S'
                   EXEC SQL
                       VALUES (:HV-LAST-DUE-DATE + 6 MONTHS)
                         INTO :HV-NEXT-DUE-DATE
                   END-EXEC
               WHEN OTHER
                   EXEC SQL
                       VALUES (:HV-LAST-DUE-DATE + 1 YEAR)
                         INTO :HV-NEXT-DUE-DATE
                   END-EXEC
           END-EVALUATE.

           EXEC SQL
               VALUES (DAYS(:HV-NEXT-DUE-DATE) - DAYS(CURRENT DATE))
                 INTO :HV-INSTALLMENT-NBR
           END-EXEC.

      * ONLY GENERATE THE INSTALLMENT WHEN ITS DUE DATE FALLS WITHIN
      * THE LEAD-TIME WINDOW (RE-USES HV-INSTALLMENT-NBR AS A SCRATCH
      * DAYS-OUT COUNTER FOR THE COMPARISON BELOW).
           IF HV-INSTALLMENT-NBR <= WS-LEAD-DAYS
               COMPUTE HV-NEXT-INSTALLMENT-NBR =
                       HV-LAST-INSTALLMENT-NBR + 1
               COMPUTE HV-INSTALLMENT-AMT =
                       HV-PREM-ANNUAL / HV-INSTALLMENT-CNT
               MOVE 'N' TO WS-SQL-ERROR-SW
               PERFORM 3000-GENERATE-INSTALLMENT
               IF WS-SQL-ERROR-SW = 'N'
                   EXEC SQL COMMIT END-EXEC
                   ADD 1 TO WS-CNT-GENERATED
               ELSE
                   EXEC SQL ROLLBACK END-EXEC
                   ADD 1 TO WS-CNT-ERRORS
                   DISPLAY 'BIL003B - GENERATION FAILED FOR '
                           HV-POL-NBR
               END-IF
           END-IF.

       3000-GENERATE-INSTALLMENT.
           EXEC SQL
               VALUES NEXT VALUE FOR SEQ_BILL_SCHED_ID
                 INTO :HV-BILL-SCHED-ID
           END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'BIL003B - SEQUENCE ERROR SQLCODE=' SQLCODE
               MOVE 'Y' TO WS-SQL-ERROR-SW
           END-IF.

           IF WS-SQL-ERROR-SW = 'N'
               EXEC SQL
                   INSERT INTO BILLING_SCHEDULE_T
                       (BILL_SCHED_ID, POL_NBR, INSTALLMENT_NBR,
                        DUE_DATE, DUE_AMT, PAID_AMT, BILL_STATUS,
                        CRT_USER, CRT_TIMESTAMP)
                   VALUES
                       (:HV-BILL-SCHED-ID, :HV-POL-NBR,
                        :HV-NEXT-INSTALLMENT-NBR, :HV-NEXT-DUE-DATE,
                        :HV-INSTALLMENT-AMT, 0, 'D',
                        :HV-CURRENT-USER, CURRENT TIMESTAMP)
               END-EXEC
               IF SQLCODE NOT = 0
                   DISPLAY 'BIL003B - INSERT SCHEDULE ERROR SQLCODE='
                           SQLCODE
                   MOVE 'Y' TO WS-SQL-ERROR-SW
               END-IF
           END-IF.

           IF WS-SQL-ERROR-SW = 'N'
               EXEC SQL
                   VALUES NEXT VALUE FOR SEQ_INVOICE_ID
                     INTO :HV-INVOICE-ID
               END-EXEC
               EXEC SQL
                   INSERT INTO INVOICE_T
                       (INVOICE_ID, POL_NBR, BILL_SCHED_ID,
                        INVOICE_DATE, INVOICE_AMT, INVOICE_STATUS,
                        CRT_USER, CRT_TIMESTAMP)
                   VALUES
                       (:HV-INVOICE-ID, :HV-POL-NBR,
                        :HV-BILL-SCHED-ID, CURRENT DATE,
                        :HV-INSTALLMENT-AMT, 'O',
                        :HV-CURRENT-USER, CURRENT TIMESTAMP)
               END-EXEC
               IF SQLCODE NOT = 0
                   DISPLAY 'BIL003B - INSERT INVOICE ERROR SQLCODE='
                           SQLCODE
                   MOVE 'Y' TO WS-SQL-ERROR-SW
               END-IF
           END-IF.

           IF WS-SQL-ERROR-SW = 'N'
               PERFORM 4000-WRITE-AUDIT-RECORD
           END-IF.

       4000-WRITE-AUDIT-RECORD.
           MOVE WS-TABLE-BILLSCHED       TO WS-AUD-TABLE-NAME.
           MOVE HV-POL-NBR                TO WS-AUD-KEY-VALUE.
           MOVE HV-INSTALLMENT-AMT        TO WS-AUD-NEW-VALUE.
           MOVE HV-CURRENT-USER           TO WS-AUD-CHG-USER.
           MOVE WS-PROGRAM-NAME           TO WS-AUD-PROGRAM-NAME.

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
               DISPLAY 'BIL003B - AUDIT LOG FAILURE FOR ' HV-POL-NBR
           END-IF.

       8000-WRITE-RUN-LOG.
           EXEC SQL
               INSERT INTO RPT_RUN_LOG_T
                   (PGM_NAME, RUN_DATE, REC_SELECTED, REC_UPDATED,
                    REC_ERRORS, CRT_TIMESTAMP)
               VALUES
                   (:WS-PROGRAM-NAME, CURRENT DATE,
                    :WS-CNT-ELIGIBLE, :WS-CNT-GENERATED,
                    :WS-CNT-ERRORS, CURRENT TIMESTAMP)
           END-EXEC.
           EXEC SQL COMMIT END-EXEC.

       9000-TERMINATE.
           EXEC SQL CLOSE BIL-CSR END-EXEC.
           DISPLAY 'BIL003B - ELIGIBLE:  ' WS-CNT-ELIGIBLE.
           DISPLAY 'BIL003B - GENERATED: ' WS-CNT-GENERATED.
           DISPLAY 'BIL003B - ERRORS:    ' WS-CNT-ERRORS.
           DISPLAY 'BIL003B - BILLING GENERATION COMPLETE'.
