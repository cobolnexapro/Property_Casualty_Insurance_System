# PCIS — Property & Casualty Insurance System
# DB2 for i Database Design Document

**Platform:** IBM i | **Database:** DB2 for i (SQL Tables + DDS PF equivalents)
**Scope:** Full physical database design for the PCIS enterprise architecture — 55 tables across all modules (CUS, AGT, QTE, UND, POL, PRM, BIL, PAY, CLM, REI, DOC, RPT, AUD, SEC, Shared).

---

## Conventions Used Throughout This Design

- Every table includes the standard audit columns: `CRT_USER VARCHAR(10)`, `CRT_TIMESTAMP TIMESTAMP`, `UPD_USER VARCHAR(10)`, `UPD_TIMESTAMP TIMESTAMP`.
- Business document keys (`CUST_ID`, `AGT_ID`, `POL_NBR`, `CLM_NBR`, etc.) are fixed-length `VARCHAR`/`CHAR` keys generated from `SEQUENCE` objects per the architecture document, not `IDENTITY` columns — this matches the COBOL host-variable design already implemented in POL001A.
- Pure detail/child-table surrogate keys (e.g., `DEDUCT_ID`, `RATE_FACTOR_ID`, `AUDIT_LOG_ID`) use `BIGINT GENERATED ALWAYS AS IDENTITY`.
- All monetary columns: `DECIMAL(11,2)` (large amounts) or `DECIMAL(9,2)` (line-level amounts), matching COMP-3 `S9(9)V99`/`S9(11)V99` host variables.
- All dates: `DATE`. All status/flag/type codes: `CHAR(1)`/`CHAR(2)`/`CHAR(3)` fixed-width, matching `PIC X` COBOL fields.
- Schema/library qualifier shown as `PCISLIB.` — substitute your actual library name.
- DDS PFs are provided as **legacy-style equivalents** per architecture §3.1 (DDS PFs are not the production standard for new PCIS development — SQL tables are — but are included here for migration/compatibility completeness as requested).

---

## 1. Table Inventory by Module (55 Tables)

| # | Module | Table | Purpose |
|---|---|---|---|
| 1 | CUS | CUSTOMER_T | Customer master (individual/commercial) |
| 2 | CUS | CUSTOMER_CONTACT_T | Customer phone/email contact points |
| 3 | CUS | CUSTOMER_ADDRESS_T | Customer mailing/physical addresses |
| 4 | AGT | AGENT_T | Agent/producer master |
| 5 | AGT | AGENT_LICENSE_T | Agent state license records |
| 6 | AGT | AGENT_COMMISSION_T | Agent commission plan/rate terms |
| 7 | AGT | COMMISSION_PAYMENT_T | Commission payment run detail |
| 8 | QTE | QUOTE_T | Quote header |
| 9 | QTE | QUOTE_COVERAGE_T | Coverages selected on a quote |
| 10 | QTE | RISK_T | Generic risk object (parent of vehicle/property) |
| 11 | QTE | VEHICLE_T | Vehicle risk detail |
| 12 | QTE | VEHICLE_FEATURE_T | Vehicle safety/feature attributes |
| 13 | QTE | PROPERTY_T | Property risk detail |
| 14 | QTE | PROPERTY_FEATURE_T | Property feature attributes |
| 15 | UND | UW_DECISION_T | Underwriting decision on a quote |
| 16 | UND | UW_REFERRAL_T | Underwriting referral/escalation |
| 17 | UND | UW_RULE_T | Underwriting rule definitions |
| 18 | POL | POLICY_T | Policy header |
| 19 | POL | COVERAGE_T | Policy coverage line |
| 20 | PRM | COVERAGE_TYPE_T | Coverage type code reference |
| 21 | POL | DEDUCTIBLE_T | Deductible terms per coverage |
| 22 | POL | ENDORSEMENT_T | Policy endorsement/amendment |
| 23 | POL | POLICY_HISTORY_T | Policy event/status history |
| 24 | POL | POLICY_VEHICLE_T | Vehicle-to-policy link |
| 25 | POL | POLICY_PROPERTY_T | Property-to-policy link |
| 26 | DOC | POLICY_DOCUMENT_T | Policy-to-document link |
| 27 | PRM | RATE_TABLE_T | Rate table header |
| 28 | PRM | RATE_FACTOR_T | Rate factor detail |
| 29 | PRM | PREMIUM_CALC_T | Premium calculation snapshot |
| 30 | BIL | BILLING_SCHEDULE_T | Installment billing schedule |
| 31 | BIL | BILLING_PLAN_T | Billing plan/frequency reference |
| 32 | BIL | INVOICE_T | Invoice header |
| 33 | BIL | INVOICE_LINE_T | Invoice line detail |
| 34 | PAY | PAYMENT_T | Payment received header |
| 35 | PAY | PAYMENT_APPLICATION_T | Payment-to-billing-schedule application |
| 36 | PAY | REFUND_T | Refund issued |
| 37 | CLM | CLAIM_T | Claim header (FNOL) |
| 38 | CLM | CLAIM_RESERVE_T | Claim reserve history |
| 39 | CLM | CLAIM_PAYMENT_T | Claim payment detail |
| 40 | CLM | CLAIM_NOTE_T | Claim adjuster notes |
| 41 | DOC | CLAIM_DOCUMENT_T | Claim-to-document link |
| 42 | CLM | CLAIM_ADJUSTER_T | Adjuster assignment |
| 43 | CLM | APPROVAL_T | Claim/transaction approval workflow |
| 44 | REI | TREATY_T | Reinsurance treaty master |
| 45 | REI | CESSION_T | Risk cession to treaty |
| 46 | REI | RECOVERY_T | Reinsurance recovery on a claim |
| 47 | DOC | DOCUMENT_T | Document/IFS metadata master |
| 48 | RPT | RPT_PARM_T | Configurable system parameters |
| 49 | RPT | RPT_RUN_LOG_T | Report/batch run log |
| 50 | AUD | AUDIT_LOG_T | Centralized audit trail |
| 51 | SEC | USER_T | Application user master |
| 52 | SEC | ROLE_T | Security role master |
| 53 | SEC | ROLE_MENU_T | Role-to-menu-option authorization |
| 54 | SEC | USER_ROLE_T | User-to-role assignment |
| 55 | Shared | CODE_TABLE_T | Generic code/description lookup |

---

## 2. Table Definitions

### 2.1 CUSTOMER_T — Customer Master
*Stores individual and commercial customer master data, the root entity for quotes and policies.*

| Column | Data Type | Null | Description |
|---|---|---|---|
| CUST_ID | VARCHAR(10) | No | **PK.** Generated from SEQ_CUSTOMER_ID |
| CUST_TYPE | CHAR(1) | No | I=Individual, C=Commercial |
| CUST_NAME | VARCHAR(60) | No | Full name / business name |
| FIRST_NAME | VARCHAR(30) | Yes | Individual first name |
| LAST_NAME | VARCHAR(30) | Yes | Individual last name |
| DOB | DATE | Yes | Date of birth (individual) |
| TAX_ID | VARCHAR(11) | Yes | SSN/EIN (encrypted at app layer) |
| CUST_STATUS | CHAR(1) | No | A=Active, I=Inactive |
| EMAIL | VARCHAR(60) | Yes | Primary email |
| PHONE | VARCHAR(15) | Yes | Primary phone |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** CUST_ID  **FK:** none
**Indexes:** CUSTL1 (CUST_NAME); CUSTL2 (TAX_ID); CUSTL3 (CUST_STATUS)

### 2.2 CUSTOMER_CONTACT_T — Customer Contact Points
| Column | Data Type | Null | Description |
|---|---|---|---|
| CONTACT_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| CUST_ID | VARCHAR(10) | No | **FK** → CUSTOMER_T |
| CONTACT_TYPE | CHAR(2) | No | EM=Email, PH=Phone, MB=Mobile, FX=Fax |
| CONTACT_VALUE | VARCHAR(60) | No | Email address or phone number |
| PREFERRED_FLAG | CHAR(1) | No | Y/N |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** CONTACT_ID  **FK:** CUST_ID → CUSTOMER_T.CUST_ID
**Indexes:** CUSCONL1 (CUST_ID)

### 2.3 CUSTOMER_ADDRESS_T — Customer Addresses
| Column | Data Type | Null | Description |
|---|---|---|---|
| ADDRESS_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| CUST_ID | VARCHAR(10) | No | **FK** → CUSTOMER_T |
| ADDR_TYPE | CHAR(1) | No | M=Mailing, P=Physical, B=Billing |
| ADDR_LINE1 | VARCHAR(40) | No | Street address |
| ADDR_LINE2 | VARCHAR(40) | Yes | Suite/Apt |
| CITY | VARCHAR(30) | No | City |
| STATE | CHAR(2) | No | State code |
| ZIP | VARCHAR(10) | No | Postal code |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** ADDRESS_ID  **FK:** CUST_ID → CUSTOMER_T.CUST_ID
**Indexes:** CUSADRL1 (CUST_ID, ADDR_TYPE)

### 2.4 AGENT_T — Agent/Producer Master
| Column | Data Type | Null | Description |
|---|---|---|---|
| AGT_ID | VARCHAR(8) | No | **PK.** From SEQ_AGENT_ID |
| AGT_NAME | VARCHAR(60) | No | Agent/agency name |
| AGT_TYPE | CHAR(1) | No | I=Independent, C=Captive |
| AGT_STATUS | CHAR(1) | No | A=Active, I=Inactive, T=Terminated |
| AGENCY_CD | VARCHAR(10) | Yes | Parent agency code |
| EMAIL | VARCHAR(60) | Yes | Agent email |
| PHONE | VARCHAR(15) | Yes | Agent phone |
| HIRE_DATE | DATE | Yes | Date appointed |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** AGT_ID  **FK:** none
**Indexes:** AGENTL1 (AGT_NAME); AGENTL2 (AGT_STATUS)

### 2.5 AGENT_LICENSE_T — Agent State Licenses
| Column | Data Type | Null | Description |
|---|---|---|---|
| LICENSE_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| AGT_ID | VARCHAR(8) | No | **FK** → AGENT_T |
| LICENSE_STATE | CHAR(2) | No | State of licensure |
| LICENSE_NBR | VARCHAR(20) | No | License number |
| LICENSE_EFF_DATE | DATE | No | Effective date |
| LICENSE_EXP_DATE | DATE | No | Expiration date |
| LICENSE_STATUS | CHAR(1) | No | A=Active, E=Expired, R=Revoked |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** LICENSE_ID  **FK:** AGT_ID → AGENT_T.AGT_ID
**Indexes:** AGTLICL1 (AGT_ID, LICENSE_STATE); AGTLICL2 (LICENSE_EXP_DATE)

### 2.6 AGENT_COMMISSION_T — Agent Commission Plan Terms
| Column | Data Type | Null | Description |
|---|---|---|---|
| COMM_PLAN_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| AGT_ID | VARCHAR(8) | No | **FK** → AGENT_T |
| POL_TYPE | CHAR(3) | No | Line of business this rate applies to |
| COMM_RATE_NEW | DECIMAL(5,2) | No | % commission, new business |
| COMM_RATE_RENEWAL | DECIMAL(5,2) | No | % commission, renewal business |
| PLAN_EFF_DATE | DATE | No | Effective date |
| PLAN_EXP_DATE | DATE | Yes | Expiration date (null = open-ended) |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** COMM_PLAN_ID  **FK:** AGT_ID → AGENT_T.AGT_ID
**Indexes:** AGTCOML1 (AGT_ID, POL_TYPE)

### 2.7 COMMISSION_PAYMENT_T — Commission Payment Run Detail
| Column | Data Type | Null | Description |
|---|---|---|---|
| COMM_PMT_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| AGT_ID | VARCHAR(8) | No | **FK** → AGENT_T |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| COMM_BASIS_AMT | DECIMAL(11,2) | No | Premium amount commission is based on |
| COMM_RATE | DECIMAL(5,2) | No | Rate applied |
| COMM_AMT | DECIMAL(9,2) | No | Computed commission amount |
| COMM_RUN_DATE | DATE | No | Payment run date |
| COMM_STATUS | CHAR(1) | No | P=Pending, A=Approved, D=Disbursed |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** COMM_PMT_ID  **FK:** AGT_ID → AGENT_T.AGT_ID; POL_NBR → POLICY_T.POL_NBR
**Indexes:** COMPAYL1 (AGT_ID, COMM_RUN_DATE); COMPAYL2 (POL_NBR)

### 2.8 QUOTE_T — Quote Header
| Column | Data Type | Null | Description |
|---|---|---|---|
| QUOTE_ID | VARCHAR(12) | No | **PK.** From SEQ_QUOTE_ID |
| CUST_ID | VARCHAR(10) | No | **FK** → CUSTOMER_T |
| AGT_ID | VARCHAR(8) | No | **FK** → AGENT_T |
| POL_TYPE | CHAR(3) | No | AUT, HOM, etc. |
| QUOTE_DATE | DATE | No | Date created |
| QUOTE_EXP_DATE | DATE | No | Quote validity expiration |
| QUOTE_PREMIUM | DECIMAL(11,2) | Yes | Quoted annual premium |
| QUOTE_STATUS | CHAR(1) | No | D=Draft, S=Submitted, A=Approved, C=Converted, X=Expired |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** QUOTE_ID  **FK:** CUST_ID → CUSTOMER_T.CUST_ID; AGT_ID → AGENT_T.AGT_ID
**Indexes:** QUOTEL1 (CUST_ID); QUOTEL2 (AGT_ID, QUOTE_STATUS)

### 2.9 QUOTE_COVERAGE_T — Quote Coverage Selections
| Column | Data Type | Null | Description |
|---|---|---|---|
| QUOTE_COV_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| QUOTE_ID | VARCHAR(12) | No | **FK** → QUOTE_T |
| COV_TYPE_CD | VARCHAR(5) | No | **FK** → COVERAGE_TYPE_T |
| LIMIT_AMT | DECIMAL(11,2) | No | Selected limit |
| EST_PREMIUM | DECIMAL(9,2) | Yes | Estimated premium for this coverage |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** QUOTE_COV_ID  **FK:** QUOTE_ID → QUOTE_T.QUOTE_ID; COV_TYPE_CD → COVERAGE_TYPE_T.COV_TYPE_CD
**Indexes:** QTECOVL1 (QUOTE_ID)

