# PCIS - Claims Management Module (CLM) - IBM i

This repository contains the design documentation, DDS display file definitions, and batch processing logic for the Claims Management (CLM) module of the Property & Casualty Insurance System (PCIS). Built for the IBM i (AS/400) environment, it manages the entire claim lifecycle from initial reporting (FNOL) through adjuster maintenance, supervisory approval, and final payment disbursement.

## System Architecture Highlights

*   **Modular Segregation of Duties:** The system enforces strict separation between claim approval and claim payment[span_0](start_span)[span_0](end_span). The Claim Payment program (`CLM004A`) does not auto-route to the Claim Approval program (`CLM003A`); if a payment exceeds an adjuster's authority, the operator is explicitly directed to secure separate supervisory approval[span_1](start_span)[span_1](end_span).
*   **Immutable Reserve History:** Claim reserve amounts are never overwritten in place[span_2](start_span)[span_2](end_span). Every adjustment or drawdown appends a new row to the `CLAIM_RESERVE_T` history table, capturing the specific change reason to satisfy actuarial audit requirements[span_3](start_span)[span_3](end_span).
*   **Reinsurance Integration:** The system flags potential reinsurance recoveries without blocking the core workflow[span_4](start_span)[span_4](end_span)[span_5](start_span)[span_5](end_span). The batch payment processor (`CLM006B`) evaluates disbursements against a configurable threshold (e.g., $100,000.00)[span_6](start_span)[span_6](end_span) and inserts pending rows into the `RECOVERY_T` table for downstream processing by the Reinsurance (REI) module[span_7](start_span)[span_7](end_span)[span_8](start_span)[span_8](end_span).

## Core Module Inventory

### 1. Interactive Programs (Design Only)
*   **`CLM001A` (Claim Registration/FNOL):** Opens a new claim against an active policy, auto-assigns an adjuster, sets the initial reserve (`CLAIM_RESERVE_T`), and captures the loss narrative (`CLAIM_NOTE_T`)[span_9](start_span)[span_9](end_span). Uses display panel `CLMFNLD1`[span_10](start_span)[span_10](end_span)[span_11](start_span)[span_11](end_span).
*   **`CLM002A` (Claim Update):** Manages ongoing claim adjustments, including reserve modifications, status changes (Open, Closed, Reopened), and adjuster reassignments[span_12](start_span)[span_12](end_span). Uses display panel `CLMUPDD1`[span_13](start_span)[span_13](end_span).
*   **`CLM003A` (Claim Approval):** Allows supervisory personnel to approve or deny claims or specific payment requests based on defined authority limits[span_14](start_span)[span_14](end_span). Uses display panel `CLMAPRD1`[span_15](start_span)[span_15](end_span)[span_16](start_span)[span_16](end_span).
*   **`CLM004A` (Claim Payment):** Validates the requested payment against the remaining reserve and the requesting adjuster's individual authority limit before logging the payment (`CLAIM_PAYMENT_T`) and drawing down the reserve[span_17](start_span)[span_17](end_span). Uses display panel `CLMPAYD1`[span_18](start_span)[span_18](end_span).
*   **`CLM005A` (Claim Inquiry):** A read-only program utilizing subfile tabs to view reserve history, payments, case notes, and attached documents[span_19](start_span)[span_19](end_span). Uses display panel `CLMINQD1`[span_20](start_span)[span_20](end_span)[span_21](start_span)[span_21](end_span).

### 2. Batch Processing Programs (COBOL)
*   **`CLM006B` (Claim Payment Processing):** Selects approved reserve rows from `CLAIM_RESERVE_T` where the approved amount exceeds the paid-to-date amount[span_22](start_span)[span_22](end_span). It generates the corresponding disbursement records in `CLAIM_PAYMENT_T`, updates the outstanding reserve balance, and logs the transactions to the audit trail[span_23](start_span)[span_23](end_span).

## Supporting Modules (Reference)
While focused on Claims, this repository also includes related structural examples from the broader PCIS ecosystem:
*   **Audit Archiving (`AUD002B`):** A batch job that safely moves rows older than a configured retention period (default 365 days) from `AUDIT_LOG_T` to `AUDIT_LOG_ARCHIVE_T` before deleting them from the live table[span_24](start_span)[span_24](end_span).
*   **Billing Generation (`BIL003B`):** Evaluates active policies based on their `BILLING_PLAN_T` frequency to generate upcoming installments in `BILLING_SCHEDULE_T` and corresponding invoices in `INVOICE_T`[span_25](start_span)[span_25](end_span). Includes accompanying display definitions like `BILINVD1` (Invoice Generation)[span_26](start_span)[span_26](end_span), `BILPMTD1` (Payment Entry)[span_27](start_span)[span_27](end_span), and `BILINQD1` (Account History)[span_28](start_span)[span_28](end_span).
