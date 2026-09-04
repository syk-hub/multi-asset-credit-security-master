-- 06_survivorship_decisions.sql
-- CONTROL-layer attribute-level survivorship candidates and decisions

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER;
USE SCHEMA CONTROL;

-- ==================================================================
-- 1) SURVIVORSHIP_CANDIDATES
-- Long form: one row per match group, source record, and attribute
-- Eligible groups: match_status IN ('CROSS_SOURCE_MATCH','SINGLE_SOURCE_ONLY')
-- ==================================================================
CREATE OR REPLACE VIEW SURVIVORSHIP_CANDIDATES AS
WITH sma AS (
  SELECT *
  FROM SOURCE_MATCH_ASSIGNMENTS
  WHERE match_status IN ('CROSS_SOURCE_MATCH','SINGLE_SOURCE_ONLY')
),
src AS (
  SELECT
    sma.match_group_key,
    sma.match_key_type,
    sma.match_key_value,
    sma.match_status,
    sma.source_system,
    sma.source_record_key,
    sma.source_file,
    sma.source_row_number,
    sma.load_ts,
    -- explicit staging/business attributes (preserve raw + typed where available)
    s.issuer_name,
    s.instrument_name,
    s.instrument_type,
    s.synthetic_cusip,
    s.synthetic_isin,
    s.currency,
    s.issue_date_raw,
    s.issue_date,
    s.maturity_date_raw,
    s.maturity_date,
    s.coupon_rate_raw,
    s.coupon_rate,
    s.coupon_type,
    s.seniority,
    s.secured_flag_raw,
    s.secured_flag,
    s.credit_status,
    s.rating,
    s.rating_agency,
    s.effective_from_raw,
    s.effective_from
  FROM sma
  JOIN CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS s
    ON sma.source_file = s.source_file
   AND sma.source_row_number = s.source_row_number
   AND sma.load_ts = s.load_ts
)

/*
Return columns:
- match_group_key
- match_key_type
- match_key_value
- match_status
- source_system
- source_record_key
- source_file
- source_row_number
- load_ts
- attribute_name
- original_value
- canonical_value
- candidate_is_valid
- rejection_reason
*/

