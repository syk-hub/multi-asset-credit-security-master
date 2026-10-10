-- Batch 02 RAW preparation.
-- Run this before uploading the three files to the named stage.

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER_BATCH_02;
USE SCHEMA RAW;

CREATE OR REPLACE FILE FORMAT JSON_FORMAT
  TYPE = 'JSON'
  COMPRESSION = 'AUTO'
  ENABLE_OCTAL = FALSE;

CREATE OR REPLACE FILE FORMAT CSV_FORMAT
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  EMPTY_FIELD_AS_NULL = TRUE
  TRIM_SPACE = TRUE;

CREATE STAGE IF NOT EXISTS CSM_INTERNAL_STAGE;

CREATE TABLE IF NOT EXISTS VENDOR_ALPHA_RAW (
  payload VARIANT,
  source_file STRING,
  source_row_number NUMBER,
  load_ts TIMESTAMP_TZ
);

CREATE TABLE IF NOT EXISTS VENDOR_BETA_RAW (
  payload VARIANT,
  source_file STRING,
  source_row_number NUMBER,
  load_ts TIMESTAMP_TZ
);

CREATE TABLE IF NOT EXISTS LEGACY_SECURITY_MASTER_RAW (
  vendor_security_id VARCHAR,
  synthetic_cusip VARCHAR,
  issuer_name VARCHAR,
  instrument_name VARCHAR,
  instrument_type VARCHAR,
  rating VARCHAR,
  rating_agency VARCHAR,
  source_system VARCHAR,
  source_file STRING,
  source_row_number NUMBER,
  load_ts TIMESTAMP_TZ
);

-- Stop here. Upload these local files through Snowsight to the
-- CREDIT_SECURITY_MASTER_BATCH_02.RAW.CSM_INTERNAL_STAGE under the
-- batch_02/ folder before running 02b_raw_loading.sql.
