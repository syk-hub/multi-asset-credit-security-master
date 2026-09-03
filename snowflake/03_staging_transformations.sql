-- 03_staging_transformations.sql
-- Create STAGING views that parse and standardize RAW payloads while preserving raw values

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER;
USE SCHEMA STAGING;

-- STG_VENDOR_ALPHA: extract fields from raw VARIANT payload and apply standardization rules
CREATE OR REPLACE VIEW STG_VENDOR_ALPHA AS
SELECT
  -- canonical and standardized fields
  UPPER(NULLIF(TRIM(payload:"source_system"::STRING), '')) AS source_system,
  NULLIF(TRIM(payload:"vendor_security_id"::STRING), '') AS vendor_security_id,
  NULLIF(TRIM(payload:"issuer_name"::STRING), '') AS issuer_name,
  NULLIF(TRIM(payload:"instrument_name"::STRING), '') AS instrument_name,
  UPPER(NULLIF(TRIM(payload:"instrument_type"::STRING), '')) AS instrument_type,
  NULLIF(TRIM(payload:"synthetic_cusip"::STRING), '') AS synthetic_cusip,
  NULLIF(TRIM(payload:"synthetic_isin"::STRING), '') AS synthetic_isin,
  UPPER(NULLIF(TRIM(payload:"currency"::STRING), '')) AS currency,

  -- raw and typed dates
  payload:"issue_date"::STRING AS issue_date_raw,
  TRY_TO_DATE(payload:"issue_date"::STRING) AS issue_date,
  payload:"maturity_date"::STRING AS maturity_date_raw,
  TRY_TO_DATE(payload:"maturity_date"::STRING) AS maturity_date,

  -- coupon
  payload:"coupon_rate"::STRING AS coupon_rate_raw,
  TRY_TO_DECIMAL(payload:"coupon_rate"::STRING, 10, 4) AS coupon_rate,
  NULLIF(TRIM(payload:"coupon_type"::STRING), '') AS coupon_type,

  NULLIF(TRIM(payload:"seniority"::STRING), '') AS seniority,
  payload:"secured_flag"::STRING AS secured_flag_raw,
  TRY_TO_BOOLEAN(payload:"secured_flag"::STRING) AS secured_flag,

  UPPER(NULLIF(TRIM(payload:"credit_status"::STRING), '')) AS credit_status,
  UPPER(NULLIF(TRIM(payload:"rating"::STRING), '')) AS rating,
  UPPER(NULLIF(TRIM(payload:"rating_agency"::STRING), '')) AS rating_agency,

  -- effective dating and ingestion timestamp from payload
  payload:"effective_from"::STRING AS effective_from_raw,
  TRY_TO_DATE(payload:"effective_from"::STRING) AS effective_from,
  payload:"ingestion_timestamp"::STRING AS ingestion_timestamp_raw,
  TRY_TO_TIMESTAMP_TZ(payload:"ingestion_timestamp"::STRING) AS ingestion_timestamp,

  -- RAW ingestion metadata
  source_file,
  source_row_number,
  load_ts,

  -- source record key for traceability
  UPPER(NULLIF(TRIM(payload:"source_system"::STRING), '')) || '|' || NULLIF(TRIM(payload:"vendor_security_id"::STRING), '') AS source_record_key
FROM RAW.VENDOR_ALPHA_RAW;


-- STG_VENDOR_BETA: same transformations applied to vendor BETA
CREATE OR REPLACE VIEW STG_VENDOR_BETA AS
SELECT
  UPPER(NULLIF(TRIM(payload:"source_system"::STRING), '')) AS source_system,
  NULLIF(TRIM(payload:"vendor_security_id"::STRING), '') AS vendor_security_id,
  NULLIF(TRIM(payload:"issuer_name"::STRING), '') AS issuer_name,
  NULLIF(TRIM(payload:"instrument_name"::STRING), '') AS instrument_name,
  UPPER(NULLIF(TRIM(payload:"instrument_type"::STRING), '')) AS instrument_type,
  NULLIF(TRIM(payload:"synthetic_cusip"::STRING), '') AS synthetic_cusip,
  NULLIF(TRIM(payload:"synthetic_isin"::STRING), '') AS synthetic_isin,
  UPPER(NULLIF(TRIM(payload:"currency"::STRING), '')) AS currency,

  payload:"issue_date"::STRING AS issue_date_raw,
  TRY_TO_DATE(payload:"issue_date"::STRING) AS issue_date,
  payload:"maturity_date"::STRING AS maturity_date_raw,
  TRY_TO_DATE(payload:"maturity_date"::STRING) AS maturity_date,

  payload:"coupon_rate"::STRING AS coupon_rate_raw,
  TRY_TO_DECIMAL(payload:"coupon_rate"::STRING, 10, 4) AS coupon_rate,
  NULLIF(TRIM(payload:"coupon_type"::STRING), '') AS coupon_type,

  NULLIF(TRIM(payload:"seniority"::STRING), '') AS seniority,
  payload:"secured_flag"::STRING AS secured_flag_raw,
  TRY_TO_BOOLEAN(payload:"secured_flag"::STRING) AS secured_flag,

  UPPER(NULLIF(TRIM(payload:"credit_status"::STRING), '')) AS credit_status,
  UPPER(NULLIF(TRIM(payload:"rating"::STRING), '')) AS rating,
  UPPER(NULLIF(TRIM(payload:"rating_agency"::STRING), '')) AS rating_agency,

  payload:"effective_from"::STRING AS effective_from_raw,
  TRY_TO_DATE(payload:"effective_from"::STRING) AS effective_from,
  payload:"ingestion_timestamp"::STRING AS ingestion_timestamp_raw,
  TRY_TO_TIMESTAMP_TZ(payload:"ingestion_timestamp"::STRING) AS ingestion_timestamp,

  source_file,
  source_row_number,
  load_ts,

  UPPER(NULLIF(TRIM(payload:"source_system"::STRING), '')) || '|' || NULLIF(TRIM(payload:"vendor_security_id"::STRING), '') AS source_record_key