SELECT
  match_group_key,
  match_key_type,
  match_key_value,
  match_status,
  source_system,
  source_record_key,
  source_file,
  source_row_number,
  load_ts,
  'issuer_name' AS attribute_name,
  NULLIF(TRIM(issuer_name), '') AS original_value,
  NULLIF(TRIM(issuer_name), '') AS canonical_value,
  CASE WHEN NULLIF(TRIM(issuer_name), '') IS NOT NULL THEN TRUE ELSE FALSE END AS candidate_is_valid,
  CASE WHEN NULLIF(TRIM(issuer_name), '') IS NULL THEN 'Null original value' ELSE NULL END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'instrument_name' AS attribute_name,
  NULLIF(TRIM(instrument_name), '') AS original_value,
  NULLIF(TRIM(instrument_name), '') AS canonical_value,
  CASE WHEN NULLIF(TRIM(instrument_name), '') IS NOT NULL THEN TRUE ELSE FALSE END AS candidate_is_valid,
  CASE WHEN NULLIF(TRIM(instrument_name), '') IS NULL THEN 'Null original value' ELSE NULL END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'instrument_type' AS attribute_name,
  NULLIF(TRIM(instrument_type), '') AS original_value,
  CASE WHEN UPPER(NULLIF(TRIM(instrument_type), '')) = 'CLO' THEN 'CLO_TRANCHE'
       WHEN UPPER(NULLIF(TRIM(instrument_type), '')) = 'CLO_TRANCHE' THEN 'CLO_TRANCHE'
       ELSE UPPER(NULLIF(TRIM(instrument_type), '')) END AS canonical_value,
  CASE WHEN UPPER(NULLIF(TRIM(instrument_type), '')) IS NOT NULL THEN TRUE ELSE FALSE END AS candidate_is_valid,
  CASE WHEN UPPER(NULLIF(TRIM(instrument_type), '')) IS NULL THEN 'Null original value' ELSE NULL END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'synthetic_cusip' AS attribute_name,
  NULLIF(TRIM(synthetic_cusip), '') AS original_value,
  NULLIF(TRIM(synthetic_cusip), '') AS canonical_value,
  CASE WHEN NULLIF(TRIM(synthetic_cusip), '') IS NOT NULL THEN TRUE ELSE FALSE END AS candidate_is_valid,
  CASE WHEN NULLIF(TRIM(synthetic_cusip), '') IS NULL THEN 'Null original value' ELSE NULL END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'synthetic_isin' AS attribute_name,
  NULLIF(TRIM(synthetic_isin), '') AS original_value,
  NULLIF(TRIM(synthetic_isin), '') AS canonical_value,
  CASE WHEN NULLIF(TRIM(synthetic_isin), '') IS NOT NULL THEN TRUE ELSE FALSE END AS candidate_is_valid,
  CASE WHEN NULLIF(TRIM(synthetic_isin), '') IS NULL THEN 'Null original value' ELSE NULL END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'currency' AS attribute_name,
  UPPER(NULLIF(TRIM(currency), '')) AS original_value,
  UPPER(NULLIF(TRIM(currency), '')) AS canonical_value,
  CASE WHEN UPPER(NULLIF(TRIM(currency), '')) IN ('USD','EUR','GBP','JPY') THEN TRUE WHEN UPPER(NULLIF(TRIM(currency), '')) IS NULL THEN FALSE ELSE FALSE END AS candidate_is_valid,
  CASE
    WHEN UPPER(NULLIF(TRIM(currency), '')) IS NULL THEN 'Null original value'
    WHEN UPPER(NULLIF(TRIM(currency), '')) NOT IN ('USD','EUR','GBP','JPY') THEN 'Outside project-approved currency domain'
    ELSE NULL
  END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'issue_date' AS attribute_name,
  NULLIF(TRIM(issue_date_raw), '') AS original_value,
  CASE WHEN issue_date IS NOT NULL THEN TO_VARCHAR(issue_date, 'YYYY-MM-DD') ELSE NULL END AS canonical_value,
  CASE
    WHEN NULLIF(TRIM(issue_date_raw), '') IS NULL THEN FALSE
    WHEN issue_date IS NOT NULL THEN TRUE
    ELSE FALSE
  END AS candidate_is_valid,
  CASE
    WHEN NULLIF(TRIM(issue_date_raw), '') IS NULL THEN 'Null original value'
    WHEN NULLIF(TRIM(issue_date_raw), '') IS NOT NULL AND issue_date IS NULL THEN 'Parse failure: issue_date'
    ELSE NULL
  END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'maturity_date' AS attribute_name,
  NULLIF(TRIM(maturity_date_raw), '') AS original_value,
  CASE WHEN maturity_date IS NOT NULL THEN TO_VARCHAR(maturity_date, 'YYYY-MM-DD') ELSE NULL END AS canonical_value,
  CASE
    WHEN NULLIF(TRIM(maturity_date_raw), '') IS NULL THEN FALSE
    WHEN maturity_date IS NULL THEN FALSE
    WHEN issue_date IS NULL THEN TRUE
    WHEN maturity_date > issue_date THEN TRUE
    ELSE FALSE
  END AS candidate_is_valid,
  CASE
    WHEN NULLIF(TRIM(maturity_date_raw), '') IS NULL THEN 'Null original value'
    WHEN NULLIF(TRIM(maturity_date_raw), '') IS NOT NULL AND maturity_date IS NULL THEN 'Parse failure: maturity_date'
    WHEN issue_date IS NOT NULL AND maturity_date <= issue_date THEN 'Maturity date is not after issue date'
    ELSE NULL
  END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'coupon_rate' AS attribute_name,
  NULLIF(TRIM(coupon_rate_raw), '') AS original_value,
  CASE WHEN coupon_rate IS NOT NULL THEN TO_VARCHAR(coupon_rate) ELSE NULL END AS canonical_value,
  CASE
    WHEN NULLIF(TRIM(coupon_rate_raw), '') IS NULL THEN FALSE
    WHEN coupon_rate IS NOT NULL AND coupon_rate >= 0 AND coupon_rate <= 30 THEN TRUE
    WHEN coupon_rate IS NOT NULL THEN FALSE
    ELSE FALSE
  END AS candidate_is_valid,
  CASE
    WHEN NULLIF(TRIM(coupon_rate_raw), '') IS NULL THEN 'Null original value'
    WHEN NULLIF(TRIM(coupon_rate_raw), '') IS NOT NULL AND coupon_rate IS NULL THEN 'Parse failure: coupon_rate'
    WHEN NOT (coupon_rate >= 0 AND coupon_rate <= 30) THEN 'Coupon rate out of allowed range'
    ELSE NULL
  END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'coupon_type' AS attribute_name,
  NULLIF(TRIM(coupon_type), '') AS original_value,
  NULLIF(TRIM(coupon_type), '') AS canonical_value,
  CASE WHEN NULLIF(TRIM(coupon_type), '') IS NOT NULL THEN TRUE ELSE FALSE END AS candidate_is_valid,
  CASE WHEN NULLIF(TRIM(coupon_type), '') IS NULL THEN 'Null original value' ELSE NULL END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'seniority' AS attribute_name,
  NULLIF(TRIM(seniority), '') AS original_value,
  NULLIF(TRIM(seniority), '') AS canonical_value,
  CASE WHEN NULLIF(TRIM(seniority), '') IS NOT NULL THEN TRUE ELSE FALSE END AS candidate_is_valid,
  CASE WHEN NULLIF(TRIM(seniority), '') IS NULL THEN 'Null original value' ELSE NULL END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'secured_flag' AS attribute_name,
  NULLIF(TRIM(secured_flag_raw), '') AS original_value,
  CASE WHEN secured_flag IS NOT NULL THEN TO_VARCHAR(secured_flag) ELSE NULL END AS canonical_value,
  CASE
    WHEN NULLIF(TRIM(secured_flag_raw), '') IS NULL THEN FALSE
    WHEN secured_flag IS NOT NULL THEN TRUE
    ELSE FALSE
  END AS candidate_is_valid,
  CASE
    WHEN NULLIF(TRIM(secured_flag_raw), '') IS NULL THEN 'Null original value'
    WHEN NULLIF(TRIM(secured_flag_raw), '') IS NOT NULL AND secured_flag IS NULL THEN 'Parse failure: secured_flag'
    ELSE NULL
  END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'credit_status' AS attribute_name,
  NULLIF(TRIM(credit_status), '') AS original_value,
  NULLIF(TRIM(credit_status), '') AS canonical_value,
  CASE WHEN NULLIF(TRIM(credit_status), '') IS NOT NULL THEN TRUE ELSE FALSE END AS candidate_is_valid,
  CASE WHEN NULLIF(TRIM(credit_status), '') IS NULL THEN 'Null original value' ELSE NULL END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'rating' AS attribute_name,
  NULLIF(TRIM(rating), '') AS original_value,
  NULLIF(TRIM(rating), '') AS canonical_value,
  CASE WHEN NULLIF(TRIM(rating), '') IS NOT NULL THEN TRUE ELSE FALSE END AS candidate_is_valid,
  CASE WHEN NULLIF(TRIM(rating), '') IS NULL THEN 'Null original value' ELSE NULL END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'rating_agency' AS attribute_name,
  NULLIF(TRIM(rating_agency), '') AS original_value,
  NULLIF(TRIM(rating_agency), '') AS canonical_value,
  CASE WHEN NULLIF(TRIM(rating_agency), '') IS NOT NULL THEN TRUE ELSE FALSE END AS candidate_is_valid,
  CASE WHEN NULLIF(TRIM(rating_agency), '') IS NULL THEN 'Null original value' ELSE NULL END AS rejection_reason