### 2.10 RISK_T — Generic Risk Object
| Column | Data Type | Null | Description |
|---|---|---|---|
| RISK_ID | VARCHAR(12) | No | **PK** |
| QUOTE_ID | VARCHAR(12) | Yes | **FK** → QUOTE_T (originating quote) |
| RISK_TYPE | CHAR(1) | No | V=Vehicle, P=Property |
| TERRITORY_CD | VARCHAR(6) | Yes | Rating territory |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** RISK_ID  **FK:** QUOTE_ID → QUOTE_T.QUOTE_ID
**Indexes:** RISKL1 (QUOTE_ID); RISKL2 (TERRITORY_CD)

### 2.11 VEHICLE_T — Vehicle Risk Detail
| Column | Data Type | Null | Description |
|---|---|---|---|
| VEHICLE_ID | VARCHAR(12) | No | **PK** |
| RISK_ID | VARCHAR(12) | No | **FK** → RISK_T |
| VIN | VARCHAR(17) | No | Vehicle Identification Number |
| MAKE | VARCHAR(20) | No | Manufacturer |
| MODEL | VARCHAR(20) | No | Model |
| MODEL_YEAR | SMALLINT | No | Model year |
| USAGE_TYPE | CHAR(2) | No | PL=Pleasure, CM=Commute, BU=Business |
| ANNUAL_MILEAGE | INTEGER | Yes | Estimated annual mileage |
| ACTUAL_CASH_VALUE | DECIMAL(11,2) | Yes | ACV |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** VEHICLE_ID  **FK:** RISK_ID → RISK_T.RISK_ID
**Indexes:** VEHICLEL1 (VIN); VEHICLEL2 (RISK_ID)

### 2.12 VEHICLE_FEATURE_T — Vehicle Safety/Feature Attributes
| Column | Data Type | Null | Description |
|---|---|---|---|
| VEH_FEAT_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| VEHICLE_ID | VARCHAR(12) | No | **FK** → VEHICLE_T |
| FEAT_CD | VARCHAR(10) | No | e.g., ABS, AIRBAG, ANTITHEFT |
| FEAT_VALUE | VARCHAR(30) | Yes | Feature value/detail |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** VEH_FEAT_ID  **FK:** VEHICLE_ID → VEHICLE_T.VEHICLE_ID
**Indexes:** VEHFEATL1 (VEHICLE_ID)

### 2.13 PROPERTY_T — Property Risk Detail
| Column | Data Type | Null | Description |
|---|---|---|---|
| PROP_ID | VARCHAR(12) | No | **PK** |
| RISK_ID | VARCHAR(12) | No | **FK** → RISK_T |
| PROP_TYPE | CHAR(2) | No | SF=Single Family, CO=Condo, RN=Rental |
| ADDR_LINE1 | VARCHAR(40) | No | Property address |
| CITY | VARCHAR(30) | No | City |
| STATE | CHAR(2) | No | State |
| ZIP | VARCHAR(10) | No | Postal code |
| YEAR_BUILT | SMALLINT | Yes | Year built |
| SQ_FOOTAGE | INTEGER | Yes | Square footage |
| CONSTRUCTION_TYPE | CHAR(2) | Yes | FR=Frame, MA=Masonry |
| REPLACEMENT_VALUE | DECIMAL(13,2) | Yes | Replacement cost value |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** PROP_ID  **FK:** RISK_ID → RISK_T.RISK_ID
**Indexes:** PROPERTYL1 (RISK_ID); PROPERTYL2 (ZIP)

### 2.14 PROPERTY_FEATURE_T — Property Feature Attributes
| Column | Data Type | Null | Description |
|---|---|---|---|
| PROP_FEAT_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| PROP_ID | VARCHAR(12) | No | **FK** → PROPERTY_T |
| FEAT_CD | VARCHAR(10) | No | e.g., ROOF_AGE, ALARM, POOL |
| FEAT_VALUE | VARCHAR(30) | Yes | Value/detail |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** PROP_FEAT_ID  **FK:** PROP_ID → PROPERTY_T.PROP_ID
**Indexes:** PROPFEATL1 (PROP_ID)

### 2.15 UW_DECISION_T — Underwriting Decision
| Column | Data Type | Null | Description |
|---|---|---|---|
| UW_DECISION_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| QUOTE_ID | VARCHAR(12) | No | **FK** → QUOTE_T |
| UW_USER | VARCHAR(10) | No | Underwriter who decided |
| DECISION_CD | CHAR(1) | No | A=Approved, D=Declined, R=Referred |
| DECISION_DATE | DATE | No | Decision date |
| DECISION_REASON | VARCHAR(100) | Yes | Reason/comments |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** UW_DECISION_ID  **FK:** QUOTE_ID → QUOTE_T.QUOTE_ID
**Indexes:** UWDECL1 (QUOTE_ID)

### 2.16 UW_REFERRAL_T — Underwriting Referral
| Column | Data Type | Null | Description |
|---|---|---|---|
| REFERRAL_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| QUOTE_ID | VARCHAR(12) | No | **FK** → QUOTE_T |
| REFERRAL_RULE_ID | BIGINT | Yes | **FK** → UW_RULE_T |
| REFERRED_TO_USER | VARCHAR(10) | No | Senior underwriter assigned |
| REFERRAL_STATUS | CHAR(1) | No | O=Open, C=Closed |
| REFERRAL_DATE | DATE | No | Date referred |
| RESOLUTION_DATE | DATE | Yes | Date resolved |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** REFERRAL_ID  **FK:** QUOTE_ID → QUOTE_T.QUOTE_ID; REFERRAL_RULE_ID → UW_RULE_T.UW_RULE_ID
**Indexes:** UWREFL1 (QUOTE_ID); UWREFL2 (REFERRAL_STATUS)

### 2.17 UW_RULE_T — Underwriting Rule Definitions
| Column | Data Type | Null | Description |
|---|---|---|---|
| UW_RULE_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| RULE_NAME | VARCHAR(40) | No | Descriptive rule name |
| POL_TYPE | CHAR(3) | No | LOB this rule applies to |
| RULE_EXPRESSION | VARCHAR(200) | No | Encoded condition (app-level interpreted) |
| ACTIVE_FLAG | CHAR(1) | No | Y/N |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** UW_RULE_ID  **FK:** none
**Indexes:** UWRULEL1 (POL_TYPE, ACTIVE_FLAG)

### 2.18 POLICY_T — Policy Header
| Column | Data Type | Null | Description |
|---|---|---|---|
| POL_NBR | VARCHAR(12) | No | **PK.** From SEQ_POLICY_NBR |
| POL_TYPE | CHAR(3) | No | AUT, HOM, etc. |
| CUST_ID | VARCHAR(10) | No | **FK** → CUSTOMER_T |
| AGT_ID | VARCHAR(8) | No | **FK** → AGENT_T |
| QUOTE_ID | VARCHAR(12) | Yes | **FK** → QUOTE_T |
| POL_EFF_DATE | DATE | No | Term effective date |
| POL_EXP_DATE | DATE | No | Term expiration date |
| POL_STATUS | CHAR(1) | No | A=Active, E=Expired, C=Cancelled, Q=Pending |
| PREM_ANNUAL | DECIMAL(11,2) | No | Total annual premium |
| UW_DECISION | CHAR(1) | Yes | Copied UW decision at issue |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** POL_NBR  **FK:** CUST_ID → CUSTOMER_T.CUST_ID; AGT_ID → AGENT_T.AGT_ID; QUOTE_ID → QUOTE_T.QUOTE_ID
**Indexes:** POLICYL1 (CUST_ID); POLICYL2 (AGT_ID, POL_STATUS); POLICYL3 (POL_EXP_DATE)

### 2.19 COVERAGE_T — Policy Coverage Line
| Column | Data Type | Null | Description |
|---|---|---|---|
| COVERAGE_ID | VARCHAR(14) | No | **PK.** From SEQ_COVERAGE_ID |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| COV_TYPE_CD | VARCHAR(5) | No | **FK** → COVERAGE_TYPE_T |
| LIMIT_AMT | DECIMAL(11,2) | No | Coverage limit |
| PREMIUM_AMT | DECIMAL(9,2) | No | Premium for this coverage line |
| COV_EFF_DATE | DATE | No | Coverage effective date |
| COV_EXP_DATE | DATE | No | Coverage expiration date |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** COVERAGE_ID  **FK:** POL_NBR → POLICY_T.POL_NBR; COV_TYPE_CD → COVERAGE_TYPE_T.COV_TYPE_CD
**Indexes:** COVERAGEL1 (POL_NBR); COVERAGEL2 (COV_TYPE_CD)

### 2.20 COVERAGE_TYPE_T — Coverage Type Reference
| Column | Data Type | Null | Description |
|---|---|---|---|
| COV_TYPE_CD | VARCHAR(5) | No | **PK** |
| COV_DESC | VARCHAR(60) | No | Description |
| POL_TYPE | CHAR(3) | No | LOB applicability |
| MANDATORY_FLAG | CHAR(1) | No | Y/N — required coverage for the LOB |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** COV_TYPE_CD  **FK:** none
**Indexes:** COVTYPL1 (POL_TYPE)

### 2.21 DEDUCTIBLE_T — Deductible Terms
| Column | Data Type | Null | Description |
|---|---|---|---|
| DEDUCT_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| COVERAGE_ID | VARCHAR(14) | No | **FK** → COVERAGE_T |
| DED_TYPE | CHAR(1) | No | F=Fixed, P=Percentage |
| DED_AMT | DECIMAL(9,2) | No | Deductible amount/percent |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** DEDUCT_ID  **FK:** COVERAGE_ID → COVERAGE_T.COVERAGE_ID
**Indexes:** DEDUCTL1 (COVERAGE_ID)

### 2.22 ENDORSEMENT_T — Policy Endorsement
| Column | Data Type | Null | Description |
|---|---|---|---|
| ENDT_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| ENDT_TYPE | VARCHAR(10) | No | Type of change |
| ENDT_DESC | VARCHAR(100) | No | Description of change |
| ENDT_DATE | DATE | No | Endorsement date |
| PREM_CHANGE | DECIMAL(9,2) | Yes | Premium impact (+/-) |
| ENDT_STATUS | CHAR(1) | No | P=Pending, A=Applied |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** ENDT_ID  **FK:** POL_NBR → POLICY_T.POL_NBR
**Indexes:** ENDTL1 (POL_NBR, ENDT_DATE DESC)

### 2.23 POLICY_HISTORY_T — Policy Event History
| Column | Data Type | Null | Description |
|---|---|---|---|
| POL_HIST_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| EVENT_TYPE | CHAR(3) | No | ISS, END, REN, CAN |
| EVENT_DATE | DATE | No | Event date |
| NEW_STATUS | CHAR(1) | Yes | Resulting policy status |
| EVENT_DESC | VARCHAR(100) | Yes | Free text description |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** POL_HIST_ID  **FK:** POL_NBR → POLICY_T.POL_NBR
**Indexes:** POLHISL1 (POL_NBR, EVENT_DATE DESC)

### 2.24 POLICY_VEHICLE_T — Vehicle-to-Policy Link
| Column | Data Type | Null | Description |
|---|---|---|---|
| POL_VEH_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| VEHICLE_ID | VARCHAR(12) | No | **FK** → VEHICLE_T |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** POL_VEH_ID  **FK:** POL_NBR → POLICY_T.POL_NBR; VEHICLE_ID → VEHICLE_T.VEHICLE_ID
**Indexes:** POLVEHL1 (POL_NBR); POLVEHL2 (VEHICLE_ID)

### 2.25 POLICY_PROPERTY_T — Property-to-Policy Link
| Column | Data Type | Null | Description |
|---|---|---|---|
| POL_PROP_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| PROP_ID | VARCHAR(12) | No | **FK** → PROPERTY_T |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** POL_PROP_ID  **FK:** POL_NBR → POLICY_T.POL_NBR; PROP_ID → PROPERTY_T.PROP_ID
**Indexes:** POLPROPL1 (POL_NBR); POLPROPL2 (PROP_ID)

### 2.26 POLICY_DOCUMENT_T — Policy-to-Document Link
| Column | Data Type | Null | Description |
|---|---|---|---|
| POL_DOC_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| DOCUMENT_ID | VARCHAR(14) | No | **FK** → DOCUMENT_T |
| LINK_DATE | DATE | No | Date linked |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** POL_DOC_ID  **FK:** POL_NBR → POLICY_T.POL_NBR; DOCUMENT_ID → DOCUMENT_T.DOCUMENT_ID
**Indexes:** POLDOCL1 (POL_NBR); POLDOCL2 (DOCUMENT_ID)

### 2.27 RATE_TABLE_T — Rate Table Header
| Column | Data Type | Null | Description |
|---|---|---|---|
| RATE_TABLE_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| POL_TYPE | CHAR(3) | No | LOB |
| STATE | CHAR(2) | No | State applicability |
| RATE_VERSION | VARCHAR(10) | No | Version identifier |
| EFF_DATE | DATE | No | Effective date |
| EXP_DATE | DATE | Yes | Expiration date |
| BASE_RATE | DECIMAL(9,4) | No | Base rate per unit exposure |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** RATE_TABLE_ID  **FK:** none
**Indexes:** RATETABL1 (POL_TYPE, STATE, EFF_DATE)

### 2.28 RATE_FACTOR_T — Rate Factor Detail
| Column | Data Type | Null | Description |
|---|---|---|---|
| RATE_FACTOR_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| RATE_TABLE_ID | BIGINT | No | **FK** → RATE_TABLE_T |
| FACTOR_TYPE | VARCHAR(15) | No | e.g., AGE, TERRITORY, CONSTR_TYPE |
| FACTOR_VALUE_CD | VARCHAR(10) | No | Value bucket this factor applies to |
| FACTOR_MULT | DECIMAL(7,4) | No | Multiplier applied to base rate |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** RATE_FACTOR_ID  **FK:** RATE_TABLE_ID → RATE_TABLE_T.RATE_TABLE_ID
**Indexes:** RATEFACL1 (RATE_TABLE_ID, FACTOR_TYPE)

