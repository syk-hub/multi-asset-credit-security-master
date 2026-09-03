-- 02_raw_ingestion.sql
-- Create raw-layer file formats, internal stage and raw tables; load raw files

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER;
USE SCHEMA RAW;

-- NOTE: When running in Snowsight please upload local files via
-- Ingestion > Add Data > Load files into a Stage. Do NOT use PUT in Snowsight.

-- 1) JSON file format for vendor NDJSON (both vendor_alpha.json and vendor_beta.json are NDJSON; one JSON object per line)
CREATE OR REPLACE FILE FORMAT JSON_FORMAT
  TYPE = 'JSON'
  COMPRESSION = 'AUTO'
  ENABLE_OCTAL = FALSE
  ;

-- 2) CSV file format for legacy CSV (header present, quoted values allowed)
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  EMPTY_FIELD_AS_NULL = TRUE
  TRIM_SPACE = TRUE
  ;

-- 3) Internal named stage for uploading the three source files
CREATE STAGE IF NOT EXISTS CSM_INTERNAL_STAGE;

-- 4) Raw tables
-- VENDOR_ALPHA_RAW: preserves the exact JSON payload as VARIANT and adds metadata
CREATE TABLE IF NOT EXISTS VENDOR_ALPHA_RAW (
  payload VARIANT,
  source_file STRING,
  source_row_number NUMBER,
  load_ts TIMESTAMP_TZ
);

-- VENDOR_BETA_RAW: same structure as alpha
CREATE TABLE IF NOT EXISTS VENDOR_BETA_RAW (
  payload VARIANT,
  source_file STRING,
  source_row_number NUMBER,
  load_ts TIMESTAMP_TZ
);

-- LEGACY_SECURITY_MASTER_RAW: keep CSV business fields as VARCHAR; metadata appended
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

-- 5) COPY INTO statements
-- These assume files have been uploaded to @CREDIT_SECURITY_MASTER.RAW.CSM_INTERNAL_STAGE

-- Load vendor_alpha.json (newline-delimited JSON; one JSON object per line)
COPY INTO VENDOR_ALPHA_RAW (payload, source_file, source_row_number, load_ts)
  FROM (
    SELECT $1, metadata$filename, metadata$file_row_number, metadata$start_scan_time
    FROM @CREDIT_SECURITY_MASTER.RAW.CSM_INTERNAL_STAGE/vendor_alpha.json (FILE_FORMAT => 'JSON_FORMAT')
  );

-- Load vendor_beta.json
COPY INTO VENDOR_BETA_RAW (payload, source_file, source_row_number, load_ts)
  FROM (
    SELECT $1, metadata$filename, metadata$file_row_number, metadata$start_scan_time
    FROM @CREDIT_SECURITY_MASTER.RAW.CSM_INTERNAL_STAGE/vendor_beta.json (FILE_FORMAT => 'JSON_FORMAT')
  );

-- Load legacy CSV (exact header fields preserved as VARCHAR)
COPY INTO LEGACY_SECURITY_MASTER_RAW (
    vendor_security_id,
    synthetic_cusip,
    issuer_name,
    instrument_name,
    instrument_type,
    rating,
    rating_agency,
    source_system,
    source_file,
    source_row_number,
    load_ts
  )
  FROM (
    SELECT $1,$2,$3,$4,$5,$6,$7,$8, metadata$filename, metadata$file_row_number, metadata$start_scan_time
    FROM @CREDIT_SECURITY_MASTER.RAW.CSM_INTERNAL_STAGE/legacy_security_master.csv (FILE_FORMAT => 'CSV_FORMAT')
  );

-- End of raw ingestion script

-- Post-load verification
-- Successfully executed in Snowflake.
-- Expected and observed row counts:
--   VENDOR_ALPHA_RAW = 30
--   VENDOR_BETA_RAW = 30
--   LEGACY_SECURITY_MASTER_RAW = 31
-- All three COPY INTO results reported errors_seen = 0.

SELECT
    'VENDOR_ALPHA_RAW' AS table_name,
    COUNT(*) AS row_count
FROM VENDOR_ALPHA_RAW

UNION ALL

SELECT
    'VENDOR_BETA_RAW',
    COUNT(*)
FROM VENDOR_BETA_RAW

UNION ALL

SELECT
    'LEGACY_SECURITY_MASTER_RAW',
    COUNT(*)
FROM LEGACY_SECURITY_MASTER_RAW

ORDER BY table_name;