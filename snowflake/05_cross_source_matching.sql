-- 05_cross_source_matching.sql
-- CONTROL-layer cross-source matching and conflict analysis

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER;
USE SCHEMA CONTROL;

-- 1) SOURCE_MATCH_ASSIGNMENTS: record-level match keys and group metrics
CREATE OR REPLACE VIEW SOURCE_MATCH_ASSIGNMENTS AS
WITH src AS (
  SELECT
    source_system,
    vendor_security_id,
    source_record_key,
    synthetic_cusip,
    synthetic_isin,
    UPPER(NULLIF(TRIM(synthetic_cusip), '')) AS normalized_cusip,
    UPPER(NULLIF(TRIM(synthetic_isin), '')) AS normalized_isin,
    source_file,
    source_row_number,
    load_ts
  FROM CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS
),
cusip_profile AS (
  -- for each normalized CUSIP count distinct non-null ISINs
  SELECT
    normalized_cusip,
    COUNT(DISTINCT normalized_isin) AS distinct_non_null_isin_count
  FROM src
  WHERE normalized_cusip IS NOT NULL
  GROUP BY normalized_cusip
),
keys AS (
  -- join source rows to cusip profile to decide how to treat CUSIP collisions
  SELECT
    s.*,
    COALESCE(cp.distinct_non_null_isin_count, 0) AS distinct_non_null_isin_count,
    CASE
   WHEN s.normalized_cusip IS NOT NULL
     AND COALESCE(cp.distinct_non_null_isin_count, 0) <= 1 THEN 'CUSIP'
   WHEN s.normalized_cusip IS NOT NULL
     AND COALESCE(cp.distinct_non_null_isin_count, 0) > 1
     AND s.normalized_isin IS NOT NULL THEN 'ISIN_COLLISION_SPLIT'
   WHEN s.normalized_cusip IS NOT NULL
     AND COALESCE(cp.distinct_non_null_isin_count, 0) > 1
     AND s.normalized_isin IS NULL THEN 'AMBIGUOUS_CUSIP'
   WHEN s.normalized_cusip IS NULL
     AND s.normalized_isin IS NOT NULL THEN 'ISIN'
   ELSE 'NONE'
    END AS match_key_type,
    CASE
   WHEN s.normalized_cusip IS NOT NULL
     AND COALESCE(cp.distinct_non_null_isin_count, 0) <= 1 THEN s.normalized_cusip
   WHEN s.normalized_cusip IS NOT NULL
     AND COALESCE(cp.distinct_non_null_isin_count, 0) > 1
     AND s.normalized_isin IS NOT NULL THEN s.normalized_isin
   WHEN s.normalized_cusip IS NOT NULL
     AND COALESCE(cp.distinct_non_null_isin_count, 0) > 1
     AND s.normalized_isin IS NULL THEN s.normalized_cusip
   WHEN s.normalized_cusip IS NULL
     AND s.normalized_isin IS NOT NULL THEN s.normalized_isin
   ELSE NULL
    END AS match_key_value,
    CASE
   WHEN s.normalized_cusip IS NOT NULL
     AND COALESCE(cp.distinct_non_null_isin_count, 0) <= 1 THEN 'CUSIP|' || s.normalized_cusip
   WHEN s.normalized_cusip IS NOT NULL
     AND COALESCE(cp.distinct_non_null_isin_count, 0) > 1
     AND s.normalized_isin IS NOT NULL THEN 'ISIN|' || s.normalized_isin
   WHEN s.normalized_cusip IS NOT NULL
     AND COALESCE(cp.distinct_non_null_isin_count, 0) > 1
     AND s.normalized_isin IS NULL THEN 'AMBIGUOUS_CUSIP|'
        || s.normalized_cusip
        || '|'
        || COALESCE(s.source_file, '<NULL_FILE>')
        || '|'
        || COALESCE(TO_VARCHAR(s.source_row_number), '<NULL_ROW>')
   WHEN s.normalized_cusip IS NULL
     AND s.normalized_isin IS NOT NULL THEN 'ISIN|' || s.normalized_isin
   ELSE 'NO_ID|'
     || COALESCE(s.source_file, '<NULL_FILE>')
     || '|'
     || COALESCE(TO_VARCHAR(s.source_row_number), '<NULL_ROW>')
    END AS match_group_key
  FROM src s
  LEFT JOIN cusip_profile cp
    ON s.normalized_cusip = cp.normalized_cusip
),
group_metrics AS (
  SELECT
    match_group_key,
    match_key_type,
    match_key_value,
    COUNT(DISTINCT source_system) AS distinct_source_count,
    COUNT(*) AS source_record_count
  FROM keys
  GROUP BY match_group_key, match_key_type, match_key_value
)
SELECT
  k.source_system,
  k.vendor_security_id,
  k.source_record_key,
  k.synthetic_cusip,
  k.synthetic_isin,
  k.normalized_cusip,
  k.normalized_isin,
  k.match_key_type,
  k.match_key_value,
  k.match_group_key,
  k.source_file,
  k.source_row_number,
  k.load_ts,
  gm.distinct_source_count,
  gm.source_record_count,
  CASE
    WHEN k.match_key_type = 'AMBIGUOUS_CUSIP' THEN 'AMBIGUOUS_IDENTIFIER'
    WHEN k.match_key_type = 'NONE' THEN 'NO_IDENTIFIER'
    WHEN gm.distinct_source_count >= 2 THEN 'CROSS_SOURCE_MATCH'
    ELSE 'SINGLE_SOURCE_ONLY'
  END AS match_status