### 2.29 PREMIUM_CALC_T — Premium Calculation Snapshot
| Column | Data Type | Null | Description |
|---|---|---|---|
| PREM_CALC_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| POL_NBR | VARCHAR(12) | Yes | **FK** → POLICY_T |
| QUOTE_ID | VARCHAR(12) | Yes | **FK** → QUOTE_T |
| CALC_DATE | DATE | No | Calculation date |
| BASE_PREMIUM | DECIMAL(11,2) | No | Pre-factor premium |
| TOTAL_FACTOR | DECIMAL(7,4) | No | Combined rate factor multiplier |
| FINAL_PREMIUM | DECIMAL(11,2) | No | Resulting premium |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** PREM_CALC_ID  **FK:** POL_NBR → POLICY_T.POL_NBR; QUOTE_ID → QUOTE_T.QUOTE_ID
**Indexes:** PREMCALCL1 (POL_NBR); PREMCALCL2 (QUOTE_ID)

### 2.30 BILLING_SCHEDULE_T — Installment Billing Schedule
| Column | Data Type | Null | Description |
|---|---|---|---|
| BILL_SCHED_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| BILL_PLAN_ID | BIGINT | No | **FK** → BILLING_PLAN_T |
| INSTALLMENT_NBR | SMALLINT | No | Sequence within term |
| DUE_DATE | DATE | No | Installment due date |
| AMT_DUE | DECIMAL(9,2) | No | Amount due |
| AMT_PAID | DECIMAL(9,2) | No | Amount paid to date |
| SCHED_STATUS | CHAR(1) | No | O=Open, P=Paid, V=Void |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** BILL_SCHED_ID  **FK:** POL_NBR → POLICY_T.POL_NBR; BILL_PLAN_ID → BILLING_PLAN_T.BILL_PLAN_ID
**Indexes:** BILSCHL1 (POL_NBR, DUE_DATE); BILSCHL2 (SCHED_STATUS, DUE_DATE)

### 2.31 BILLING_PLAN_T — Billing Plan Reference
| Column | Data Type | Null | Description |
|---|---|---|---|
| BILL_PLAN_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| PLAN_DESC | VARCHAR(40) | No | e.g., Monthly, Quarterly, Annual |
| NBR_INSTALLMENTS | SMALLINT | No | Number of installments per term |
| INSTALLMENT_FEE | DECIMAL(7,2) | Yes | Per-installment service fee |
| ACTIVE_FLAG | CHAR(1) | No | Y/N |

**PK:** BILL_PLAN_ID  **FK:** none
**Indexes:** BILPLANL1 (ACTIVE_FLAG)

### 2.32 INVOICE_T — Invoice Header
| Column | Data Type | Null | Description |
|---|---|---|---|
| INVOICE_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| INVOICE_DATE | DATE | No | Invoice generation date |
| INVOICE_DUE_DATE | DATE | No | Payment due date |
| INVOICE_AMT | DECIMAL(11,2) | No | Total invoice amount |
| INVOICE_STATUS | CHAR(1) | No | O=Open, P=Paid, C=Cancelled |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** INVOICE_ID  **FK:** POL_NBR → POLICY_T.POL_NBR
**Indexes:** INVOICEL1 (POL_NBR, INVOICE_DATE DESC); INVOICEL2 (INVOICE_STATUS)

### 2.33 INVOICE_LINE_T — Invoice Line Detail
| Column | Data Type | Null | Description |
|---|---|---|---|
| INVOICE_LINE_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| INVOICE_ID | BIGINT | No | **FK** → INVOICE_T |
| BILL_SCHED_ID | BIGINT | Yes | **FK** → BILLING_SCHEDULE_T |
| LINE_DESC | VARCHAR(60) | No | Line item description |
| LINE_AMT | DECIMAL(9,2) | No | Line amount |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** INVOICE_LINE_ID  **FK:** INVOICE_ID → INVOICE_T.INVOICE_ID; BILL_SCHED_ID → BILLING_SCHEDULE_T.BILL_SCHED_ID
**Indexes:** INVLINEL1 (INVOICE_ID)

### 2.34 PAYMENT_T — Payment Received Header
| Column | Data Type | Null | Description |
|---|---|---|---|
| PAYMENT_ID | VARCHAR(14) | No | **PK.** From SEQ_PAYMENT_ID |
| POL_NBR | VARCHAR(12) | Yes | **FK** → POLICY_T |
| CUST_ID | VARCHAR(10) | No | **FK** → CUSTOMER_T |
| PAYMENT_DATE | DATE | No | Date received |
| PAYMENT_METHOD | CHAR(2) | No | CK=Check, CC=Card, AC=ACH |
| PAYMENT_AMT | DECIMAL(11,2) | No | Total payment amount |
| PAYMENT_STATUS | CHAR(1) | No | R=Received, A=Applied, F=Failed |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** PAYMENT_ID  **FK:** POL_NBR → POLICY_T.POL_NBR; CUST_ID → CUSTOMER_T.CUST_ID
**Indexes:** PAYMENTL1 (POL_NBR); PAYMENTL2 (CUST_ID, PAYMENT_DATE DESC)

### 2.35 PAYMENT_APPLICATION_T — Payment-to-Schedule Application
| Column | Data Type | Null | Description |
|---|---|---|---|
| PAY_APPL_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| PAYMENT_ID | VARCHAR(14) | No | **FK** → PAYMENT_T |
| BILL_SCHED_ID | BIGINT | No | **FK** → BILLING_SCHEDULE_T |
| APPLIED_AMT | DECIMAL(9,2) | No | Amount applied to this installment |
| APPLIED_DATE | DATE | No | Date applied |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** PAY_APPL_ID  **FK:** PAYMENT_ID → PAYMENT_T.PAYMENT_ID; BILL_SCHED_ID → BILLING_SCHEDULE_T.BILL_SCHED_ID
**Indexes:** PAYAPPL1 (PAYMENT_ID); PAYAPPL2 (BILL_SCHED_ID)

### 2.36 REFUND_T — Refund Issued
| Column | Data Type | Null | Description |
|---|---|---|---|
| REFUND_ID | VARCHAR(14) | No | **PK.** From SEQ_REFUND_ID |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| REFUND_DATE | DATE | No | Date issued |
| REFUND_AMT | DECIMAL(9,2) | No | Refund amount |
| REFUND_REASON_CD | VARCHAR(6) | Yes | **FK** → CODE_TABLE_T (CODE_TYPE='CANREASON') |
| REFUND_STATUS | CHAR(1) | No | P=Pending, I=Issued |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** REFUND_ID  **FK:** POL_NBR → POLICY_T.POL_NBR
**Indexes:** REFUNDL1 (POL_NBR)

### 2.37 CLAIM_T — Claim Header (FNOL)
| Column | Data Type | Null | Description |
|---|---|---|---|
| CLM_NBR | VARCHAR(12) | No | **PK.** From SEQ_CLAIM_NBR |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| LOSS_DATE | DATE | No | Date of loss |
| REPORT_DATE | DATE | No | Date reported |
| LOSS_TYPE | CHAR(3) | No | Type of loss (collision, fire, theft, etc.) |
| LOSS_DESC | VARCHAR(200) | Yes | Loss description |
| CLM_STATUS | CHAR(1) | No | O=Open, I=Investigating, A=Approved, P=Paid, C=Closed, D=Denied |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** CLM_NBR  **FK:** POL_NBR → POLICY_T.POL_NBR
**Indexes:** CLAIML1 (POL_NBR, LOSS_DATE); CLAIML2 (CLM_STATUS)

### 2.38 CLAIM_RESERVE_T — Claim Reserve History
| Column | Data Type | Null | Description |
|---|---|---|---|
| RESERVE_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| CLM_NBR | VARCHAR(12) | No | **FK** → CLAIM_T |
| RESERVE_DATE | DATE | No | Date of reserve change |
| RESERVE_AMT | DECIMAL(11,2) | No | Reserve amount as of this date |
| RESERVE_TYPE | CHAR(2) | No | IN=Indemnity, EX=Expense |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** RESERVE_ID  **FK:** CLM_NBR → CLAIM_T.CLM_NBR
**Indexes:** CLMRESL1 (CLM_NBR, RESERVE_DATE DESC)

### 2.39 CLAIM_PAYMENT_T — Claim Payment Detail
| Column | Data Type | Null | Description |
|---|---|---|---|
| CLM_PMT_ID | VARCHAR(14) | No | **PK.** From SEQ_CLAIM_PMT_ID |
| CLM_NBR | VARCHAR(12) | No | **FK** → CLAIM_T |
| PAYEE_NAME | VARCHAR(60) | No | Payee (interim, pending formal payee master) |
| PMT_DATE | DATE | No | Payment date |
| PMT_AMT | DECIMAL(11,2) | No | Payment amount |
| PMT_TYPE | CHAR(2) | No | IN=Indemnity, EX=Expense |
| PMT_STATUS | CHAR(1) | No | P=Pending, I=Issued, V=Voided |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** CLM_PMT_ID  **FK:** CLM_NBR → CLAIM_T.CLM_NBR
**Indexes:** CLMPMTL1 (CLM_NBR, PMT_DATE DESC)

### 2.40 CLAIM_NOTE_T — Claim Adjuster Notes
| Column | Data Type | Null | Description |
|---|---|---|---|
| CLM_NOTE_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| CLM_NBR | VARCHAR(12) | No | **FK** → CLAIM_T |
| NOTE_DATE | TIMESTAMP | No | Date/time note entered |
| NOTE_USER | VARCHAR(10) | No | Author |
| NOTE_TEXT | VARCHAR(500) | No | Note content |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** CLM_NOTE_ID  **FK:** CLM_NBR → CLAIM_T.CLM_NBR
**Indexes:** CLMNOTEL1 (CLM_NBR, NOTE_DATE DESC)

### 2.41 CLAIM_DOCUMENT_T — Claim-to-Document Link
| Column | Data Type | Null | Description |
|---|---|---|---|
| CLM_DOC_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| CLM_NBR | VARCHAR(12) | No | **FK** → CLAIM_T |
| DOCUMENT_ID | VARCHAR(14) | No | **FK** → DOCUMENT_T |
| LINK_DATE | DATE | No | Date linked |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** CLM_DOC_ID  **FK:** CLM_NBR → CLAIM_T.CLM_NBR; DOCUMENT_ID → DOCUMENT_T.DOCUMENT_ID
**Indexes:** CLMDOCL1 (CLM_NBR); CLMDOCL2 (DOCUMENT_ID)

### 2.42 CLAIM_ADJUSTER_T — Adjuster Assignment
| Column | Data Type | Null | Description |
|---|---|---|---|
| CLM_ADJ_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| CLM_NBR | VARCHAR(12) | No | **FK** → CLAIM_T |
| ADJUSTER_USER | VARCHAR(10) | No | **FK** → USER_T |
| ASSIGN_DATE | DATE | No | Date assigned |
| UNASSIGN_DATE | DATE | Yes | Date unassigned/reassigned |
| ASSIGN_STATUS | CHAR(1) | No | A=Active, C=Closed |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** CLM_ADJ_ID  **FK:** CLM_NBR → CLAIM_T.CLM_NBR; ADJUSTER_USER → USER_T.USER_ID
**Indexes:** CLMADJL1 (CLM_NBR); CLMADJL2 (ADJUSTER_USER, ASSIGN_STATUS)

### 2.43 APPROVAL_T — Claim/Transaction Approval Workflow
| Column | Data Type | Null | Description |
|---|---|---|---|
| APPROVAL_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| CLM_NBR | VARCHAR(12) | Yes | **FK** → CLAIM_T |
| APPROVAL_TYPE | VARCHAR(15) | No | e.g., PAYMENT_AUTH, RESERVE_INCR |
| REQUESTED_AMT | DECIMAL(11,2) | Yes | Amount requiring approval |
| APPROVER_USER | VARCHAR(10) | Yes | **FK** → USER_T |
| APPROVAL_STATUS | CHAR(1) | No | P=Pending, A=Approved, R=Rejected |
| APPROVAL_DATE | DATE | Yes | Date decided |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** APPROVAL_ID  **FK:** CLM_NBR → CLAIM_T.CLM_NBR; APPROVER_USER → USER_T.USER_ID
**Indexes:** APPRL1 (CLM_NBR); APPRL2 (APPROVAL_STATUS)

### 2.44 TREATY_T — Reinsurance Treaty Master
| Column | Data Type | Null | Description |
|---|---|---|---|
| TREATY_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| TREATY_NAME | VARCHAR(60) | No | Treaty/reinsurer name |
| TREATY_TYPE | CHAR(2) | No | QS=Quota Share, XL=Excess of Loss, FA=Facultative |
| EFF_DATE | DATE | No | Treaty effective date |
| EXP_DATE | DATE | Yes | Treaty expiration date |
| RETENTION_AMT | DECIMAL(13,2) | Yes | Company retention |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** TREATY_ID  **FK:** none
**Indexes:** TREATYL1 (TREATY_TYPE, EFF_DATE)

### 2.45 CESSION_T — Risk Cession to Treaty
| Column | Data Type | Null | Description |
|---|---|---|---|
| CESSION_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| POL_NBR | VARCHAR(12) | No | **FK** → POLICY_T |
| TREATY_ID | BIGINT | No | **FK** → TREATY_T |
| CEDED_PCT | DECIMAL(5,2) | No | % ceded |
| CEDED_PREMIUM | DECIMAL(11,2) | No | Premium ceded |
| CESSION_DATE | DATE | No | Date ceded |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** CESSION_ID  **FK:** POL_NBR → POLICY_T.POL_NBR; TREATY_ID → TREATY_T.TREATY_ID
**Indexes:** CESSIONL1 (POL_NBR); CESSIONL2 (TREATY_ID)

### 2.46 RECOVERY_T — Reinsurance Recovery on a Claim
| Column | Data Type | Null | Description |
|---|---|---|---|
| RECOVERY_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| CLM_NBR | VARCHAR(12) | No | **FK** → CLAIM_T |
| TREATY_ID | BIGINT | No | **FK** → TREATY_T |
| RECOVERY_AMT | DECIMAL(11,2) | No | Amount recovered/recoverable |
| RECOVERY_STATUS | CHAR(1) | No | P=Pending, R=Received |
| RECOVERY_DATE | DATE | Yes | Date received |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** RECOVERY_ID  **FK:** CLM_NBR → CLAIM_T.CLM_NBR; TREATY_ID → TREATY_T.TREATY_ID
**Indexes:** RECOVL1 (CLM_NBR); RECOVL2 (TREATY_ID)

