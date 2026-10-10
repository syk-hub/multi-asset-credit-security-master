# Batch 02 test plan

## Purpose and scope

Batch 02 is a deliberately small synthetic input set for exercising the
existing matching, data-quality, and survivorship workflow and recording
expected versus actual outcomes. It is a separate regression exercise, not a
revision of batch 01's fixture or expectations.

The fixture is generated locally by
`python/generate_validation_batch.py`; its inputs are validated by
`tests/batch_02/validate_batch_02_inputs.py`. This work does not change SQL,
run the batch 01 generator or validator, or connect to Snowflake.
The original inputs under `data/`, generator
`python/generate_synthetic_data.py`, validator
`tests/validate_generated_data.py`, and the fixed batch 01 assertions in SQL
09 remain unchanged.

## Batch identity and identifiers

All new security identifiers will use an unmistakable `B02-` prefix, for
example `B02-CUSIP-001`, `B02-ISIN-001`, `B02-ISSUER-001`, and
`B02-ALPHA-001`. They will not reuse batch 01's `SYN-CUSIP-*`,
`SYN-ISIN-*`, or `VEND-*` values. These are synthetic test identifiers, not
real-world identifiers.

The eventual three source files will retain batch 01's existing formats and
field conventions:

- `vendor_alpha.json`: newline-delimited JSON objects.
- `vendor_beta.json`: newline-delimited JSON objects.
- `legacy_security_master.csv`: a header row and the existing eight-column
  legacy schema.

The generator is `python/generate_validation_batch.py`. It writes only
beneath `data/batch_02/`, preserves those JSON and CSV formats, uses explicit
values and fixed timestamps for repeatable output, and never writes to or
overwrites batch 01's files. The batch-specific expectations live in
`tests/batch_02/`, with this plan's companion `expected_results.csv` and
input-only validator `validate_batch_02_inputs.py`; run notes and output
capture will live in `results/batch_02/`. The existing validator will remain
in `tests/` and its batch 01 checks will not be changed or repurposed for
these inputs.

## Execution environment

Batch 02 is planned for a separate Snowflake database named
`CREDIT_SECURITY_MASTER_BATCH_02`, so its objects and results do not overwrite
batch 01's `CREDIT_SECURITY_MASTER` objects. No database will be created in
this planning step.

The existing SQL scripts contain explicit `USE DATABASE
CREDIT_SECURITY_MASTER` statements and fully qualified references to that
database. Therefore, selecting the batch 02 database alone will not redirect
the current scripts. Before execution, a separate, reviewed run-time SQL
arrangement must direct the pipeline to the batch 02 database without changing
the batch 01 rules or running destructive DDL against batch 01. No such SQL
change or database-reference revision is part of this step.

SQL 09 embeds batch 01 record counts and known values, and the Python
validator reads the original `data/` paths and enforces batch 01 counts and
fixtures. They are regression checks for batch 01, not batch 02 acceptance
tests. Batch 02 will use its own targeted checks against the rule-level
outcomes below; do not change the current rules merely to satisfy a test.

## Cases

Each case has its own security identifiers and source rows; no source record
is shared across cases. The table below is the finalized fixture
specification. `—` means an explicit JSON null for a vendor identifier or an
empty CSV cell for a Legacy CUSIP. Each JSON row also has the common fields
described below. Within a case, all unlisted attributes agree; the only
deliberate disagreements are the values shown in the table. The second
B02-07 Alpha row has a distinct source key and exists to carry the malformed
date.

### Common exact input values

All vendor records use `source_system` `VENDOR_ALPHA` or `VENDOR_BETA`
according to feed, `issue_date` `2020-01-01`, `maturity_date` `2030-01-01`,
`coupon_rate` `5.0`, `coupon_type` `FIXED`, `seniority` `Senior Secured`,
`secured_flag` `true`, `credit_status` `PERFORMING`, `rating_agency`
`B02-RATING-AGENCY`, and `ingestion_timestamp`
`2026-10-06T00:00:00+00:00`. Unless overridden in the table, each vendor row
uses issuer `B02-ISSUER-CASEnn`, instrument name
`B02-ISSUER-CASEnn NOTE`, type `BOND`, CUSIP `B02-CUSIP-CASEnn`, ISIN
`B02-ISIN-CASEnn`, currency `USD`, rating `BBB`, and effective date
`2020-01-01`, with `nn` replaced by that row's two-digit case number.