FROM src

UNION ALL

SELECT
  match_group_key, match_key_type, match_key_value, match_status, source_system, source_record_key, source_file, source_row_number, load_ts,
  'effective_from' AS attribute_name,
  NULLIF(TRIM(effective_from_raw), '') AS original_value,
  CASE WHEN effective_from IS NOT NULL THEN TO_VARCHAR(effective_from, 'YYYY-MM-DD') ELSE NULL END AS canonical_value,
  CASE
    WHEN NULLIF(TRIM(effective_from_raw), '') IS NULL THEN FALSE
    WHEN effective_from IS NOT NULL THEN TRUE
    ELSE FALSE
  END AS candidate_is_valid,
  CASE
    WHEN NULLIF(TRIM(effective_from_raw), '') IS NULL THEN 'Null original value'
    WHEN NULLIF(TRIM(effective_from_raw), '') IS NOT NULL AND effective_from IS NULL THEN 'Parse failure: effective_from'
    ELSE NULL
  END AS rejection_reason
FROM src;


-- ==================================================================
-- 2) SURVIVORSHIP_DECISIONS
-- One row per eligible match_group_key + attribute_name
-- Uses only candidates where candidate_is_valid = TRUE
-- ==================================================================
CREATE OR REPLACE VIEW SURVIVORSHIP_DECISIONS AS
WITH
eligible_groups AS (
  SELECT DISTINCT match_group_key, match_key_type, match_key_value, match_status
  FROM SURVIVORSHIP_CANDIDATES
),
attribute_list AS (
  SELECT VALUE::STRING AS attribute_name
  FROM TABLE(FLATTEN(INPUT => PARSE_JSON('["issuer_name","instrument_name","instrument_type","synthetic_cusip","synthetic_isin","currency","issue_date","maturity_date","coupon_rate","coupon_type","seniority","secured_flag","credit_status","rating","rating_agency","effective_from"]')))
),
decision_grid AS (
  SELECT eg.match_group_key, eg.match_key_type, eg.match_key_value, eg.match_status, al.attribute_name
  FROM eligible_groups eg
  CROSS JOIN attribute_list al
),
valid_candidates AS (
  SELECT * FROM SURVIVORSHIP_CANDIDATES WHERE candidate_is_valid = TRUE
),
value_support AS (
  SELECT
    match_group_key,
    attribute_name,
    canonical_value,
    COUNT(DISTINCT source_system) AS supporting_source_count,
    COUNT(*) AS supporting_record_count
  FROM valid_candidates
  GROUP BY match_group_key, attribute_name, canonical_value
),
candidate_stats AS (
  SELECT
    dc.match_group_key,
    dc.attribute_name,
    COUNT(vc.canonical_value) AS valid_candidate_count,
    COUNT(DISTINCT vc.canonical_value) AS distinct_valid_value_count
  FROM decision_grid dc
  LEFT JOIN valid_candidates vc
    ON dc.match_group_key = vc.match_group_key
   AND dc.attribute_name = vc.attribute_name
  GROUP BY dc.match_group_key, dc.attribute_name
),
maximum_support AS (
  SELECT match_group_key, attribute_name, MAX(supporting_source_count) AS maximum_supporting_source_count
  FROM value_support
  GROUP BY match_group_key, attribute_name
),
winning_values AS (
  SELECT vs.match_group_key, vs.attribute_name, vs.canonical_value, vs.supporting_source_count
  FROM value_support vs
  JOIN maximum_support ms
    ON vs.match_group_key = ms.match_group_key
   AND vs.attribute_name = ms.attribute_name
   AND vs.supporting_source_count = ms.maximum_supporting_source_count
),
winner_stats AS (
  SELECT match_group_key, attribute_name, COUNT(*) AS winner_count, MIN(canonical_value) AS winner_value
  FROM winning_values
  GROUP BY match_group_key, attribute_name
),
single_value AS (
  SELECT match_group_key, attribute_name, MIN(canonical_value) AS sole_value
  FROM value_support
  GROUP BY match_group_key, attribute_name
  HAVING COUNT(DISTINCT canonical_value) = 1
),
effective_max AS (
  SELECT match_group_key, attribute_name, MAX(canonical_value) AS max_value
  FROM value_support
  WHERE attribute_name = 'effective_from'
  GROUP BY match_group_key, attribute_name
),
observed_values AS (
  SELECT match_group_key, attribute_name, LISTAGG(DISTINCT canonical_value, ', ') WITHIN GROUP (ORDER BY canonical_value) AS observed_valid_values
  FROM value_support
  GROUP BY match_group_key, attribute_name
)