### 2.47 DOCUMENT_T — Document/IFS Metadata Master
| Column | Data Type | Null | Description |
|---|---|---|---|
| DOCUMENT_ID | VARCHAR(14) | No | **PK.** From SEQ_DOCUMENT_ID |
| DOC_TYPE | VARCHAR(15) | No | e.g., APPLICATION, PHOTO, CORRESPONDENCE |
| DOC_TITLE | VARCHAR(60) | No | Display title |
| IFS_PATH | VARCHAR(200) | No | IFS storage path/object reference |
| UPLOAD_DATE | DATE | No | Date uploaded |
| UPLOAD_USER | VARCHAR(10) | No | Uploading user |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** DOCUMENT_ID  **FK:** none
**Indexes:** DOCUMENTL1 (DOC_TYPE); DOCUMENTL2 (UPLOAD_DATE DESC)

### 2.48 RPT_PARM_T — Configurable System Parameters
| Column | Data Type | Null | Description |
|---|---|---|---|
| PARM_NAME | VARCHAR(30) | No | **PK.** e.g., RENEWAL_WINDOW_DAYS |
| PARM_VALUE | VARCHAR(50) | No | Parameter value (string-typed, app-cast) |
| PARM_DESC | VARCHAR(100) | Yes | Description |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** PARM_NAME  **FK:** none
**Indexes:** none required (PK lookup only)

### 2.49 RPT_RUN_LOG_T — Report/Batch Run Log
| Column | Data Type | Null | Description |
|---|---|---|---|
| RUN_LOG_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| REPORT_ID | VARCHAR(10) | No | e.g., RPT001A |
| RUN_DATE | TIMESTAMP | No | Run start timestamp |
| RUN_STATUS | CHAR(1) | No | S=Success, F=Failed, R=Running |
| ROW_COUNT | INTEGER | Yes | Rows processed |
| RUN_USER | VARCHAR(10) | No | User/job that initiated run |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** RUN_LOG_ID  **FK:** none
**Indexes:** RPTRUNL1 (REPORT_ID, RUN_DATE DESC)

### 2.50 AUDIT_LOG_T — Centralized Audit Trail
| Column | Data Type | Null | Description |
|---|---|---|---|
| AUDIT_LOG_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| TABLE_NAME | VARCHAR(30) | No | Table affected |
| KEY_VALUE | VARCHAR(30) | No | PK value of affected row |
| ACTION_CD | CHAR(1) | No | A=Add, C=Change, D=Delete |
| FIELD_NAME | VARCHAR(30) | Yes | Field changed (C actions) |
| OLD_VALUE | VARCHAR(100) | Yes | Prior value |
| NEW_VALUE | VARCHAR(100) | Yes | New value |
| CHG_USER | VARCHAR(10) | No | User responsible |
| CHG_TIMESTAMP | TIMESTAMP | No | Timestamp of change |
| PROGRAM_NAME | VARCHAR(10) | No | Program that made the change |

**PK:** AUDIT_LOG_ID  **FK:** none (intentionally decoupled from business tables for append-only durability)
**Indexes:** AUDLOGL1 (TABLE_NAME, KEY_VALUE); AUDLOGL2 (CHG_USER, CHG_TIMESTAMP DESC)

### 2.51 USER_T — Application User Master
| Column | Data Type | Null | Description |
|---|---|---|---|
| USER_ID | VARCHAR(10) | No | **PK.** Sign-on user profile name |
| USER_NAME | VARCHAR(60) | No | Full name |
| EMAIL | VARCHAR(60) | Yes | Email |
| USER_STATUS | CHAR(1) | No | A=Active, I=Inactive, L=Locked |
| LAST_SIGNON | TIMESTAMP | Yes | Last successful signon |
| FAILED_ATTEMPTS | SMALLINT | No | Consecutive failed logon attempts |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |
| UPD_USER | VARCHAR(10) | Yes | Audit |
| UPD_TIMESTAMP | TIMESTAMP | Yes | Audit |

**PK:** USER_ID  **FK:** none
**Indexes:** USERL1 (USER_STATUS)

### 2.52 ROLE_T — Security Role Master
| Column | Data Type | Null | Description |
|---|---|---|---|
| ROLE_ID | VARCHAR(10) | No | **PK** |
| ROLE_DESC | VARCHAR(60) | No | Description |
| ACTIVE_FLAG | CHAR(1) | No | Y/N |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** ROLE_ID  **FK:** none
**Indexes:** none required (PK lookup only)

### 2.53 ROLE_MENU_T — Role-to-Menu-Option Authorization
| Column | Data Type | Null | Description |
|---|---|---|---|
| ROLE_MENU_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| ROLE_ID | VARCHAR(10) | No | **FK** → ROLE_T |
| MENU_OPTION | VARCHAR(10) | No | Program/menu-option code, e.g., POL001A |
| ACCESS_LEVEL | CHAR(1) | No | R=Read, U=Update, F=Full |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** ROLE_MENU_ID  **FK:** ROLE_ID → ROLE_T.ROLE_ID
**Indexes:** ROLEMENUL1 (ROLE_ID, MENU_OPTION)

### 2.54 USER_ROLE_T — User-to-Role Assignment
| Column | Data Type | Null | Description |
|---|---|---|---|
| USER_ROLE_ID | BIGINT GENERATED ALWAYS AS IDENTITY | No | **PK** |
| USER_ID | VARCHAR(10) | No | **FK** → USER_T |
| ROLE_ID | VARCHAR(10) | No | **FK** → ROLE_T |
| ASSIGN_DATE | DATE | No | Date assigned |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** USER_ROLE_ID  **FK:** USER_ID → USER_T.USER_ID; ROLE_ID → ROLE_T.ROLE_ID
**Indexes:** USERROLL1 (USER_ID); USERROLL2 (ROLE_ID)

### 2.55 CODE_TABLE_T — Generic Code/Description Lookup
| Column | Data Type | Null | Description |
|---|---|---|---|
| CODE_TYPE | VARCHAR(20) | No | **PK (1 of 2).** Domain, e.g., CANREASON |
| CODE_VALUE | VARCHAR(10) | No | **PK (2 of 2).** Code value |
| CODE_DESC | VARCHAR(60) | No | Description |
| ACTIVE_FLAG | CHAR(1) | No | Y/N |
| CRT_USER | VARCHAR(10) | No | Audit |
| CRT_TIMESTAMP | TIMESTAMP | No | Audit |

**PK:** CODE_TYPE, CODE_VALUE  **FK:** none
**Indexes:** none required (PK lookup only)

---

## 3. SQL DDL — CREATE TABLE Scripts (DB2 for i)