Every Legacy row has source system `LEGACY` and the same issuer, instrument
type, rating agency and (unless overridden) instrument name, rating, and
CUSIP values as its corresponding case's common defaults. Legacy rows use
only the existing eight CSV columns; they do not supply ISIN, currency,
dates, or the other vendor-only attributes. `vendor_security_id` is exactly
the value in the table.

| Case | Source | vendor_security_id | CUSIP | ISIN | Type | Currency | Instrument name | Rating | effective_from |
|---|---|---|---|---|---|---|---|---|---|
| 01 | Alpha | B02-ALPHA-CASE01 | B02-CUSIP-CASE01 | B02-ISIN-CASE01 | BOND | USD | B02-ISSUER-CASE01 NOTE | BBB | 2020-01-01 |
| 01 | Beta | B02-BETA-CASE01 | B02-CUSIP-CASE01 | B02-ISIN-CASE01 | BOND | USD | B02-ISSUER-CASE01 NOTE | BBB | 2020-01-01 |
| 01 | Legacy | B02-LEGACY-CASE01 | B02-CUSIP-CASE01 | — | BOND | n/a | B02-ISSUER-CASE01 NOTE | BBB | n/a |
| 02 | Alpha | B02-ALPHA-CASE02 | B02-CUSIP-CASE02 | B02-ISIN-CASE02 | BOND | USD | B02-ISSUER-CASE02 ALPHA NAME | BBB | 2020-01-01 |
| 02 | Beta | B02-BETA-CASE02 | B02-CUSIP-CASE02 | B02-ISIN-CASE02 | BOND | USD | B02-ISSUER-CASE02 CONSENSUS NAME | BBB | 2020-01-01 |
| 02 | Legacy | B02-LEGACY-CASE02 | B02-CUSIP-CASE02 | — | BOND | n/a | B02-ISSUER-CASE02 CONSENSUS NAME | BBB | n/a |
| 03 | Alpha | B02-ALPHA-CASE03 | B02-CUSIP-CASE03 | B02-ISIN-CASE03 | BOND | USD | B02-ISSUER-CASE03 NOTE | AAA | 2020-01-01 |
| 03 | Beta | B02-BETA-CASE03 | B02-CUSIP-CASE03 | B02-ISIN-CASE03 | BOND | USD | B02-ISSUER-CASE03 NOTE | BBB | 2020-01-01 |
| 03 | Legacy | B02-LEGACY-CASE03 | B02-CUSIP-CASE03 | — | BOND | n/a | B02-ISSUER-CASE03 NOTE | BB | n/a |
| 04 | Alpha | B02-ALPHA-CASE04 | B02-CUSIP-CASE04 | B02-ISIN-CASE04 | BOND | USD | B02-ISSUER-CASE04 NOTE | BBB | 2020-01-01 |
| 04 | Beta | B02-BETA-CASE04 | B02-CUSIP-CASE04 | B02-ISIN-CASE04 | BOND | EUR | B02-ISSUER-CASE04 NOTE | BBB | 2020-01-01 |
| 04 | Legacy | B02-LEGACY-CASE04 | B02-CUSIP-CASE04 | — | BOND | n/a | B02-ISSUER-CASE04 NOTE | BBB | n/a |
| 05 | Alpha | B02-ALPHA-CASE05 | B02-CUSIP-CASE05 | B02-ISIN-CASE05 | BOND | ZZZ | B02-ISSUER-CASE05 NOTE | BBB | 2020-01-01 |
| 05 | Beta | B02-BETA-CASE05 | B02-CUSIP-CASE05 | B02-ISIN-CASE05 | BOND | GBP | B02-ISSUER-CASE05 NOTE | BBB | 2020-01-01 |
| 05 | Legacy | B02-LEGACY-CASE05 | B02-CUSIP-CASE05 | — | BOND | n/a | B02-ISSUER-CASE05 NOTE | BBB | n/a |
| 06 | Alpha | B02-ALPHA-CASE06 | B02-CUSIP-CASE06 | B02-ISIN-CASE06 | CLO | USD | B02-ISSUER-CASE06 NOTE | BBB | 2020-01-01 |
| 06 | Beta | B02-BETA-CASE06 | B02-CUSIP-CASE06 | B02-ISIN-CASE06 | CLO_TRANCHE | USD | B02-ISSUER-CASE06 NOTE | BBB | 2020-01-01 |
| 06 | Legacy | B02-LEGACY-CASE06 | B02-CUSIP-CASE06 | — | CLO | n/a | B02-ISSUER-CASE06 NOTE | BBB | n/a |
| 07 | Alpha | B02-ALPHA-CASE07 | B02-CUSIP-CASE07 | B02-ISIN-CASE07 | BOND | USD | B02-ISSUER-CASE07 NOTE | BBB | 2020-01-01 |
| 07 | Beta | B02-BETA-CASE07 | B02-CUSIP-CASE07 | B02-ISIN-CASE07 | BOND | USD | B02-ISSUER-CASE07 NOTE | BBB | 2022-05-06 |
| 07 | Alpha | B02-ALPHA-CASE07-INVALID | B02-CUSIP-CASE07 | B02-ISIN-CASE07 | BOND | USD | B02-ISSUER-CASE07 NOTE | BBB | not-a-date |
| 08 | Alpha | B02-ALPHA-CASE08 | B02-CUSIP-CASE08 | B02-ISIN-CASE08 | BOND | USD | B02-ISSUER-CASE08 NOTE | BBB | 2020-01-01 |
| 09 | Alpha | B02-ALPHA-CASE09 | — | — | BOND | USD | B02-ISSUER-CASE09 NOTE | BBB | 2020-01-01 |
| 10 | Alpha | B02-ALPHA-CASE10 | B02-CUSIP-CASE10 | B02-ISIN-CASE10-A | BOND | USD | B02-ISSUER-CASE10 NOTE | BBB | 2020-01-01 |
| 10 | Beta | B02-BETA-CASE10 | B02-CUSIP-CASE10 | B02-ISIN-CASE10-B | BOND | USD | B02-ISSUER-CASE10 NOTE | BBB | 2020-01-01 |
| 10 | Legacy | B02-LEGACY-CASE10 | B02-CUSIP-CASE10 | — | BOND | n/a | B02-ISSUER-CASE10 NOTE | BBB | n/a |
| 11 | Alpha | B02-ALPHA-CASE11 | B02-CUSIP-CASE11 | B02-ISIN-CASE11 | BOND | USD | B02-ISSUER-CASE11 NOTE | BBB | 2020-01-01 |
| 11 | Alpha | B02-ALPHA-CASE11 | B02-CUSIP-CASE11 | B02-ISIN-CASE11 | BOND | USD | B02-ISSUER-CASE11 NOTE | BBB | 2020-01-01 |
| 12 | Alpha | B02-ALPHA-CASE12 | B02-CUSIP-CASE12 | B02-ISIN-CASE12-SHARED | BOND | USD | B02-ISSUER-CASE12 NOTE | BBB | 2020-01-01 |
| 12 | Beta | B02-BETA-CASE12 | B02-CUSIP-CASE12 | B02-ISIN-CASE12-OTHER | BOND | USD | B02-ISSUER-CASE12 NOTE | BBB | 2020-01-01 |
| 12 | Beta | B02-BETA-CASE12-ISIN-ONLY | — | B02-ISIN-CASE12-SHARED | BOND | USD | B02-ISSUER-CASE12 NOTE | BBB | 2020-01-01 |