SELECT
  dg.match_group_key,
  eg.match_key_type,
  eg.match_key_value,
  eg.match_status,
  dg.attribute_name,

  -- selected_value per rules
  CASE
    WHEN COALESCE(cs.distinct_valid_value_count,0) = 0 THEN NULL
    WHEN COALESCE(cs.distinct_valid_value_count,0) = 1 THEN sv.sole_value
    WHEN dg.attribute_name = 'effective_from' AND COALESCE(cs.distinct_valid_value_count,0) > 1 THEN em.max_value
    WHEN COALESCE(ws.winner_count,0) = 1 THEN ws.winner_value
    ELSE NULL
  END AS selected_value,

  -- decision_status
  CASE
    WHEN COALESCE(cs.distinct_valid_value_count,0) = 0 THEN 'UNRESOLVED'
    WHEN COALESCE(cs.distinct_valid_value_count,0) = 1 THEN 'RESOLVED'
    WHEN dg.attribute_name = 'effective_from' AND COALESCE(cs.distinct_valid_value_count,0) > 1 THEN 'RESOLVED'
    WHEN COALESCE(ws.winner_count,0) = 1 THEN 'RESOLVED'
    ELSE 'UNRESOLVED'
  END AS decision_status,

  -- resolution_method
  CASE
    WHEN COALESCE(cs.distinct_valid_value_count,0) = 0 THEN 'NO_VALID_CANDIDATE'
    WHEN COALESCE(cs.distinct_valid_value_count,0) = 1 THEN 'UNANIMOUS_OR_SINGLE_VALUE'
    WHEN dg.attribute_name = 'effective_from' AND COALESCE(cs.distinct_valid_value_count,0) > 1 THEN 'LATEST_VALID_DATE'
    WHEN COALESCE(ws.winner_count,0) = 1 THEN 'DISTINCT_SOURCE_MAJORITY'
    ELSE 'UNRESOLVED_SUPPORT_TIE'
  END AS resolution_method,

  COALESCE(cs.valid_candidate_count,0) AS valid_candidate_count,
  COALESCE(cs.distinct_valid_value_count,0) AS distinct_valid_value_count,

  -- selected_value_source_count: join back to value_support on the selected value expression
  COALESCE(vs_sel.supporting_source_count, 0) AS selected_value_source_count,

  COALESCE(ob.observed_valid_values, '') AS observed_valid_values