```sql
SET SCHEMA PCISLIB;

-- Sequence objects (key generation, per architecture §3.5)
CREATE SEQUENCE SEQ_CUSTOMER_ID AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_AGENT_ID    AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_QUOTE_ID    AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_POLICY_NBR  AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_COVERAGE_ID AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_DEDUCT_ID   AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_BILL_SCHED_ID AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_CLAIM_NBR   AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_CLAIM_PMT_ID AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_PAYMENT_ID  AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_REFUND_ID   AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_DOCUMENT_ID AS BIGINT START WITH 1 NO CYCLE;
CREATE SEQUENCE SEQ_AUDIT_LOG_ID AS BIGINT START WITH 1 NO CYCLE;

-- =========================================================
-- CUS MODULE
-- =========================================================
CREATE TABLE CUSTOMER_T (
  CUST_ID         VARCHAR(10)   NOT NULL,
  CUST_TYPE       CHAR(1)       NOT NULL,
  CUST_NAME       VARCHAR(60)   NOT NULL,
  FIRST_NAME      VARCHAR(30),
  LAST_NAME       VARCHAR(30),
  DOB             DATE,
  TAX_ID          VARCHAR(11),
  CUST_STATUS     CHAR(1)       NOT NULL DEFAULT 'A',
  EMAIL           VARCHAR(60),
  PHONE           VARCHAR(15),
  CRT_USER        VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER        VARCHAR(10),
  UPD_TIMESTAMP   TIMESTAMP,
  CONSTRAINT PK_CUSTOMER_T PRIMARY KEY (CUST_ID)
);
CREATE INDEX CUSTL1 ON CUSTOMER_T (CUST_NAME);
CREATE INDEX CUSTL2 ON CUSTOMER_T (TAX_ID);
CREATE INDEX CUSTL3 ON CUSTOMER_T (CUST_STATUS);

CREATE TABLE CUSTOMER_CONTACT_T (
  CONTACT_ID      BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  CUST_ID         VARCHAR(10)   NOT NULL,
  CONTACT_TYPE    CHAR(2)       NOT NULL,
  CONTACT_VALUE   VARCHAR(60)   NOT NULL,
  PREFERRED_FLAG  CHAR(1)       NOT NULL DEFAULT 'N',
  CRT_USER        VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER        VARCHAR(10),
  UPD_TIMESTAMP   TIMESTAMP,
  CONSTRAINT PK_CUSTOMER_CONTACT_T PRIMARY KEY (CONTACT_ID),
  CONSTRAINT FK_CUSCON_CUST FOREIGN KEY (CUST_ID) REFERENCES CUSTOMER_T (CUST_ID)
);
CREATE INDEX CUSCONL1 ON CUSTOMER_CONTACT_T (CUST_ID);

CREATE TABLE CUSTOMER_ADDRESS_T (
  ADDRESS_ID      BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  CUST_ID         VARCHAR(10)   NOT NULL,
  ADDR_TYPE       CHAR(1)       NOT NULL,
  ADDR_LINE1      VARCHAR(40)   NOT NULL,
  ADDR_LINE2      VARCHAR(40),
  CITY            VARCHAR(30)   NOT NULL,
  STATE           CHAR(2)       NOT NULL,
  ZIP             VARCHAR(10)   NOT NULL,
  CRT_USER        VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER        VARCHAR(10),
  UPD_TIMESTAMP   TIMESTAMP,
  CONSTRAINT PK_CUSTOMER_ADDRESS_T PRIMARY KEY (ADDRESS_ID),
  CONSTRAINT FK_CUSADR_CUST FOREIGN KEY (CUST_ID) REFERENCES CUSTOMER_T (CUST_ID)
);
CREATE INDEX CUSADRL1 ON CUSTOMER_ADDRESS_T (CUST_ID, ADDR_TYPE);

-- =========================================================
-- AGT MODULE
-- =========================================================
CREATE TABLE AGENT_T (
  AGT_ID          VARCHAR(8)    NOT NULL,
  AGT_NAME        VARCHAR(60)   NOT NULL,
  AGT_TYPE        CHAR(1)       NOT NULL,
  AGT_STATUS      CHAR(1)       NOT NULL DEFAULT 'A',
  AGENCY_CD       VARCHAR(10),
  EMAIL           VARCHAR(60),
  PHONE           VARCHAR(15),
  HIRE_DATE       DATE,
  CRT_USER        VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER        VARCHAR(10),
  UPD_TIMESTAMP   TIMESTAMP,
  CONSTRAINT PK_AGENT_T PRIMARY KEY (AGT_ID)
);
CREATE INDEX AGENTL1 ON AGENT_T (AGT_NAME);
CREATE INDEX AGENTL2 ON AGENT_T (AGT_STATUS);

CREATE TABLE AGENT_LICENSE_T (
  LICENSE_ID        BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  AGT_ID            VARCHAR(8)   NOT NULL,
  LICENSE_STATE     CHAR(2)      NOT NULL,
  LICENSE_NBR       VARCHAR(20)  NOT NULL,
  LICENSE_EFF_DATE  DATE         NOT NULL,
  LICENSE_EXP_DATE  DATE         NOT NULL,
  LICENSE_STATUS    CHAR(1)      NOT NULL DEFAULT 'A',
  CRT_USER          VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER          VARCHAR(10),
  UPD_TIMESTAMP     TIMESTAMP,
  CONSTRAINT PK_AGENT_LICENSE_T PRIMARY KEY (LICENSE_ID),
  CONSTRAINT FK_AGTLIC_AGT FOREIGN KEY (AGT_ID) REFERENCES AGENT_T (AGT_ID)
);
CREATE INDEX AGTLICL1 ON AGENT_LICENSE_T (AGT_ID, LICENSE_STATE);
CREATE INDEX AGTLICL2 ON AGENT_LICENSE_T (LICENSE_EXP_DATE);

CREATE TABLE AGENT_COMMISSION_T (
  COMM_PLAN_ID       BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  AGT_ID             VARCHAR(8)    NOT NULL,
  POL_TYPE           CHAR(3)       NOT NULL,
  COMM_RATE_NEW      DECIMAL(5,2)  NOT NULL,
  COMM_RATE_RENEWAL  DECIMAL(5,2)  NOT NULL,
  PLAN_EFF_DATE      DATE          NOT NULL,
  PLAN_EXP_DATE      DATE,
  CRT_USER           VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER           VARCHAR(10),
  UPD_TIMESTAMP      TIMESTAMP,
  CONSTRAINT PK_AGENT_COMMISSION_T PRIMARY KEY (COMM_PLAN_ID),
  CONSTRAINT FK_AGTCOM_AGT FOREIGN KEY (AGT_ID) REFERENCES AGENT_T (AGT_ID)
);
CREATE INDEX AGTCOML1 ON AGENT_COMMISSION_T (AGT_ID, POL_TYPE);

CREATE TABLE COMMISSION_PAYMENT_T (
  COMM_PMT_ID      BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  AGT_ID           VARCHAR(8)    NOT NULL,
  POL_NBR          VARCHAR(12)   NOT NULL,
  COMM_BASIS_AMT   DECIMAL(11,2) NOT NULL,
  COMM_RATE        DECIMAL(5,2)  NOT NULL,
  COMM_AMT         DECIMAL(9,2)  NOT NULL,
  COMM_RUN_DATE    DATE          NOT NULL,
  COMM_STATUS      CHAR(1)       NOT NULL DEFAULT 'P',
  CRT_USER         VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER         VARCHAR(10),
  UPD_TIMESTAMP    TIMESTAMP,
  CONSTRAINT PK_COMMISSION_PAYMENT_T PRIMARY KEY (COMM_PMT_ID),
  CONSTRAINT FK_COMPAY_AGT FOREIGN KEY (AGT_ID) REFERENCES AGENT_T (AGT_ID),
  CONSTRAINT FK_COMPAY_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR)
);
CREATE INDEX COMPAYL1 ON COMMISSION_PAYMENT_T (AGT_ID, COMM_RUN_DATE);
CREATE INDEX COMPAYL2 ON COMMISSION_PAYMENT_T (POL_NBR);

-- =========================================================
-- QTE MODULE
-- =========================================================
CREATE TABLE QUOTE_T (
  QUOTE_ID        VARCHAR(12)   NOT NULL,
  CUST_ID         VARCHAR(10)   NOT NULL,
  AGT_ID          VARCHAR(8)    NOT NULL,
  POL_TYPE        CHAR(3)       NOT NULL,
  QUOTE_DATE      DATE          NOT NULL,
  QUOTE_EXP_DATE  DATE          NOT NULL,
  QUOTE_PREMIUM   DECIMAL(11,2),
  QUOTE_STATUS    CHAR(1)       NOT NULL DEFAULT 'D',
  CRT_USER        VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER        VARCHAR(10),
  UPD_TIMESTAMP   TIMESTAMP,
  CONSTRAINT PK_QUOTE_T PRIMARY KEY (QUOTE_ID),
  CONSTRAINT FK_QUOTE_CUST FOREIGN KEY (CUST_ID) REFERENCES CUSTOMER_T (CUST_ID),
  CONSTRAINT FK_QUOTE_AGT FOREIGN KEY (AGT_ID) REFERENCES AGENT_T (AGT_ID)
);
CREATE INDEX QUOTEL1 ON QUOTE_T (CUST_ID);
CREATE INDEX QUOTEL2 ON QUOTE_T (AGT_ID, QUOTE_STATUS);

CREATE TABLE RISK_T (
  RISK_ID         VARCHAR(12)   NOT NULL,
  QUOTE_ID        VARCHAR(12),
  RISK_TYPE       CHAR(1)       NOT NULL,
  TERRITORY_CD    VARCHAR(6),
  CRT_USER        VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER        VARCHAR(10),
  UPD_TIMESTAMP   TIMESTAMP,
  CONSTRAINT PK_RISK_T PRIMARY KEY (RISK_ID),
  CONSTRAINT FK_RISK_QUOTE FOREIGN KEY (QUOTE_ID) REFERENCES QUOTE_T (QUOTE_ID)
);
CREATE INDEX RISKL1 ON RISK_T (QUOTE_ID);
CREATE INDEX RISKL2 ON RISK_T (TERRITORY_CD);

CREATE TABLE VEHICLE_T (
  VEHICLE_ID         VARCHAR(12)   NOT NULL,
  RISK_ID            VARCHAR(12)   NOT NULL,
  VIN                VARCHAR(17)   NOT NULL,
  MAKE               VARCHAR(20)   NOT NULL,
  MODEL              VARCHAR(20)   NOT NULL,
  MODEL_YEAR         SMALLINT      NOT NULL,
  USAGE_TYPE         CHAR(2)       NOT NULL,
  ANNUAL_MILEAGE     INTEGER,
  ACTUAL_CASH_VALUE  DECIMAL(11,2),
  CRT_USER           VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER           VARCHAR(10),
  UPD_TIMESTAMP      TIMESTAMP,
  CONSTRAINT PK_VEHICLE_T PRIMARY KEY (VEHICLE_ID),
  CONSTRAINT FK_VEHICLE_RISK FOREIGN KEY (RISK_ID) REFERENCES RISK_T (RISK_ID)
);
CREATE INDEX VEHICLEL1 ON VEHICLE_T (VIN);
CREATE INDEX VEHICLEL2 ON VEHICLE_T (RISK_ID);

CREATE TABLE VEHICLE_FEATURE_T (
  VEH_FEAT_ID    BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  VEHICLE_ID     VARCHAR(12)  NOT NULL,
  FEAT_CD        VARCHAR(10)  NOT NULL,
  FEAT_VALUE     VARCHAR(30),
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_VEHICLE_FEATURE_T PRIMARY KEY (VEH_FEAT_ID),
  CONSTRAINT FK_VEHFEAT_VEH FOREIGN KEY (VEHICLE_ID) REFERENCES VEHICLE_T (VEHICLE_ID)
);
CREATE INDEX VEHFEATL1 ON VEHICLE_FEATURE_T (VEHICLE_ID);

CREATE TABLE PROPERTY_T (
  PROP_ID             VARCHAR(12)   NOT NULL,
  RISK_ID             VARCHAR(12)   NOT NULL,
  PROP_TYPE           CHAR(2)       NOT NULL,
  ADDR_LINE1          VARCHAR(40)   NOT NULL,
  CITY                VARCHAR(30)   NOT NULL,
  STATE               CHAR(2)       NOT NULL,
  ZIP                 VARCHAR(10)   NOT NULL,
  YEAR_BUILT          SMALLINT,
  SQ_FOOTAGE          INTEGER,
  CONSTRUCTION_TYPE   CHAR(2),
  REPLACEMENT_VALUE   DECIMAL(13,2),
  CRT_USER            VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER            VARCHAR(10),
  UPD_TIMESTAMP       TIMESTAMP,
  CONSTRAINT PK_PROPERTY_T PRIMARY KEY (PROP_ID),
  CONSTRAINT FK_PROPERTY_RISK FOREIGN KEY (RISK_ID) REFERENCES RISK_T (RISK_ID)
);
CREATE INDEX PROPERTYL1 ON PROPERTY_T (RISK_ID);
CREATE INDEX PROPERTYL2 ON PROPERTY_T (ZIP);

CREATE TABLE PROPERTY_FEATURE_T (
  PROP_FEAT_ID   BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  PROP_ID        VARCHAR(12)  NOT NULL,
  FEAT_CD        VARCHAR(10)  NOT NULL,
  FEAT_VALUE     VARCHAR(30),
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_PROPERTY_FEATURE_T PRIMARY KEY (PROP_FEAT_ID),
  CONSTRAINT FK_PROPFEAT_PROP FOREIGN KEY (PROP_ID) REFERENCES PROPERTY_T (PROP_ID)
);
CREATE INDEX PROPFEATL1 ON PROPERTY_FEATURE_T (PROP_ID);

CREATE TABLE COVERAGE_TYPE_T (
  COV_TYPE_CD      VARCHAR(5)    NOT NULL,
  COV_DESC         VARCHAR(60)   NOT NULL,
  POL_TYPE         CHAR(3)       NOT NULL,
  MANDATORY_FLAG   CHAR(1)       NOT NULL DEFAULT 'N',
  CRT_USER         VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_COVERAGE_TYPE_T PRIMARY KEY (COV_TYPE_CD)
);
CREATE INDEX COVTYPL1 ON COVERAGE_TYPE_T (POL_TYPE);

CREATE TABLE QUOTE_COVERAGE_T (
  QUOTE_COV_ID   BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  QUOTE_ID       VARCHAR(12)   NOT NULL,
  COV_TYPE_CD    VARCHAR(5)    NOT NULL,
  LIMIT_AMT      DECIMAL(11,2) NOT NULL,
  EST_PREMIUM    DECIMAL(9,2),
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER       VARCHAR(10),
  UPD_TIMESTAMP  TIMESTAMP,
  CONSTRAINT PK_QUOTE_COVERAGE_T PRIMARY KEY (QUOTE_COV_ID),
  CONSTRAINT FK_QTECOV_QUOTE FOREIGN KEY (QUOTE_ID) REFERENCES QUOTE_T (QUOTE_ID),
  CONSTRAINT FK_QTECOV_COVTYPE FOREIGN KEY (COV_TYPE_CD) REFERENCES COVERAGE_TYPE_T (COV_TYPE_CD)
);
CREATE INDEX QTECOVL1 ON QUOTE_COVERAGE_T (QUOTE_ID);

-- =========================================================
-- UND MODULE
-- =========================================================
CREATE TABLE UW_RULE_T (
  UW_RULE_ID       BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  RULE_NAME        VARCHAR(40)   NOT NULL,
  POL_TYPE         CHAR(3)       NOT NULL,
  RULE_EXPRESSION  VARCHAR(200)  NOT NULL,
  ACTIVE_FLAG      CHAR(1)       NOT NULL DEFAULT 'Y',
  CRT_USER         VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER         VARCHAR(10),
  UPD_TIMESTAMP    TIMESTAMP,
  CONSTRAINT PK_UW_RULE_T PRIMARY KEY (UW_RULE_ID)
);
CREATE INDEX UWRULEL1 ON UW_RULE_T (POL_TYPE, ACTIVE_FLAG);

CREATE TABLE UW_DECISION_T (
  UW_DECISION_ID   BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  QUOTE_ID         VARCHAR(12)   NOT NULL,
  UW_USER          VARCHAR(10)   NOT NULL,
  DECISION_CD      CHAR(1)       NOT NULL,
  DECISION_DATE    DATE          NOT NULL,
  DECISION_REASON  VARCHAR(100),
  CRT_USER         VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_UW_DECISION_T PRIMARY KEY (UW_DECISION_ID),
  CONSTRAINT FK_UWDEC_QUOTE FOREIGN KEY (QUOTE_ID) REFERENCES QUOTE_T (QUOTE_ID)
);
CREATE INDEX UWDECL1 ON UW_DECISION_T (QUOTE_ID);

CREATE TABLE UW_REFERRAL_T (
  REFERRAL_ID        BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  QUOTE_ID           VARCHAR(12)  NOT NULL,
  REFERRAL_RULE_ID   BIGINT,
  REFERRED_TO_USER   VARCHAR(10)  NOT NULL,
  REFERRAL_STATUS    CHAR(1)      NOT NULL DEFAULT 'O',
  REFERRAL_DATE      DATE         NOT NULL,
  RESOLUTION_DATE    DATE,
  CRT_USER           VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_UW_REFERRAL_T PRIMARY KEY (REFERRAL_ID),
  CONSTRAINT FK_UWREF_QUOTE FOREIGN KEY (QUOTE_ID) REFERENCES QUOTE_T (QUOTE_ID),
  CONSTRAINT FK_UWREF_RULE FOREIGN KEY (REFERRAL_RULE_ID) REFERENCES UW_RULE_T (UW_RULE_ID)
);
CREATE INDEX UWREFL1 ON UW_REFERRAL_T (QUOTE_ID);
CREATE INDEX UWREFL2 ON UW_REFERRAL_T (REFERRAL_STATUS);

-- =========================================================
-- POL MODULE
-- =========================================================
CREATE TABLE POLICY_T (
  POL_NBR        VARCHAR(12)   NOT NULL,
  POL_TYPE       CHAR(3)       NOT NULL,
  CUST_ID        VARCHAR(10)   NOT NULL,
  AGT_ID         VARCHAR(8)    NOT NULL,
  QUOTE_ID       VARCHAR(12),
  POL_EFF_DATE   DATE          NOT NULL,
  POL_EXP_DATE   DATE          NOT NULL,
  POL_STATUS     CHAR(1)       NOT NULL DEFAULT 'Q',
  PREM_ANNUAL    DECIMAL(11,2) NOT NULL,
  UW_DECISION    CHAR(1),
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER       VARCHAR(10),
  UPD_TIMESTAMP  TIMESTAMP,
  CONSTRAINT PK_POLICY_T PRIMARY KEY (POL_NBR),
  CONSTRAINT FK_POLICY_CUST FOREIGN KEY (CUST_ID) REFERENCES CUSTOMER_T (CUST_ID),
  CONSTRAINT FK_POLICY_AGT FOREIGN KEY (AGT_ID) REFERENCES AGENT_T (AGT_ID),
  CONSTRAINT FK_POLICY_QUOTE FOREIGN KEY (QUOTE_ID) REFERENCES QUOTE_T (QUOTE_ID)
);
CREATE INDEX POLICYL1 ON POLICY_T (CUST_ID);
CREATE INDEX POLICYL2 ON POLICY_T (AGT_ID, POL_STATUS);
CREATE INDEX POLICYL3 ON POLICY_T (POL_EXP_DATE);

CREATE TABLE COVERAGE_T (
  COVERAGE_ID    VARCHAR(14)   NOT NULL,
  POL_NBR        VARCHAR(12)   NOT NULL,
  COV_TYPE_CD    VARCHAR(5)    NOT NULL,
  LIMIT_AMT      DECIMAL(11,2) NOT NULL,
  PREMIUM_AMT    DECIMAL(9,2)  NOT NULL,
  COV_EFF_DATE   DATE          NOT NULL,
  COV_EXP_DATE   DATE          NOT NULL,
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER       VARCHAR(10),
  UPD_TIMESTAMP  TIMESTAMP,
  CONSTRAINT PK_COVERAGE_T PRIMARY KEY (COVERAGE_ID),
  CONSTRAINT FK_COVERAGE_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR),
  CONSTRAINT FK_COVERAGE_TYPE FOREIGN KEY (COV_TYPE_CD) REFERENCES COVERAGE_TYPE_T (COV_TYPE_CD)
);
CREATE INDEX COVERAGEL1 ON COVERAGE_T (POL_NBR);
CREATE INDEX COVERAGEL2 ON COVERAGE_T (COV_TYPE_CD);

CREATE TABLE DEDUCTIBLE_T (
  DEDUCT_ID      BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  COVERAGE_ID    VARCHAR(14)  NOT NULL,
  DED_TYPE       CHAR(1)      NOT NULL DEFAULT 'F',
  DED_AMT        DECIMAL(9,2) NOT NULL,
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER       VARCHAR(10),
  UPD_TIMESTAMP  TIMESTAMP,
  CONSTRAINT PK_DEDUCTIBLE_T PRIMARY KEY (DEDUCT_ID),
  CONSTRAINT FK_DEDUCT_COV FOREIGN KEY (COVERAGE_ID) REFERENCES COVERAGE_T (COVERAGE_ID)
);
CREATE INDEX DEDUCTL1 ON DEDUCTIBLE_T (COVERAGE_ID);

CREATE TABLE ENDORSEMENT_T (
  ENDT_ID        BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  POL_NBR        VARCHAR(12)   NOT NULL,
  ENDT_TYPE      VARCHAR(10)   NOT NULL,
  ENDT_DESC      VARCHAR(100)  NOT NULL,
  ENDT_DATE      DATE          NOT NULL,
  PREM_CHANGE    DECIMAL(9,2),
  ENDT_STATUS    CHAR(1)       NOT NULL DEFAULT 'P',
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER       VARCHAR(10),
  UPD_TIMESTAMP  TIMESTAMP,
  CONSTRAINT PK_ENDORSEMENT_T PRIMARY KEY (ENDT_ID),
  CONSTRAINT FK_ENDT_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR)
);
CREATE INDEX ENDTL1 ON ENDORSEMENT_T (POL_NBR, ENDT_DATE DESC);

CREATE TABLE POLICY_HISTORY_T (
  POL_HIST_ID    BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  POL_NBR        VARCHAR(12)  NOT NULL,
  EVENT_TYPE     CHAR(3)      NOT NULL,
  EVENT_DATE     DATE         NOT NULL,
  NEW_STATUS     CHAR(1),
  EVENT_DESC     VARCHAR(100),
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_POLICY_HISTORY_T PRIMARY KEY (POL_HIST_ID),
  CONSTRAINT FK_POLHIS_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR)
);
CREATE INDEX POLHISL1 ON POLICY_HISTORY_T (POL_NBR, EVENT_DATE DESC);

CREATE TABLE POLICY_VEHICLE_T (
  POL_VEH_ID     BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  POL_NBR        VARCHAR(12)  NOT NULL,
  VEHICLE_ID     VARCHAR(12)  NOT NULL,
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_POLICY_VEHICLE_T PRIMARY KEY (POL_VEH_ID),
  CONSTRAINT FK_POLVEH_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR),
  CONSTRAINT FK_POLVEH_VEH FOREIGN KEY (VEHICLE_ID) REFERENCES VEHICLE_T (VEHICLE_ID)
);
CREATE INDEX POLVEHL1 ON POLICY_VEHICLE_T (POL_NBR);
CREATE INDEX POLVEHL2 ON POLICY_VEHICLE_T (VEHICLE_ID);

CREATE TABLE POLICY_PROPERTY_T (
  POL_PROP_ID    BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  POL_NBR        VARCHAR(12)  NOT NULL,
  PROP_ID        VARCHAR(12)  NOT NULL,
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_POLICY_PROPERTY_T PRIMARY KEY (POL_PROP_ID),
  CONSTRAINT FK_POLPROP_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR),
  CONSTRAINT FK_POLPROP_PROP FOREIGN KEY (PROP_ID) REFERENCES PROPERTY_T (PROP_ID)
);
CREATE INDEX POLPROPL1 ON POLICY_PROPERTY_T (POL_NBR);
CREATE INDEX POLPROPL2 ON POLICY_PROPERTY_T (PROP_ID);

-- =========================================================
-- PRM MODULE
-- =========================================================
CREATE TABLE RATE_TABLE_T (
  RATE_TABLE_ID  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  POL_TYPE       CHAR(3)       NOT NULL,
  STATE          CHAR(2)       NOT NULL,
  RATE_VERSION   VARCHAR(10)   NOT NULL,
  EFF_DATE       DATE          NOT NULL,
  EXP_DATE       DATE,
  BASE_RATE      DECIMAL(9,4)  NOT NULL,
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER       VARCHAR(10),
  UPD_TIMESTAMP  TIMESTAMP,
  CONSTRAINT PK_RATE_TABLE_T PRIMARY KEY (RATE_TABLE_ID)
);
CREATE INDEX RATETABL1 ON RATE_TABLE_T (POL_TYPE, STATE, EFF_DATE);

CREATE TABLE RATE_FACTOR_T (
  RATE_FACTOR_ID    BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  RATE_TABLE_ID     BIGINT        NOT NULL,
  FACTOR_TYPE       VARCHAR(15)   NOT NULL,
  FACTOR_VALUE_CD   VARCHAR(10)   NOT NULL,
  FACTOR_MULT       DECIMAL(7,4)  NOT NULL,
  CRT_USER          VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_RATE_FACTOR_T PRIMARY KEY (RATE_FACTOR_ID),
  CONSTRAINT FK_RATEFAC_RATETBL FOREIGN KEY (RATE_TABLE_ID) REFERENCES RATE_TABLE_T (RATE_TABLE_ID)
);
CREATE INDEX RATEFACL1 ON RATE_FACTOR_T (RATE_TABLE_ID, FACTOR_TYPE);

CREATE TABLE PREMIUM_CALC_T (
  PREM_CALC_ID   BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  POL_NBR        VARCHAR(12),
  QUOTE_ID       VARCHAR(12),
  CALC_DATE      DATE          NOT NULL,
  BASE_PREMIUM   DECIMAL(11,2) NOT NULL,
  TOTAL_FACTOR   DECIMAL(7,4)  NOT NULL,
  FINAL_PREMIUM  DECIMAL(11,2) NOT NULL,
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_PREMIUM_CALC_T PRIMARY KEY (PREM_CALC_ID),
  CONSTRAINT FK_PREMCALC_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR),
  CONSTRAINT FK_PREMCALC_QUOTE FOREIGN KEY (QUOTE_ID) REFERENCES QUOTE_T (QUOTE_ID)
);
CREATE INDEX PREMCALCL1 ON PREMIUM_CALC_T (POL_NBR);
CREATE INDEX PREMCALCL2 ON PREMIUM_CALC_T (QUOTE_ID);

-- =========================================================
-- BIL MODULE
-- =========================================================
CREATE TABLE BILLING_PLAN_T (
  BILL_PLAN_ID       BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  PLAN_DESC          VARCHAR(40)   NOT NULL,
  NBR_INSTALLMENTS   SMALLINT      NOT NULL,
  INSTALLMENT_FEE    DECIMAL(7,2),
  ACTIVE_FLAG        CHAR(1)       NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_BILLING_PLAN_T PRIMARY KEY (BILL_PLAN_ID)
);
CREATE INDEX BILPLANL1 ON BILLING_PLAN_T (ACTIVE_FLAG);

CREATE TABLE BILLING_SCHEDULE_T (
  BILL_SCHED_ID     BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  POL_NBR           VARCHAR(12)   NOT NULL,
  BILL_PLAN_ID      BIGINT        NOT NULL,
  INSTALLMENT_NBR   SMALLINT      NOT NULL,
  DUE_DATE          DATE          NOT NULL,
  AMT_DUE           DECIMAL(9,2)  NOT NULL,
  AMT_PAID          DECIMAL(9,2)  NOT NULL DEFAULT 0,
  SCHED_STATUS      CHAR(1)       NOT NULL DEFAULT 'O',
  CRT_USER          VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER          VARCHAR(10),
  UPD_TIMESTAMP     TIMESTAMP,
  CONSTRAINT PK_BILLING_SCHEDULE_T PRIMARY KEY (BILL_SCHED_ID),
  CONSTRAINT FK_BILSCH_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR),
  CONSTRAINT FK_BILSCH_PLAN FOREIGN KEY (BILL_PLAN_ID) REFERENCES BILLING_PLAN_T (BILL_PLAN_ID)
);
CREATE INDEX BILSCHL1 ON BILLING_SCHEDULE_T (POL_NBR, DUE_DATE);
CREATE INDEX BILSCHL2 ON BILLING_SCHEDULE_T (SCHED_STATUS, DUE_DATE);

CREATE TABLE INVOICE_T (
  INVOICE_ID         BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  POL_NBR            VARCHAR(12)   NOT NULL,
  INVOICE_DATE       DATE          NOT NULL,
  INVOICE_DUE_DATE   DATE          NOT NULL,
  INVOICE_AMT        DECIMAL(11,2) NOT NULL,
  INVOICE_STATUS     CHAR(1)       NOT NULL DEFAULT 'O',
  CRT_USER           VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER           VARCHAR(10),
  UPD_TIMESTAMP      TIMESTAMP,
  CONSTRAINT PK_INVOICE_T PRIMARY KEY (INVOICE_ID),
  CONSTRAINT FK_INVOICE_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR)
);
CREATE INDEX INVOICEL1 ON INVOICE_T (POL_NBR, INVOICE_DATE DESC);
CREATE INDEX INVOICEL2 ON INVOICE_T (INVOICE_STATUS);

CREATE TABLE INVOICE_LINE_T (
  INVOICE_LINE_ID  BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  INVOICE_ID       BIGINT       NOT NULL,
  BILL_SCHED_ID    BIGINT,
  LINE_DESC        VARCHAR(60)  NOT NULL,
  LINE_AMT         DECIMAL(9,2) NOT NULL,
  CRT_USER         VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_INVOICE_LINE_T PRIMARY KEY (INVOICE_LINE_ID),
  CONSTRAINT FK_INVLINE_INV FOREIGN KEY (INVOICE_ID) REFERENCES INVOICE_T (INVOICE_ID),
  CONSTRAINT FK_INVLINE_BILSCH FOREIGN KEY (BILL_SCHED_ID) REFERENCES BILLING_SCHEDULE_T (BILL_SCHED_ID)
);
CREATE INDEX INVLINEL1 ON INVOICE_LINE_T (INVOICE_ID);

-- =========================================================
-- PAY MODULE
-- =========================================================
CREATE TABLE PAYMENT_T (
  PAYMENT_ID      VARCHAR(14)   NOT NULL,
  POL_NBR         VARCHAR(12),
  CUST_ID         VARCHAR(10)   NOT NULL,
  PAYMENT_DATE    DATE          NOT NULL,
  PAYMENT_METHOD  CHAR(2)       NOT NULL,
  PAYMENT_AMT     DECIMAL(11,2) NOT NULL,
  PAYMENT_STATUS  CHAR(1)       NOT NULL DEFAULT 'R',
  CRT_USER        VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER        VARCHAR(10),
  UPD_TIMESTAMP   TIMESTAMP,
  CONSTRAINT PK_PAYMENT_T PRIMARY KEY (PAYMENT_ID),
  CONSTRAINT FK_PAYMENT_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR),
  CONSTRAINT FK_PAYMENT_CUST FOREIGN KEY (CUST_ID) REFERENCES CUSTOMER_T (CUST_ID)
);
CREATE INDEX PAYMENTL1 ON PAYMENT_T (POL_NBR);
CREATE INDEX PAYMENTL2 ON PAYMENT_T (CUST_ID, PAYMENT_DATE DESC);

CREATE TABLE PAYMENT_APPLICATION_T (
  PAY_APPL_ID    BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  PAYMENT_ID     VARCHAR(14)  NOT NULL,
  BILL_SCHED_ID  BIGINT       NOT NULL,
  APPLIED_AMT    DECIMAL(9,2) NOT NULL,
  APPLIED_DATE   DATE         NOT NULL,
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_PAYMENT_APPLICATION_T PRIMARY KEY (PAY_APPL_ID),
  CONSTRAINT FK_PAYAPPL_PAY FOREIGN KEY (PAYMENT_ID) REFERENCES PAYMENT_T (PAYMENT_ID),
  CONSTRAINT FK_PAYAPPL_BILSCH FOREIGN KEY (BILL_SCHED_ID) REFERENCES BILLING_SCHEDULE_T (BILL_SCHED_ID)
);
CREATE INDEX PAYAPPL1 ON PAYMENT_APPLICATION_T (PAYMENT_ID);
CREATE INDEX PAYAPPL2 ON PAYMENT_APPLICATION_T (BILL_SCHED_ID);

CREATE TABLE REFUND_T (
  REFUND_ID         VARCHAR(14)  NOT NULL,
  POL_NBR           VARCHAR(12)  NOT NULL,
  REFUND_DATE       DATE         NOT NULL,
  REFUND_AMT        DECIMAL(9,2) NOT NULL,
  REFUND_REASON_CD  VARCHAR(6),
  REFUND_STATUS     CHAR(1)      NOT NULL DEFAULT 'P',
  CRT_USER          VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER          VARCHAR(10),
  UPD_TIMESTAMP     TIMESTAMP,
  CONSTRAINT PK_REFUND_T PRIMARY KEY (REFUND_ID),
  CONSTRAINT FK_REFUND_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR)
);
CREATE INDEX REFUNDL1 ON REFUND_T (POL_NBR);

-- =========================================================
-- CLM MODULE
-- =========================================================
CREATE TABLE CLAIM_T (
  CLM_NBR        VARCHAR(12)   NOT NULL,
  POL_NBR        VARCHAR(12)   NOT NULL,
  LOSS_DATE      DATE          NOT NULL,
  REPORT_DATE    DATE          NOT NULL,
  LOSS_TYPE      CHAR(3)       NOT NULL,
  LOSS_DESC      VARCHAR(200),
  CLM_STATUS     CHAR(1)       NOT NULL DEFAULT 'O',
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER       VARCHAR(10),
  UPD_TIMESTAMP  TIMESTAMP,
  CONSTRAINT PK_CLAIM_T PRIMARY KEY (CLM_NBR),
  CONSTRAINT FK_CLAIM_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR)
);
CREATE INDEX CLAIML1 ON CLAIM_T (POL_NBR, LOSS_DATE);
CREATE INDEX CLAIML2 ON CLAIM_T (CLM_STATUS);

CREATE TABLE CLAIM_RESERVE_T (
  RESERVE_ID     BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  CLM_NBR        VARCHAR(12)   NOT NULL,
  RESERVE_DATE   DATE          NOT NULL,
  RESERVE_AMT    DECIMAL(11,2) NOT NULL,
  RESERVE_TYPE   CHAR(2)       NOT NULL,
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_CLAIM_RESERVE_T PRIMARY KEY (RESERVE_ID),
  CONSTRAINT FK_CLMRES_CLM FOREIGN KEY (CLM_NBR) REFERENCES CLAIM_T (CLM_NBR)
);
CREATE INDEX CLMRESL1 ON CLAIM_RESERVE_T (CLM_NBR, RESERVE_DATE DESC);

CREATE TABLE CLAIM_PAYMENT_T (
  CLM_PMT_ID     VARCHAR(14)   NOT NULL,
  CLM_NBR        VARCHAR(12)   NOT NULL,
  PAYEE_NAME     VARCHAR(60)   NOT NULL,
  PMT_DATE       DATE          NOT NULL,
  PMT_AMT        DECIMAL(11,2) NOT NULL,
  PMT_TYPE       CHAR(2)       NOT NULL,
  PMT_STATUS     CHAR(1)       NOT NULL DEFAULT 'P',
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER       VARCHAR(10),
  UPD_TIMESTAMP  TIMESTAMP,
  CONSTRAINT PK_CLAIM_PAYMENT_T PRIMARY KEY (CLM_PMT_ID),
  CONSTRAINT FK_CLMPMT_CLM FOREIGN KEY (CLM_NBR) REFERENCES CLAIM_T (CLM_NBR)
);
CREATE INDEX CLMPMTL1 ON CLAIM_PAYMENT_T (CLM_NBR, PMT_DATE DESC);

CREATE TABLE CLAIM_NOTE_T (
  CLM_NOTE_ID    BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  CLM_NBR        VARCHAR(12)   NOT NULL,
  NOTE_DATE      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  NOTE_USER      VARCHAR(10)   NOT NULL,
  NOTE_TEXT      VARCHAR(500)  NOT NULL,
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_CLAIM_NOTE_T PRIMARY KEY (CLM_NOTE_ID),
  CONSTRAINT FK_CLMNOTE_CLM FOREIGN KEY (CLM_NBR) REFERENCES CLAIM_T (CLM_NBR)
);
CREATE INDEX CLMNOTEL1 ON CLAIM_NOTE_T (CLM_NBR, NOTE_DATE DESC);

CREATE TABLE CLAIM_ADJUSTER_T (
  CLM_ADJ_ID       BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  CLM_NBR          VARCHAR(12)  NOT NULL,
  ADJUSTER_USER    VARCHAR(10)  NOT NULL,
  ASSIGN_DATE      DATE         NOT NULL,
  UNASSIGN_DATE    DATE,
  ASSIGN_STATUS    CHAR(1)      NOT NULL DEFAULT 'A',
  CRT_USER         VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_CLAIM_ADJUSTER_T PRIMARY KEY (CLM_ADJ_ID),
  CONSTRAINT FK_CLMADJ_CLM FOREIGN KEY (CLM_NBR) REFERENCES CLAIM_T (CLM_NBR),
  CONSTRAINT FK_CLMADJ_USER FOREIGN KEY (ADJUSTER_USER) REFERENCES USER_T (USER_ID)
);
CREATE INDEX CLMADJL1 ON CLAIM_ADJUSTER_T (CLM_NBR);
CREATE INDEX CLMADJL2 ON CLAIM_ADJUSTER_T (ADJUSTER_USER, ASSIGN_STATUS);

CREATE TABLE APPROVAL_T (
  APPROVAL_ID      BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  CLM_NBR          VARCHAR(12),
  APPROVAL_TYPE    VARCHAR(15)   NOT NULL,
  REQUESTED_AMT    DECIMAL(11,2),
  APPROVER_USER    VARCHAR(10),
  APPROVAL_STATUS  CHAR(1)       NOT NULL DEFAULT 'P',
  APPROVAL_DATE    DATE,
  CRT_USER         VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_APPROVAL_T PRIMARY KEY (APPROVAL_ID),
  CONSTRAINT FK_APPR_CLM FOREIGN KEY (CLM_NBR) REFERENCES CLAIM_T (CLM_NBR),
  CONSTRAINT FK_APPR_USER FOREIGN KEY (APPROVER_USER) REFERENCES USER_T (USER_ID)
);
CREATE INDEX APPRL1 ON APPROVAL_T (CLM_NBR);
CREATE INDEX APPRL2 ON APPROVAL_T (APPROVAL_STATUS);

-- =========================================================
-- REI MODULE
-- =========================================================
CREATE TABLE TREATY_T (
  TREATY_ID       BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  TREATY_NAME     VARCHAR(60)   NOT NULL,
  TREATY_TYPE     CHAR(2)       NOT NULL,
  EFF_DATE        DATE          NOT NULL,
  EXP_DATE        DATE,
  RETENTION_AMT   DECIMAL(13,2),
  CRT_USER        VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER        VARCHAR(10),
  UPD_TIMESTAMP   TIMESTAMP,
  CONSTRAINT PK_TREATY_T PRIMARY KEY (TREATY_ID)
);
CREATE INDEX TREATYL1 ON TREATY_T (TREATY_TYPE, EFF_DATE);

CREATE TABLE CESSION_T (
  CESSION_ID      BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  POL_NBR         VARCHAR(12)   NOT NULL,
  TREATY_ID       BIGINT        NOT NULL,
  CEDED_PCT       DECIMAL(5,2)  NOT NULL,
  CEDED_PREMIUM   DECIMAL(11,2) NOT NULL,
  CESSION_DATE    DATE          NOT NULL,
  CRT_USER        VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_CESSION_T PRIMARY KEY (CESSION_ID),
  CONSTRAINT FK_CESSION_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR),
  CONSTRAINT FK_CESSION_TREATY FOREIGN KEY (TREATY_ID) REFERENCES TREATY_T (TREATY_ID)
);
CREATE INDEX CESSIONL1 ON CESSION_T (POL_NBR);
CREATE INDEX CESSIONL2 ON CESSION_T (TREATY_ID);

CREATE TABLE RECOVERY_T (
  RECOVERY_ID      BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  CLM_NBR          VARCHAR(12)   NOT NULL,
  TREATY_ID        BIGINT        NOT NULL,
  RECOVERY_AMT     DECIMAL(11,2) NOT NULL,
  RECOVERY_STATUS  CHAR(1)       NOT NULL DEFAULT 'P',
  RECOVERY_DATE    DATE,
  CRT_USER         VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER         VARCHAR(10),
  UPD_TIMESTAMP    TIMESTAMP,
  CONSTRAINT PK_RECOVERY_T PRIMARY KEY (RECOVERY_ID),
  CONSTRAINT FK_RECOV_CLM FOREIGN KEY (CLM_NBR) REFERENCES CLAIM_T (CLM_NBR),
  CONSTRAINT FK_RECOV_TREATY FOREIGN KEY (TREATY_ID) REFERENCES TREATY_T (TREATY_ID)
);
CREATE INDEX RECOVL1 ON RECOVERY_T (CLM_NBR);
CREATE INDEX RECOVL2 ON RECOVERY_T (TREATY_ID);

-- =========================================================
-- DOC MODULE
-- =========================================================
CREATE TABLE DOCUMENT_T (
  DOCUMENT_ID    VARCHAR(14)   NOT NULL,
  DOC_TYPE       VARCHAR(15)   NOT NULL,
  DOC_TITLE      VARCHAR(60)   NOT NULL,
  IFS_PATH       VARCHAR(200)  NOT NULL,
  UPLOAD_DATE    DATE          NOT NULL,
  UPLOAD_USER    VARCHAR(10)   NOT NULL,
  CRT_USER       VARCHAR(10)   NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_DOCUMENT_T PRIMARY KEY (DOCUMENT_ID)
);
CREATE INDEX DOCUMENTL1 ON DOCUMENT_T (DOC_TYPE);
CREATE INDEX DOCUMENTL2 ON DOCUMENT_T (UPLOAD_DATE DESC);

CREATE TABLE POLICY_DOCUMENT_T (
  POL_DOC_ID     BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  POL_NBR        VARCHAR(12)  NOT NULL,
  DOCUMENT_ID    VARCHAR(14)  NOT NULL,
  LINK_DATE      DATE         NOT NULL,
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_POLICY_DOCUMENT_T PRIMARY KEY (POL_DOC_ID),
  CONSTRAINT FK_POLDOC_POL FOREIGN KEY (POL_NBR) REFERENCES POLICY_T (POL_NBR),
  CONSTRAINT FK_POLDOC_DOC FOREIGN KEY (DOCUMENT_ID) REFERENCES DOCUMENT_T (DOCUMENT_ID)
);
CREATE INDEX POLDOCL1 ON POLICY_DOCUMENT_T (POL_NBR);
CREATE INDEX POLDOCL2 ON POLICY_DOCUMENT_T (DOCUMENT_ID);

CREATE TABLE CLAIM_DOCUMENT_T (
  CLM_DOC_ID     BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  CLM_NBR        VARCHAR(12)  NOT NULL,
  DOCUMENT_ID    VARCHAR(14)  NOT NULL,
  LINK_DATE      DATE         NOT NULL,
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_CLAIM_DOCUMENT_T PRIMARY KEY (CLM_DOC_ID),
  CONSTRAINT FK_CLMDOC_CLM FOREIGN KEY (CLM_NBR) REFERENCES CLAIM_T (CLM_NBR),
  CONSTRAINT FK_CLMDOC_DOC FOREIGN KEY (DOCUMENT_ID) REFERENCES DOCUMENT_T (DOCUMENT_ID)
);
CREATE INDEX CLMDOCL1 ON CLAIM_DOCUMENT_T (CLM_NBR);
CREATE INDEX CLMDOCL2 ON CLAIM_DOCUMENT_T (DOCUMENT_ID);

-- =========================================================
-- RPT MODULE
-- =========================================================
CREATE TABLE RPT_PARM_T (
  PARM_NAME      VARCHAR(30)   NOT NULL,
  PARM_VALUE     VARCHAR(50)   NOT NULL,
  PARM_DESC      VARCHAR(100),
  UPD_USER       VARCHAR(10),
  UPD_TIMESTAMP  TIMESTAMP,
  CONSTRAINT PK_RPT_PARM_T PRIMARY KEY (PARM_NAME)
);

CREATE TABLE RPT_RUN_LOG_T (
  RUN_LOG_ID     BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  REPORT_ID      VARCHAR(10)  NOT NULL,
  RUN_DATE       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  RUN_STATUS     CHAR(1)      NOT NULL DEFAULT 'R',
  ROW_COUNT      INTEGER,
  RUN_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_RPT_RUN_LOG_T PRIMARY KEY (RUN_LOG_ID)
);
CREATE INDEX RPTRUNL1 ON RPT_RUN_LOG_T (REPORT_ID, RUN_DATE DESC);

-- =========================================================
-- AUD MODULE
-- =========================================================
CREATE TABLE AUDIT_LOG_T (
  AUDIT_LOG_ID   BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  TABLE_NAME     VARCHAR(30)   NOT NULL,
  KEY_VALUE      VARCHAR(30)   NOT NULL,
  ACTION_CD      CHAR(1)       NOT NULL,
  FIELD_NAME     VARCHAR(30),
  OLD_VALUE      VARCHAR(100),
  NEW_VALUE      VARCHAR(100),
  CHG_USER       VARCHAR(10)   NOT NULL,
  CHG_TIMESTAMP  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PROGRAM_NAME   VARCHAR(10)   NOT NULL,
  CONSTRAINT PK_AUDIT_LOG_T PRIMARY KEY (AUDIT_LOG_ID)
);
CREATE INDEX AUDLOGL1 ON AUDIT_LOG_T (TABLE_NAME, KEY_VALUE);
CREATE INDEX AUDLOGL2 ON AUDIT_LOG_T (CHG_USER, CHG_TIMESTAMP DESC);

-- =========================================================
-- SEC MODULE
-- =========================================================
CREATE TABLE USER_T (
  USER_ID          VARCHAR(10)  NOT NULL,
  USER_NAME        VARCHAR(60)  NOT NULL,
  EMAIL            VARCHAR(60),
  USER_STATUS      CHAR(1)      NOT NULL DEFAULT 'A',
  LAST_SIGNON      TIMESTAMP,
  FAILED_ATTEMPTS  SMALLINT     NOT NULL DEFAULT 0,
  CRT_USER         VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UPD_USER         VARCHAR(10),
  UPD_TIMESTAMP    TIMESTAMP,
  CONSTRAINT PK_USER_T PRIMARY KEY (USER_ID)
);
CREATE INDEX USERL1 ON USER_T (USER_STATUS);

CREATE TABLE ROLE_T (
  ROLE_ID        VARCHAR(10)  NOT NULL,
  ROLE_DESC      VARCHAR(60)  NOT NULL,
  ACTIVE_FLAG    CHAR(1)      NOT NULL DEFAULT 'Y',
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_ROLE_T PRIMARY KEY (ROLE_ID)
);

CREATE TABLE ROLE_MENU_T (
  ROLE_MENU_ID   BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  ROLE_ID        VARCHAR(10)  NOT NULL,
  MENU_OPTION    VARCHAR(10)  NOT NULL,
  ACCESS_LEVEL   CHAR(1)      NOT NULL DEFAULT 'R',
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_ROLE_MENU_T PRIMARY KEY (ROLE_MENU_ID),
  CONSTRAINT FK_ROLEMENU_ROLE FOREIGN KEY (ROLE_ID) REFERENCES ROLE_T (ROLE_ID)
);
CREATE INDEX ROLEMENUL1 ON ROLE_MENU_T (ROLE_ID, MENU_OPTION);

CREATE TABLE USER_ROLE_T (
  USER_ROLE_ID   BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
  USER_ID        VARCHAR(10)  NOT NULL,
  ROLE_ID        VARCHAR(10)  NOT NULL,
  ASSIGN_DATE    DATE         NOT NULL,
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_USER_ROLE_T PRIMARY KEY (USER_ROLE_ID),
  CONSTRAINT FK_USERROLE_USER FOREIGN KEY (USER_ID) REFERENCES USER_T (USER_ID),
  CONSTRAINT FK_USERROLE_ROLE FOREIGN KEY (ROLE_ID) REFERENCES ROLE_T (ROLE_ID)
);
CREATE INDEX USERROLL1 ON USER_ROLE_T (USER_ID);
CREATE INDEX USERROLL2 ON USER_ROLE_T (ROLE_ID);

-- =========================================================
-- SHARED
-- =========================================================
CREATE TABLE CODE_TABLE_T (
  CODE_TYPE      VARCHAR(20)  NOT NULL,
  CODE_VALUE     VARCHAR(10)  NOT NULL,
  CODE_DESC      VARCHAR(60)  NOT NULL,
  ACTIVE_FLAG    CHAR(1)      NOT NULL DEFAULT 'Y',
  CRT_USER       VARCHAR(10)  NOT NULL,
  CRT_TIMESTAMP  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT PK_CODE_TABLE_T PRIMARY KEY (CODE_TYPE, CODE_VALUE)
);
```

