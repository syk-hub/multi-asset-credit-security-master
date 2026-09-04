-- 08_core_security_master.sql
-- CORE-layer current mastered-security view and attribute lineage (uses snapshots)

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER;
USE SCHEMA CORE;

-- ==================================================================
-- 1) SECURITY_MASTER_CURRENT
-- One row per eligible match_group_key from CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT
-- ==================================================================
CREATE OR REPLACE VIEW SECURITY_MASTER_CURRENT AS
WITH decisions AS (
  SELECT *
  FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT
),
metrics AS (
  SELECT
    match_group_key,
    COUNT_IF(decision_status = 'RESOLVED') AS resolved_attribute_count,
    COUNT_IF(decision_status = 'UNRESOLVED') AS unresolved_attribute_count,
    COUNT_IF(resolution_method = 'UNRESOLVED_SUPPORT_TIE') AS unresolved_tie_count,
    COUNT_IF(resolution_method = 'NO_VALID_CANDIDATE') AS no_valid_candidate_count,
    COUNT(*) AS total_attribute_count
  FROM decisions
  GROUP BY match_group_key
),
pivoted AS (
  SELECT
    d.match_group_key,
    MAX(d.match_key_type) AS match_key_type,
    MAX(d.match_key_value) AS match_key_value,
    MAX(d.match_status) AS match_status,

    MAX(CASE WHEN attribute_name = 'issuer_name' THEN selected_value END) AS issuer_name,
    MAX(CASE WHEN attribute_name = 'instrument_name' THEN selected_value END) AS instrument_name,
    MAX(CASE WHEN attribute_name = 'instrument_type' THEN selected_value END) AS instrument_type,
    MAX(CASE WHEN attribute_name = 'synthetic_cusip' THEN selected_value END) AS synthetic_cusip,
    MAX(CASE WHEN attribute_name = 'synthetic_isin' THEN selected_value END) AS synthetic_isin,
    MAX(CASE WHEN attribute_name = 'currency' THEN selected_value END) AS currency,

    -- typed conversions
    MAX(CASE WHEN attribute_name = 'issue_date' THEN TRY_TO_DATE(selected_value,'YYYY-MM-DD') END) AS issue_date,
    MAX(CASE WHEN attribute_name = 'maturity_date' THEN TRY_TO_DATE(selected_value,'YYYY-MM-DD') END) AS maturity_date,
    MAX(CASE WHEN attribute_name = 'coupon_rate' THEN TRY_TO_DECIMAL(selected_value,10,4) END) AS coupon_rate,

    MAX(CASE WHEN attribute_name = 'coupon_type' THEN selected_value END) AS coupon_type,
    MAX(CASE WHEN attribute_name = 'seniority' THEN selected_value END) AS seniority,
    MAX(CASE WHEN attribute_name = 'secured_flag' THEN TRY_TO_BOOLEAN(selected_value) END) AS secured_flag,
    MAX(CASE WHEN attribute_name = 'credit_status' THEN selected_value END) AS credit_status,
    MAX(CASE WHEN attribute_name = 'rating' THEN selected_value END) AS rating,
    MAX(CASE WHEN attribute_name = 'rating_agency' THEN selected_value END) AS rating_agency,
    MAX(CASE WHEN attribute_name = 'effective_from' THEN TRY_TO_DATE(selected_value,'YYYY-MM-DD') END) AS effective_from

  FROM decisions d
  GROUP BY d.match_group_key
)

SELECT
  SHA2(p.match_group_key, 256) AS security_master_id,
  p.match_group_key,
  p.match_key_type,
  p.match_key_value,
  p.match_status,

  p.issuer_name,
  p.instrument_name,
  p.instrument_type,
  p.synthetic_cusip,
  p.synthetic_isin,
  p.currency,
  p.issue_date,
  p.maturity_date,
  p.coupon_rate,
  p.coupon_type,
  p.seniority,
  p.secured_flag,
  p.credit_status,
  p.rating,
  p.rating_agency,
  p.effective_from,

  COALESCE(m.resolved_attribute_count, 0) AS resolved_attribute_count,
  COALESCE(m.unresolved_attribute_count, 0) AS unresolved_attribute_count,
  COALESCE(m.unresolved_tie_count, 0) AS unresolved_tie_count,
  COALESCE(m.no_valid_candidate_count, 0) AS no_valid_candidate_count,
  COALESCE(m.total_attribute_count, 0) AS total_attribute_count,
  ROUND(100.0 * COALESCE(m.resolved_attribute_count, 0) / NULLIF(COALESCE(m.total_attribute_count, 0), 0), 2) AS completeness_percentage,

  CASE
    WHEN COALESCE(m.unresolved_tie_count, 0) > 0
      OR (p.synthetic_cusip IS NULL AND p.synthetic_isin IS NULL)
      OR p.issuer_name IS NULL
      OR p.instrument_name IS NULL
      OR p.instrument_type IS NULL
    THEN 'REVIEW_REQUIRED'
    WHEN p.match_status = 'SINGLE_SOURCE_ONLY' THEN 'PROVISIONAL_SINGLE_SOURCE'
    ELSE 'MASTERED'
  END AS master_record_status

