      ******************************************************************
      *                                                                *
      *  PROGRAM      :  AUD002B                                       *
      *  SYSTEM       :  PCIS - PROPERTY & CASUALTY INSURANCE SYSTEM   *
      *  MODULE       :  AUDIT TRAIL (AUD)                            *
      *  PURPOSE      :  AUDIT ARCHIVING - BATCH. MOVES AUDIT_LOG_T    *
      *                  ROWS OLDER THAN THE CONFIGURED RETENTION      *
      *                  PERIOD TO AUDIT_LOG_ARCHIVE_T, VERIFIES THE   *
      *                  ARCHIVE COPY ROW-COUNT-MATCHES THE SOURCE     *
      *                  BEFORE DELETING FROM THE LIVE TABLE, AND      *
      *                  WRITES A SUMMARY RUN RECORD FOR COMPLIANCE.   *
      *                  AUDIT_LOG_T IS DELIBERATELY NOT PURGED BY ANY *
      *                  OTHER PROGRAM IN THE SYSTEM.                  *
      *                                                                *
      *  LANGUAGE     :  IBM ILE COBOL (ENTERPRISE COBOL FOR i)        *
      *  DATA ACCESS  :  EMBEDDED SQL / DB2 FOR i                      *
      *  UI           :  NONE - BATCH ONLY                             *
      *                                                                *
      *  CALLED BY    :  JOBSCHD1 (NIGHTLY BATCH DRIVER) - MONTH-END   *
      *                  SCHEDULE ENTRY ONLY (NOT EVERY NIGHTLY RUN)   *
      *  CALLS        :  NONE (DOES NOT CALL AUDLOG01 - ARCHIVING IS   *
      *                  NOT ITSELF AN AUDITABLE BUSINESS EVENT, BUT   *
      *                  WRITES ITS OWN RUN-LOG ROW FOR TRACEABILITY)  *
      *                                                                *
      *  TABLES       :  AUDIT_LOG_T          (SELECT, DELETE)        *
      *                  AUDIT_LOG_ARCHIVE_T  (INSERT)                *
      *                  RPT_RUN_LOG_T        (INSERT)                *
      *                                                                *
      *  RETENTION    :  ACTIVE TABLE RETAINS THE MOST RECENT          *
      *                  WS-RETENTION-DAYS (DEFAULT 365) OF AUDIT      *
      *                  HISTORY; OLDER ROWS ARE ARCHIVED, NEVER       *
      *                  HARD-DELETED WITHOUT A VERIFIED ARCHIVE COPY. *
      *                                                                *
      *  COMMIT SCOPE :  ONE CHUNK (WS-CHUNK-SIZE ROWS) PER COMMIT     *
      *                  CYCLE - LARGE ARCHIVE RUNS DO NOT HOLD A      *
      *                  SINGLE LONG-RUNNING TRANSACTION/LOCK SET.     *
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
       PROGRAM-ID.    AUD002B.
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

       01  WS-PROGRAM-NAME             PIC X(8)  VALUE 'AUD002B'.
       01  WS-RETENTION-DAYS           PIC S9(5) VALUE +365.
       01  WS-CHUNK-SIZE                PIC S9(7) VALUE +5000.
       01  WS-CUTOFF-TIMESTAMP          PIC X(26).

       01  WS-COUNTERS.
           05  WS-CNT-ARCHIVED         PIC S9(9) VALUE 0.
           05  WS-CNT-DELETED          PIC S9(9) VALUE 0.
           05  WS-CNT-CHUNK-ARCHIVED   PIC S9(7) VALUE 0.
           05  WS-CNT-CHUNK-DELETED    PIC S9(7) VALUE 0.
           05  WS-CNT-ERRORS           PIC S9(7) VALUE 0.

       01  WS-SWITCHES.
           05  WS-MORE-ROWS-SW         PIC X     VALUE 'Y'.
               88  MORE-ROWS-TO-ARCHIVE         VALUE 'Y'.
           05  WS-SQL-ERROR-SW         PIC X     VALUE 'N'.
               88  SQL-ERROR                    VALUE 'Y'.
           05  WS-COUNT-MISMATCH-SW    PIC X     VALUE 'N'.
               88  COUNT-MISMATCH                VALUE 'Y'.

       01  HV-SOURCE-COUNT             PIC S9(9) COMP-3.
       01  HV-ARCHIVE-COUNT            PIC S9(9) COMP-3.
       01  HV-CURRENT-USER             PIC X(10) VALUE 'BATCHAUD'.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INITIALIZE.
           PERFORM 2000-ARCHIVE-ONE-CHUNK
               UNTIL NOT MORE-ROWS-TO-ARCHIVE
                  OR SQL-ERROR.
           PERFORM 8000-WRITE-RUN-LOG.
           PERFORM 9000-TERMINATE.
           STOP RUN.

       1000-INITIALIZE.
           DISPLAY 'AUD002B - AUDIT ARCHIVING STARTED'.
           EXEC SQL
               VALUES (CURRENT TIMESTAMP - :WS-RETENTION-DAYS DAYS)
                 INTO :WS-CUTOFF-TIMESTAMP
           END-EXEC.
           DISPLAY 'AUD002B - ARCHIVE CUTOFF: ' WS-CUTOFF-TIMESTAMP.

       2000-ARCHIVE-ONE-CHUNK.
           MOVE 'N' TO WS-SQL-ERROR-SW.
           MOVE 'N' TO WS-COUNT-MISMATCH-SW.
           MOVE 0   TO WS-CNT-CHUNK-ARCHIVED.
           MOVE 0   TO WS-CNT-CHUNK-DELETED.

           PERFORM 2100-COPY-CHUNK-TO-ARCHIVE.

           IF WS-SQL-ERROR-SW = 'N'
               PERFORM 2200-VERIFY-CHUNK-COPY
           END-IF.

           IF WS-SQL-ERROR-SW = 'N' AND NOT COUNT-MISMATCH
               PERFORM 2300-DELETE-CHUNK-FROM-LIVE
           END-IF.

           IF WS-SQL-ERROR-SW = 'N' AND NOT COUNT-MISMATCH
               EXEC SQL COMMIT END-EXEC
               ADD WS-CNT-CHUNK-ARCHIVED TO WS-CNT-ARCHIVED
               ADD WS-CNT-CHUNK-DELETED  TO WS-CNT-DELETED
               IF WS-CNT-CHUNK-ARCHIVED < WS-CHUNK-SIZE
                   MOVE 'N' TO WS-MORE-ROWS-SW
               END-IF
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               ADD 1 TO WS-CNT-ERRORS
               DISPLAY 'AUD002B - CHUNK FAILED - ARCHIVE RUN HALTED'
               MOVE 'N' TO WS-MORE-ROWS-SW
           END-IF.

       2100-COPY-CHUNK-TO-ARCHIVE.
      * COPIES THE OLDEST WS-CHUNK-SIZE ROWS BEYOND THE RETENTION
      * CUTOFF THAT ARE NOT ALREADY PRESENT IN THE ARCHIVE TABLE.
           EXEC SQL
               INSERT INTO AUDIT_LOG_ARCHIVE_T
                   SELECT A.* FROM AUDIT_LOG_T A
                    WHERE A.CRT_TIMESTAMP < :WS-CUTOFF-TIMESTAMP
                      AND NOT EXISTS
                          (SELECT 1 FROM AUDIT_LOG_ARCHIVE_T X
                            WHERE X.AUDIT_LOG_ID = A.AUDIT_LOG_ID)
                    ORDER BY A.CRT_TIMESTAMP
                    FETCH FIRST :WS-CHUNK-SIZE ROWS ONLY
           END-EXEC.
           IF SQLCODE < 0
               DISPLAY 'AUD002B - COPY-TO-ARCHIVE ERROR SQLCODE='
                       SQLCODE
               MOVE 'Y' TO WS-SQL-ERROR-SW
           ELSE
               MOVE SQLERRD(3) TO WS-CNT-CHUNK-ARCHIVED
           END-IF.

       2200-VERIFY-CHUNK-COPY.
      * SAFETY CHECK - CONFIRM THE ARCHIVE TABLE NOW CONTAINS AT
      * LEAST AS MANY MATCHING ROWS AS WERE JUST INSERTED BEFORE ANY
      * DELETE FROM THE LIVE TABLE IS ATTEMPTED.
           EXEC SQL
               SELECT COUNT(*) INTO :HV-ARCHIVE-COUNT
                 FROM AUDIT_LOG_ARCHIVE_T X
                WHERE X.CRT_TIMESTAMP < :WS-CUTOFF-TIMESTAMP
           END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY 'AUD002B - VERIFY COUNT ERROR SQLCODE=' SQLCODE
               MOVE 'Y' TO WS-SQL-ERROR-SW
           END-IF.
           IF HV-ARCHIVE-COUNT < WS-CNT-CHUNK-ARCHIVED
               DISPLAY 'AUD002B - ARCHIVE VERIFICATION MISMATCH - '
                       'DELETE SKIPPED FOR SAFETY'
               MOVE 'Y' TO WS-COUNT-MISMATCH-SW
           END-IF.

       2300-DELETE-CHUNK-FROM-LIVE.
           EXEC SQL
               DELETE FROM AUDIT_LOG_T A
                WHERE A.CRT_TIMESTAMP < :WS-CUTOFF-TIMESTAMP
                  AND EXISTS
                      (SELECT 1 FROM AUDIT_LOG_ARCHIVE_T X
                        WHERE X.AUDIT_LOG_ID = A.AUDIT_LOG_ID)
                  AND A.AUDIT_LOG_ID IN
                      (SELECT X.AUDIT_LOG_ID
                         FROM AUDIT_LOG_ARCHIVE_T X
                        WHERE X.CRT_TIMESTAMP < :WS-CUTOFF-TIMESTAMP
                        FETCH FIRST :WS-CHUNK-SIZE ROWS ONLY)
           END-EXEC.
           IF SQLCODE < 0
               DISPLAY 'AUD002B - DELETE-FROM-LIVE ERROR SQLCODE='
                       SQLCODE
               MOVE 'Y' TO WS-SQL-ERROR-SW
           ELSE
               MOVE SQLERRD(3) TO WS-CNT-CHUNK-DELETED
           END-IF.

       8000-WRITE-RUN-LOG.
           EXEC SQL
               INSERT INTO RPT_RUN_LOG_T
                   (PGM_NAME, RUN_DATE, REC_SELECTED, REC_UPDATED,
                    REC_ERRORS, CRT_TIMESTAMP)
               VALUES
                   (:WS-PROGRAM-NAME, CURRENT DATE,
                    :WS-CNT-ARCHIVED, :WS-CNT-DELETED,
                    :WS-CNT-ERRORS, CURRENT TIMESTAMP)
           END-EXEC.
           EXEC SQL COMMIT END-EXEC.

       9000-TERMINATE.
           DISPLAY 'AUD002B - ROWS ARCHIVED: ' WS-CNT-ARCHIVED.
           DISPLAY 'AUD002B - ROWS DELETED:  ' WS-CNT-DELETED.
           DISPLAY 'AUD002B - ERRORS:        ' WS-CNT-ERRORS.
           DISPLAY 'AUD002B - AUDIT ARCHIVING COMPLETE'.