Cases 10 and 12 are the only CUSIPs associated with multiple non-null ISINs.
Case 12 uses a second Beta row for the ISIN-only record because the existing
Legacy schema has no ISIN column. The repeated source-record key is
intentional only in case 11. Batch totals are 14 Alpha JSON objects, 10 Beta
JSON objects, and 7 Legacy CSV data rows
(31 physical source rows total); these are input counts, not pipeline output
expectations.

### B02-01 — Agreement across sources

- **Source records:** The exact case 01 rows in the fixture table: Alpha,
  Beta, and Legacy for one shared
  `B02-CUSIP-*`, with matching issuer name, instrument name, and instrument
  type. Use the Legacy CSV only for fields it actually carries.
- **Existing rule:** SQL 05 groups records sharing a non-colliding CUSIP;
  SQL 06 accepts valid values and resolves a single distinct value.
- **Expected behavior:** The three rows receive one cross-source match group.
  The agreed valid attributes, including `B02-ISSUER-CASE01 NOTE`,
  `BOND`, and `BBB`, are selected; the legacy fields absent from its CSV row
  are not expected to be supplied by Legacy.
- **Check:** Inspect `SOURCE_MATCH_ASSIGNMENTS` and
  `MATCH_GROUP_SUMMARY` for one group with all three source systems, then
  inspect that group's decisions and CORE values for the agreed attributes.
