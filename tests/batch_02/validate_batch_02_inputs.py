"""Validate the generated batch_02 input files without Snowflake access."""
from __future__ import annotations

import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data" / "batch_02"
LEGACY_FIELDS = (
    "vendor_security_id",
    "synthetic_cusip",
    "issuer_name",
    "instrument_name",
    "instrument_type",
    "rating",
    "rating_agency",
    "source_system",
)
VENDOR_FIELDS = {
    "vendor_security_id",
    "issuer_name",
    "instrument_name",
    "instrument_type",
    "synthetic_cusip",
    "synthetic_isin",
    "currency",
    "issue_date",
    "maturity_date",
    "coupon_rate",
    "coupon_type",
    "seniority",
    "secured_flag",
    "credit_status",
    "rating",
    "rating_agency",
    "effective_from",
    "source_system",
    "ingestion_timestamp",
}
EXPECTED_COUNTS = {"ALPHA": 14, "BETA": 10, "LEGACY": 7}
EXPECTED_CASE_SOURCES = {
    1: ("ALPHA", "BETA", "LEGACY"),
    2: ("ALPHA", "BETA", "LEGACY"),
    3: ("ALPHA", "BETA", "LEGACY"),
    4: ("ALPHA", "BETA", "LEGACY"),
    5: ("ALPHA", "BETA", "LEGACY"),
    6: ("ALPHA", "BETA", "LEGACY"),
    7: ("ALPHA", "ALPHA", "BETA"),
    8: ("ALPHA",),
    9: ("ALPHA",),
    10: ("ALPHA", "BETA", "LEGACY"),
    11: ("ALPHA", "ALPHA"),
    12: ("ALPHA", "BETA", "BETA"),
}
SHARED_ATTRIBUTES = (
    "issuer_name",
    "instrument_name",
    "instrument_type",
    "synthetic_cusip",
    "synthetic_isin",
    "currency",
    "issue_date",
    "maturity_date",
    "coupon_rate",
    "coupon_type",
    "seniority",
    "secured_flag",
    "credit_status",
    "rating",
    "rating_agency",
    "effective_from",
)
ALLOWED_VARIATIONS = {
    2: {"instrument_name"},
    3: {"rating"},
    4: {"currency"},
    5: {"currency"},
    6: {"instrument_type"},
    7: {"effective_from"},
    9: {"synthetic_cusip", "synthetic_isin"},
    10: {"synthetic_isin"},
    12: {"synthetic_cusip", "synthetic_isin"},
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def load_ndjson(path: Path, expected_source_system: str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as source:
        for line_number, line in enumerate(source, start=1):
            require(bool(line.strip()), f"{path.name}:{line_number} is a blank line")
            try:
                record = json.loads(line)
            except json.JSONDecodeError as error:
                raise SystemExit(
                    f"FAIL: invalid JSON at {path.name}:{line_number}: {error}"
                ) from error
            require(isinstance(record, dict), f"{path.name}:{line_number} is not an object")
            require(
                set(record) == VENDOR_FIELDS,
                f"{path.name}:{line_number} has unexpected JSON fields",
            )
            require(
                record["source_system"] == expected_source_system,
                f"{path.name}:{line_number} has the wrong source_system",
            )
            require(
                record["ingestion_timestamp"] == "2026-10-06T00:00:00+00:00",
                f"{path.name}:{line_number} has a non-fixed ingestion timestamp",
            )
            records.append(record)
    return records


def load_legacy(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source)
        require(
            tuple(reader.fieldnames or ()) == LEGACY_FIELDS,
            "legacy CSV header does not match the existing eight-column schema",
        )
        records = list(reader)
    for index, record in enumerate(records, start=2):
        require(
            None not in record and set(record) == set(LEGACY_FIELDS),
            f"legacy_security_master.csv:{index} has an invalid column count",
        )
        require(record["source_system"] == "LEGACY", f"legacy CSV row {index} is not LEGACY")
    return records


def case_number(record: dict[str, Any]) -> int:
    match = re.search(r"CASE(\d{2})", record["vendor_security_id"])
    require(match is not None, f"missing CASEnn tag in {record['vendor_security_id']}")
    return int(match.group(1))


def main() -> None:
    alpha = load_ndjson(DATA_DIR / "vendor_alpha.json", "VENDOR_ALPHA")
    beta = load_ndjson(DATA_DIR / "vendor_beta.json", "VENDOR_BETA")
    legacy = load_legacy(DATA_DIR / "legacy_security_master.csv")
    require(len(alpha) == EXPECTED_COUNTS["ALPHA"], "Alpha row count must be exactly 14")
    require(len(beta) == EXPECTED_COUNTS["BETA"], "Beta row count must be exactly 9")
    require(len(legacy) == EXPECTED_COUNTS["LEGACY"], "Legacy data row count must be exactly 8")

    records: list[dict[str, Any]] = alpha + beta + legacy
    source_names = {
        "VENDOR_ALPHA": "ALPHA",
        "VENDOR_BETA": "BETA",
        "LEGACY": "LEGACY",
    }
    by_case: dict[int, list[dict[str, Any]]] = defaultdict(list)
    source_record_keys: Counter[str] = Counter()
    key_cases: dict[str, set[int]] = defaultdict(set)
    identifiers_by_cusip: dict[str, set[str]] = defaultdict(set)
    cusip_cases: dict[str, set[int]] = defaultdict(set)

    for record in records:
        number = case_number(record)
        require(number in EXPECTED_CASE_SOURCES, f"unexpected case number {number}")
        by_case[number].append(record)
        source_system = record["source_system"]
        require(source_system in source_names, f"unexpected source_system {source_system}")
        source_name = source_names[source_system]
        vendor_id = record["vendor_security_id"]
        require(
            vendor_id.startswith(f"B02-{source_name}-CASE{number:02d}"),
            f"{vendor_id} does not identify its source and case",
        )
        source_key = f"{source_system}|{vendor_id}"
        source_record_keys[source_key] += 1
        key_cases[source_key].add(number)
        cusip = record.get("synthetic_cusip") or None
        isin = record.get("synthetic_isin") or None
        if cusip:
            require(
                cusip.startswith(f"B02-CUSIP-CASE{number:02d}"),
                f"{vendor_id} has a CUSIP outside case {number:02d}",
            )
            cusip_cases[cusip].add(number)
            if isin:
                identifiers_by_cusip[cusip].add(isin)

    require(set(by_case) == set(range(1, 13)), "expected each case 01 through 12")
    for number, expected_sources in EXPECTED_CASE_SOURCES.items():
        observed_sources = tuple(
            sorted(source_names[record["source_system"]] for record in by_case[number])
        )
        require(
            observed_sources == tuple(sorted(expected_sources)),
            f"case {number:02d} source rows do not match the designed inventory",
        )

    duplicate_keys = {key: count for key, count in source_record_keys.items() if count > 1}
    expected_duplicate = {"VENDOR_ALPHA|B02-ALPHA-CASE11": 2}
    require(
        duplicate_keys == expected_duplicate,
        f"unexpected duplicate source_record_keys: {duplicate_keys}",
    )
    require(
        all(key_cases[key] == {11} for key in duplicate_keys),
        "the intended duplicate source_record_key occurs outside B02-11",
    )

    multi_isin_cusips = {
        cusip: values
        for cusip, values in identifiers_by_cusip.items()
        if len(values) > 1
    }
    expected_multi_isin = {
        "B02-CUSIP-CASE10": {"B02-ISIN-CASE10-A", "B02-ISIN-CASE10-B"},
        "B02-CUSIP-CASE12": {
            "B02-ISIN-CASE12-SHARED",
            "B02-ISIN-CASE12-OTHER",
        },
    }
    require(
        multi_isin_cusips == expected_multi_isin,
        f"multi-ISIN CUSIP collisions differ from cases 10 and 12: {multi_isin_cusips}",
    )
    require(
        all(len(cases) == 1 for cases in cusip_cases.values()),
        "a CUSIP is reused across separate test cases",
    )

    for number, case_records in by_case.items():
        variations = ALLOWED_VARIATIONS.get(number, set())
        for attribute in SHARED_ATTRIBUTES:
            values = {
                record[attribute]
                for record in case_records
                if attribute in record and record[attribute] not in (None, "")
            }
            require(
                len(values) <= 1 or attribute in variations,
                f"case {number:02d} has an unintended {attribute} disagreement: {values}",
            )

    def source_rows(number: int, source_name: str) -> list[dict[str, Any]]:
        expected_source_system = {
            "ALPHA": "VENDOR_ALPHA",
            "BETA": "VENDOR_BETA",
            "LEGACY": "LEGACY",
        }[source_name]
        return [
            record
            for record in by_case[number]
            if record["source_system"] == expected_source_system
        ]

    # Verify the specific deliberately planted conditions and exact values.
    require(
        len({record["synthetic_cusip"] for record in by_case[1]}) == 1
        and len({record["instrument_name"] for record in by_case[1]}) == 1,
        "B02-01 records do not agree on their shared values",
    )
    require(
        [record["instrument_name"] for record in source_rows(2, "ALPHA") + source_rows(2, "BETA")]
        == ["B02-ISSUER-CASE02 ALPHA NAME", "B02-ISSUER-CASE02 CONSENSUS NAME"]
        and source_rows(2, "LEGACY")[0]["instrument_name"]
        == "B02-ISSUER-CASE02 CONSENSUS NAME",
        "B02-02 majority values are incorrect",
    )
    require(
        [record["rating"] for record in source_rows(3, "ALPHA") + source_rows(3, "BETA")]
        == ["AAA", "BBB"]
        and source_rows(3, "LEGACY")[0]["rating"] == "BB",
        "B02-03 three-way rating tie values are incorrect",
    )
    require(
        [record["currency"] for record in source_rows(4, "ALPHA") + source_rows(4, "BETA")]
        == ["USD", "EUR"],
        "B02-04 currency tie values are incorrect",
    )
    require(
        [record["currency"] for record in source_rows(5, "ALPHA") + source_rows(5, "BETA")]
        == ["ZZZ", "GBP"],
        "B02-05 invalid and valid currency values are incorrect",
    )
    require(
        {record["instrument_type"] for record in by_case[6]}
        == {"CLO", "CLO_TRANCHE"},
        "B02-06 normalization spellings are incorrect",
    )
    require(
        {record["effective_from"] for record in by_case[7]}
        == {"2020-01-01", "2022-05-06", "not-a-date"},
        "B02-07 effective_from values are incorrect",
    )
    require(
        len(by_case[8]) == 1 and by_case[8][0]["source_system"] == "VENDOR_ALPHA",
        "B02-08 must contain only one Alpha row",
    )
    require(
        len(by_case[9]) == 1
        and by_case[9][0]["synthetic_cusip"] is None
        and by_case[9][0]["synthetic_isin"] is None,
        "B02-09 must have both identifiers missing",
    )
    require(
        len(source_rows(10, "LEGACY")) == 1
        and source_rows(10, "LEGACY")[0]["synthetic_cusip"] == "B02-CUSIP-CASE10",
        "B02-10 Legacy row must lack ISIN while retaining the colliding CUSIP",
    )
    require(
        len(source_rows(11, "ALPHA")) == 2
        and source_rows(11, "ALPHA")[0] == source_rows(11, "ALPHA")[1],
        "B02-11 must contain exactly two identical physical source records",
    )
    require(
        source_rows(12, "ALPHA")[0]["synthetic_isin"]
        == source_rows(12, "BETA")[1]["synthetic_isin"]
        == "B02-ISIN-CASE12-SHARED"
        and source_rows(12, "BETA")[1]["synthetic_cusip"] is None,
        "B02-12 shared-ISIN and ISIN-only records are not as designed",
    )

    print("Batch 02 input validation passed.")
    print(f"Vendor alpha rows: {len(alpha)}")
    print(f"Vendor beta rows: {len(beta)}")
    print(f"Legacy CSV data rows: {len(legacy)}")
    print(f"Total physical source rows: {len(records)}")
    print("Validated 12 isolated cases; duplicate source key only in B02-11.")
    print("Multi-ISIN CUSIP collisions occur only in B02-10 and B02-12.")


if __name__ == "__main__":
    main()
