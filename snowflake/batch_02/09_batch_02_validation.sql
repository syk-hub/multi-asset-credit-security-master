-- Batch 02 targeted validation.
-- Read-only. Prepared locally; not executed in Snowflake.
-- All 26 rows in tests/batch_02/expected_results.csv are covered: 24
-- CONFIRMED checks are PASS/FAIL assertions; the two INVESTIGATE checks are
-- emitted as diagnostics after the assertion result set. Independent RAW
-- and STAGING preparation checks are emitted before the CSV-backed assertions.

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER_BATCH_02;

-- Preparation checks: separate from the 24 CSV-backed PASS/FAIL assertions.
SELECT
  'RAW_ALPHA' AS check_name,
  14 AS expected_rows,
  COUNT(*) AS actual_rows,
  CASE WHEN COUNT(*) = 14 THEN 'PASS' ELSE 'FAIL' END AS test_status
FROM CREDIT_SECURITY_MASTER_BATCH_02.RAW.VENDOR_ALPHA_RAW

UNION ALL

SELECT
  'RAW_BETA',
  10,
  COUNT(*),
  CASE WHEN COUNT(*) = 10 THEN 'PASS' ELSE 'FAIL' END
FROM CREDIT_SECURITY_MASTER_BATCH_02.RAW.VENDOR_BETA_RAW

UNION ALL

SELECT
  'RAW_LEGACY',
  7,
  COUNT(*),
  CASE WHEN COUNT(*) = 7 THEN 'PASS' ELSE 'FAIL' END
FROM CREDIT_SECURITY_MASTER_BATCH_02.RAW.LEGACY_SECURITY_MASTER_RAW

UNION ALL

SELECT
  'STAGING_TOTAL',
  31,
  COUNT(*),
  CASE WHEN COUNT(*) = 31 THEN 'PASS' ELSE 'FAIL' END
FROM CREDIT_SECURITY_MASTER_BATCH_02.STAGING.ALL_SOURCE_RECORDS
ORDER BY check_name;