- **Expectation:** Confirmed by the current matching and single-value
  survivorship logic.

### B02-02 — Unique attribute winner supported by two of three sources

- **Source records:** The exact case 02 rows in the fixture table: Alpha,
  Beta, and Legacy sharing one
  `B02-CUSIP-*`; give one tested, Legacy-supported text attribute (such as
  `instrument_name`) one value in Alpha and a different value in both Beta and
  Legacy.
- **Existing rule:** SQL 06 counts distinct supporting `source_system` values
  per valid canonical value and selects a unique maximum-support value.
- **Expected behavior:** `B02-ISSUER-CASE02 CONSENSUS NAME` is selected with
  two distinct
  source systems of support; Alpha's alternative does not win.
- **Check:** Inspect the attribute decision for `DISTINCT_SOURCE_MAJORITY`,
  `selected_value_source_count = 2`, and the two supporting source systems in
  attribute lineage.
- **Expectation:** Confirmed by the current distinct-source majority rule.

### B02-03 — Equal three-way attribute support remains unresolved

- **Source records:** The exact case 03 rows in the fixture table: Alpha,
  Beta, and Legacy sharing one
  `B02-CUSIP-*`; supply three different non-empty values for a Legacy-supported
  attribute such as `rating`.
- **Existing rule:** SQL 06 selects only a unique highest source count; it
  labels a tie `UNRESOLVED_SUPPORT_TIE`. SQL 08 marks a record with an
  unresolved tie `REVIEW_REQUIRED`.
- **Expected behavior:** No rating is selected (`selected_value` is NULL and
  the method is `UNRESOLVED_SUPPORT_TIE`), no selected-value rating
  lineage is emitted, and the security is review-required because of the tie.
- **Check:** Inspect the rating decision, the corresponding CORE row and
  status, and the absence of rating lineage.
- **Expectation:** Confirmed by current survivorship and CORE status logic.

### B02-04 — Legacy null is not a conflicting vote

- **Source records:** The exact case 04 rows in the fixture table: Alpha and
  Beta share a CUSIP with two different valid currencies; Legacy also has
  that CUSIP. Currency
  is not present in the Legacy CSV schema, and SQL 03 supplies a NULL legacy
  currency.
- **Existing rule:** SQL 03 represents legacy currency as NULL; SQL 06
  includes only `candidate_is_valid = TRUE` values when counting support.
- **Expected behavior:** The absent Legacy value contributes neither a third
  value nor support for either vendor's value. With Alpha and Beta providing
  `USD` and `EUR` respectively, the tested currency remains a 1-to-1
  unresolved support tie and has no selected value.
- **Check:** Inspect the Legacy currency candidate as invalid/null, then check
  that only two valid vendor candidates and two distinct valid values
  contribute to the unresolved decision.
- **Expectation:** Confirmed by the explicit NULL placeholder and valid
  candidate filter.

### B02-05 — Invalid value is rejected while a valid alternative survives

- **Source records:** The exact case 05 rows in the fixture table: Alpha's
  currency is `ZZZ`, Beta's is `GBP`, and Legacy also has the CUSIP but no
  currency column.
- **Existing rule:** SQL 06 permits only `USD`, `EUR`, `GBP`, and `JPY` as
  currency candidates and excludes invalid candidates from decision support.
