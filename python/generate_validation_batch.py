"""Generate the deterministic batch_02 synthetic security-master inputs.

Run from any directory with:
    python python/generate_validation_batch.py

This generator writes only beneath data/batch_02/ and does not use the
batch_01 generator.
"""
from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any, Optional

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "data" / "batch_02"
FIXED_TIMESTAMP = "2026-10-06T00:00:00+00:00"
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


def make_vendor_record(
    source: str,
    case_number: int,
    overrides: Optional[dict[str, Any]] = None,
    vendor_id_suffix: str = "",
) -> dict[str, Any]:
    case_id = f"{case_number:02d}"
    issuer = f"B02-ISSUER-CASE{case_id}"
    record: dict[str, Any] = {
        "vendor_security_id": f"B02-{source}-CASE{case_id}{vendor_id_suffix}",
        "issuer_name": issuer,
        "instrument_name": f"{issuer} NOTE",
        "instrument_type": "BOND",
        "synthetic_cusip": f"B02-CUSIP-CASE{case_id}",
        "synthetic_isin": f"B02-ISIN-CASE{case_id}",
        "currency": "USD",
        "issue_date": "2020-01-01",
        "maturity_date": "2030-01-01",
        "coupon_rate": 5.0,
        "coupon_type": "FIXED",
        "seniority": "Senior Secured",
        "secured_flag": True,
        "credit_status": "PERFORMING",
        "rating": "BBB",
        "rating_agency": "B02-RATING-AGENCY",
        "effective_from": "2020-01-01",
        "source_system": f"VENDOR_{source}",
        "ingestion_timestamp": FIXED_TIMESTAMP,
    }
    if overrides:
        record.update(overrides)
    return record