WITH
staging AS (
  SELECT *
  FROM CREDIT_SECURITY_MASTER_BATCH_02.STAGING.ALL_SOURCE_RECORDS
),
assignments AS (
  SELECT *
  FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.SOURCE_MATCH_ASSIGNMENTS
),
candidates AS (
  SELECT *
  FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.SURVIVORSHIP_CANDIDATES_SNAPSHOT
),
decisions AS (
  SELECT *
  FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT
),
core AS (
  SELECT *
  FROM CREDIT_SECURITY_MASTER_BATCH_02.CORE.SECURITY_MASTER_CURRENT
),
lineage AS (
  SELECT *
  FROM CREDIT_SECURITY_MASTER_BATCH_02.CORE.SECURITY_MASTER_ATTRIBUTE_LINEAGE
),
dq AS (
  SELECT *
  FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.DQ_EXCEPTIONS
),
physical_assignment_counts AS (
  SELECT
    s.source_file,
    s.source_row_number,
    s.load_ts,
    COUNT(a.source_row_number) AS assignment_count
  FROM staging s
  LEFT JOIN assignments a
    ON a.source_file = s.source_file
   AND a.source_row_number = s.source_row_number
   AND a.load_ts = s.load_ts
  GROUP BY s.source_file, s.source_row_number, s.load_ts
),
assertions AS (
  SELECT
    'B02-01-A' AS assertion_id,
    'B02-01' AS case_id,
    'Matching status' AS check_name,
    'One group; all three source rows CROSS_SOURCE_MATCH' AS expected_result,
    TO_VARCHAR((SELECT COUNT(DISTINCT match_group_key) FROM assignments
      WHERE synthetic_cusip = 'B02-CUSIP-CASE01'))
      || ' groups; cross-source assignment rows='
      || TO_VARCHAR((SELECT COUNT(*) FROM assignments
        WHERE synthetic_cusip = 'B02-CUSIP-CASE01'
          AND match_status = 'CROSS_SOURCE_MATCH')) AS actual_result,
    CASE WHEN
      (SELECT COUNT(DISTINCT match_group_key) FROM assignments
        WHERE synthetic_cusip = 'B02-CUSIP-CASE01') = 1
      AND (SELECT COUNT(*) FROM assignments
        WHERE synthetic_cusip = 'B02-CUSIP-CASE01'
          AND match_status = 'CROSS_SOURCE_MATCH') = 3
      THEN 'PASS' ELSE 'FAIL' END AS test_status

  UNION ALL

  SELECT
    'B02-01-B','B02-01','Issuer, name, type, rating survivorship',
    'B02-ISSUER-CASE01; B02-ISSUER-CASE01 NOTE; BOND; BBB',
    COALESCE((SELECT MAX(issuer_name) FROM core
      WHERE match_key_value = 'B02-CUSIP-CASE01'), '<missing>')
      || '; ' || COALESCE((SELECT MAX(instrument_name) FROM core
        WHERE match_key_value = 'B02-CUSIP-CASE01'), '<missing>')
      || '; ' || COALESCE((SELECT MAX(instrument_type) FROM core
        WHERE match_key_value = 'B02-CUSIP-CASE01'), '<missing>')
      || '; ' || COALESCE((SELECT MAX(rating) FROM core
        WHERE match_key_value = 'B02-CUSIP-CASE01'), '<NULL>'),
    CASE WHEN
      (SELECT COUNT(*) FROM core WHERE match_key_value = 'B02-CUSIP-CASE01') = 1
      AND (SELECT MAX(issuer_name) FROM core WHERE match_key_value = 'B02-CUSIP-CASE01') = 'B02-ISSUER-CASE01'
      AND (SELECT MAX(instrument_name) FROM core WHERE match_key_value = 'B02-CUSIP-CASE01') = 'B02-ISSUER-CASE01 NOTE'
      AND (SELECT MAX(instrument_type) FROM core WHERE match_key_value = 'B02-CUSIP-CASE01') = 'BOND'
      AND (SELECT MAX(rating) FROM core WHERE match_key_value = 'B02-CUSIP-CASE01') = 'BBB'
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-02-A','B02-02','Matching status',
    'All three rows share one CROSS_SOURCE_MATCH group',
    TO_VARCHAR((SELECT COUNT(DISTINCT match_group_key) FROM assignments
      WHERE synthetic_cusip = 'B02-CUSIP-CASE02'))
      || ' groups; cross-source rows='
      || TO_VARCHAR((SELECT COUNT(*) FROM assignments
        WHERE synthetic_cusip = 'B02-CUSIP-CASE02'
          AND match_status = 'CROSS_SOURCE_MATCH')),
    CASE WHEN
      (SELECT COUNT(DISTINCT match_group_key) FROM assignments
        WHERE synthetic_cusip = 'B02-CUSIP-CASE02') = 1
      AND (SELECT COUNT(*) FROM assignments
        WHERE synthetic_cusip = 'B02-CUSIP-CASE02'
          AND match_status = 'CROSS_SOURCE_MATCH') = 3
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-02-B','B02-02','Instrument-name majority',
    'B02-ISSUER-CASE02 CONSENSUS NAME; DISTINCT_SOURCE_MAJORITY; source count 2',
    COALESCE((SELECT MAX(selected_value) FROM decisions
      WHERE match_key_value = 'B02-CUSIP-CASE02'
        AND attribute_name = 'instrument_name'), '<NULL>')
      || '; ' || COALESCE((SELECT MAX(resolution_method) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE02'
          AND attribute_name = 'instrument_name'), '<missing>')
      || '; source count=' || COALESCE(TO_VARCHAR((SELECT MAX(selected_value_source_count)
        FROM decisions WHERE match_key_value = 'B02-CUSIP-CASE02'
          AND attribute_name = 'instrument_name')), '<missing>'),
    CASE WHEN
      (SELECT MAX(selected_value) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE02'
          AND attribute_name = 'instrument_name') = 'B02-ISSUER-CASE02 CONSENSUS NAME'
      AND (SELECT MAX(resolution_method) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE02'
          AND attribute_name = 'instrument_name') = 'DISTINCT_SOURCE_MAJORITY'
      AND (SELECT MAX(selected_value_source_count) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE02'
          AND attribute_name = 'instrument_name') = 2
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-02-C','B02-02','Majority lineage',
    'Selected instrument-name lineage includes Beta and Legacy',
    COALESCE((SELECT LISTAGG(DISTINCT source_system, ', ')
      WITHIN GROUP (ORDER BY source_system) FROM lineage
      WHERE match_key_value = 'B02-CUSIP-CASE02'
        AND attribute_name = 'instrument_name'), '<no lineage>'),
    CASE WHEN
      (SELECT COUNT(*) FROM lineage
        WHERE match_key_value = 'B02-CUSIP-CASE02'
          AND attribute_name = 'instrument_name'
          AND canonical_value = 'B02-ISSUER-CASE02 CONSENSUS NAME'
          AND source_system = 'VENDOR_BETA') = 1
      AND (SELECT COUNT(*) FROM lineage
        WHERE match_key_value = 'B02-CUSIP-CASE02'
          AND attribute_name = 'instrument_name'
          AND canonical_value = 'B02-ISSUER-CASE02 CONSENSUS NAME'
          AND source_system = 'LEGACY') = 1
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-03-A','B02-03','Rating decision',
    'NULL; UNRESOLVED; UNRESOLVED_SUPPORT_TIE',
    COALESCE((SELECT MAX(selected_value) FROM decisions
      WHERE match_key_value = 'B02-CUSIP-CASE03'
        AND attribute_name = 'rating'), '<NULL>')
      || '; ' || COALESCE((SELECT MAX(decision_status) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE03'
          AND attribute_name = 'rating'), '<missing>')
      || '; ' || COALESCE((SELECT MAX(resolution_method) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE03'
          AND attribute_name = 'rating'), '<missing>'),
    CASE WHEN
      (SELECT MAX(selected_value) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE03'
          AND attribute_name = 'rating') IS NULL
      AND (SELECT MAX(decision_status) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE03'
          AND attribute_name = 'rating') = 'UNRESOLVED'
      AND (SELECT MAX(resolution_method) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE03'
          AND attribute_name = 'rating') = 'UNRESOLVED_SUPPORT_TIE'
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-03-B','B02-03','CORE status','REVIEW_REQUIRED',
    COALESCE((SELECT MAX(master_record_status) FROM core
      WHERE match_key_value = 'B02-CUSIP-CASE03'), '<missing>'),
    CASE WHEN (SELECT MAX(master_record_status) FROM core
      WHERE match_key_value = 'B02-CUSIP-CASE03') = 'REVIEW_REQUIRED'
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-03-C','B02-03','Rating lineage','No selected-value rating lineage rows',
    TO_VARCHAR((SELECT COUNT(*) FROM lineage
      WHERE match_key_value = 'B02-CUSIP-CASE03'
        AND attribute_name = 'rating')),
    CASE WHEN (SELECT COUNT(*) FROM lineage
      WHERE match_key_value = 'B02-CUSIP-CASE03'
        AND attribute_name = 'rating') = 0
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-04-A','B02-04','Legacy candidate','Legacy currency candidate is invalid and null',
    COALESCE((SELECT TO_VARCHAR(candidate_is_valid) || '; '
        || COALESCE(original_value, '<NULL>') FROM candidates
      WHERE match_key_value = 'B02-CUSIP-CASE04'
        AND source_system = 'LEGACY'
        AND attribute_name = 'currency' LIMIT 1), '<missing candidate>'),
    CASE WHEN
      (SELECT COUNT(*) FROM candidates
        WHERE match_key_value = 'B02-CUSIP-CASE04'
          AND source_system = 'LEGACY'
          AND attribute_name = 'currency'
          AND candidate_is_valid = FALSE
          AND original_value IS NULL) = 1
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-04-B','B02-04','Currency tie',
    'NULL; UNRESOLVED_SUPPORT_TIE; observed values EUR and USD',
    COALESCE((SELECT MAX(selected_value) FROM decisions
      WHERE match_key_value = 'B02-CUSIP-CASE04'
        AND attribute_name = 'currency'), '<NULL>')
      || '; ' || COALESCE((SELECT MAX(resolution_method) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE04'
          AND attribute_name = 'currency'), '<missing>')
      || '; ' || COALESCE((SELECT MAX(observed_valid_values) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE04'
          AND attribute_name = 'currency'), '<missing>'),
    CASE WHEN
      (SELECT MAX(selected_value) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE04'
          AND attribute_name = 'currency') IS NULL
      AND (SELECT MAX(resolution_method) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE04'
          AND attribute_name = 'currency') = 'UNRESOLVED_SUPPORT_TIE'
      AND (SELECT MAX(observed_valid_values) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE04'
          AND attribute_name = 'currency') = 'EUR, USD'
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-05-A','B02-05','Invalid candidate','Alpha ZZZ is invalid',
    COALESCE((SELECT TO_VARCHAR(candidate_is_valid) || '; '
        || COALESCE(rejection_reason, '<no rejection reason>') FROM candidates
      WHERE match_key_value = 'B02-CUSIP-CASE05'
        AND source_system = 'VENDOR_ALPHA'
        AND attribute_name = 'currency' LIMIT 1), '<missing candidate>'),
    CASE WHEN (SELECT COUNT(*) FROM candidates
      WHERE match_key_value = 'B02-CUSIP-CASE05'
        AND source_system = 'VENDOR_ALPHA'
        AND attribute_name = 'currency'
        AND original_value = 'ZZZ'
        AND candidate_is_valid = FALSE) = 1
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-05-B','B02-05','Currency decision','CORE currency GBP from Beta',
    COALESCE((SELECT MAX(currency) FROM core
      WHERE match_key_value = 'B02-CUSIP-CASE05'), '<NULL>')
      || '; decision=' || COALESCE((SELECT MAX(selected_value) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE05'
          AND attribute_name = 'currency'), '<NULL>'),
    CASE WHEN
      (SELECT MAX(currency) FROM core
        WHERE match_key_value = 'B02-CUSIP-CASE05') = 'GBP'
      AND (SELECT MAX(selected_value) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE05'
          AND attribute_name = 'currency') = 'GBP'
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-06-A','B02-06','Canonical candidates','Alpha, Beta, and Legacy canonicalize to CLO_TRANCHE',
    COALESCE((SELECT LISTAGG(DISTINCT canonical_value, ', ')
      WITHIN GROUP (ORDER BY canonical_value) FROM candidates
      WHERE match_key_value = 'B02-CUSIP-CASE06'
        AND attribute_name = 'instrument_type'), '<no candidates>'),
    CASE WHEN
      (SELECT COUNT(*) FROM candidates
        WHERE match_key_value = 'B02-CUSIP-CASE06'
          AND attribute_name = 'instrument_type') = 3
      AND (SELECT COUNT(DISTINCT canonical_value) FROM candidates
        WHERE match_key_value = 'B02-CUSIP-CASE06'
          AND attribute_name = 'instrument_type'
      ) = 1
      AND (SELECT MAX(canonical_value) FROM candidates
        WHERE match_key_value = 'B02-CUSIP-CASE06'
          AND attribute_name = 'instrument_type') = 'CLO_TRANCHE'
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-06-B','B02-06','Type survivorship','Selected instrument_type CLO_TRANCHE',
    COALESCE((SELECT MAX(instrument_type) FROM core
      WHERE match_key_value = 'B02-CUSIP-CASE06'), '<NULL>'),
    CASE WHEN (SELECT MAX(instrument_type) FROM core
      WHERE match_key_value = 'B02-CUSIP-CASE06') = 'CLO_TRANCHE'
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-07-A','B02-07','Invalid date DQ','DQ006 for B02-ALPHA-CASE07-INVALID',
    TO_VARCHAR((SELECT COUNT(*) FROM dq
      WHERE rule_id = 'DQ006'
        AND vendor_security_id = 'B02-ALPHA-CASE07-INVALID'
        AND field_name = 'effective_from_raw')),
    CASE WHEN (SELECT COUNT(*) FROM dq
      WHERE rule_id = 'DQ006'
        AND vendor_security_id = 'B02-ALPHA-CASE07-INVALID'
        AND field_name = 'effective_from_raw') = 1
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-07-B','B02-07','Latest valid date','2022-05-06; LATEST_VALID_DATE',
    COALESCE((SELECT MAX(selected_value) FROM decisions
      WHERE match_key_value = 'B02-CUSIP-CASE07'
        AND attribute_name = 'effective_from'), '<NULL>')
      || '; ' || COALESCE((SELECT MAX(resolution_method) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE07'
          AND attribute_name = 'effective_from'), '<missing>'),
    CASE WHEN
      (SELECT MAX(selected_value) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE07'
          AND attribute_name = 'effective_from') = '2022-05-06'
      AND (SELECT MAX(resolution_method) FROM decisions
        WHERE match_key_value = 'B02-CUSIP-CASE07'
          AND attribute_name = 'effective_from') = 'LATEST_VALID_DATE'
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-08-A','B02-08','Matching status','SINGLE_SOURCE_ONLY',
    COALESCE((SELECT MAX(match_status) FROM assignments
      WHERE vendor_security_id = 'B02-ALPHA-CASE08'), '<missing>'),
    CASE WHEN
      (SELECT COUNT(*) FROM assignments
        WHERE vendor_security_id = 'B02-ALPHA-CASE08'
          AND match_status = 'SINGLE_SOURCE_ONLY') = 1
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-08-B','B02-08','CORE status','PROVISIONAL_SINGLE_SOURCE',
    COALESCE((SELECT MAX(master_record_status) FROM core
      WHERE match_key_value = 'B02-CUSIP-CASE08'), '<missing>'),
    CASE WHEN (SELECT MAX(master_record_status) FROM core
      WHERE match_key_value = 'B02-CUSIP-CASE08') = 'PROVISIONAL_SINGLE_SOURCE'
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-09-A','B02-09','DQ003','One DQ003 row for missing identifiers',
    TO_VARCHAR((SELECT COUNT(*) FROM dq
      WHERE rule_id = 'DQ003'
        AND vendor_security_id = 'B02-ALPHA-CASE09')),
    CASE WHEN (SELECT COUNT(*) FROM dq
      WHERE rule_id = 'DQ003'
        AND vendor_security_id = 'B02-ALPHA-CASE09') = 1
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-09-B','B02-09','Matching and eligibility','NONE; NO_IDENTIFIER; no survivorship candidate',
    COALESCE((SELECT MAX(match_key_type) || '; ' || MAX(match_status)
      FROM assignments WHERE vendor_security_id = 'B02-ALPHA-CASE09'),
      '<missing assignment>')
      || '; candidate rows=' || TO_VARCHAR((SELECT COUNT(*) FROM candidates
        WHERE source_record_key = 'VENDOR_ALPHA|B02-ALPHA-CASE09')),
    CASE WHEN
      (SELECT MAX(match_key_type) FROM assignments
        WHERE vendor_security_id = 'B02-ALPHA-CASE09') = 'NONE'
      AND (SELECT MAX(match_status) FROM assignments
        WHERE vendor_security_id = 'B02-ALPHA-CASE09') = 'NO_IDENTIFIER'
      AND (SELECT COUNT(*) FROM candidates
        WHERE source_record_key = 'VENDOR_ALPHA|B02-ALPHA-CASE09') = 0
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-10-A','B02-10','Collision split','Alpha and Beta use distinct ISIN keys',
    COALESCE((SELECT MAX(match_key_type) || '; ' || MAX(match_key_value)
      FROM assignments WHERE vendor_security_id = 'B02-ALPHA-CASE10'),
      '<missing Alpha>')
      || ' | ' || COALESCE((SELECT MAX(match_key_type) || '; ' || MAX(match_key_value)
        FROM assignments WHERE vendor_security_id = 'B02-BETA-CASE10'),
        '<missing Beta>'),
    CASE WHEN
      (SELECT MAX(match_key_type) FROM assignments
        WHERE vendor_security_id = 'B02-ALPHA-CASE10') = 'ISIN_COLLISION_SPLIT'
      AND (SELECT MAX(match_key_value) FROM assignments
        WHERE vendor_security_id = 'B02-ALPHA-CASE10') = 'B02-ISIN-CASE10-A'
      AND (SELECT MAX(match_key_type) FROM assignments
        WHERE vendor_security_id = 'B02-BETA-CASE10') = 'ISIN_COLLISION_SPLIT'
      AND (SELECT MAX(match_key_value) FROM assignments
        WHERE vendor_security_id = 'B02-BETA-CASE10') = 'B02-ISIN-CASE10-B'
      AND (SELECT COUNT(DISTINCT match_group_key) FROM assignments
        WHERE vendor_security_id IN ('B02-ALPHA-CASE10','B02-BETA-CASE10')) = 2
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-10-B','B02-10','Legacy ambiguity','Legacy is AMBIGUOUS_IDENTIFIER and excluded from candidates',
    COALESCE((SELECT MAX(match_status) FROM assignments
      WHERE vendor_security_id = 'B02-LEGACY-CASE10'), '<missing>')
      || '; candidate rows=' || TO_VARCHAR((SELECT COUNT(*) FROM candidates
        WHERE source_record_key = 'LEGACY|B02-LEGACY-CASE10')),
    CASE WHEN
      (SELECT MAX(match_status) FROM assignments
        WHERE vendor_security_id = 'B02-LEGACY-CASE10') = 'AMBIGUOUS_IDENTIFIER'
      AND (SELECT COUNT(*) FROM candidates
        WHERE source_record_key = 'LEGACY|B02-LEGACY-CASE10') = 0
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-11-A','B02-11','DQ011 detection','Two DQ011 rows for duplicated source_record_key',
    TO_VARCHAR((SELECT COUNT(*) FROM dq
      WHERE rule_id = 'DQ011'
        AND source_record_key = 'VENDOR_ALPHA|B02-ALPHA-CASE11')),
    CASE WHEN (SELECT COUNT(*) FROM dq
      WHERE rule_id = 'DQ011'
        AND source_record_key = 'VENDOR_ALPHA|B02-ALPHA-CASE11') = 2
      THEN 'PASS' ELSE 'FAIL' END

  UNION ALL

  SELECT
    'B02-12-A','B02-12','One assignment per physical row',
    'Every physical STAGING row has exactly one matching assignment',
    TO_VARCHAR((SELECT COUNT(*) FROM physical_assignment_counts
      WHERE assignment_count <> 1))
      || ' physical rows have assignment_count other than 1; staging rows='
      || TO_VARCHAR((SELECT COUNT(*) FROM staging))
      || '; assignment rows=' || TO_VARCHAR((SELECT COUNT(*) FROM assignments)),
    CASE WHEN (SELECT COUNT(*) FROM physical_assignment_counts
      WHERE assignment_count <> 1) = 0
      AND (SELECT COUNT(*) FROM physical_assignment_counts) = (SELECT COUNT(*) FROM staging)
      THEN 'PASS' ELSE 'FAIL' END
)
SELECT
  assertion_id,
  case_id,
  check_name,
  expected_result,
  actual_result,
  test_status,
  CASE WHEN test_status = 'PASS' THEN NULL
       ELSE 'Compare actual result with expected result; no SQL rule is changed by this check.'
  END AS failure_message