- **Expected behavior:** `ZZZ` is marked invalid and does not block selection
  of the sole valid value, `GBP`. The rejected candidate remains visible for
  audit; this is not a rule change.
- **Check:** Inspect the Alpha candidate and rejection reason, the currency
  decision, and CORE currency and lineage for `GBP`.
- **Expectation:** Confirmed by the currency validity domain and valid-only
  survivorship logic.

### B02-06 — Instrument-type canonicalization

- **Source records:** The exact case 06 rows in the fixture table: Alpha and
  Legacy report `CLO`, while Beta reports `CLO_TRANCHE`.
- **Existing rule:** SQL 03 uppercases instrument type. SQL 06 canonicalizes
  both `CLO` and `CLO_TRANCHE` to `CLO_TRANCHE` before support is counted.
- **Expected behavior:** The canonical value is `CLO_TRANCHE`; equivalent
  source spellings do not create a survivorship conflict.
- **Check:** Compare each source candidate's original and canonical values,
  then inspect the selected decision and CORE instrument type.
- **Expectation:** Confirmed by the current canonicalization rule.

### B02-07 — Latest valid effective date wins

- **Source records:** The exact case 07 rows in the fixture table: Alpha
  reports `2020-01-01`, Beta reports `2022-05-06`, and a second Alpha record
  with a distinct vendor ID reports `not-a-date`. Both Alpha rows share
  identifiers, and all ordinary attributes agree.
- **Existing rule:** SQL 03 parses `effective_from` using `TRY_TO_DATE`;
  SQL 04 flags a non-empty unparseable raw date as DQ006. SQL 06 excludes
  invalid candidates and chooses the maximum valid date for this attribute.
- **Expected behavior:** `2022-05-06` is selected with
  `LATEST_VALID_DATE`. `not-a-date` is not selected or counted as valid
  support.
- **Check:** Inspect raw and typed staging values, DQ006 if an invalid raw
  value is included, candidate validity, and the `LATEST_VALID_DATE` decision
  and CORE date.
- **Expectation:** Confirmed for selecting the latest parseable date; any
  invalid raw date's DQ reporting is separately confirmed by DQ006.

### B02-08 — Security present in only one source

- **Source records:** The single Alpha case 08 row from the fixture table,
  with a unique CUSIP and no
  corresponding Beta or Legacy row. Supply the ordinary required security
  attributes so the status test is not confounded by missing core fields.
- **Existing rule:** SQL 05 labels a non-ambiguous group with only one
  distinct source as `SINGLE_SOURCE_ONLY`; SQL 06 includes such groups in
  survivorship; SQL 08 gives them `PROVISIONAL_SINGLE_SOURCE` status unless
  other review conditions apply.
- **Expected behavior:** The record remains a distinct
  `SINGLE_SOURCE_ONLY` group and has CORE status
  `PROVISIONAL_SINGLE_SOURCE`, not cross-source matched.
- **Check:** Inspect the assignment status, decision eligibility, and CORE
  `match_status` and `master_record_status`.
- **Expectation:** Confirmed by the matching and CORE status conditions.

### B02-09 — Both matching identifiers are missing

- **Source records:** The single Alpha case 09 row from the fixture table,
  with `synthetic_cusip` and
  `synthetic_isin` both null, and no duplicate copy in another source.
- **Existing rule:** SQL 04 emits DQ003 when both identifiers are null; SQL 05
  assigns key type `NONE` and status `NO_IDENTIFIER`; SQL 06 excludes
  `NO_IDENTIFIER` assignments from survivorship candidates.
- **Expected behavior:** The row is flagged for missing identifiers and is
  not silently matched or included in a CORE security group.
- **Check:** Locate its DQ003 row and `NO_IDENTIFIER` assignment, then verify
  it does not appear among survivorship candidates or eligible CORE groups.
- **Expectation:** Confirmed by current DQ, matching, and eligibility logic.

### B02-10 — One CUSIP associated with multiple ISINs

- **Source records:** The exact case 10 rows in the fixture table: Alpha and
  Beta share `B02-CUSIP-CASE10` with ISINs `B02-ISIN-CASE10-A` and
  `B02-ISIN-CASE10-B`; Legacy has the CUSIP and no ISIN.