FROM keys k
LEFT JOIN group_metrics gm
  ON k.match_group_key = gm.match_group_key;


-- 2) MATCH_GROUP_SUMMARY: one row per match group with source coverage
CREATE OR REPLACE VIEW MATCH_GROUP_SUMMARY AS
WITH groups AS (
  SELECT
    match_group_key,
    match_key_type,
    match_key_value,
    COUNT(DISTINCT source_system) AS distinct_source_count,
    COUNT(*) AS source_record_count
  FROM SOURCE_MATCH_ASSIGNMENTS
  GROUP BY match_group_key, match_key_type, match_key_value
),
distinct_group_sources AS (
  SELECT DISTINCT match_group_key, source_system
  FROM SOURCE_MATCH_ASSIGNMENTS
),
source_lists AS (
  SELECT
    match_group_key,
    LISTAGG(source_system, ', ') WITHIN GROUP (ORDER BY source_system) AS source_systems
  FROM distinct_group_sources
  GROUP BY match_group_key
)
SELECT
  g.match_group_key,
  g.match_key_type,
  g.match_key_value,
  g.distinct_source_count,
  g.source_record_count,
  sl.source_systems AS source_systems,
  CASE
    WHEN g.match_key_type = 'AMBIGUOUS_CUSIP' THEN 'AMBIGUOUS_IDENTIFIER'
    WHEN g.match_key_type = 'NONE' THEN 'NO_IDENTIFIER'
    WHEN g.distinct_source_count >= 2 THEN 'CROSS_SOURCE_MATCH'
    ELSE 'SINGLE_SOURCE_ONLY'
  END AS match_status
FROM groups g
LEFT JOIN source_lists sl
  ON g.match_group_key = sl.match_group_key;


-- 3) ATTRIBUTE_CONFLICTS: identify groups with differing non-null values
CREATE OR REPLACE VIEW ATTRIBUTE_CONFLICTS AS
WITH
-- reuse assignments to get match keys and lineage
  sma AS (
    SELECT * FROM SOURCE_MATCH_ASSIGNMENTS
  ),

-- build attribute-value rows (one block per attribute) as VARCHAR
  attribute_values AS (
        -- issuer_name
        SELECT sma.match_group_key,
          sma.match_key_type,
          sma.match_key_value,
          sma.source_system,
          'issuer_name' AS attribute_name,
          TRIM(s.issuer_name) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE TRIM(s.issuer_name) IS NOT NULL

    UNION ALL

    -- instrument_name
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'instrument_name' AS attribute_name, TRIM(s.instrument_name) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE TRIM(s.instrument_name) IS NOT NULL

    UNION ALL

    -- instrument_type
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'instrument_type' AS attribute_name, TRIM(s.instrument_type) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE TRIM(s.instrument_type) IS NOT NULL

    UNION ALL

    -- synthetic_isin
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'synthetic_isin' AS attribute_name, TRIM(s.synthetic_isin) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE TRIM(s.synthetic_isin) IS NOT NULL

    UNION ALL

    -- currency
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'currency' AS attribute_name, TRIM(s.currency) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE TRIM(s.currency) IS NOT NULL

    UNION ALL

    -- issue_date (format YYYY-MM-DD)
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'issue_date' AS attribute_name, TO_VARCHAR(s.issue_date, 'YYYY-MM-DD') AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE s.issue_date IS NOT NULL

    UNION ALL

    -- maturity_date
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'maturity_date' AS attribute_name, TO_VARCHAR(s.maturity_date, 'YYYY-MM-DD') AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE s.maturity_date IS NOT NULL

    UNION ALL

    -- coupon_rate
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'coupon_rate' AS attribute_name, TO_VARCHAR(s.coupon_rate) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE s.coupon_rate IS NOT NULL

    UNION ALL

    -- coupon_type
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'coupon_type' AS attribute_name, TRIM(s.coupon_type) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE TRIM(s.coupon_type) IS NOT NULL

    UNION ALL

    -- seniority
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'seniority' AS attribute_name, TRIM(s.seniority) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE TRIM(s.seniority) IS NOT NULL

    UNION ALL

    -- secured_flag (boolean to varchar)
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'secured_flag' AS attribute_name, TO_VARCHAR(s.secured_flag) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE s.secured_flag IS NOT NULL

    UNION ALL

    -- credit_status
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'credit_status' AS attribute_name, TRIM(s.credit_status) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE TRIM(s.credit_status) IS NOT NULL

    UNION ALL

    -- rating
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'rating' AS attribute_name, TRIM(s.rating) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE TRIM(s.rating) IS NOT NULL

    UNION ALL

    -- rating_agency
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'rating_agency' AS attribute_name, TRIM(s.rating_agency) AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE TRIM(s.rating_agency) IS NOT NULL

    UNION ALL

    -- effective_from
        SELECT sma.match_group_key, sma.match_key_type, sma.match_key_value, sma.source_system,
          'effective_from' AS attribute_name, TO_VARCHAR(s.effective_from, 'YYYY-MM-DD') AS attribute_value
        FROM sma
        JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
          ON sma.source_file = s.source_file
         AND sma.source_row_number = s.source_row_number
         AND sma.load_ts = s.load_ts
        WHERE s.effective_from IS NOT NULL
  ),

