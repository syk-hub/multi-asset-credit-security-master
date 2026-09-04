-- 09_end_to_end_validation.sql
-- Read-only end-to-end validation suite for CREDIT_SECURITY_MASTER

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER;

-- Detailed tests
WITH
raw_counts AS (
  SELECT
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.RAW.VENDOR_ALPHA_RAW) AS alpha_cnt,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.RAW.VENDOR_BETA_RAW) AS beta_cnt,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.RAW.LEGACY_SECURITY_MASTER_RAW) AS legacy_cnt
),
staging_counts AS (
  SELECT COUNT(*) AS staging_cnt FROM CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS
),
dq_stats AS (
  SELECT
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.DQ_EXCEPTIONS) AS total_exceptions,
    (SELECT COUNT(DISTINCT COALESCE(source_file, '<NULL_FILE>') || '|' || COALESCE(TO_VARCHAR(source_row_number), '<NULL_ROW>')) FROM CREDIT_SECURITY_MASTER.CONTROL.DQ_EXCEPTIONS) AS distinct_physical_records,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.DQ_EXCEPTIONS WHERE rule_id = 'DQ003') AS dq003_cnt,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.DQ_EXCEPTIONS WHERE rule_id = 'DQ010') AS dq010_cnt
),
matching_stats AS (
  SELECT
    COUNT(*) AS total_assignments,
    SUM(CASE WHEN match_status = 'AMBIGUOUS_IDENTIFIER' THEN 1 ELSE 0 END) AS ambiguous_cnt,
    SUM(CASE WHEN match_status = 'NO_IDENTIFIER' THEN 1 ELSE 0 END) AS no_identifier_cnt,
    SUM(CASE WHEN match_status = 'SINGLE_SOURCE_ONLY' THEN 1 ELSE 0 END) AS single_source_only_cnt,
    SUM(CASE WHEN match_status = 'CROSS_SOURCE_MATCH' THEN 1 ELSE 0 END) AS cross_source_match_cnt,
    COUNT(DISTINCT match_group_key) AS distinct_match_groups
  FROM CREDIT_SECURITY_MASTER.CONTROL.SOURCE_MATCH_ASSIGNMENTS
),
survivorship_stats AS (
  SELECT
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_CANDIDATES_SNAPSHOT) AS candidates_snapshot_rows,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT) AS decisions_snapshot_rows,
    (SELECT COUNT(DISTINCT match_group_key) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT) AS decisions_distinct_groups,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT) = (SELECT COUNT(DISTINCT match_group_key) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT) * 16 AS decisions_rows_match_bool,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_CANDIDATES_SNAPSHOT WHERE candidate_is_valid = FALSE AND original_value IS NOT NULL) AS non_null_rejected_candidates,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT WHERE resolution_method = 'UNRESOLVED_SUPPORT_TIE') AS unresolved_support_ties
),
core_stats AS (
  SELECT
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT) AS core_rows,
    (SELECT COUNT(DISTINCT security_master_id) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT) AS core_distinct_ids,
    (SELECT COUNT(DISTINCT match_group_key) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT) AS core_distinct_match_groups,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE master_record_status = 'MASTERED') AS core_mastered,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE master_record_status = 'PROVISIONAL_SINGLE_SOURCE') AS core_provisional,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE master_record_status = 'REVIEW_REQUIRED') AS core_review_required
),
known_outcomes AS (
  SELECT
    (SELECT MAX(TO_VARCHAR(maturity_date,'YYYY-MM-DD')) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0006') AS s0006_maturity,
    (SELECT MAX(CASE WHEN rating IS NULL THEN 'NULL' ELSE rating END) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0007') AS s0007_rating,
    (SELECT MAX(master_record_status) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0007') AS s0007_status,
    (SELECT MAX(instrument_type) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0008') AS s0008_instrument_type,
    (SELECT MAX(TO_VARCHAR(effective_from,'YYYY-MM-DD')) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0009') AS s0009_effective_from,
    (SELECT MAX(currency) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0010') AS s0010_currency
),
lineage_counts AS (
  SELECT
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_ATTRIBUTE_LINEAGE l
      WHERE
           (l.match_key_value = 'SYN-CUSIP-0006' AND l.attribute_name = 'maturity_date')
        OR (l.match_key_value = 'SYN-CUSIP-0007' AND l.attribute_name = 'rating')
        OR (l.match_key_value = 'SYN-CUSIP-0008' AND l.attribute_name = 'instrument_type')
        OR (l.match_key_value = 'SYN-CUSIP-0009' AND l.attribute_name = 'effective_from')
        OR (l.match_key_value = 'SYN-CUSIP-0010' AND l.attribute_name = 'currency')
    ) AS targeted_lineage_count,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_ATTRIBUTE_LINEAGE l
      WHERE l.match_key_value = 'SYN-CUSIP-0007' AND l.attribute_name = 'rating') AS s0007_rating_lineage_count
)

SELECT
  test_id,
  test_category,
  test_name,
  expected_value,
  actual_value,
  test_status,
  failure_message
FROM (
  -- T001
  SELECT 'T001' AS test_id, 'RAW COUNTS' AS test_category, 'VENDOR_ALPHA_RAW row count' AS test_name,
    TO_VARCHAR(30) AS expected_value,
    TO_VARCHAR((SELECT alpha_cnt FROM raw_counts)) AS actual_value,
    CASE WHEN (SELECT alpha_cnt FROM raw_counts) = 30 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    CASE WHEN (SELECT alpha_cnt FROM raw_counts) = 30 THEN NULL ELSE 'alpha raw count mismatch' END AS failure_message

  UNION ALL

  -- T002
  SELECT 'T002','RAW COUNTS','VENDOR_BETA_RAW row count', TO_VARCHAR(30), TO_VARCHAR((SELECT beta_cnt FROM raw_counts)),
    CASE WHEN (SELECT beta_cnt FROM raw_counts) = 30 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT beta_cnt FROM raw_counts) = 30 THEN NULL ELSE 'beta raw count mismatch' END

  UNION ALL

  -- T003
  SELECT 'T003','RAW COUNTS','LEGACY_SECURITY_MASTER_RAW row count', TO_VARCHAR(31), TO_VARCHAR((SELECT legacy_cnt FROM raw_counts)),
    CASE WHEN (SELECT legacy_cnt FROM raw_counts) = 31 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT legacy_cnt FROM raw_counts) = 31 THEN NULL ELSE 'legacy raw count mismatch' END

  UNION ALL

  -- T004 combined raw
  SELECT 'T004','RAW COUNTS','Combined RAW row count', TO_VARCHAR(91), TO_VARCHAR((SELECT alpha_cnt+beta_cnt+legacy_cnt FROM raw_counts)),
    CASE WHEN (SELECT alpha_cnt+beta_cnt+legacy_cnt FROM raw_counts) = 91 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT alpha_cnt+beta_cnt+legacy_cnt FROM raw_counts) = 91 THEN NULL ELSE 'combined raw count mismatch' END

  UNION ALL

  -- T005 staging count
  SELECT 'T005','STAGING RECONCILIATION','STAGING.ALL_SOURCE_RECORDS row count', TO_VARCHAR(91), TO_VARCHAR((SELECT staging_cnt FROM staging_counts)),
    CASE WHEN (SELECT staging_cnt FROM staging_counts) = 91 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT staging_cnt FROM staging_counts) = 91 THEN NULL ELSE 'staging row count mismatch' END

  UNION ALL

  -- T006 staging equals raw
  SELECT 'T006','STAGING RECONCILIATION','STAGING equals combined RAW', TO_VARCHAR(1), TO_VARCHAR(CASE WHEN (SELECT staging_cnt FROM staging_counts) = (SELECT alpha_cnt+beta_cnt+legacy_cnt FROM raw_counts) THEN 1 ELSE 0 END),
    CASE WHEN (SELECT staging_cnt FROM staging_counts) = (SELECT alpha_cnt+beta_cnt+legacy_cnt FROM raw_counts) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT staging_cnt FROM staging_counts) = (SELECT alpha_cnt+beta_cnt+legacy_cnt FROM raw_counts) THEN NULL ELSE 'staging != combined raw' END

  UNION ALL

  -- T007 total DQ exceptions
  SELECT 'T007','DATA QUALITY','CONTROL.DQ_EXCEPTIONS total exception instances', TO_VARCHAR(2), TO_VARCHAR((SELECT total_exceptions FROM dq_stats)),
    CASE WHEN (SELECT total_exceptions FROM dq_stats) = 2 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT total_exceptions FROM dq_stats) = 2 THEN NULL ELSE 'dq exceptions count mismatch' END

  UNION ALL

  -- T008 distinct physical records in DQ_EXCEPTIONS
  SELECT 'T008','DATA QUALITY','Distinct physical records in DQ_EXCEPTIONS', TO_VARCHAR(2), TO_VARCHAR((SELECT distinct_physical_records FROM dq_stats)),
    CASE WHEN (SELECT distinct_physical_records FROM dq_stats) = 2 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT distinct_physical_records FROM dq_stats) = 2 THEN NULL ELSE 'distinct physical records mismatch' END

  UNION ALL

  -- T009 DQ003 count
  SELECT 'T009','DATA QUALITY','DQ003 Missing synthetic identifiers count', TO_VARCHAR(1), TO_VARCHAR((SELECT dq003_cnt FROM dq_stats)),
    CASE WHEN (SELECT dq003_cnt FROM dq_stats) = 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT dq003_cnt FROM dq_stats) = 1 THEN NULL ELSE 'dq003 count mismatch' END

  UNION ALL

  -- T010 DQ010 count
  SELECT 'T010','DATA QUALITY','DQ010 Invalid date chronology count', TO_VARCHAR(1), TO_VARCHAR((SELECT dq010_cnt FROM dq_stats)),
    CASE WHEN (SELECT dq010_cnt FROM dq_stats) = 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT dq010_cnt FROM dq_stats) = 1 THEN NULL ELSE 'dq010 count mismatch' END

  UNION ALL

  -- T011 matching total assignments
  SELECT 'T011','MATCHING','SOURCE_MATCH_ASSIGNMENTS row count', TO_VARCHAR(91), TO_VARCHAR((SELECT total_assignments FROM matching_stats)),
    CASE WHEN (SELECT total_assignments FROM matching_stats) = 91 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT total_assignments FROM matching_stats) = 91 THEN NULL ELSE 'matching assignments count mismatch' END

  UNION ALL

  -- T012 ambiguous identifier source record count
  SELECT 'T012','MATCHING','AMBIGUOUS_IDENTIFIER source record count', TO_VARCHAR(1), TO_VARCHAR((SELECT ambiguous_cnt FROM matching_stats)),
    CASE WHEN (SELECT ambiguous_cnt FROM matching_stats) = 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT ambiguous_cnt FROM matching_stats) = 1 THEN NULL ELSE 'ambiguous identifier count mismatch' END

  UNION ALL

  -- T013 NO_IDENTIFIER source record count
  SELECT 'T013','MATCHING','NO_IDENTIFIER source record count', TO_VARCHAR(1), TO_VARCHAR((SELECT no_identifier_cnt FROM matching_stats)),
    CASE WHEN (SELECT no_identifier_cnt FROM matching_stats) = 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT no_identifier_cnt FROM matching_stats) = 1 THEN NULL ELSE 'no_identifier count mismatch' END

  UNION ALL

  -- T014 SINGLE_SOURCE_ONLY source record count
  SELECT 'T014','MATCHING','SINGLE_SOURCE_ONLY source record count', TO_VARCHAR(2), TO_VARCHAR((SELECT single_source_only_cnt FROM matching_stats)),
    CASE WHEN (SELECT single_source_only_cnt FROM matching_stats) = 2 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT single_source_only_cnt FROM matching_stats) = 2 THEN NULL ELSE 'single_source_only count mismatch' END

  UNION ALL

  -- T015 CROSS_SOURCE_MATCH source record count
  SELECT 'T015','MATCHING','CROSS_SOURCE_MATCH source record count', TO_VARCHAR(87), TO_VARCHAR((SELECT cross_source_match_cnt FROM matching_stats)),
    CASE WHEN (SELECT cross_source_match_cnt FROM matching_stats) = 87 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT cross_source_match_cnt FROM matching_stats) = 87 THEN NULL ELSE 'cross_source_match count mismatch' END

  UNION ALL

  -- T016 distinct match groups
  SELECT 'T016','MATCHING','Distinct match groups across SOURCE_MATCH_ASSIGNMENTS', TO_VARCHAR(34), TO_VARCHAR((SELECT distinct_match_groups FROM matching_stats)),
    CASE WHEN (SELECT distinct_match_groups FROM matching_stats) = 34 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT distinct_match_groups FROM matching_stats) = 34 THEN NULL ELSE 'distinct match groups mismatch' END

  UNION ALL

  -- T017 candidates snapshot rows
  SELECT 'T017','SURVIVORSHIP SNAPSHOTS','SURVIVORSHIP_CANDIDATES_SNAPSHOT row count', TO_VARCHAR(1424), TO_VARCHAR((SELECT candidates_snapshot_rows FROM survivorship_stats)),
    CASE WHEN (SELECT candidates_snapshot_rows FROM survivorship_stats) = 1424 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT candidates_snapshot_rows FROM survivorship_stats) = 1424 THEN NULL ELSE 'candidates snapshot count mismatch' END

  UNION ALL

  -- T018 decisions snapshot rows
  SELECT 'T018','SURVIVORSHIP SNAPSHOTS','SURVIVORSHIP_DECISIONS_SNAPSHOT row count', TO_VARCHAR(512), TO_VARCHAR((SELECT decisions_snapshot_rows FROM survivorship_stats)),
    CASE WHEN (SELECT decisions_snapshot_rows FROM survivorship_stats) = 512 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT decisions_snapshot_rows FROM survivorship_stats) = 512 THEN NULL ELSE 'decisions snapshot count mismatch' END

  UNION ALL

  -- T019 distinct decision snapshot match groups
  SELECT 'T019','SURVIVORSHIP SNAPSHOTS','Distinct decision snapshot match groups', TO_VARCHAR(32), TO_VARCHAR((SELECT decisions_distinct_groups FROM survivorship_stats)),
    CASE WHEN (SELECT decisions_distinct_groups FROM survivorship_stats) = 32 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT decisions_distinct_groups FROM survivorship_stats) = 32 THEN NULL ELSE 'decisions distinct groups mismatch' END

  UNION ALL

  -- T020 decision rows equal distinct groups * 16
  SELECT 'T020','SURVIVORSHIP SNAPSHOTS','Decision rows equal distinct groups * 16', 'TRUE', TO_VARCHAR(CASE WHEN (SELECT decisions_rows_match_bool FROM survivorship_stats) THEN 'TRUE' ELSE 'FALSE' END),
    CASE WHEN (SELECT decisions_rows_match_bool FROM survivorship_stats) THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT decisions_rows_match_bool FROM survivorship_stats) THEN NULL ELSE 'decision rows != groups * 16' END

  UNION ALL

  -- T021 non-null rejected candidates
  SELECT 'T021','SURVIVORSHIP SNAPSHOTS','Non-null rejected candidates', TO_VARCHAR(2), TO_VARCHAR((SELECT non_null_rejected_candidates FROM survivorship_stats)),
    CASE WHEN (SELECT non_null_rejected_candidates FROM survivorship_stats) = 2 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT non_null_rejected_candidates FROM survivorship_stats) = 2 THEN NULL ELSE 'non-null rejected candidates mismatch' END

  UNION ALL

  -- T022 unresolved support ties
  SELECT 'T022','SURVIVORSHIP SNAPSHOTS','Unresolved support ties', TO_VARCHAR(1), TO_VARCHAR((SELECT unresolved_support_ties FROM survivorship_stats)),
    CASE WHEN (SELECT unresolved_support_ties FROM survivorship_stats) = 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT unresolved_support_ties FROM survivorship_stats) = 1 THEN NULL ELSE 'unresolved support ties mismatch' END

  UNION ALL

  -- T023 CORE row count
  SELECT 'T023','CORE','CORE.SECURITY_MASTER_CURRENT row count', TO_VARCHAR(32), TO_VARCHAR((SELECT core_rows FROM core_stats)),
    CASE WHEN (SELECT core_rows FROM core_stats) = 32 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT core_rows FROM core_stats) = 32 THEN NULL ELSE 'core row count mismatch' END

  UNION ALL

  -- T024 distinct security_master_id count
  SELECT 'T024','CORE','Distinct security_master_id count', TO_VARCHAR(32), TO_VARCHAR((SELECT core_distinct_ids FROM core_stats)),
    CASE WHEN (SELECT core_distinct_ids FROM core_stats) = 32 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT core_distinct_ids FROM core_stats) = 32 THEN NULL ELSE 'distinct security_master_id mismatch' END

  UNION ALL

  -- T025 distinct match_group_key count in CORE
  SELECT 'T025','CORE','Distinct match_group_key count in CORE', TO_VARCHAR(32), TO_VARCHAR((SELECT core_distinct_match_groups FROM core_stats)),
    CASE WHEN (SELECT core_distinct_match_groups FROM core_stats) = 32 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT core_distinct_match_groups FROM core_stats) = 32 THEN NULL ELSE 'core distinct match_group_key mismatch' END

  UNION ALL

  -- T026 MASTERED record count
  SELECT 'T026','CORE','MASTERED record count', TO_VARCHAR(29), TO_VARCHAR((SELECT core_mastered FROM core_stats)),
    CASE WHEN (SELECT core_mastered FROM core_stats) = 29 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT core_mastered FROM core_stats) = 29 THEN NULL ELSE 'mastered count mismatch' END

  UNION ALL

  -- T027 PROVISIONAL_SINGLE_SOURCE record count
  SELECT 'T027','CORE','PROVISIONAL_SINGLE_SOURCE record count', TO_VARCHAR(2), TO_VARCHAR((SELECT core_provisional FROM core_stats)),
    CASE WHEN (SELECT core_provisional FROM core_stats) = 2 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT core_provisional FROM core_stats) = 2 THEN NULL ELSE 'provisional count mismatch' END

  UNION ALL

  -- T028 REVIEW_REQUIRED record count
  SELECT 'T028','CORE','REVIEW_REQUIRED record count', TO_VARCHAR(1), TO_VARCHAR((SELECT core_review_required FROM core_stats)),
    CASE WHEN (SELECT core_review_required FROM core_stats) = 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT core_review_required FROM core_stats) = 1 THEN NULL ELSE 'review_required count mismatch' END

  UNION ALL

  -- T029 SYN-CUSIP-0006 maturity_date
  SELECT 'T029','KNOWN SURVIVORSHIP OUTCOMES','SYN-CUSIP-0006 maturity_date', TO_VARCHAR('2026-12-28'), TO_VARCHAR((SELECT s0006_maturity FROM known_outcomes)),
    CASE WHEN (SELECT s0006_maturity FROM known_outcomes) = '2026-12-28' THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT s0006_maturity FROM known_outcomes) = '2026-12-28' THEN NULL ELSE 'SYN-CUSIP-0006 maturity mismatch' END

  UNION ALL

  -- T030 SYN-CUSIP-0007 rating is NULL
  SELECT 'T030','KNOWN SURVIVORSHIP OUTCOMES','SYN-CUSIP-0007 rating is NULL', TO_VARCHAR('NULL'), TO_VARCHAR((SELECT s0007_rating FROM known_outcomes)),
    CASE WHEN (SELECT s0007_rating FROM known_outcomes) = 'NULL' THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT s0007_rating FROM known_outcomes) = 'NULL' THEN NULL ELSE 'SYN-CUSIP-0007 rating not NULL' END

  UNION ALL

  -- T031 SYN-CUSIP-0007 master_record_status = REVIEW_REQUIRED
  SELECT 'T031','KNOWN SURVIVORSHIP OUTCOMES','SYN-CUSIP-0007 master_record_status', TO_VARCHAR('REVIEW_REQUIRED'), TO_VARCHAR((SELECT s0007_status FROM known_outcomes)),
    CASE WHEN (SELECT s0007_status FROM known_outcomes) = 'REVIEW_REQUIRED' THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT s0007_status FROM known_outcomes) = 'REVIEW_REQUIRED' THEN NULL ELSE 'SYN-CUSIP-0007 status mismatch' END

  UNION ALL

  -- T032 SYN-CUSIP-0008 instrument_type = CLO_TRANCHE
  SELECT 'T032','KNOWN SURVIVORSHIP OUTCOMES','SYN-CUSIP-0008 instrument_type', TO_VARCHAR('CLO_TRANCHE'), TO_VARCHAR((SELECT s0008_instrument_type FROM known_outcomes)),
    CASE WHEN (SELECT s0008_instrument_type FROM known_outcomes) = 'CLO_TRANCHE' THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT s0008_instrument_type FROM known_outcomes) = 'CLO_TRANCHE' THEN NULL ELSE 'SYN-CUSIP-0008 instrument_type mismatch' END

  UNION ALL

  -- T033 SYN-CUSIP-0009 effective_from = 2018-12-30
  SELECT 'T033','KNOWN SURVIVORSHIP OUTCOMES','SYN-CUSIP-0009 effective_from', TO_VARCHAR('2018-12-30'), TO_VARCHAR((SELECT s0009_effective_from FROM known_outcomes)),
    CASE WHEN (SELECT s0009_effective_from FROM known_outcomes) = '2018-12-30' THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT s0009_effective_from FROM known_outcomes) = '2018-12-30' THEN NULL ELSE 'SYN-CUSIP-0009 effective_from mismatch' END

  UNION ALL

  -- T034 SYN-CUSIP-0010 currency = GBP
  SELECT 'T034','KNOWN SURVIVORSHIP OUTCOMES','SYN-CUSIP-0010 currency', TO_VARCHAR('GBP'), TO_VARCHAR((SELECT s0010_currency FROM known_outcomes)),
    CASE WHEN (SELECT s0010_currency FROM known_outcomes) = 'GBP' THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT s0010_currency FROM known_outcomes) = 'GBP' THEN NULL ELSE 'SYN-CUSIP-0010 currency mismatch' END

  UNION ALL

  -- T035 targeted lineage rows total 5
  SELECT 'T035','LINEAGE','Five targeted selected-value lineage rows total', TO_VARCHAR(5), TO_VARCHAR((SELECT targeted_lineage_count FROM lineage_counts)),
    CASE WHEN (SELECT targeted_lineage_count FROM lineage_counts) = 5 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT targeted_lineage_count FROM lineage_counts) = 5 THEN NULL ELSE 'targeted lineage count mismatch' END

  UNION ALL

  -- T036 zero selected-value lineage rows for SYN-CUSIP-0007 rating
  SELECT 'T036','LINEAGE','No selected-value lineage rows for SYN-CUSIP-0007 rating', TO_VARCHAR(0), TO_VARCHAR((SELECT s0007_rating_lineage_count FROM lineage_counts)),
    CASE WHEN (SELECT s0007_rating_lineage_count FROM lineage_counts) = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN (SELECT s0007_rating_lineage_count FROM lineage_counts) = 0 THEN NULL ELSE 'unexpected lineage for 0007 rating' END
) AS detailed_tests
ORDER BY test_id;