FROM decision_grid dg
LEFT JOIN eligible_groups eg
  ON dg.match_group_key = eg.match_group_key
LEFT JOIN candidate_stats cs
  ON dg.match_group_key = cs.match_group_key
 AND dg.attribute_name = cs.attribute_name
LEFT JOIN maximum_support ms
  ON dg.match_group_key = ms.match_group_key
 AND dg.attribute_name = ms.attribute_name
LEFT JOIN winner_stats ws
  ON dg.match_group_key = ws.match_group_key
 AND dg.attribute_name = ws.attribute_name
LEFT JOIN single_value sv
  ON dg.match_group_key = sv.match_group_key
 AND dg.attribute_name = sv.attribute_name
LEFT JOIN effective_max em
  ON dg.match_group_key = em.match_group_key
 AND dg.attribute_name = em.attribute_name
LEFT JOIN observed_values ob
  ON dg.match_group_key = ob.match_group_key
 AND dg.attribute_name = ob.attribute_name

-- left join to get supporting_source_count for whichever value was selected
LEFT JOIN value_support vs_sel
  ON dg.match_group_key = vs_sel.match_group_key
 AND dg.attribute_name = vs_sel.attribute_name
 AND vs_sel.canonical_value = CASE
    WHEN COALESCE(cs.distinct_valid_value_count,0) = 1 THEN sv.sole_value
    WHEN dg.attribute_name = 'effective_from' AND COALESCE(cs.distinct_valid_value_count,0) > 1 THEN em.max_value
    WHEN COALESCE(ws.winner_count,0) = 1 THEN ws.winner_value
    ELSE NULL END;


