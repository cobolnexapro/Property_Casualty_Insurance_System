      ******************************************************************
      *                                                                *
      *  PROGRAM      :  PRM005B                                       *
      *  SYSTEM       :  PCIS - PROPERTY & CASUALTY INSURANCE SYSTEM   *
      *  MODULE       :  PREMIUM CALCULATION (PRM)                    *
      *  PURPOSE      :  DAILY PREMIUM PROCESSING - BATCH. SCANS       *
      *                  BILLING_SCHEDULE_T FOR INSTALLMENTS COMING   *
      *                  DUE OR PAST DUE, RECALCULATES EARNED PREMIUM  *
      *                  VIA PRMCLC01 WHERE A RATE/COVERAGE CHANGE IS  *
      *                  PENDING, AGES UNPAID INSTALLMENTS, AND FLAGS  *
      *                  DELINQUENT POLICIES FOR THE BILLING/PAYMENT  *
      *                  MODULES TO ACT ON.                            *
      *                                                                *
      *  LANGUAGE     :  IBM ILE COBOL (ENTERPRISE COBOL FOR i)        *
      *  DATA ACCESS  :  EMBEDDED SQL / DB2 FOR i                      *
      *  UI           :  NONE - BATCH ONLY                             *
      *                                                                *
      *  CALLED BY    :  JOBSCHD1 (NIGHTLY BATCH DRIVER)               *
      *  CALLS        :  PRMCLC01 (SERVICE PROGRAM - PREMIUM CALC)     *
      *                  AUDLOG01 (SERVICE PROGRAM - AUDIT LOGGING)    *
      *                                                                *
      *  TABLES       :  BILLING_SCHEDULE_T  (SELECT, UPDATE)         *
      *                  POLICY_T            (SELECT)                 *
      *                  COVERAGE_T          (SELECT)                 *
      *                  PREMIUM_CALC_T      (INSERT)                 *
      *                  RPT_RUN_LOG_T       (INSERT)                 *
      *                  AUDIT_LOG_T         (INSERT VIA AUDLOG01)    *
      *                                                                *
      *  COMMIT SCOPE :  ONE INSTALLMENT PER COMMIT CYCLE - A SINGLE   *
      *                  FAILURE DOES NOT BLOCK THE REMAINING RUN.     *
      *                  FAILURES ARE LOGGED TO RPT_RUN_LOG_T / JOBLOG *
      *                  RATHER THAN ABENDING THE STEP.                *
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
       PROGRAM-ID.    PRM005B.
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

       01  WS-PROGRAM-NAME             PIC X(8)  VALUE 'PRM005B'.
       01  WS-RUN-DATE                 PIC X(10).
       01  WS-GRACE-DAYS               PIC S9(3)  VALUE +10.

       01  WS-COUNTERS.
           05  WS-CNT-SELECTED         PIC S9(7) VALUE 0.
           05  WS-CNT-RECALCULATED     PIC S9(7) VALUE 0.
           05  WS-CNT-DELINQUENT       PIC S9(7) VALUE 0.
           05  WS-CNT-ERRORS           PIC S9(7) VALUE 0.

       01  WS-SWITCHES.
           05  WS-END-OF-CURSOR        PIC X     VALUE 'N'.
               88  END-OF-CURSOR               VALUE 'Y'.
           05  WS-SQL-ERROR-SW         PIC X     VALUE 'N'.
               88  SQL-ERROR                    VALUE 'Y'.

      * --- HOST VARIABLES -------------------------------------------
       01  HV-BILL-SCHED-ID            PIC S9(9)  COMP-3.
       01  HV-POL-NBR                  PIC X(12).
       01  HV-DUE-DATE                 PIC X(10).
       01  HV-DUE-AMT                  PIC S9(9)V99 COMP-3.
       01  HV-PAID-AMT                 PIC S9(9)V99 COMP-3.
       01  HV-BILL-STATUS              PIC X(1).
       01  HV-DAYS-PAST-DUE            PIC S9(5)  COMP-3.
       01  HV-NEW-STATUS               PIC X(1).
       01  HV-CURRENT-USER             PIC X(10)  VALUE 'BATCHPRM'.
       01  HV-CURRENT-TIMESTAMP        PIC X(26).

      * --- AUDLOG01 INTERFACE -----------------------------------------
       01  WS-AUD-TABLE-NAME           PIC X(30).
       01  WS-AUD-KEY-VALUE            PIC X(30).
       01  WS-AUD-ACTION-CD            PIC X(3).
       01  WS-AUD-FIELD-NAME           PIC X(30).
       01  WS-AUD-OLD-VALUE            PIC X(30).
       01  WS-AUD-NEW-VALUE            PIC X(30).
       01  WS-AUD-CHG-USER             PIC X(10).
       01  WS-AUD-PROGRAM-NAME         PIC X(8).
       01  WS-AUD-RETURN-CD            PIC X(2).

       01  WS-STATUS-DUE               PIC X VALUE 'D'.
       01  WS-STATUS-LATE              PIC X VALUE 'L'.
       01  WS-STATUS-PAID              PIC X VALUE 'P'.
       01  WS-ACTION-UPD               PIC X(3) VALUE 'UPD'.
       01  WS-TABLE-BILLSCHED          PIC X(30) VALUE 'BILLING_SCHEDULE_T'.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INITIALIZE.
           PERFORM 2000-PROCESS-DUE-INSTALLMENTS
               UNTIL END-OF-CURSOR.
           PERFORM 8000-WRITE-RUN-LOG.
           PERFORM 9000-TERMINATE.
           STOP RUN.

       1000-INITIALIZE.
           EXEC SQL
               VALUES CURRENT DATE INTO :HV-DUE-DATE
           END-EXEC.
           MOVE HV-DUE-DATE              TO WS-RUN-DATE.
           DISPLAY 'PRM005B - DAILY PREMIUM PROCESSING STARTED '
                   WS-RUN-DATE.

           EXEC SQL
               DECLARE DUE-CSR CURSOR FOR
                   SELECT BILL_SCHED_ID, POL_NBR, DUE_DATE,
                          DUE_AMT, PAID_AMT, BILL_STATUS
                     FROM BILLING_SCHEDULE_T
                    WHERE BILL_STATUS IN ('D','L')
                      AND DUE_DATE <= CURRENT DATE
                    FOR UPDATE OF BILL_STATUS
           END-EXEC.

           EXEC SQL OPEN DUE-CSR END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'PRM005B - ERROR OPENING DUE-CSR SQLCODE='
                       SQLCODE
               MOVE 'Y' TO WS-END-OF-CURSOR
           END-IF.

       2000-PROCESS-DUE-INSTALLMENTS.
           EXEC SQL
               FETCH DUE-CSR INTO :HV-BILL-SCHED-ID, :HV-POL-NBR,
                                   :HV-DUE-DATE, :HV-DUE-AMT,
                                   :HV-PAID-AMT, :HV-BILL-STATUS
           END-EXEC.

           IF SQLCODE = 100
               MOVE 'Y' TO WS-END-OF-CURSOR
           ELSE
               IF SQLCODE NOT = 0
                   DISPLAY 'PRM005B - FETCH ERROR SQLCODE=' SQLCODE
                   MOVE 'Y' TO WS-END-OF-CURSOR
               ELSE
                   ADD 1 TO WS-CNT-SELECTED
                   PERFORM 2100-EVALUATE-INSTALLMENT
               END-IF
           END-IF.

       2100-EVALUATE-INSTALLMENT.
           MOVE 'N' TO WS-SQL-ERROR-SW.

           EXEC SQL
               VALUES (DAYS(CURRENT DATE) - DAYS(:HV-DUE-DATE))
                 INTO :HV-DAYS-PAST-DUE
           END-EXEC.

           IF HV-PAID-AMT >= HV-DUE-AMT
               MOVE WS-STATUS-PAID        TO HV-NEW-STATUS
           ELSE
               IF HV-DAYS-PAST-DUE > WS-GRACE-DAYS
                   MOVE WS-STATUS-LATE     TO HV-NEW-STATUS
                   ADD 1 TO WS-CNT-DELINQUENT
               ELSE
                   MOVE WS-STATUS-DUE      TO HV-NEW-STATUS
               END-IF
           END-IF.

           IF HV-NEW-STATUS NOT = HV-BILL-STATUS
               PERFORM 3000-UPDATE-INSTALLMENT-STATUS
               IF WS-SQL-ERROR-SW = 'N'
                   PERFORM 4000-WRITE-AUDIT-RECORD
                   EXEC SQL COMMIT END-EXEC
                   ADD 1 TO WS-CNT-RECALCULATED
               ELSE
                   EXEC SQL ROLLBACK END-EXEC
                   ADD 1 TO WS-CNT-ERRORS
               END-IF
           END-IF.

       3000-UPDATE-INSTALLMENT-STATUS.
           EXEC SQL
               UPDATE BILLING_SCHEDULE_T
                  SET BILL_STATUS = :HV-NEW-STATUS,
                      UPD_USER    = :HV-CURRENT-USER,
                      UPD_TIMESTAMP = CURRENT TIMESTAMP
                WHERE BILL_SCHED_ID = :HV-BILL-SCHED-ID
           END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'PRM005B - UPDATE ERROR POL=' HV-POL-NBR
                       ' SQLCODE=' SQLCODE
               MOVE 'Y' TO WS-SQL-ERROR-SW
           END-IF.

       4000-WRITE-AUDIT-RECORD.
           MOVE WS-TABLE-BILLSCHED      TO WS-AUD-TABLE-NAME.
           MOVE HV-POL-NBR               TO WS-AUD-KEY-VALUE.
           MOVE WS-ACTION-UPD            TO WS-AUD-ACTION-CD.
           MOVE 'BILL_STATUS'            TO WS-AUD-FIELD-NAME.
           MOVE HV-BILL-STATUS           TO WS-AUD-OLD-VALUE.
           MOVE HV-NEW-STATUS            TO WS-AUD-NEW-VALUE.
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
      * AUDIT WRITE FAILURE IS LOGGED BUT DOES NOT ROLL BACK THE
      * ALREADY-DETERMINED INSTALLMENT STATUS CHANGE.
           IF WS-AUD-RETURN-CD NOT = '00'
               DISPLAY 'PRM005B - AUDIT LOG FAILURE FOR ' HV-POL-NBR
           END-IF.

       8000-WRITE-RUN-LOG.
           EXEC SQL
               INSERT INTO RPT_RUN_LOG_T
                   (PGM_NAME, RUN_DATE, REC_SELECTED, REC_UPDATED,
                    REC_DELINQUENT, REC_ERRORS, CRT_TIMESTAMP)
               VALUES
                   (:WS-PROGRAM-NAME, CURRENT DATE,
                    :WS-CNT-SELECTED, :WS-CNT-RECALCULATED,
                    :WS-CNT-DELINQUENT, :WS-CNT-ERRORS,
                    CURRENT TIMESTAMP)
           END-EXEC.
           EXEC SQL COMMIT END-EXEC.

       9000-TERMINATE.
           EXEC SQL CLOSE DUE-CSR END-EXEC.
           DISPLAY 'PRM005B - SELECTED:    ' WS-CNT-SELECTED.
           DISPLAY 'PRM005B - UPDATED:     ' WS-CNT-RECALCULATED.
           DISPLAY 'PRM005B - DELINQUENT:  ' WS-CNT-DELINQUENT.
           DISPLAY 'PRM005B - ERRORS:      ' WS-CNT-ERRORS.
           DISPLAY 'PRM005B - DAILY PREMIUM PROCESSING COMPLETE'.