> **Note on table ordering:** `COMMISSION_PAYMENT_T` and `CLAIM_ADJUSTER_T`/`APPROVAL_T` reference `POLICY_T`/`USER_T`, which are created later in physical script order above for readability — in an actual deployment script, create parent tables (`USER_T`, `POLICY_T`) before dependent child tables, or add foreign keys via `ALTER TABLE ... ADD CONSTRAINT` after all `CREATE TABLE` statements run.

---

## 4. DDS Physical File (PF) Equivalents

Per architecture §3.1, DDS PFs are **not** the production standard for new PCIS tables — SQL `CREATE TABLE` is — but the following DDS source is provided as the legacy-style equivalent for migration/compatibility scenarios. Each PF below corresponds 1:1 to the SQL table of the same root name. A representative full set is shown for the core CUS/AGT/QTE/POL/CLM tables; remaining tables follow the identical conversion pattern (`VARCHAR(n)` → `n A`, `DECIMAL(p,s)` → `p s P`, `DATE` → `L`, `TIMESTAMP` → `Z`, `CHAR(n)` → `n A`).

```
*-----------------------------------------------------------*
* DDS: CUSTPF - Customer Master Physical File (CUSTOMER_T)  *
*-----------------------------------------------------------*
     A          R CUSTREC
     A            CUSTID        10A
     A            CUSTTYPE       1A
     A            CUSTNAME      60A
     A            FSTNAME       30A
     A            LSTNAME       30A
     A            DOB            L
     A            TAXID         11A
     A            CUSTSTAT       1A
     A            EMAIL         60A
     A            PHONE         15A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K CUSTID
*-----------------------------------------------------------*
* DDS: CUSCONPF - Customer Contact PF (CUSTOMER_CONTACT_T)  *
*-----------------------------------------------------------*
     A          R CUSCONREC
     A            CONTID        9B 0
     A            CUSTID        10A
     A            CONTTYPE       2A
     A            CONTVAL       60A
     A            PREFFLAG       1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K CONTID
*-----------------------------------------------------------*
* DDS: CUSADRPF - Customer Address PF (CUSTOMER_ADDRESS_T)  *
*-----------------------------------------------------------*
     A          R CUSADRREC
     A            ADDRID        9B 0
     A            CUSTID        10A
     A            ADDRTYPE       1A
     A            ADDRLN1       40A
     A            ADDRLN2       40A
     A            CITY          30A
     A            STATE          2A
     A            ZIP           10A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K ADDRID
*-----------------------------------------------------------*
* DDS: AGENTPF - Agent Master PF (AGENT_T)                  *
*-----------------------------------------------------------*
     A          R AGENTREC
     A            AGTID          8A
     A            AGTNAME       60A
     A            AGTTYPE        1A
     A            AGTSTAT        1A
     A            AGENCYCD      10A
     A            EMAIL         60A
     A            PHONE         15A
     A            HIREDT         L
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K AGTID
*-----------------------------------------------------------*
* DDS: AGTLICPF - Agent License PF (AGENT_LICENSE_T)        *
*-----------------------------------------------------------*
     A          R AGTLICREC
     A            LICID         9B 0
     A            AGTID          8A
     A            LICSTATE       2A
     A            LICNBR        20A
     A            LICEFFDT       L
     A            LICEXPDT       L
     A            LICSTAT        1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K LICID
*-----------------------------------------------------------*
* DDS: AGTCOMPF - Agent Commission Plan PF (AGENT_COMMISSION_T)*
*-----------------------------------------------------------*
     A          R AGTCOMREC
     A            COMPLANID     9B 0
     A            AGTID          8A
     A            POLTYPE        3A
     A            COMRATNEW    5  2P
     A            COMRATREN    5  2P
     A            PLANEFFDT      L
     A            PLANEXPDT      L
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K COMPLANID
*-----------------------------------------------------------*
* DDS: COMPAYPF - Commission Payment PF (COMMISSION_PAYMENT_T)*
*-----------------------------------------------------------*
     A          R COMPAYREC
     A            COMPMTID      9B 0
     A            AGTID          8A
     A            POLNBR        12A
     A            COMBASAMT   11  2P
     A            COMRATE      5  2P
     A            COMAMT       9  2P
     A            COMRUNDT       L
     A            COMSTAT        1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K COMPMTID
*-----------------------------------------------------------*
* DDS: QUOTEPF - Quote Header PF (QUOTE_T)                  *
*-----------------------------------------------------------*
     A          R QUOTEREC
     A            QUOTEID       12A
     A            CUSTID        10A
     A            AGTID          8A
     A            POLTYPE        3A
     A            QUOTEDT        L
     A            QUOTEXPDT      L
     A            QUOTEPREM   11  2P
     A            QUOTESTAT      1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K QUOTEID
*-----------------------------------------------------------*
* DDS: RISKPF - Generic Risk PF (RISK_T)                    *
*-----------------------------------------------------------*
     A          R RISKREC
     A            RISKID        12A
     A            QUOTEID       12A
     A            RISKTYPE       1A
     A            TERRCD         6A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K RISKID
*-----------------------------------------------------------*
* DDS: VEHPF - Vehicle Risk PF (VEHICLE_T)                  *
*-----------------------------------------------------------*
     A          R VEHREC
     A            VEHID         12A
     A            RISKID        12A
     A            VIN           17A
     A            MAKE          20A
     A            MODEL         20A
     A            MODELYR        4S 0
     A            USAGETYPE      2A
     A            ANNMILE       9S 0
     A            ACV          11  2P
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K VEHID
*-----------------------------------------------------------*
* DDS: PROPPF - Property Risk PF (PROPERTY_T)               *
*-----------------------------------------------------------*
     A          R PROPREC
     A            PROPID        12A
     A            RISKID        12A
     A            PROPTYPE       2A
     A            ADDRLN1       40A
     A            CITY          30A
     A            STATE          2A
     A            ZIP           10A
     A            YRBUILT        4S 0
     A            SQFOOT         9S 0
     A            CONSTTYPE      2A
     A            REPLVAL      13  2P
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K PROPID
*-----------------------------------------------------------*
* DDS: POLPF - Policy Header PF (POLICY_T)                  *
*-----------------------------------------------------------*
     A          R POLREC
     A            POLNBR        12A
     A            POLTYPE        3A
     A            CUSTID        10A
     A            AGTID          8A
     A            QUOTEID       12A
     A            POLEFFDT       L
     A            POLEXPDT       L
     A            POLSTAT        1A
     A            PREMANN     11  2P
     A            UWDEC          1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K POLNBR
*-----------------------------------------------------------*
* DDS: COVPF - Coverage Line PF (COVERAGE_T)                *
*-----------------------------------------------------------*
     A          R COVREC
     A            COVID         14A
     A            POLNBR        12A
     A            COVTYPECD      5A
     A            LIMITAMT    11  2P
     A            PREMAMT      9  2P
     A            COVEFFDT       L
     A            COVEXPDT       L
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K COVID
*-----------------------------------------------------------*
* DDS: DEDUCTPF - Deductible Terms PF (DEDUCTIBLE_T)        *
*-----------------------------------------------------------*
     A          R DEDUCTREC
     A            DEDUCTID      9B 0
     A            COVID         14A
     A            DEDTYPE        1A
     A            DEDAMT       9  2P
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K DEDUCTID
*-----------------------------------------------------------*
* DDS: ENDTPF - Endorsement PF (ENDORSEMENT_T)              *
*-----------------------------------------------------------*
     A          R ENDTREC
     A            ENDTID        9B 0
     A            POLNBR        12A
     A            ENDTTYPE      10A
     A            ENDTDESC     100A
     A            ENDTDT         L
     A            PREMCHG      9  2P
     A            ENDTSTAT       1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K ENDTID
*-----------------------------------------------------------*
* DDS: POLHISPF - Policy History PF (POLICY_HISTORY_T)      *
*-----------------------------------------------------------*
     A          R POLHISREC
     A            POLHISID      9B 0
     A            POLNBR        12A
     A            EVENTTYPE      3A
     A            EVENTDT        L
     A            NEWSTAT        1A
     A            EVENTDESC    100A
     A            CRTUSER       10A
     A            CRTTS          Z
     A          K POLHISID
*-----------------------------------------------------------*
* DDS: BILSCHPF - Billing Schedule PF (BILLING_SCHEDULE_T)  *
*-----------------------------------------------------------*
     A          R BILSCHREC
     A            BILSCHID      9B 0
     A            POLNBR        12A
     A            BILPLANID     9B 0
     A            INSTLNBR       4S 0
     A            DUEDATE        L
     A            AMTDUE       9  2P
     A            AMTPAID      9  2P
     A            SCHDSTAT       1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K BILSCHID
*-----------------------------------------------------------*
* DDS: PAYPF - Payment Header PF (PAYMENT_T)                *
*-----------------------------------------------------------*
     A          R PAYREC
     A            PAYID         14A
     A            POLNBR        12A
     A            CUSTID        10A
     A            PAYDATE        L
     A            PAYMETHOD      2A
     A            PAYAMT      11  2P
     A            PAYSTAT        1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K PAYID
*-----------------------------------------------------------*
* DDS: CLMPF - Claim Header PF (CLAIM_T)                    *
*-----------------------------------------------------------*
     A          R CLMREC
     A            CLMNBR        12A
     A            POLNBR        12A
     A            LOSSDATE       L
     A            REPDATE        L
     A            LOSSTYPE       3A
     A            LOSSDESC     200A
     A            CLMSTAT        1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K CLMNBR
*-----------------------------------------------------------*
* DDS: CLMRESPF - Claim Reserve History PF (CLAIM_RESERVE_T)*
*-----------------------------------------------------------*
     A          R CLMRESREC
     A            RESID         9B 0
     A            CLMNBR        12A
     A            RESDATE        L
     A            RESAMT      11  2P
     A            RESTYPE        2A
     A            CRTUSER       10A
     A            CRTTS          Z
     A          K RESID
*-----------------------------------------------------------*
* DDS: CLMPMTPF - Claim Payment Detail PF (CLAIM_PAYMENT_T) *
*-----------------------------------------------------------*
     A          R CLMPMTREC
     A            CLMPMTID      14A
     A            CLMNBR        12A
     A            PAYEENAME     60A
     A            PMTDATE        L
     A            PMTAMT      11  2P
     A            PMTTYPE        2A
     A            PMTSTAT        1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K CLMPMTID
*-----------------------------------------------------------*
* DDS: CLMNOTPF - Claim Note PF (CLAIM_NOTE_T)              *
*-----------------------------------------------------------*
     A          R CLMNOTREC
     A            NOTEID        9B 0
     A            CLMNBR        12A
     A            NOTEDATE       Z
     A            NOTEUSER      10A
     A            NOTETEXT     500A
     A            CRTUSER       10A
     A            CRTTS          Z
     A          K NOTEID
*-----------------------------------------------------------*
* DDS: AUDLOGPF - Audit Log PF (AUDIT_LOG_T)                *
*-----------------------------------------------------------*
     A          R AUDLOGREC
     A            AUDID         9B 0
     A            TABNAME       30A
     A            KEYVAL        30A
     A            ACTNCD         1A
     A            FLDNAME       30A
     A            OLDVAL       100A
     A            NEWVAL       100A
     A            CHGUSER       10A
     A            CHGTS          Z
     A            PGMNAME       10A
     A          K AUDID
*-----------------------------------------------------------*
* DDS: USERPF - Application User PF (USER_T)                *
*-----------------------------------------------------------*
     A          R USERREC
     A            USERID        10A
     A            USERNAME      60A
     A            EMAIL         60A
     A            USERSTAT       1A
     A            LASTSIGN       Z
     A            FAILATMP       4S 0
     A            CRTUSER       10A
     A            CRTTS          Z
     A            UPDUSER       10A
     A            UPDTS          Z
     A          K USERID
*-----------------------------------------------------------*
* DDS: ROLEPF - Security Role PF (ROLE_T)                   *
*-----------------------------------------------------------*
     A          R ROLEREC
     A            ROLEID        10A
     A            ROLEDESC      60A
     A            ACTVFLAG       1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A          K ROLEID
*-----------------------------------------------------------*
* DDS: CODETABPF - Generic Code Table PF (CODE_TABLE_T)     *
*-----------------------------------------------------------*
     A          R CODETABREC
     A            CODETYPE      20A
     A            CODEVAL       10A
     A            CODEDESC      60A
     A            ACTVFLAG       1A
     A            CRTUSER       10A
     A            CRTTS          Z
     A          K CODETYPE
     A          K CODEVAL
```

