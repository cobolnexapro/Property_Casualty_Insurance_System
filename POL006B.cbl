      ******************************************************************
      *                                                                *
      *  PROGRAM      :  POL006B                                       *
      *  SYSTEM       :  PCIS - PROPERTY & CASUALTY INSURANCE SYSTEM   *
      *  MODULE       :  POLICY ADMINISTRATION (POL)                  *
      *  PURPOSE      :  RENEWAL PROCESSING - BATCH. SELECTS ALL       *
      *                  ACTIVE POLICIES WHOSE EXPIRATION DATE FALLS   *
      *                  WITHIN THE CONFIGURED RENEWAL WINDOW,         *
      *                  RECALCULATES PREMIUM VIA PRMCLC01, CREATES    *
      *                  THE NEXT-TERM POLICY/COVERAGE/DEDUCTIBLE      *
      *                  ROWS, EXPIRES THE PRIOR TERM, AND WRITES      *
      *                  DUAL POLICY_HISTORY_T EVENTS.                 *
      *                                                                *
      *  LANGUAGE     :  IBM ILE COBOL (ENTERPRISE COBOL FOR i)        *
      *  DATA ACCESS  :  EMBEDDED SQL / DB2 FOR i                      *
      *  UI           :  NONE - BATCH ONLY                             *
      *                                                                *
      *  CALLED BY    :  JOBSCHD2 (NIGHTLY RENEWAL BATCH DRIVER)       *
      *  CALLS        :  PRMCLC01 (SERVICE PROGRAM - PREMIUM CALC)     *
      *                  AUDLOG01 (SERVICE PROGRAM - AUDIT LOGGING)    *
      *                                                                *
      *  TABLES       :  POLICY_T            (SELECT, INSERT, UPDATE) *
      *                  COVERAGE_T          (SELECT, INSERT)         *
      *                  DEDUCTIBLE_T        (SELECT, INSERT)         *
      *                  POLICY_HISTORY_T    (INSERT)                 *
      *                  PREMIUM_CALC_T      (INSERT)                 *
      *                  RPT_RUN_LOG_T       (INSERT)                 *
      *                  AUDIT_LOG_T         (INSERT VIA AUDLOG01)    *
      *                                                                *
      *  COMMIT SCOPE :  ONE POLICY PER COMMIT CYCLE PER PCIS BATCH    *
      *                  STANDARD (SECTION 7.4 ITEM 6 OF THE PCIS      *
      *                  ENTERPRISE ARCHITECTURE) - A SINGLE RENEWAL   *
      *                  FAILURE IS LOGGED AND DOES NOT BLOCK THE      *
      *                  REMAINING RENEWAL POPULATION.                 *
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
       PROGRAM-ID.    POL006B.
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

       01  WS-PROGRAM-NAME             PIC X(8)  VALUE 'POL006B'.
       01  WS-RENEWAL-WINDOW-DAYS      PIC S9(3) VALUE +60.

       01  WS-COUNTERS.
           05  WS-CNT-ELIGIBLE         PIC S9(7) VALUE 0.
           05  WS-CNT-RENEWED          PIC S9(7) VALUE 0.
           05  WS-CNT-ERRORS           PIC S9(7) VALUE 0.

       01  WS-SWITCHES.
           05  WS-END-OF-CURSOR        PIC X     VALUE 'N'.
               88  END-OF-CURSOR               VALUE 'Y'.
           05  WS-SQL-ERROR-SW         PIC X     VALUE 'N'.
               88  SQL-ERROR                    VALUE 'Y'.

      * --- HOST VARIABLES -------------------------------------------
       01  HV-OLD-POL-NBR              PIC X(12).
       01  HV-NEW-POL-NBR              PIC X(12).
       01  HV-CUST-ID                  PIC S9(9) COMP-3.
       01  HV-AGENT-ID                 PIC S9(9) COMP-3.
       01  HV-POL-TYPE                 PIC X(3).
       01  HV-STATE-CD                 PIC X(2).
       01  HV-OLD-EXP-DATE             PIC X(10).
       01  HV-NEW-EFF-DATE             PIC X(10).
       01  HV-NEW-EXP-DATE             PIC X(10).
       01  HV-OLD-PREMIUM              PIC S9(9)V99 COMP-3.
       01  HV-NEW-PREMIUM              PIC S9(9)V99 COMP-3.
       01  HV-COVERAGE-ID              PIC X(10).
       01  HV-COV-TYPE-CD              PIC X(3).
       01  HV-COV-LIMIT-AMT            PIC S9(9)V99 COMP-3.
       01  HV-COV-PREMIUM-AMT          PIC S9(9)V99 COMP-3.
       01  HV-NEW-COVERAGE-ID          PIC X(10).
       01  HV-CURRENT-USER             PIC X(10) VALUE 'BATCHREN'.

      * --- PRMCLC01 INTERFACE -----------------------------------------
       01  WS-PRM-RETURN-PREMIUM       PIC S9(9)V99 COMP-3.
       01  WS-PRM-RETURN-CD            PIC X(2).
       01  WS-PRM-UW-DECISION          PIC X(8).

      * --- AUDLOG01 INTERFACE -----------------------------------------
       01  WS-AUD-TABLE-NAME           PIC X(30).
       01  WS-AUD-KEY-VALUE            PIC X(30).
       01  WS-AUD-ACTION-CD            PIC X(3) VALUE 'REN'.
       01  WS-AUD-FIELD-NAME           PIC X(30) VALUE 'ALL-FIELDS'.
       01  WS-AUD-OLD-VALUE            PIC X(30).
       01  WS-AUD-NEW-VALUE            PIC X(30).
       01  WS-AUD-CHG-USER             PIC X(10).
       01  WS-AUD-PROGRAM-NAME         PIC X(8).
       01  WS-AUD-RETURN-CD            PIC X(2).

       01  WS-TABLE-POLICY             PIC X(30) VALUE 'POLICY_T'.
       01  WS-STATUS-ACTIVE            PIC X     VALUE 'A'.
       01  WS-STATUS-EXPIRED           PIC X     VALUE 'E'.
       01  WS-EVENT-RENEW-OLD          PIC X(3)  VALUE 'EXP'.
       01  WS-EVENT-RENEW-NEW          PIC X(3)  VALUE 'REN'.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INITIALIZE.
           PERFORM 2000-PROCESS-RENEWAL-CANDIDATE
               UNTIL END-OF-CURSOR.
           PERFORM 8000-WRITE-RUN-LOG.
           PERFORM 9000-TERMINATE.
           STOP RUN.

       1000-INITIALIZE.
           DISPLAY 'POL006B - RENEWAL PROCESSING STARTED'.

           EXEC SQL
               DECLARE REN-CSR CURSOR FOR
                   SELECT POL_NBR, CUST_ID, AGENT_ID, POL_TYPE,
                          STATE_CD, POL_EXP_DATE, PREM_ANNUAL
                     FROM POLICY_T
                    WHERE POL_STATUS = 'A'
                      AND POL_EXP_DATE <=
                          (CURRENT DATE + :WS-RENEWAL-WINDOW-DAYS DAYS)
                      AND POL_EXP_DATE >= CURRENT DATE
           END-EXEC.

           EXEC SQL OPEN REN-CSR END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'POL006B - ERROR OPENING REN-CSR SQLCODE='
                       SQLCODE
               MOVE 'Y' TO WS-END-OF-CURSOR
           END-IF.

       2000-PROCESS-RENEWAL-CANDIDATE.
           EXEC SQL
               FETCH REN-CSR INTO :HV-OLD-POL-NBR, :HV-CUST-ID,
                                   :HV-AGENT-ID, :HV-POL-TYPE,
                                   :HV-STATE-CD, :HV-OLD-EXP-DATE,
                                   :HV-OLD-PREMIUM
           END-EXEC.

           IF SQLCODE = 100
               MOVE 'Y' TO WS-END-OF-CURSOR
           ELSE
               IF SQLCODE NOT = 0
                   DISPLAY 'POL006B - FETCH ERROR SQLCODE=' SQLCODE
                   MOVE 'Y' TO WS-END-OF-CURSOR
               ELSE
                   ADD 1 TO WS-CNT-ELIGIBLE
                   MOVE 'N' TO WS-SQL-ERROR-SW
                   PERFORM 3000-RENEW-ONE-POLICY
                   IF WS-SQL-ERROR-SW = 'N'
                       EXEC SQL COMMIT END-EXEC
                       ADD 1 TO WS-CNT-RENEWED
                   ELSE
                       EXEC SQL ROLLBACK END-EXEC
                       ADD 1 TO WS-CNT-ERRORS
                       DISPLAY 'POL006B - RENEWAL FAILED FOR '
                               HV-OLD-POL-NBR
                   END-IF
               END-IF
           END-IF.

       3000-RENEW-ONE-POLICY.
           PERFORM 3100-RECALCULATE-PREMIUM.
           IF WS-SQL-ERROR-SW = 'N'
               PERFORM 3200-GENERATE-NEW-POLICY-NBR
           END-IF.
           IF WS-SQL-ERROR-SW = 'N'
               PERFORM 3300-INSERT-NEW-POLICY-TERM
           END-IF.
           IF WS-SQL-ERROR-SW = 'N'
               PERFORM 3400-CARRY-FORWARD-COVERAGE
           END-IF.
           IF WS-SQL-ERROR-SW = 'N'
               PERFORM 3500-EXPIRE-PRIOR-TERM
           END-IF.
           IF WS-SQL-ERROR-SW = 'N'
               PERFORM 3600-WRITE-HISTORY-EVENTS
               PERFORM 3700-WRITE-AUDIT-RECORD
           END-IF.

       3100-RECALCULATE-PREMIUM.
      * CALL TO SHARED RATING SERVICE PROGRAM - RATES MAY HAVE
      * CHANGED SINCE THE PRIOR TERM WAS RATED.
           CALL 'PRMCLC01' USING HV-POL-TYPE
                                  HV-STATE-CD
                                  HV-OLD-PREMIUM
                                  WS-PRM-RETURN-PREMIUM
                                  WS-PRM-RETURN-CD
                                  WS-PRM-UW-DECISION.
           IF WS-PRM-RETURN-CD NOT = '00'
               DISPLAY 'POL006B - PRMCLC01 RETURN CD=' WS-PRM-RETURN-CD
                       ' FOR ' HV-OLD-POL-NBR
               MOVE 'Y' TO WS-SQL-ERROR-SW
           ELSE
               MOVE WS-PRM-RETURN-PREMIUM TO HV-NEW-PREMIUM
           END-IF.

       3200-GENERATE-NEW-POLICY-NBR.
           EXEC SQL
               VALUES NEXT VALUE FOR SEQ_POLICY_NBR
                 INTO :HV-NEW-POL-NBR
           END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'POL006B - SEQUENCE ERROR SQLCODE=' SQLCODE
               MOVE 'Y' TO WS-SQL-ERROR-SW
           ELSE
               ADD 1 TO HV-OLD-EXP-DATE.
               MOVE HV-OLD-EXP-DATE       TO HV-NEW-EFF-DATE
               EXEC SQL
                   VALUES (:HV-NEW-EFF-DATE + 1 YEAR)
                     INTO :HV-NEW-EXP-DATE
               END-EXEC
           END-IF.

       3300-INSERT-NEW-POLICY-TERM.
           EXEC SQL
               INSERT INTO POLICY_T
                   (POL_NBR, CUST_ID, AGENT_ID, POL_TYPE, STATE_CD,
                    POL_EFF_DATE, POL_EXP_DATE, POL_STATUS,
                    PREM_ANNUAL, CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-NEW-POL-NBR, :HV-CUST-ID, :HV-AGENT-ID,
                    :HV-POL-TYPE, :HV-STATE-CD,
                    :HV-NEW-EFF-DATE, :HV-NEW-EXP-DATE, 'A',
                    :HV-NEW-PREMIUM, :HV-CURRENT-USER,
                    CURRENT TIMESTAMP)
           END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'POL006B - INSERT POLICY_T ERROR SQLCODE='
                       SQLCODE
               MOVE 'Y' TO WS-SQL-ERROR-SW
           END-IF.

       3400-CARRY-FORWARD-COVERAGE.
           EXEC SQL
               DECLARE COV-CSR CURSOR FOR
                   SELECT COVERAGE_ID, COV_TYPE_CD, LIMIT_AMT,
                          PREMIUM_AMT
                     FROM COVERAGE_T
                    WHERE POL_NBR = :HV-OLD-POL-NBR
           END-EXEC.
           EXEC SQL OPEN COV-CSR END-EXEC.
           PERFORM UNTIL SQLCODE = 100 OR WS-SQL-ERROR-SW = 'Y'
               EXEC SQL
                   FETCH COV-CSR INTO :HV-COVERAGE-ID,
                                       :HV-COV-TYPE-CD,
                                       :HV-COV-LIMIT-AMT,
                                       :HV-COV-PREMIUM-AMT
               END-EXEC
               IF SQLCODE = 0
                   PERFORM 3410-INSERT-NEW-COVERAGE
               ELSE
                   IF SQLCODE NOT = 100
                       MOVE 'Y' TO WS-SQL-ERROR-SW
                   END-IF
               END-IF
           END-PERFORM.
           EXEC SQL CLOSE COV-CSR END-EXEC.

       3410-INSERT-NEW-COVERAGE.
           EXEC SQL
               VALUES NEXT VALUE FOR SEQ_COVERAGE_ID
                 INTO :HV-NEW-COVERAGE-ID
           END-EXEC.
           EXEC SQL
               INSERT INTO COVERAGE_T
                   (COVERAGE_ID, POL_NBR, COV_TYPE_CD, LIMIT_AMT,
                    PREMIUM_AMT, EFF_DATE, EXP_DATE,
                    CRT_USER, CRT_TIMESTAMP)
               VALUES
                   (:HV-NEW-COVERAGE-ID, :HV-NEW-POL-NBR,
                    :HV-COV-TYPE-CD, :HV-COV-LIMIT-AMT,
                    :HV-COV-PREMIUM-AMT, :HV-NEW-EFF-DATE,
                    :HV-NEW-EXP-DATE, :HV-CURRENT-USER,
                    CURRENT TIMESTAMP)
           END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'POL006B - INSERT COVERAGE_T ERROR SQLCODE='
                       SQLCODE
               MOVE 'Y' TO WS-SQL-ERROR-SW
           END-IF.

       3500-EXPIRE-PRIOR-TERM.
           EXEC SQL
               UPDATE POLICY_T
                  SET POL_STATUS = 'E',
                      UPD_USER = :HV-CURRENT-USER,
                      UPD_TIMESTAMP = CURRENT TIMESTAMP
                WHERE POL_NBR = :HV-OLD-POL-NBR
           END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'POL006B - EXPIRE PRIOR TERM ERROR SQLCODE='
                       SQLCODE
               MOVE 'Y' TO WS-SQL-ERROR-SW
           END-IF.

       3600-WRITE-HISTORY-EVENTS.
           EXEC SQL
               INSERT INTO POLICY_HISTORY_T
                   (POL_NBR, EVENT_TYPE, EVENT_DATE, CRT_USER,
                    CRT_TIMESTAMP)
               VALUES
                   (:HV-OLD-POL-NBR, :WS-EVENT-RENEW-OLD,
                    CURRENT DATE, :HV-CURRENT-USER, CURRENT TIMESTAMP)
           END-EXEC.
           EXEC SQL
               INSERT INTO POLICY_HISTORY_T
                   (POL_NBR, EVENT_TYPE, EVENT_DATE, CRT_USER,
                    CRT_TIMESTAMP)
               VALUES
                   (:HV-NEW-POL-NBR, :WS-EVENT-RENEW-NEW,
                    CURRENT DATE, :HV-CURRENT-USER, CURRENT TIMESTAMP)
           END-EXEC.

       3700-WRITE-AUDIT-RECORD.
           MOVE WS-TABLE-POLICY          TO WS-AUD-TABLE-NAME.
           MOVE HV-NEW-POL-NBR           TO WS-AUD-KEY-VALUE.
           MOVE HV-OLD-POL-NBR           TO WS-AUD-OLD-VALUE.
           MOVE HV-NEW-POL-NBR           TO WS-AUD-NEW-VALUE.
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
               DISPLAY 'POL006B - AUDIT LOG FAILURE FOR '
                       HV-NEW-POL-NBR
           END-IF.

       8000-WRITE-RUN-LOG.
           EXEC SQL
               INSERT INTO RPT_RUN_LOG_T
                   (PGM_NAME, RUN_DATE, REC_SELECTED, REC_UPDATED,
                    REC_ERRORS, CRT_TIMESTAMP)
               VALUES
                   (:WS-PROGRAM-NAME, CURRENT DATE,
                    :WS-CNT-ELIGIBLE, :WS-CNT-RENEWED,
                    :WS-CNT-ERRORS, CURRENT TIMESTAMP)
           END-EXEC.
           EXEC SQL COMMIT END-EXEC.

       9000-TERMINATE.
           EXEC SQL CLOSE REN-CSR END-EXEC.
           DISPLAY 'POL006B - ELIGIBLE: ' WS-CNT-ELIGIBLE.
           DISPLAY 'POL006B - RENEWED:  ' WS-CNT-RENEWED.
           DISPLAY 'POL006B - ERRORS:   ' WS-CNT-ERRORS.
           DISPLAY 'POL006B - RENEWAL PROCESSING COMPLETE'.