- **Existing rule:** SQL 05 counts distinct non-null ISINs per normalized
  CUSIP. It splits identified rows by ISIN when that count exceeds one and
  assigns rows lacking an ISIN to an ambiguous-CUSIP key.
- **Expected behavior:** The two identified rows belong to distinct groups
  `ISIN|B02-ISIN-CASE10-A` and `ISIN|B02-ISIN-CASE10-B`, rather than being
  merged solely by CUSIP. The Legacy row
  is `AMBIGUOUS_IDENTIFIER`, not force-matched to either group, and excluded
  from survivorship.
- **Check:** Inspect the CUSIP profile's associated ISINs, each source
  assignment's key type, value and group, and the Legacy assignment/status.
- **Expectation:** Confirmed as the behavior directly encoded in SQL 05;
  this test does not declare that any broader business interpretation of an
  ISIN collision is correct.

### B02-11 — Duplicate source-record keys

- **Source records:** The two identical Alpha case 11 rows in the fixture
  table share `VENDOR_ALPHA|B02-ALPHA-CASE11`; other identifiers and
  attributes match, so the only deliberate condition is the repeated source
  key.
- **Existing rule:** SQL 04's DQ011 flags every row whose non-null
  `source_record_key` occurs more than once. SQL 05 and SQL 06 operate on
  physical source rows and group by match key/source coverage, not by a
  unique-key remediation step.
- **Expected behavior:** DQ011 reports both physical duplicate rows for
  `VENDOR_ALPHA|B02-ALPHA-CASE11`. Whether both
  physical rows remain represented independently downstream, affect candidate
  counts/lineage, or are otherwise harmless is not asserted in advance.
- **Check:** Verify both physical records and their DQ011 results using
  source file and row number; trace them through assignments, candidates,
  decisions, and lineage. Record whether assignment-to-input row
  reconciliation still holds and whether duplicate rows alter outcomes.
- **Expectation:** DQ011 detection is confirmed; downstream duplicate
  handling requires investigation.

### B02-12 — Collision-split record and ISIN-only row share an ISIN

- **Source records:** The exact case 12 rows in the fixture table. Alpha and
  Beta share `B02-CUSIP-CASE12` with different ISINs. A second Beta row has
  no CUSIP and Alpha's `B02-ISIN-CASE12-SHARED`. All three source-record keys
  are distinct. The extra Beta row is necessary because the Legacy CSV
  schema has no ISIN column.
- **Existing rule:** SQL 05 assigns a collision row with an ISIN the key
  `ISIN|<ISIN>` and assigns an ISIN-only row the same key format. Its final
  assignment query joins group metrics by `match_group_key`.
- **Expected behavior:** Every physical staging row is expected to receive
  exactly one matching assignment; validate this invariant by grouping on
  source file, source row number, and load timestamp. Separately, both rows
  with the shared ISIN are assigned key `ISIN|B02-ISIN-CASE12-SHARED` by
  construction. Investigate whether this
  intended key reuse yields a single coherent assignment per physical row,
  creates an unintended duplicate assignment, or has other downstream
  effects. Do not label a shared group itself a defect without checking the
  row-level evidence and intended match semantics.
- **Check:** Reconcile each physical input row to `SOURCE_MATCH_ASSIGNMENTS`
  using source file, source row number, and load timestamp; compare assignment
  counts to source rows; inspect both shared-ISIN assignments, group metrics,
  match-group summary, survivorship candidates, and CORE rows. Record whether
  one input row appears more than once and whether the two shared-ISIN rows
  are treated as one group.
- **Expectation:** Investigate. The SQL's key expressions predict a shared
  ISIN group, but the absence or presence of duplicate assignments and the
  business correctness of that outcome must be established from execution.

## Result recording

`tests/batch_02/expected_results.csv` provides one or more focused checks per
case. `CONFIRMED` means the stated expected result follows a rule that is
explicitly encoded in the existing SQL; it does not mean batch 02 has already
been run. `INVESTIGATE` marks behavior for which the outcome or its correct
interpretation must be established during execution. Actuals, evidence,
discrepancies, and any reruns belong in `docs/batch_02_investigation.md` and
eventually `results/batch_02/`.