-- Summary query: re-run the same validation logic and aggregate PASS/FAIL
WITH
raw_counts AS (
  SELECT
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.RAW.VENDOR_ALPHA_RAW) AS alpha_cnt,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.RAW.VENDOR_BETA_RAW) AS beta_cnt,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.RAW.LEGACY_SECURITY_MASTER_RAW) AS legacy_cnt
),
staging_counts AS (
  SELECT COUNT(*) AS staging_cnt FROM CREDIT_SECURITY_MASTER.STAGING.ALL_SOURCE_RECORDS
),
dq_stats AS (
  SELECT
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.DQ_EXCEPTIONS) AS total_exceptions,
    (SELECT COUNT(DISTINCT COALESCE(source_file, '<NULL_FILE>') || '|' || COALESCE(TO_VARCHAR(source_row_number), '<NULL_ROW>')) FROM CREDIT_SECURITY_MASTER.CONTROL.DQ_EXCEPTIONS) AS distinct_physical_records,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.DQ_EXCEPTIONS WHERE rule_id = 'DQ003') AS dq003_cnt,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.DQ_EXCEPTIONS WHERE rule_id = 'DQ010') AS dq010_cnt
),
matching_stats AS (
  SELECT
    COUNT(*) AS total_assignments,
    SUM(CASE WHEN match_status = 'AMBIGUOUS_IDENTIFIER' THEN 1 ELSE 0 END) AS ambiguous_cnt,
    SUM(CASE WHEN match_status = 'NO_IDENTIFIER' THEN 1 ELSE 0 END) AS no_identifier_cnt,
    SUM(CASE WHEN match_status = 'SINGLE_SOURCE_ONLY' THEN 1 ELSE 0 END) AS single_source_only_cnt,
    SUM(CASE WHEN match_status = 'CROSS_SOURCE_MATCH' THEN 1 ELSE 0 END) AS cross_source_match_cnt,
    COUNT(DISTINCT match_group_key) AS distinct_match_groups
  FROM CREDIT_SECURITY_MASTER.CONTROL.SOURCE_MATCH_ASSIGNMENTS
),
survivorship_stats AS (
  SELECT
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_CANDIDATES_SNAPSHOT) AS candidates_snapshot_rows,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT) AS decisions_snapshot_rows,
    (SELECT COUNT(DISTINCT match_group_key) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT) AS decisions_distinct_groups,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_CANDIDATES_SNAPSHOT WHERE candidate_is_valid = FALSE AND original_value IS NOT NULL) AS non_null_rejected_candidates,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CONTROL.SURVIVORSHIP_DECISIONS_SNAPSHOT WHERE resolution_method = 'UNRESOLVED_SUPPORT_TIE') AS unresolved_support_ties
),
core_stats AS (
  SELECT
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT) AS core_rows,
    (SELECT COUNT(DISTINCT security_master_id) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT) AS core_distinct_ids,
    (SELECT COUNT(DISTINCT match_group_key) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT) AS core_distinct_match_groups,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE master_record_status = 'MASTERED') AS core_mastered,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE master_record_status = 'PROVISIONAL_SINGLE_SOURCE') AS core_provisional,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE master_record_status = 'REVIEW_REQUIRED') AS core_review_required
),
known_outcomes AS (
  SELECT
    (SELECT MAX(TO_VARCHAR(maturity_date,'YYYY-MM-DD')) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0006') AS s0006_maturity,
    (SELECT MAX(CASE WHEN rating IS NULL THEN 'NULL' ELSE rating END) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0007') AS s0007_rating,
    (SELECT MAX(master_record_status) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0007') AS s0007_status,
    (SELECT MAX(instrument_type) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0008') AS s0008_instrument_type,
    (SELECT MAX(TO_VARCHAR(effective_from,'YYYY-MM-DD')) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0009') AS s0009_effective_from,
    (SELECT MAX(currency) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_CURRENT WHERE match_key_value = 'SYN-CUSIP-0010') AS s0010_currency
),
lineage_counts AS (
  SELECT
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_ATTRIBUTE_LINEAGE l
      WHERE
           (l.match_key_value = 'SYN-CUSIP-0006' AND l.attribute_name = 'maturity_date')
        OR (l.match_key_value = 'SYN-CUSIP-0007' AND l.attribute_name = 'rating')
        OR (l.match_key_value = 'SYN-CUSIP-0008' AND l.attribute_name = 'instrument_type')
        OR (l.match_key_value = 'SYN-CUSIP-0009' AND l.attribute_name = 'effective_from')
        OR (l.match_key_value = 'SYN-CUSIP-0010' AND l.attribute_name = 'currency')
    ) AS targeted_lineage_count,
    (SELECT COUNT(*) FROM CREDIT_SECURITY_MASTER.CORE.SECURITY_MASTER_ATTRIBUTE_LINEAGE l
      WHERE l.match_key_value = 'SYN-CUSIP-0007' AND l.attribute_name = 'rating') AS s0007_rating_lineage_count
)

-- Build the detailed test results again and aggregate PASS/FAIL
SELECT
  COUNT(*) AS total_tests,
  SUM(CASE WHEN test_status = 'PASS' THEN 1 ELSE 0 END) AS passed_tests,
  SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END) AS failed_tests,
  CASE WHEN SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END AS overall_status
FROM (
  -- reproduce tests (only using the aggregate CTE values computed above)
  SELECT 'T001' AS test_id, CASE WHEN (SELECT alpha_cnt FROM raw_counts) = 30 THEN 'PASS' ELSE 'FAIL' END AS test_status
  UNION ALL SELECT 'T002', CASE WHEN (SELECT beta_cnt FROM raw_counts) = 30 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T003', CASE WHEN (SELECT legacy_cnt FROM raw_counts) = 31 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T004', CASE WHEN (SELECT alpha_cnt+beta_cnt+legacy_cnt FROM raw_counts) = 91 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T005', CASE WHEN (SELECT staging_cnt FROM staging_counts) = 91 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T006', CASE WHEN (SELECT staging_cnt FROM staging_counts) = (SELECT alpha_cnt+beta_cnt+legacy_cnt FROM raw_counts) THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T007', CASE WHEN (SELECT total_exceptions FROM dq_stats) = 2 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T008', CASE WHEN (SELECT distinct_physical_records FROM dq_stats) = 2 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T009', CASE WHEN (SELECT dq003_cnt FROM dq_stats) = 1 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T010', CASE WHEN (SELECT dq010_cnt FROM dq_stats) = 1 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T011', CASE WHEN (SELECT total_assignments FROM matching_stats) = 91 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T012', CASE WHEN (SELECT ambiguous_cnt FROM matching_stats) = 1 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T013', CASE WHEN (SELECT no_identifier_cnt FROM matching_stats) = 1 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T014', CASE WHEN (SELECT single_source_only_cnt FROM matching_stats) = 2 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T015', CASE WHEN (SELECT cross_source_match_cnt FROM matching_stats) = 87 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T016', CASE WHEN (SELECT distinct_match_groups FROM matching_stats) = 34 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T017', CASE WHEN (SELECT candidates_snapshot_rows FROM survivorship_stats) = 1424 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T018', CASE WHEN (SELECT decisions_snapshot_rows FROM survivorship_stats) = 512 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T019', CASE WHEN (SELECT decisions_distinct_groups FROM survivorship_stats) = 32 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T020', CASE WHEN (SELECT decisions_snapshot_rows FROM survivorship_stats) = (SELECT decisions_distinct_groups FROM survivorship_stats) * 16 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T021', CASE WHEN (SELECT non_null_rejected_candidates FROM survivorship_stats) = 2 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T022', CASE WHEN (SELECT unresolved_support_ties FROM survivorship_stats) = 1 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T023', CASE WHEN (SELECT core_rows FROM core_stats) = 32 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T024', CASE WHEN (SELECT core_distinct_ids FROM core_stats) = 32 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T025', CASE WHEN (SELECT core_distinct_match_groups FROM core_stats) = 32 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T026', CASE WHEN (SELECT core_mastered FROM core_stats) = 29 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T027', CASE WHEN (SELECT core_provisional FROM core_stats) = 2 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T028', CASE WHEN (SELECT core_review_required FROM core_stats) = 1 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T029', CASE WHEN (SELECT s0006_maturity FROM known_outcomes) = '2026-12-28' THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T030', CASE WHEN (SELECT s0007_rating FROM known_outcomes) = 'NULL' THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T031', CASE WHEN (SELECT s0007_status FROM known_outcomes) = 'REVIEW_REQUIRED' THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T032', CASE WHEN (SELECT s0008_instrument_type FROM known_outcomes) = 'CLO_TRANCHE' THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T033', CASE WHEN (SELECT s0009_effective_from FROM known_outcomes) = '2018-12-30' THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T034', CASE WHEN (SELECT s0010_currency FROM known_outcomes) = 'GBP' THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T035', CASE WHEN (SELECT targeted_lineage_count FROM lineage_counts) = 5 THEN 'PASS' ELSE 'FAIL' END
  UNION ALL SELECT 'T036', CASE WHEN (SELECT s0007_rating_lineage_count FROM lineage_counts) = 0 THEN 'PASS' ELSE 'FAIL' END
) tests;