FROM RAW.VENDOR_BETA_RAW;


-- STG_LEGACY_SECURITY_MASTER: standardize available legacy CSV columns and add NULL placeholders
CREATE OR REPLACE VIEW STG_LEGACY_SECURITY_MASTER AS
SELECT
  UPPER(NULLIF(TRIM(source_system), '')) AS source_system,
  NULLIF(TRIM(vendor_security_id), '') AS vendor_security_id,
  NULLIF(TRIM(issuer_name), '') AS issuer_name,
  NULLIF(TRIM(instrument_name), '') AS instrument_name,
  UPPER(NULLIF(TRIM(instrument_type), '')) AS instrument_type,
  NULLIF(TRIM(synthetic_cusip), '') AS synthetic_cusip,
  -- legacy has no ISIN
  NULL::VARCHAR AS synthetic_isin,
  -- legacy may not provide currency
  NULL::VARCHAR AS currency,

  -- missing date/numeric fields from legacy preserved as NULLs
  NULL::STRING AS issue_date_raw,
  NULL::DATE AS issue_date,
  NULL::STRING AS maturity_date_raw,
  NULL::DATE AS maturity_date,

  NULL::STRING AS coupon_rate_raw,
  NULL::NUMBER(10,4) AS coupon_rate,
  NULL::VARCHAR AS coupon_type,

  NULL::VARCHAR AS seniority,
  NULL::STRING AS secured_flag_raw,
  NULL::BOOLEAN AS secured_flag,

  NULL::VARCHAR AS credit_status,
  UPPER(NULLIF(TRIM(rating), '')) AS rating,
  UPPER(NULLIF(TRIM(rating_agency), '')) AS rating_agency,

  NULL::STRING AS effective_from_raw,
  NULL::DATE AS effective_from,
  NULL::STRING AS ingestion_timestamp_raw,
  NULL::TIMESTAMP_TZ AS ingestion_timestamp,

  source_file,
  source_row_number,
  load_ts,

  UPPER(NULLIF(TRIM(source_system), '')) || '|' || NULLIF(TRIM(vendor_security_id), '') AS source_record_key
FROM RAW.LEGACY_SECURITY_MASTER_RAW;


-- ALL_SOURCE_RECORDS: union all vendor and legacy staging views (identical column order)
CREATE OR REPLACE VIEW ALL_SOURCE_RECORDS AS
SELECT
  source_system,
  vendor_security_id,
  issuer_name,
  instrument_name,
  instrument_type,
  synthetic_cusip,
  synthetic_isin,
  currency,
  issue_date_raw,
  issue_date,
  maturity_date_raw,
  maturity_date,
  coupon_rate_raw,
  coupon_rate,
  coupon_type,
  seniority,
  secured_flag_raw,
  secured_flag,
  credit_status,
  rating,
  rating_agency,
  effective_from_raw,
  effective_from,
  ingestion_timestamp_raw,
  ingestion_timestamp,
  source_file,
  source_row_number,
  load_ts,
  source_record_key
FROM STG_VENDOR_ALPHA
UNION ALL
SELECT
  source_system,
  vendor_security_id,
  issuer_name,
  instrument_name,
  instrument_type,
  synthetic_cusip,
  synthetic_isin,
  currency,
  issue_date_raw,
  issue_date,
  maturity_date_raw,
  maturity_date,
  coupon_rate_raw,
  coupon_rate,
  coupon_type,
  seniority,
  secured_flag_raw,
  secured_flag,
  credit_status,
  rating,
  rating_agency,
  effective_from_raw,
  effective_from,
  ingestion_timestamp_raw,
  ingestion_timestamp,
  source_file,
  source_row_number,
  load_ts,
  source_record_key
FROM STG_VENDOR_BETA
UNION ALL
SELECT
  source_system,
  vendor_security_id,
  issuer_name,
  instrument_name,
  instrument_type,
  synthetic_cusip,
  synthetic_isin,
  currency,
  issue_date_raw,
  issue_date,
  maturity_date_raw,
  maturity_date,
  coupon_rate_raw,
  coupon_rate,
  coupon_type,
  seniority,
  secured_flag_raw,
  secured_flag,
  credit_status,
  rating,
  rating_agency,
  effective_from_raw,
  effective_from,
  ingestion_timestamp_raw,
  ingestion_timestamp,
  source_file,
  source_row_number,
  load_ts,
  source_record_key
FROM STG_LEGACY_SECURITY_MASTER;


-- Verification queries
-- Verification: consolidated counts
SELECT 'STG_VENDOR_ALPHA' AS view_name, COUNT(*) AS row_count FROM STG_VENDOR_ALPHA
UNION ALL
SELECT 'STG_VENDOR_BETA' AS view_name, COUNT(*) AS row_count FROM STG_VENDOR_BETA
UNION ALL
SELECT 'STG_LEGACY_SECURITY_MASTER' AS view_name, COUNT(*) AS row_count FROM STG_LEGACY_SECURITY_MASTER
UNION ALL
SELECT 'ALL_SOURCE_RECORDS' AS view_name, COUNT(*) AS row_count FROM ALL_SOURCE_RECORDS;

-- Sample: five rows ordered by source_system and vendor_security_id
SELECT * FROM ALL_SOURCE_RECORDS
ORDER BY source_system, vendor_security_id
LIMIT 5;
