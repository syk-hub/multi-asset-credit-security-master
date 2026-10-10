# Batch 02 investigation

## Purpose

Record the batch_02 synthetic input design, execution evidence, actual versus
expected outcomes, discrepancies, and investigation for the Snowflake
security-master workflow. Batch 02 is isolated from batch 01; the original
batch 01 inputs, generator, validator, SQL, and validation expectations were
not changed.

The batch_02 testing phase is complete. Defects and unexplained
reconciliation discrepancies remain open; completion does not mean all tests
passed.

## Input batch

**Batch identity:** batch_02
**Synthetic identifier prefix:** `B02-`
**Snowflake database:** `CREDIT_SECURITY_MASTER_BATCH_02`
**Snowflake execution:** Completed October 9, 2026, Pacific time

Files:

- Generator: `python/generate_validation_batch.py`
- Source inputs: `data/batch_02/`
- Expected checks: `tests/batch_02/expected_results.csv`
- Input validator: `tests/batch_02/validate_batch_02_inputs.py`
- Execution SQL: `snowflake/batch_02/`
- Assertion report: `tests/batch_02/actual_assertion_results.txt`
- Investigation report: `tests/batch_02/actual_investigation_results.txt`

The batch contains 14 Alpha JSON objects, 10 Beta JSON objects, and 7 Legacy
CSV data rows (31 physical input rows). The Legacy CSV retains the original
eight-column schema; the B02-12 ISIN-only row is consequently a second Beta
JSON record.

Both actual-result text reports are **copied CoCo reports, not direct
Snowflake result exports**. They record the supplied query outputs. The
investigation report distinguishes observed facts from hypotheses about
their cause.

## Expected results

The case design is in `docs/batch_02_test_plan.md`, with 26 focused
assertions in `tests/batch_02/expected_results.csv`. Of those, 24 are
CONFIRMED PASS/FAIL assertions and 2 are INVESTIGATE diagnostics. The four
RAW/STAGING preparation checks are reported separately from the CSV-backed
assertions.

## Execution steps

Execution completed in the isolated database on October 9, 2026, Pacific
time. The prepared order was setup, RAW preparation, upload pause, RAW
loading, staging transformations, data-quality controls, matching,
survivorship decisions, snapshots, CORE, and batch_02 validation. No SQL
processing rules were changed during the run.

## Actual results

### Preparation counts

All four preparation checks passed:

| Check | Expected | Observed | Status |
|---|---:|---:|---|
| RAW Alpha | 14 | 14 | PASS |
| RAW Beta | 10 | 10 | PASS |
| RAW Legacy | 7 | 7 | PASS |
| STAGING total | 31 | 31 | PASS |

### Scenario assertions

The 24 CSV-backed assertions produced **23 PASS and 1 FAIL**. The failure was
B02-12-A, the invariant that every physical staging row receives exactly
one matching assignment. The summary was 31 physical rows and 33 assignment
rows.

### Matching and decision reconciliation

The supplied assignment diagnostics show that two physical CASE12 rows each
receive two assignments:

- Alpha `B02-ALPHA-CASE12`, `vendor_alpha.json` row 14.
- Beta `B02-BETA-CASE12-ISIN-ONLY`, `vendor_beta.json` row 10.

The duplicate assignment rows for each physical row have identical
`match_group_key`, `match_key_value`, and `match_status`. The assignment
invariant is violated; shared group membership does not make duplicate
assignments acceptable.

Decision reconciliation reported 256 decision rows, while 13 distinct
eligible groups multiplied by 16 attributes yields 208 expected rows.
The comparison failed. The difference is 48 rows.

### CORE

The supplied CORE summary reported 13 records:

| Status | Observed records |
|---|---:|
| MASTERED | 5 |
| PROVISIONAL_SINGLE_SOURCE | 6 |
| REVIEW_REQUIRED | 2 |

No duplicate security-master IDs were reported.

### CASE11 duplicate source-record key

DQ011 detected both duplicate Alpha source rows with key
`VENDOR_ALPHA|B02-ALPHA-CASE11`. The supplied downstream observations were:

- 32 survivorship candidate rows.
- 16 survivorship decision rows for the match group.
- `selected_value_source_count` remained 1 across the reported decisions.
- 32 selected-value lineage rows.
- 1 CORE record.

The detailed decision report showed two valid candidates per attribute, one
distinct valid value, and one distinct supporting source system. The lineage
report showed two physical-row lineage entries per attribute. The duplicate
records are retained through candidates and lineage; their repetition does
not increase the distinct-source support count above 1.

See the copied CoCo reports in
`tests/batch_02/actual_assertion_results.txt` and
`tests/batch_02/actual_investigation_results.txt` for the transcribed
assertion rows and detailed diagnostic output.

## Discrepancies and investigation

### Observed

- The batch_02 validation reported B02-12-A FAIL: two physical CASE12 rows
  receive two assignments each, producing 33 assignments from 31 physical
  inputs.
- The decision reconciliation reported 256 rows versus 208 expected for 13
  groups times 16 attributes.
- CASE11's duplicate rows were detected by DQ011 and remained visible in
  survivorship candidates and selected-value lineage. Distinct-source
  support remained 1.
- CORE reported 13 records, with 5 MASTERED, 6 PROVISIONAL_SINGLE_SOURCE,
  and 2 REVIEW_REQUIRED; no duplicate IDs were reported.

### Inferred or unconfirmed

The exact cause of the 256-versus-208 decision reconciliation discrepancy
remains **unconfirmed**. A fan-out related to collision-split/shared-ISIN
groups is a hypothesis only; the copied reports do not establish the root
cause. It must be verified from the executed query/view definitions and
physical row-level evidence before being treated as a defect explanation.

The CASE12 assignment duplication is an observed defect against the
one-assignment-per-physical-row invariant. The reason for the duplication
and the appropriate remediation remain open. No matching, survivorship, or
CORE rule was changed to suppress the observation.

For CASE11, duplicate candidate and lineage rows are observed, while the
appropriate business policy for handling duplicate source-record keys
remains a separate open question.

## Changes and rerun results

No processing-rule changes or reruns are recorded. The batch_02 testing
phase is complete with defects open. Scenario results are not an all-pass
outcome: 23 PASS and 1 FAIL; all four preparation checks passed.

## Limitations

- Actual result reports are copied CoCo reports, not direct Snowflake result
  exports.
- The cause of the decision reconciliation discrepancy is not confirmed.
- The CASE12 assignment defect and duplicate-key downstream policy remain
  open; no fix was attempted as part of this experiment.
- This experiment does not change or replace batch 01 validation
  expectations.
