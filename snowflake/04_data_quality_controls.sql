-- 04_data_quality_controls.sql
-- CONTROL-layer data quality views over STAGING.ALL_SOURCE_RECORDS

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER;
USE SCHEMA CONTROL;

-- DQ_EXCEPTIONS: row-level exception list. One row per failed rule per source record.
CREATE OR REPLACE VIEW DQ_EXCEPTIONS AS
WITH src AS (
  SELECT *,
         COUNT(*) OVER (PARTITION BY source_record_key) AS dup_cnt
  FROM CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS
)

-- Rule blocks below must return identical column types and order.
SELECT
  CAST('DQ001' AS VARCHAR) AS rule_id,
  CAST('Missing source system' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('source_system' AS VARCHAR) AS field_name,
  CAST(source_system AS VARCHAR) AS raw_value,
  CAST('Missing source_system' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE source_system IS NULL

UNION ALL

SELECT
  CAST('DQ002' AS VARCHAR) AS rule_id,
  CAST('Missing vendor security id' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('vendor_security_id' AS VARCHAR) AS field_name,
  CAST(vendor_security_id AS VARCHAR) AS raw_value,
  CAST('Missing vendor_security_id' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE vendor_security_id IS NULL

UNION ALL

SELECT
  CAST('DQ003' AS VARCHAR) AS rule_id,
  CAST('Missing synthetic identifiers' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('synthetic_identifiers' AS VARCHAR) AS field_name,
  CAST(CONCAT('CUSIP=', COALESCE(synthetic_cusip,''), ';ISIN=', COALESCE(synthetic_isin,'')) AS VARCHAR) AS raw_value,
  CAST('Both synthetic_cusip and synthetic_isin are NULL' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE synthetic_cusip IS NULL
  AND synthetic_isin IS NULL

UNION ALL

SELECT
  CAST('DQ004' AS VARCHAR) AS rule_id,
  CAST('Invalid issue date' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('issue_date_raw' AS VARCHAR) AS field_name,
  CAST(issue_date_raw AS VARCHAR) AS raw_value,
  CAST('Non-empty issue_date_raw could not be parsed to DATE' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE issue_date_raw IS NOT NULL
  AND TRIM(issue_date_raw) <> ''
  AND issue_date IS NULL

UNION ALL

SELECT
  CAST('DQ005' AS VARCHAR) AS rule_id,
  CAST('Invalid maturity date' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('maturity_date_raw' AS VARCHAR) AS field_name,
  CAST(maturity_date_raw AS VARCHAR) AS raw_value,
  CAST('Non-empty maturity_date_raw could not be parsed to DATE' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE maturity_date_raw IS NOT NULL
  AND TRIM(maturity_date_raw) <> ''
  AND maturity_date IS NULL

UNION ALL

SELECT
  CAST('DQ006' AS VARCHAR) AS rule_id,
  CAST('Invalid effective_from date' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('effective_from_raw' AS VARCHAR) AS field_name,
  CAST(effective_from_raw AS VARCHAR) AS raw_value,
  CAST('Non-empty effective_from_raw could not be parsed to DATE' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE effective_from_raw IS NOT NULL
  AND TRIM(effective_from_raw) <> ''
  AND effective_from IS NULL

UNION ALL

SELECT
  CAST('DQ007' AS VARCHAR) AS rule_id,
  CAST('Invalid coupon rate' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('coupon_rate_raw' AS VARCHAR) AS field_name,
  CAST(coupon_rate_raw AS VARCHAR) AS raw_value,
  CAST('Non-empty coupon_rate_raw could not be parsed to DECIMAL' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE coupon_rate_raw IS NOT NULL
  AND TRIM(coupon_rate_raw) <> ''
  AND coupon_rate IS NULL

UNION ALL

SELECT
  CAST('DQ008' AS VARCHAR) AS rule_id,
  CAST('Invalid secured flag' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('secured_flag_raw' AS VARCHAR) AS field_name,
  CAST(secured_flag_raw AS VARCHAR) AS raw_value,
  CAST('Non-empty secured_flag_raw could not be parsed to BOOLEAN' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE secured_flag_raw IS NOT NULL
  AND TRIM(secured_flag_raw) <> ''
  AND secured_flag IS NULL

UNION ALL

SELECT
  CAST('DQ009' AS VARCHAR) AS rule_id,
  CAST('Invalid ingestion timestamp' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('ingestion_timestamp_raw' AS VARCHAR) AS field_name,
  CAST(ingestion_timestamp_raw AS VARCHAR) AS raw_value,
  CAST('Non-empty ingestion_timestamp_raw could not be parsed to TIMESTAMP_TZ' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE ingestion_timestamp_raw IS NOT NULL
  AND TRIM(ingestion_timestamp_raw) <> ''
  AND ingestion_timestamp IS NULL

UNION ALL

SELECT
  CAST('DQ010' AS VARCHAR) AS rule_id,
  CAST('Invalid date chronology' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('maturity_date' AS VARCHAR) AS field_name,
  CAST(CONCAT('issue_date=', TO_VARCHAR(issue_date), ';maturity_date=', TO_VARCHAR(maturity_date)) AS VARCHAR) AS raw_value,
  CAST('maturity_date is not after issue_date' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE issue_date IS NOT NULL
  AND maturity_date IS NOT NULL
  AND maturity_date <= issue_date

UNION ALL

SELECT
  CAST('DQ011' AS VARCHAR) AS rule_id,
  CAST('Duplicate source record key' AS VARCHAR) AS rule_name,
  CAST('ERROR' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('source_record_key' AS VARCHAR) AS field_name,
  CAST(source_record_key AS VARCHAR) AS raw_value,
  CAST(CONCAT('Duplicate source_record_key; count=', TO_VARCHAR(dup_cnt)) AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE source_record_key IS NOT NULL
  AND dup_cnt > 1

UNION ALL

SELECT
  CAST('DQ012' AS VARCHAR) AS rule_id,
  CAST('Implausible coupon rate' AS VARCHAR) AS rule_name,
  CAST('WARNING' AS VARCHAR) AS severity,
  CAST(source_system AS VARCHAR) AS source_system,
  CAST(vendor_security_id AS VARCHAR) AS vendor_security_id,
  CAST(source_record_key AS VARCHAR) AS source_record_key,
  CAST('coupon_rate' AS VARCHAR) AS field_name,
  CAST(TO_VARCHAR(coupon_rate) AS VARCHAR) AS raw_value,
  CAST('Coupon rate is below 0 or above 30' AS VARCHAR) AS issue_description,
  CAST(source_file AS VARCHAR) AS source_file,
  CAST(source_row_number AS NUMBER) AS source_row_number,
  CAST(load_ts AS TIMESTAMP_TZ) AS load_ts
FROM src
WHERE coupon_rate IS NOT NULL
  AND (coupon_rate < 0 OR coupon_rate > 30)
;


-- DQ_SUMMARY: aggregated exception counts
CREATE OR REPLACE VIEW DQ_SUMMARY AS
SELECT
  rule_id,
  rule_name,
  severity,
  source_system,
  COUNT(*) AS exception_count,
  COUNT(
    DISTINCT COALESCE(source_file, '<NULL_FILE>')
    || '|'
    || COALESCE(TO_VARCHAR(source_row_number), '<NULL_ROW>')
  ) AS distinct_record_count
FROM DQ_EXCEPTIONS
GROUP BY rule_id, rule_name, severity, source_system;


-- Verification queries
-- 1) summary ordered
SELECT * FROM DQ_SUMMARY
ORDER BY severity, rule_id, source_system;

-- 2) detailed exceptions
SELECT * FROM DQ_EXCEPTIONS
ORDER BY rule_id, source_system, vendor_security_id, source_row_number;

-- 3) reconciliation: total records, records with exceptions, total exceptions, records without exceptions
WITH
  total_records AS (
    SELECT COUNT(*) AS cnt FROM CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS
  ),
  records_with_exceptions AS (
    SELECT COUNT(
      DISTINCT COALESCE(source_file, '<NULL_FILE>')
      || '|'
      || COALESCE(TO_VARCHAR(source_row_number), '<NULL_ROW>')
    ) AS cnt FROM DQ_EXCEPTIONS
  ),
  total_exceptions AS (
    SELECT COUNT(*) AS cnt FROM DQ_EXCEPTIONS
  )
SELECT
  (SELECT cnt FROM total_records) AS total_source_records,
  (SELECT cnt FROM records_with_exceptions) AS records_with_at_least_one_exception,
  (SELECT cnt FROM total_exceptions) AS total_exception_instances,
  ( (SELECT cnt FROM total_records) - (SELECT cnt FROM records_with_exceptions) ) AS records_without_exceptions;