**DDS conversion pattern for all remaining tables** (COVERAGE_TYPE_T, QUOTE_COVERAGE_T, VEHICLE_FEATURE_T, PROPERTY_FEATURE_T, UW_DECISION_T, UW_REFERRAL_T, UW_RULE_T, POLICY_VEHICLE_T, POLICY_PROPERTY_T, POLICY_DOCUMENT_T, RATE_TABLE_T, RATE_FACTOR_T, PREMIUM_CALC_T, BILLING_PLAN_T, INVOICE_T, INVOICE_LINE_T, PAYMENT_APPLICATION_T, REFUND_T, CLAIM_DOCUMENT_T, CLAIM_ADJUSTER_T, APPROVAL_T, TREATY_T, CESSION_T, RECOVERY_T, DOCUMENT_T, RPT_PARM_T, RPT_RUN_LOG_T, ROLE_MENU_T, USER_ROLE_T):

| SQL Type | DDS Equivalent |
|---|---|
| `VARCHAR(n)` / `CHAR(n)` | `n A` |
| `SMALLINT` | `4S 0` |
| `INTEGER` | `9S 0` |
| `BIGINT` / `BIGINT GENERATED ALWAYS AS IDENTITY` | `9B 0` |
| `DECIMAL(p,s)` | `p s P` |
| `DATE` | `L` |
| `TIMESTAMP` | `Z` |
| `PRIMARY KEY` | `K` keyword line(s) at end of record format |