FROM pivoted p
LEFT JOIN metrics m
  ON p.match_group_key = m.match_group_key;


-- ==================================================================
-- 2) SECURITY_MASTER_ATTRIBUTE_LINEAGE
-- One row per supporting candidate for a selected attribute value
-- ==================================================================
CREATE OR REPLACE VIEW SECURITY_MASTER_ATTRIBUTE_LINEAGE AS
SELECT
  SHA2(d.match_group_key, 256) AS security_master_id,
  d.match_group_key,
  d.match_key_type,
  d.match_key_value,
  d.match_status,
  d.attribute_name,
  d.selected_value,
  d.decision_status,
  d.resolution_method,
  d.selected_value_source_count,
  c.source_system,
  c.source_record_key,
  c.original_value,
  c.canonical_value,
  c.source_file,
  c.source_row_number,
  c.load_ts
FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT d
JOIN CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_CANDIDATES_SNAPSHOT c
  ON d.match_group_key = c.match_group_key
 AND d.attribute_name = c.attribute_name
 AND c.candidate_is_valid = TRUE
  -- only lineage for selected (non-null) mastered values
 AND d.selected_value IS NOT NULL
  -- match canonical (string) to selected_value
 AND c.canonical_value = d.selected_value;


-- ==================================================================
-- Verification queries
-- ==================================================================

-- 1) Core row reconciliation (use snapshot groups)
SELECT
  (SELECT COUNT(DISTINCT match_group_key) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT) AS eligible_match_group_count,
  (SELECT COUNT(*) FROM SECURITY_MASTER_CURRENT) AS core_security_count,
  CASE WHEN (SELECT COUNT(DISTINCT match_group_key) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT) = (SELECT COUNT(*) FROM SECURITY_MASTER_CURRENT) THEN 'TRUE' ELSE 'FALSE' END AS counts_match;

-- 2) Master-status summary
SELECT master_record_status, COUNT(*) AS record_count
FROM SECURITY_MASTER_CURRENT
GROUP BY master_record_status;

-- 3) Uniqueness checks: single scan of CORE view
SELECT
  COUNT(*) AS total_core_rows,
  COUNT(DISTINCT security_master_id) AS distinct_security_master_ids,
  COUNT(DISTINCT match_group_key) AS distinct_match_group_keys,
  COUNT(*) - COUNT(DISTINCT security_master_id)
    AS duplicate_security_master_id_count,
  COUNT(*) - COUNT(DISTINCT match_group_key)
    AS duplicate_match_group_key_count
FROM SECURITY_MASTER_CURRENT;

-- 4) Targeted mastered results for selected match keys
SELECT
  security_master_id,
  match_key_value,
  issuer_name,
  instrument_name,
  instrument_type,
  synthetic_cusip,
  synthetic_isin,
  currency,
  issue_date,
  maturity_date,
  coupon_rate,
  coupon_type,
  seniority,
  secured_flag,
  credit_status,
  rating,
  rating_agency,
  effective_from,
  resolved_attribute_count,
  unresolved_attribute_count,
  unresolved_tie_count,
  no_valid_candidate_count,
  total_attribute_count,
  completeness_percentage,
  master_record_status
FROM SECURITY_MASTER_CURRENT
WHERE match_key_value IN ('SYN-CUSIP-0006','SYN-CUSIP-0007','SYN-CUSIP-0008','SYN-CUSIP-0009','SYN-CUSIP-0010')
ORDER BY match_key_value;

-- 5) Lineage test for targeted decisions
SELECT
  l.match_key_value,
  l.attribute_name,
  l.selected_value,
  l.resolution_method,
  l.source_system,
  l.original_value,
  l.canonical_value
FROM SECURITY_MASTER_ATTRIBUTE_LINEAGE l
WHERE
       (l.match_key_value = 'SYN-CUSIP-0006'
        AND l.attribute_name = 'maturity_date')
    OR (l.match_key_value = 'SYN-CUSIP-0007'
        AND l.attribute_name = 'rating')
    OR (l.match_key_value = 'SYN-CUSIP-0008'
        AND l.attribute_name = 'instrument_type')
    OR (l.match_key_value = 'SYN-CUSIP-0009'
        AND l.attribute_name = 'effective_from')
    OR (l.match_key_value = 'SYN-CUSIP-0010'
        AND l.attribute_name = 'currency')
ORDER BY l.match_key_value, l.attribute_name, l.source_system;

-- 6) Completeness distribution
SELECT completeness_percentage, master_record_status, COUNT(*) AS record_count
FROM SECURITY_MASTER_CURRENT
GROUP BY completeness_percentage, master_record_status
ORDER BY completeness_percentage DESC, master_record_status;