-- aggregate conflicts per group+attribute
  conflicts AS (
    SELECT
      match_group_key,
      match_key_type,
      match_key_value,
      attribute_name,
      COUNT(DISTINCT attribute_value) AS distinct_non_null_value_count,
      LISTAGG(DISTINCT attribute_value, ', ') WITHIN GROUP (ORDER BY attribute_value) AS observed_values,
      LISTAGG(DISTINCT source_system, ', ') WITHIN GROUP (ORDER BY source_system) AS contributing_sources
    FROM attribute_values
    GROUP BY match_group_key, match_key_type, match_key_value, attribute_name
    HAVING COUNT(DISTINCT attribute_value) > 1
  ),

-- join to group metrics to filter only multi-source groups
  group_info AS (
    SELECT
      match_group_key,
      COUNT(DISTINCT source_system) AS distinct_source_count
    FROM SOURCE_MATCH_ASSIGNMENTS
    GROUP BY match_group_key
  )

SELECT
  c.match_group_key,
  c.match_key_type,
  c.match_key_value,
  c.attribute_name,
  c.distinct_non_null_value_count,
  c.observed_values,
  c.contributing_sources,
  CASE
    WHEN c.attribute_name IN ('synthetic_isin','instrument_type') THEN 'ERROR'
    ELSE 'WARNING'
  END AS conflict_severity,
  CAST('Multiple non-null source values observed; no winning value selected' AS VARCHAR) AS issue_description
FROM conflicts c
JOIN group_info gi
  ON c.match_group_key = gi.match_group_key
WHERE gi.distinct_source_count >= 2;


-- Verification queries
-- 1) Match-status summary
SELECT
  match_status,
  COUNT(*) AS source_record_count,
  COUNT(DISTINCT match_group_key) AS match_group_count
FROM SOURCE_MATCH_ASSIGNMENTS
GROUP BY match_status
ORDER BY match_status;

-- 2) Match-group detail
SELECT * FROM MATCH_GROUP_SUMMARY
ORDER BY match_status, match_group_key;

-- Verification: list records flagged AMBIGUOUS_IDENTIFIER
SELECT *
FROM SOURCE_MATCH_ASSIGNMENTS
WHERE match_status = 'AMBIGUOUS_IDENTIFIER'
ORDER BY match_group_key, source_system, source_row_number;

-- 3) Conflict summary grouped
SELECT
  conflict_severity,
  attribute_name,
  COUNT(DISTINCT match_group_key) AS conflict_group_count,
  COUNT(*) AS total_conflict_rows
FROM ATTRIBUTE_CONFLICTS
GROUP BY conflict_severity, attribute_name
ORDER BY conflict_severity, attribute_name;

-- 4) Full attribute conflicts
SELECT * FROM ATTRIBUTE_CONFLICTS
ORDER BY conflict_severity, attribute_name, match_group_key;

-- 5) Reconciliation: SOURCE_MATCH_ASSIGNMENTS rows equal STAGING rows
SELECT
  (SELECT COUNT(*) FROM SOURCE_MATCH_ASSIGNMENTS) AS assignments_row_count,
  (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS) AS staging_row_count;