FROM assertions
ORDER BY assertion_id;

-- INVESTIGATE diagnostics; these result sets are not PASS/FAIL assertions.

-- B02-11: observe duplicate-key effects without asserting downstream totals.
SELECT
  'B02-11' AS case_id,
  'SOURCE_MATCH_ASSIGNMENTS' AS diagnostic_layer,
  source_file,
  source_row_number,
  load_ts,
  source_record_key,
  match_key_type,
  match_key_value,
  match_group_key,
  match_status
FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.SOURCE_MATCH_ASSIGNMENTS
WHERE source_record_key = 'VENDOR_ALPHA|B02-ALPHA-CASE11'
ORDER BY source_file, source_row_number, load_ts;

SELECT
  'B02-11' AS case_id,
  'SURVIVORSHIP / CORE SUMMARY' AS diagnostic_layer,
  (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.SURVIVORSHIP_CANDIDATES_SNAPSHOT
    WHERE source_record_key = 'VENDOR_ALPHA|B02-ALPHA-CASE11') AS candidate_rows,
  (SELECT COUNT(DISTINCT match_group_key) FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT
    WHERE match_key_value = 'B02-CUSIP-CASE11') AS decision_groups,
  (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER_BATCH_02.CORE.SECURITY_MASTER_CURRENT
    WHERE match_key_value = 'B02-CUSIP-CASE11') AS core_rows,
  'Diagnostic only; downstream duplicate-key behavior is not assigned an expected total.' AS note;

