      ******************************************************************
      *                                                                *
      *  PROGRAM      :  CMM001B                                       *
      *  SYSTEM       :  PCIS - PROPERTY & CASUALTY INSURANCE SYSTEM   *
      *  MODULE       :  AGENT MANAGEMENT (AGT) - COMMISSION CALC      *
      *  PURPOSE      :  COMMISSION CALCULATION - BATCH. SELECTS ALL   *
      *                  PAID BILLING_SCHEDULE_T INSTALLMENTS NOT YET  *
      *                  COMMISSIONED, LOOKS UP EACH POLICY'S AGENT    *
      *                  AND THAT AGENT'S COMMISSION PLAN/RATE FROM    *
      *                  AGENT_COMMISSION_T, COMPUTES THE COMMISSION   *
      *                  AMOUNT, WRITES THE COMMISSION LEDGER ENTRY,   *
      *                  AND MARKS THE INSTALLMENT AS COMMISSIONED.    *
      *                                                                *
      *  LANGUAGE     :  IBM ILE COBOL (ENTERPRISE COBOL FOR i)        *
      *  DATA ACCESS  :  EMBEDDED SQL / DB2 FOR i                      *
      *  UI           :  NONE - BATCH ONLY                             *
      *                                                                *
      *  CALLED BY    :  JOBSCHD3 (MONTHLY BILLING/STATEMENT DRIVER)   *
      *  CALLS        :  AUDLOG01 (SERVICE PROGRAM - AUDIT LOGGING)    *
      *                                                                *
      *  TABLES       :  BILLING_SCHEDULE_T  (SELECT, UPDATE)         *
      *                  POLICY_T            (SELECT)                 *
      *                  AGENT_COMMISSION_T  (SELECT)                 *
      *                  COMMISSION_LEDGER_T (INSERT)                 *
      *                  RPT_RUN_LOG_T       (INSERT)                 *
      *                  AUDIT_LOG_T         (INSERT VIA AUDLOG01)    *
      *                                                                *
      *  COMMIT SCOPE :  ONE INSTALLMENT PER COMMIT CYCLE - A SINGLE   *
      *                  FAILURE IS LOGGED AND DOES NOT BLOCK THE      *
      *                  REMAINING COMMISSION RUN.                    *
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
       PROGRAM-ID.    CMM001B.
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

       01  WS-PROGRAM-NAME             PIC X(8)  VALUE 'CMM001B'.

       01  WS-COUNTERS.
           05  WS-CNT-SELECTED         PIC S9(7) VALUE 0.
           05  WS-CNT-CALCULATED       PIC S9(7) VALUE 0.
           05  WS-CNT-NO-PLAN          PIC S9(7) VALUE 0.
           05  WS-CNT-ERRORS           PIC S9(7) VALUE 0.
           05  WS-TOT-COMMISSION       PIC S9(11)V99 COMP-3 VALUE 0.

       01  WS-SWITCHES.
           05  WS-END-OF-CURSOR        PIC X     VALUE 'N'.
               88  END-OF-CURSOR               VALUE 'Y'.
           05  WS-SQL-ERROR-SW         PIC X     VALUE 'N'.
               88  SQL-ERROR                    VALUE 'Y'.
           05  WS-PLAN-FOUND-SW        PIC X     VALUE 'N'.
               88  PLAN-FOUND                   VALUE 'Y'.

      * --- HOST VARIABLES -------------------------------------------
       01  HV-BILL-SCHED-ID            PIC S9(9) COMP-3.
       01  HV-POL-NBR                  PIC X(12).
       01  HV-PAID-AMT                 PIC S9(9)V99 COMP-3.
       01  HV-AGENT-ID                 PIC S9(9) COMP-3.
       01  HV-COMM-RATE                PIC S9(3)V9999 COMP-3.
       01  HV-COMM-PLAN-ID             PIC S9(9) COMP-3.
       01  HV-COMMISSION-AMT           PIC S9(9)V99 COMP-3.
       01  HV-LEDGER-ID                PIC S9(9) COMP-3.
       01  HV-CURRENT-USER             PIC X(10) VALUE 'BATCHCMM'.

      * --- AUDLOG01 INTERFACE -----------------------------------------
       01  WS-AUD-TABLE-NAME           PIC X(30).
       01  WS-AUD-KEY-VALUE            PIC X(30).
       01  WS-AUD-ACTION-CD            PIC X(3) VALUE 'ADD'.
       01  WS-AUD-FIELD-NAME           PIC X(30) VALUE 'COMMISSION_AMT'.
       01  WS-AUD-OLD-VALUE            PIC X(30) VALUE SPACES.
       01  WS-AUD-NEW-VALUE            PIC X(30).
       01  WS-AUD-CHG-USER             PIC X(10).
       01  WS-AUD-PROGRAM-NAME         PIC X(8).
       01  WS-AUD-RETURN-CD            PIC X(2).

       01  WS-TABLE-COMMLEDGER         PIC X(30) VALUE
                                            'COMMISSION_LEDGER_T'.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INITIALIZE.
           PERFORM 2000-PROCESS-PAID-INSTALLMENT
               UNTIL END-OF-CURSOR.
           PERFORM 8000-WRITE-RUN-LOG.
           PERFORM 9000-TERMINATE.
           STOP RUN.

       1000-INITIALIZE.
           DISPLAY 'CMM001B - COMMISSION CALCULATION STARTED'.

           EXEC SQL
               DECLARE CMM-CSR CURSOR FOR
                   SELECT BS.BILL_SCHED_ID, BS.POL_NBR,
                          BS.PAID_AMT, P.AGENT_ID
                     FROM BILLING_SCHEDULE_T BS, POLICY_T P
                    WHERE BS.POL_NBR = P.POL_NBR
                      AND BS.BILL_STATUS = 'P'
                      AND BS.COMM_CALC_FLAG IS NULL
           END-EXEC.

           EXEC SQL OPEN CMM-CSR END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'CMM001B - ERROR OPENING CMM-CSR SQLCODE='
                       SQLCODE
               MOVE 'Y' TO WS-END-OF-CURSOR
           END-IF.

       2000-PROCESS-PAID-INSTALLMENT.
           EXEC SQL
               FETCH CMM-CSR INTO :HV-BILL-SCHED-ID, :HV-POL-NBR,
                                   :HV-PAID-AMT, :HV-AGENT-ID
           END-EXEC.

           IF SQLCODE = 100
               MOVE 'Y' TO WS-END-OF-CURSOR
           ELSE
               IF SQLCODE NOT = 0
                   DISPLAY 'CMM001B - FETCH ERROR SQLCODE=' SQLCODE
                   MOVE 'Y' TO WS-END-OF-CURSOR
               ELSE
                   ADD 1 TO WS-CNT-SELECTED
                   MOVE 'N' TO WS-SQL-ERROR-SW
                   PERFORM 2100-LOOKUP-COMMISSION-PLAN
                   IF PLAN-FOUND AND WS-SQL-ERROR-SW = 'N'
                       PERFORM 3000-CALCULATE-AND-POST-COMMISSION
                   END-IF
                   IF WS-SQL-ERROR-SW = 'N'
                       EXEC SQL COMMIT END-EXEC
                   ELSE
                       EXEC SQL ROLLBACK END-EXEC
                       ADD 1 TO WS-CNT-ERRORS
                       DISPLAY 'CMM001B - CALC FAILED FOR '
                               HV-POL-NBR
                   END-IF
               END-IF
           END-IF.

       2100-LOOKUP-COMMISSION-PLAN.
           MOVE 'N' TO WS-PLAN-FOUND-SW.
           EXEC SQL
               SELECT COMM_PLAN_ID, COMM_RATE
                 INTO :HV-COMM-PLAN-ID, :HV-COMM-RATE
                 FROM AGENT_COMMISSION_T
                WHERE AGENT_ID = :HV-AGENT-ID
                  AND EFF_DATE <= CURRENT DATE
                  AND (EXP_DATE IS NULL OR EXP_DATE > CURRENT DATE)
                FETCH FIRST 1 ROW ONLY
           END-EXEC.
           IF SQLCODE = 0
               MOVE 'Y' TO WS-PLAN-FOUND-SW
           ELSE
               IF SQLCODE = 100
                   ADD 1 TO WS-CNT-NO-PLAN
                   DISPLAY 'CMM001B - NO ACTIVE COMMISSION PLAN '
                           'FOR AGENT ' HV-AGENT-ID
               ELSE
                   DISPLAY 'CMM001B - LOOKUP ERROR SQLCODE=' SQLCODE
                   MOVE 'Y' TO WS-SQL-ERROR-SW
               END-IF
           END-IF.

       3000-CALCULATE-AND-POST-COMMISSION.
           COMPUTE HV-COMMISSION-AMT ROUNDED =
                   HV-PAID-AMT * (HV-COMM-RATE / 100)
               ON SIZE ERROR
                   DISPLAY 'CMM001B - SIZE ERROR COMPUTING COMMISSION'
                   MOVE 'Y' TO WS-SQL-ERROR-SW
           END-COMPUTE.

           IF WS-SQL-ERROR-SW = 'N'
               EXEC SQL
                   VALUES NEXT VALUE FOR SEQ_COMMISSION_LEDGER_ID
                     INTO :HV-LEDGER-ID
               END-EXEC
               EXEC SQL
                   INSERT INTO COMMISSION_LEDGER_T
                       (LEDGER_ID, AGENT_ID, POL_NBR,
                        BILL_SCHED_ID, COMM_PLAN_ID, COMM_RATE,
                        COMMISSION_AMT, CALC_DATE,
                        CRT_USER, CRT_TIMESTAMP)
                   VALUES
                       (:HV-LEDGER-ID, :HV-AGENT-ID, :HV-POL-NBR,
                        :HV-BILL-SCHED-ID, :HV-COMM-PLAN-ID,
                        :HV-COMM-RATE, :HV-COMMISSION-AMT,
                        CURRENT DATE, :HV-CURRENT-USER,
                        CURRENT TIMESTAMP)
               END-EXEC
               IF SQLCODE NOT = 0
                   DISPLAY 'CMM001B - INSERT LEDGER ERROR SQLCODE='
                           SQLCODE
                   MOVE 'Y' TO WS-SQL-ERROR-SW
               END-IF
           END-IF.

           IF WS-SQL-ERROR-SW = 'N'
               EXEC SQL
                   UPDATE BILLING_SCHEDULE_T
                      SET COMM_CALC_FLAG = 'Y',
                          UPD_USER = :HV-CURRENT-USER,
                          UPD_TIMESTAMP = CURRENT TIMESTAMP
                    WHERE BILL_SCHED_ID = :HV-BILL-SCHED-ID
               END-EXEC
               IF SQLCODE NOT = 0
                   DISPLAY 'CMM001B - UPDATE FLAG ERROR SQLCODE='
                           SQLCODE
                   MOVE 'Y' TO WS-SQL-ERROR-SW
               END-IF
           END-IF.

           IF WS-SQL-ERROR-SW = 'N'
               ADD 1 TO WS-CNT-CALCULATED
               ADD HV-COMMISSION-AMT TO WS-TOT-COMMISSION
               PERFORM 4000-WRITE-AUDIT-RECORD
           END-IF.

       4000-WRITE-AUDIT-RECORD.
           MOVE WS-TABLE-COMMLEDGER      TO WS-AUD-TABLE-NAME.
           MOVE HV-POL-NBR                TO WS-AUD-KEY-VALUE.
           MOVE HV-COMMISSION-AMT         TO WS-AUD-NEW-VALUE.
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
               DISPLAY 'CMM001B - AUDIT LOG FAILURE FOR ' HV-POL-NBR
           END-IF.

       8000-WRITE-RUN-LOG.
           EXEC SQL
               INSERT INTO RPT_RUN_LOG_T
                   (PGM_NAME, RUN_DATE, REC_SELECTED, REC_UPDATED,
                    REC_ERRORS, CRT_TIMESTAMP)
               VALUES
                   (:WS-PROGRAM-NAME, CURRENT DATE,
                    :WS-CNT-SELECTED, :WS-CNT-CALCULATED,
                    :WS-CNT-ERRORS, CURRENT TIMESTAMP)
           END-EXEC.
           EXEC SQL COMMIT END-EXEC.

       9000-TERMINATE.
           EXEC SQL CLOSE CMM-CSR END-EXEC.
           DISPLAY 'CMM001B - SELECTED:        ' WS-CNT-SELECTED.
           DISPLAY 'CMM001B - CALCULATED:      ' WS-CNT-CALCULATED.
           DISPLAY 'CMM001B - NO ACTIVE PLAN:  ' WS-CNT-NO-PLAN.
           DISPLAY 'CMM001B - ERRORS:          ' WS-CNT-ERRORS.
           DISPLAY 'CMM001B - TOTAL COMMISSION: ' WS-TOT-COMMISSION.
           DISPLAY 'CMM001B - COMMISSION CALCULATION COMPLETE'.
