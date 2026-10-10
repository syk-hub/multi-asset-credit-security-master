-- Batch 02 RAW loading.
-- Run only after the three files are uploaded beneath batch_02/ on the stage.
-- Expected input row counts are fixture counts; no execution is asserted here.

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER_BATCH_02;
USE SCHEMA RAW;

COPY INTO VENDOR_ALPHA_RAW (payload, source_file, source_row_number, load_ts)
  FROM (
    SELECT $1, metadata$filename, metadata$file_row_number, metadata$start_scan_time
    FROM @CREDIT_SECURITY_MASTER_BATCH_02.RAW.CSM_INTERNAL_STAGE/batch_02/vendor_alpha.json
      (FILE_FORMAT => 'JSON_FORMAT')
  );

COPY INTO VENDOR_BETA_RAW (payload, source_file, source_row_number, load_ts)
  FROM (
    SELECT $1, metadata$filename, metadata$file_row_number, metadata$start_scan_time
    FROM @CREDIT_SECURITY_MASTER_BATCH_02.RAW.CSM_INTERNAL_STAGE/batch_02/vendor_beta.json
      (FILE_FORMAT => 'JSON_FORMAT')
  );

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
    SELECT $1,$2,$3,$4,$5,$6,$7,$8,
           metadata$filename, metadata$file_row_number, metadata$start_scan_time
    FROM @CREDIT_SECURITY_MASTER_BATCH_02.RAW.CSM_INTERNAL_STAGE/batch_02/legacy_security_master.csv
      (FILE_FORMAT => 'CSV_FORMAT')
  );

-- Report expected versus observed input counts; this query does not assert
-- that loading succeeded.
SELECT
  'VENDOR_ALPHA_RAW' AS table_name,
  14 AS expected_input_rows,
  COUNT(*) AS observed_rows
FROM VENDOR_ALPHA_RAW

UNION ALL

SELECT
  'VENDOR_BETA_RAW',
  10,
  COUNT(*)
FROM VENDOR_BETA_RAW

UNION ALL

SELECT
  'LEGACY_SECURITY_MASTER_RAW',
  7,
  COUNT(*)
FROM LEGACY_SECURITY_MASTER_RAW
ORDER BY table_name;