SELECT
  'B02-11' AS case_id,
  d.match_group_key,
  d.match_key_type,
  d.match_key_value,
  d.attribute_name,
  d.selected_value,
  d.decision_status,
  d.resolution_method,
  d.valid_candidate_count,
  d.distinct_valid_value_count,
  d.selected_value_source_count,
  d.observed_valid_values
FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT d
WHERE d.match_group_key IN (
  SELECT DISTINCT match_group_key
  FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.SOURCE_MATCH_ASSIGNMENTS
  WHERE source_record_key = 'VENDOR_ALPHA|B02-ALPHA-CASE11'
)
ORDER BY d.match_group_key, d.attribute_name;

SELECT
  'B02-11' AS case_id,
  l.match_group_key,
  l.match_key_value,
  l.attribute_name,
  l.selected_value,
  l.resolution_method,
  l.selected_value_source_count,
  l.source_system,
  l.source_record_key,
  l.original_value,
  l.canonical_value,
  l.source_file,
  l.source_row_number,
  l.load_ts
FROM CREDIT_SECURITY_MASTER_BATCH_02.CORE.SECURITY_MASTER_ATTRIBUTE_LINEAGE l
WHERE l.source_record_key = 'VENDOR_ALPHA|B02-ALPHA-CASE11'
  AND l.match_group_key IN (
    SELECT DISTINCT match_group_key
    FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.SOURCE_MATCH_ASSIGNMENTS
    WHERE source_record_key = 'VENDOR_ALPHA|B02-ALPHA-CASE11'
  )
ORDER BY l.match_group_key, l.attribute_name, l.source_file, l.source_row_number;

-- B02-12: inspect the shared ISIN assignments and metrics. The exact-one-row
-- invariant above remains a separate PASS/FAIL assertion; duplicate rows are
-- not treated as acceptable merely because they share a match key.
SELECT
  'B02-12' AS case_id,
  a.source_system,
  a.vendor_security_id,
  a.source_file,
  a.source_row_number,
  a.load_ts,
  a.match_key_type,
  a.match_key_value,
  a.match_group_key,
  a.distinct_source_count,
  a.source_record_count,
  a.match_status
FROM CREDIT_SECURITY_MASTER_BATCH_02.CONTROL.SOURCE_MATCH_ASSIGNMENTS a
WHERE a.match_key_value IN (
  'B02-ISIN-CASE12-SHARED',
  'B02-ISIN-CASE12-OTHER'
)
ORDER BY a.match_key_value, a.source_file, a.source_row_number, a.load_ts;