Apply this mapping column-by-column against each table's definition in Section 2 to produce the equivalent PF source member.

---

## 5. Implementation Notes

- **Foreign keys to `USER_T`/`POLICY_T` created later in script order:** `CLAIM_ADJUSTER_T`, `APPROVAL_T`, and `COMMISSION_PAYMENT_T` reference tables defined later in the same script for readability grouping by module. In a real deployment, run `CREATE TABLE` statements in dependency order (parents first), or create all tables without FKs first and add constraints via `ALTER TABLE ... ADD CONSTRAINT` in a second pass.
- **Journaling:** All tables should be journaled (`STRJRNPF`) for commitment control and the audit-trail/optimistic-locking patterns already used in POL001A/POL002A.
- **AUDIT_LOG_T** is intentionally not foreign-keyed to business tables — it must remain insertable even if the source row is later deleted/archived, preserving an immutable, append-only audit record.
- **CODE_TABLE_T** and **RPT_PARM_T** are reference/configuration tables — seed with initial rows (e.g., `CODE_TYPE='CANREASON'`) before go-live, consistent with the POL open item recommending this design.
- This design directly extends the structures already implemented in `POL001A.cbl` and documented in `POL_Module_Design_Document.md` / `CLM_Module_Design_Document.md` — no naming or typing conflicts were introduced.