-- ==================================================================
-- 3) SURVIVORSHIP_SUMMARY
-- Aggregate decisions by attribute, status, and method
-- ==================================================================
CREATE OR REPLACE VIEW SURVIVORSHIP_SUMMARY AS
SELECT
  attribute_name,
  decision_status,
  resolution_method,
  COUNT(*) AS decision_count,
  COUNT(DISTINCT match_group_key) AS affected_security_count
FROM SURVIVORSHIP_DECISIONS
GROUP BY attribute_name, decision_status, resolution_method;


-- ==================================================================
-- Verification queries
-- ==================================================================
-- 1) Decisions grouped by status and method
SELECT decision_status, resolution_method, COUNT(*) AS decision_count
FROM SURVIVORSHIP_DECISIONS
GROUP BY decision_status, resolution_method
ORDER BY decision_status, resolution_method;

-- 2) All decisions for selected match keys
SELECT *
FROM SURVIVORSHIP_DECISIONS
WHERE match_key_value IN ('SYN-CUSIP-0006','SYN-CUSIP-0007','SYN-CUSIP-0008','SYN-CUSIP-0009','SYN-CUSIP-0010')
ORDER BY match_key_value, attribute_name;

-- 3) Specific decisions
SELECT * FROM SURVIVORSHIP_DECISIONS WHERE match_key_value = 'SYN-CUSIP-0006' AND attribute_name = 'maturity_date';
SELECT * FROM SURVIVORSHIP_DECISIONS WHERE match_key_value = 'SYN-CUSIP-0007' AND attribute_name = 'rating';
SELECT * FROM SURVIVORSHIP_DECISIONS WHERE match_key_value = 'SYN-CUSIP-0008' AND attribute_name = 'instrument_type';
SELECT * FROM SURVIVORSHIP_DECISIONS WHERE match_key_value = 'SYN-CUSIP-0009' AND attribute_name = 'effective_from';
SELECT * FROM SURVIVORSHIP_DECISIONS WHERE match_key_value = 'SYN-CUSIP-0010' AND attribute_name = 'currency';

-- Expected logical outcomes (documented, not enforced):
-- SYN-CUSIP-0006 maturity_date = 2026-12-28 (resolved)
-- SYN-CUSIP-0007 rating = NULL (unresolved support tie)
-- SYN-CUSIP-0008 instrument_type = CLO_TRANCHE (resolved by distinct-source majority)
-- SYN-CUSIP-0009 effective_from = 2018-12-30 (resolved by latest valid date)
-- SYN-CUSIP-0010 currency = GBP (resolved after ZZZ rejection)

-- 4) Candidate rejection detail where original_value IS NOT NULL but rejected
SELECT * FROM SURVIVORSHIP_CANDIDATES
WHERE candidate_is_valid = FALSE
  AND original_value IS NOT NULL
ORDER BY match_group_key, attribute_name;

-- 5) Reconciliation and counts
SELECT
  (SELECT COUNT(DISTINCT match_group_key) FROM SOURCE_MATCH_ASSIGNMENTS WHERE match_status IN ('CROSS_SOURCE_MATCH','SINGLE_SOURCE_ONLY')) AS eligible_match_group_count,
  (SELECT COUNT(DISTINCT match_group_key) FROM SURVIVORSHIP_DECISIONS) AS distinct_match_groups_in_decisions,
  (SELECT COUNT(*) FROM SURVIVORSHIP_DECISIONS) AS total_decision_rows,
  (SELECT COUNT(*) FROM SURVIVORSHIP_DECISIONS WHERE decision_status = 'UNRESOLVED') AS unresolved_decision_count;

-- Reconciliation proof: total_decision_rows = eligible_match_group_count * 16
WITH counts AS (
  SELECT
    (SELECT COUNT(DISTINCT match_group_key) FROM SURVIVORSHIP_CANDIDATES) AS eligible_match_group_count,
    (SELECT COUNT(*) FROM SURVIVORSHIP_DECISIONS) AS total_decision_rows
)
SELECT
  eligible_match_group_count,
  total_decision_rows,
  eligible_match_group_count * 16 AS expected_total,
  CASE WHEN total_decision_rows = eligible_match_group_count * 16 THEN 'TRUE' ELSE 'FALSE' END AS matches_expected
FROM counts;
