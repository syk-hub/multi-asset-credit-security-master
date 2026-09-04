-- 07_materialize_survivorship.sql
-- Batch-performance snapshots for CONTROL survivorship views

USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER;
USE SCHEMA CONTROL;

/*
These TRANSIENT snapshots provide a reproducible, batch-materialized
copy of the governed CONTROL views to improve downstream query
performance for CORE consumers.

Notes:
- These are batch-performance snapshots of governed CONTROL views.
- Rerun this script (SQL 07) after SQL 06 whenever upstream data
  or rules change to refresh snapshots.
- CREATE OR REPLACE refreshes the complete snapshot atomically.
- TRANSIENT tables reduce storage-protection overhead and are
  reproducible from the audit views; they are NOT independent
  sources of truth.
*/

-- A) Candidates snapshot
CREATE OR REPLACE TRANSIENT TABLE SURVIVORSHIP_CANDIDATES_SNAPSHOT
DATA_RETENTION_TIME_IN_DAYS = 1
AS
SELECT
  CURRENT_TIMESTAMP() AS snapshot_created_at,
  c.*
FROM SURVIVORSHIP_CANDIDATES c;

-- B) Decisions snapshot
CREATE OR REPLACE TRANSIENT TABLE SURVIVORSHIP_DECISIONS_SNAPSHOT
DATA_RETENTION_TIME_IN_DAYS = 1
AS
SELECT
  CURRENT_TIMESTAMP() AS snapshot_created_at,
  d.*
FROM SURVIVORSHIP_DECISIONS d;

-- Verification queries

-- candidate snapshot row count
SELECT COUNT(*) AS candidate_snapshot_row_count FROM SURVIVORSHIP_CANDIDATES_SNAPSHOT;

-- decision snapshot row count
SELECT COUNT(*) AS decision_snapshot_row_count FROM SURVIVORSHIP_DECISIONS_SNAPSHOT;

-- distinct decision match groups
SELECT COUNT(DISTINCT match_group_key) AS distinct_decision_match_groups
FROM SURVIVORSHIP_DECISIONS_SNAPSHOT;

-- min/max snapshot_created_at
SELECT MIN(snapshot_created_at) AS min_snapshot_created_at, MAX(snapshot_created_at) AS max_snapshot_created_at
FROM (
  SELECT snapshot_created_at FROM SURVIVORSHIP_CANDIDATES_SNAPSHOT
  UNION ALL
  SELECT snapshot_created_at FROM SURVIVORSHIP_DECISIONS_SNAPSHOT
);

-- Reconciliation: decision snapshot rows = distinct decision match groups * 16
WITH counts AS (
  SELECT
    (SELECT COUNT(DISTINCT match_group_key) FROM SURVIVORSHIP_DECISIONS_SNAPSHOT) AS distinct_groups,
    (SELECT COUNT(*) FROM SURVIVORSHIP_DECISIONS_SNAPSHOT) AS total_decisions
)
SELECT
  distinct_groups,
  total_decisions,
  distinct_groups * 16 AS expected_total,
  CASE WHEN total_decisions = distinct_groups * 16 THEN 'TRUE' ELSE 'FALSE' END AS matches_expected
FROM counts;

-- Expected logical result when running against our test data: 512 = 32 * 16
