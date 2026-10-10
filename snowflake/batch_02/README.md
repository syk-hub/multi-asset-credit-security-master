# Batch 02 Snowflake execution

**Execution status: Completed October 9, 2026, Pacific time.**
The batch_02 test phase is complete; defects remain open and not all checks
passed. No processing rules were changed as part of this experiment.

The scripts target the isolated database `CREDIT_SECURITY_MASTER_BATCH_02`.
They preserve existing SQL 01–08 matching, DQ, survivorship, and CORE rules.
No batch 01 SQL or validation expectations were changed.

## Execution order used

1. `01_setup.sql`
2. `02a_raw_preparation.sql`
3. **UPLOAD PAUSE:** Uploaded
   `data/batch_02/vendor_alpha.json`,
   `data/batch_02/vendor_beta.json`, and
   `data/batch_02/legacy_security_master.csv` to
   `CREDIT_SECURITY_MASTER_BATCH_02.RAW.CSM_INTERNAL_STAGE` under
   `batch_02/`.
4. `02b_raw_loading.sql`
5. `03_staging_transformations.sql`
6. `04_data_quality_controls.sql`
7. `05_cross_source_matching.sql`
8. `06_survivorship_decisions.sql`
9. `07_materialize_survivorship.sql`
10. `08_core_security_master.sql`
11. `09_batch_02_validation.sql`

## Observed results

The four preparation checks passed: RAW Alpha 14, RAW Beta 10, RAW Legacy 7,
and STAGING total 31.

The 24 scenario assertions reported 23 PASS and 1 FAIL. B02-12-A failed:
two CASE12 physical rows each received two matching assignments, resulting
in 33 assignments from 31 physical inputs. The exact-one-assignment invariant
was not waived.

Decision reconciliation failed: 256 rows were reported versus 208 expected
for 13 distinct groups times 16 attributes. The exact cause remains
unconfirmed; no speculative explanation is treated as established.

CORE reported 13 records: 5 MASTERED, 6 PROVISIONAL_SINGLE_SOURCE, and 2
REVIEW_REQUIRED. No duplicate security-master IDs were reported.

For CASE11, DQ011 detected both duplicate rows. The supplied investigation
reports show 32 candidates, 16 decisions, 32 selected-value lineage rows,
and one CORE record. Distinct-source support remained 1; duplicate physical
rows remained represented in candidates and lineage.

Detailed reports:

- `tests/batch_02/actual_assertion_results.txt`
- `tests/batch_02/actual_investigation_results.txt`
- `docs/batch_02_investigation.md`

Both text reports are copied CoCo reports, not direct Snowflake result
exports. Observed outcomes and unconfirmed causal hypotheses are identified
separately. The test phase is complete with defects open; results must not be
described as all passing.