def make_legacy_record(
    case_number: int,
    overrides: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    case_id = f"{case_number:02d}"
    issuer = f"B02-ISSUER-CASE{case_id}"
    record: dict[str, Any] = {
        "vendor_security_id": f"B02-LEGACY-CASE{case_id}",
        "synthetic_cusip": f"B02-CUSIP-CASE{case_id}",
        "issuer_name": issuer,
        "instrument_name": f"{issuer} NOTE",
        "instrument_type": "BOND",
        "rating": "BBB",
        "rating_agency": "B02-RATING-AGENCY",
        "source_system": "LEGACY",
    }
    if overrides:
        record.update(overrides)
    return record


def build_records() -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    alpha: list[dict[str, Any]] = []
    beta: list[dict[str, Any]] = []
    legacy: list[dict[str, Any]] = []

    def add_vendor(
        destination: list[dict[str, Any]],
        source: str,
        case_number: int,
        overrides: Optional[dict[str, Any]] = None,
        vendor_id_suffix: str = "",
    ) -> None:
        destination.append(
            make_vendor_record(source, case_number, overrides, vendor_id_suffix)
        )

    # B02-01: agreement across the three source systems.
    add_vendor(alpha, "ALPHA", 1)
    add_vendor(beta, "BETA", 1)
    legacy.append(make_legacy_record(1))

    # B02-02: Beta and Legacy support the unique instrument-name majority.
    add_vendor(
        alpha,
        "ALPHA",
        2,
        {"instrument_name": "B02-ISSUER-CASE02 ALPHA NAME"},
    )
    add_vendor(
        beta,
        "BETA",
        2,
        {"instrument_name": "B02-ISSUER-CASE02 CONSENSUS NAME"},
    )
    legacy.append(
        make_legacy_record(
            2, {"instrument_name": "B02-ISSUER-CASE02 CONSENSUS NAME"}
        )
    )

    # B02-03: one distinct rating from each of Alpha, Beta, and Legacy.
    add_vendor(alpha, "ALPHA", 3, {"rating": "AAA"})
    add_vendor(beta, "BETA", 3, {"rating": "BBB"})
    legacy.append(make_legacy_record(3, {"rating": "BB"}))

    # B02-04: Legacy has no currency field, leaving a two-source tie.
    add_vendor(alpha, "ALPHA", 4, {"currency": "USD"})
    add_vendor(beta, "BETA", 4, {"currency": "EUR"})
    legacy.append(make_legacy_record(4))

    # B02-05: reject ZZZ while retaining Beta's valid GBP alternative.
    add_vendor(alpha, "ALPHA", 5, {"currency": "ZZZ"})
    add_vendor(beta, "BETA", 5, {"currency": "GBP"})
    legacy.append(make_legacy_record(5))

    # B02-06: normalize the CLO spelling to CLO_TRANCHE.
    add_vendor(alpha, "ALPHA", 6, {"instrument_type": "CLO"})
    add_vendor(beta, "BETA", 6, {"instrument_type": "CLO_TRANCHE"})
    legacy.append(make_legacy_record(6, {"instrument_type": "CLO"}))

    # B02-07: two valid dates and one malformed date on a distinct source key.
    add_vendor(alpha, "ALPHA", 7, {"effective_from": "2020-01-01"})
    add_vendor(beta, "BETA", 7, {"effective_from": "2022-05-06"})
    add_vendor(
        alpha,
        "ALPHA",
        7,
        {"effective_from": "not-a-date"},
        vendor_id_suffix="-INVALID",
    )

    # B02-08: identified security appears only in Alpha.
    add_vendor(alpha, "ALPHA", 8)

    # B02-09: no matching identifier is available.
    add_vendor(alpha, "ALPHA", 9, {"synthetic_cusip": None, "synthetic_isin": None})

    # B02-10: a CUSIP collision across two ISINs and an ISIN-less Legacy row.
    add_vendor(
        alpha,
        "ALPHA",
        10,
        {
            "synthetic_isin": "B02-ISIN-CASE10-A",
        },
    )
    add_vendor(
        beta,
        "BETA",
        10,
        {
            "synthetic_isin": "B02-ISIN-CASE10-B",
        },
    )
    legacy.append(make_legacy_record(10))

    # B02-11: the only intentional duplicate source-record key.
    add_vendor(alpha, "ALPHA", 11)
    add_vendor(alpha, "ALPHA", 11)

    # B02-12: collision-split Alpha row and ISIN-only Beta row share an ISIN.
    add_vendor(
        alpha,
        "ALPHA",
        12,
        {"synthetic_isin": "B02-ISIN-CASE12-SHARED"},
    )
    add_vendor(
        beta,
        "BETA",
        12,
        {"synthetic_isin": "B02-ISIN-CASE12-OTHER"},
    )
    add_vendor(
        beta,
        "BETA",
        12,
        {
            "synthetic_cusip": None,
            "synthetic_isin": "B02-ISIN-CASE12-SHARED",
        },
        vendor_id_suffix="-ISIN-ONLY",
    )

    return alpha, beta, legacy


def write_json_lines(path: Path, records: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as output:
        for record in records:
            output.write(json.dumps(record, separators=(",", ":")) + "\n")


def write_legacy_csv(path: Path, records: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=LEGACY_FIELDS)
        writer.writeheader()
        writer.writerows(records)


def main() -> None:
    alpha, beta, legacy = build_records()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    write_json_lines(OUTPUT_DIR / "vendor_alpha.json", alpha)
    write_json_lines(OUTPUT_DIR / "vendor_beta.json", beta)
    write_legacy_csv(OUTPUT_DIR / "legacy_security_master.csv", legacy)
    print(f"Batch 02 generated in {OUTPUT_DIR}")
    print(f"Vendor alpha rows: {len(alpha)}")
    print(f"Vendor beta rows: {len(beta)}")
    print(f"Legacy CSV data rows: {len(legacy)}")
    print(f"Total physical source rows: {len(alpha) + len(beta) + len(legacy)}")


if __name__ == "__main__":
    main()
