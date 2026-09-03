"""Validation script for synthetic data files.

Exits with non-zero status if any expected condition is missing.
Run from repository root:
    python tests/validate_generated_data.py
"""
from __future__ import annotations

import csv
import json
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"


def load_ndjson(path: Path):
    with path.open("r", encoding="utf-8") as fh:
        return [json.loads(line) for line in fh if line.strip()]


def load_legacy_csv(path: Path):
    with path.open("r", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def fail(msg: str):
    print("FAIL:", msg)
    raise SystemExit(1)


def main():
    alpha_path = DATA_DIR / "vendor_alpha.json"
    beta_path = DATA_DIR / "vendor_beta.json"
    legacy_path = DATA_DIR / "legacy_security_master.csv"

    # existence
    for p in (alpha_path, beta_path, legacy_path):
        if not p.exists():
            fail(f"Missing expected file: {p}")

    alpha = load_ndjson(alpha_path)
    beta = load_ndjson(beta_path)
    legacy = load_legacy_csv(legacy_path)

    # row counts
    if len(alpha) != 30:
        fail(f"vendor_alpha.json expected 30 rows, found {len(alpha)}")
    if len(beta) != 30:
        fail(f"vendor_beta.json expected 30 rows, found {len(beta)}")
    if len(legacy) != 31:
        fail(f"legacy_security_master.csv expected 31 rows, found {len(legacy)}")

    # legacy instrument mix (includes one unmatched bond)
    legacy_counts = Counter(r["instrument_type"].upper() for r in legacy)
    expected_legacy = {"BOND": 11, "LOAN": 8, "CLO": 5, "ABS": 4, "PRIVATE": 3}
    if dict(legacy_counts) != expected_legacy:
        fail(f"Legacy instrument type counts mismatch: expected {expected_legacy}, found {dict(legacy_counts)}")

    # build lookup maps for vendor feeds
    alpha_map = {r["vendor_security_id"]: r for r in alpha}
    beta_map = {r["vendor_security_id"]: r for r in beta}

    # required fields presence (keys)
    required = [
        "vendor_security_id",
        "issuer_name",
        "instrument_name",
        "instrument_type",
        "currency",
        "issue_date",
        "maturity_date",
    ]
    for src, records in (("alpha", alpha), ("beta", beta)):
        for r in records:
            for k in required:
                if k not in r:
                    fail(f"Missing required field '{k}' in {src} record {r.get('vendor_security_id')}" )

    # 1. Missing primary identifier: VEND-BOND-0004 should have both identifiers missing in alpha
    v_miss = "VEND-BOND-0004"
    rec_miss = alpha_map.get(v_miss)
    if rec_miss is None:
        fail(f"Expected record {v_miss} not found in alpha")
    if rec_miss.get("synthetic_cusip") is not None or rec_miss.get("synthetic_isin") is not None:
        fail(f"Expected {v_miss} to have missing primary identifiers but found values")

    # 2. Duplicated identifier: find a CUSIP present in alpha[2], alpha[4], beta[4]
    cusip_map = {}
    for src, records in (("alpha", alpha), ("beta", beta)):
        for r in records:
            c = r.get("synthetic_cusip")
            if not c:
                continue
            cusip_map.setdefault(c, []).append((src.upper(), r["vendor_security_id"]))
    dup_found = False
    for c, lst in cusip_map.items():
        if len(lst) >= 3:
            # expect involvement of VEND-BOND-0003 and VEND-BOND-0005
            ids = {vid for (_, vid) in lst}
            if "VEND-BOND-0003" in ids and "VEND-BOND-0005" in ids:
                dup_found = True
                break
    if not dup_found:
        fail("Expected duplicated synthetic_cusip across vendor records not found")

    # 3. Maturity date before issue date: VEND-BOND-0006 in alpha
    v_bad_dates = "VEND-BOND-0006"
    rec_bad = alpha_map.get(v_bad_dates)
    if rec_bad is None:
        fail(f"Expected record {v_bad_dates} not found in alpha")
    try:
        issue = datetime.fromisoformat(rec_bad["issue_date"]) 
        mat = datetime.fromisoformat(rec_bad["maturity_date"]) 
    except Exception as e:
        fail(f"Error parsing dates for {v_bad_dates}: {e}")
    if mat >= issue:
        fail(f"Expected maturity before issue for {v_bad_dates}, but found issue={rec_bad['issue_date']} maturity={rec_bad['maturity_date']}")

    # 4. Conflicting vendor rating: VEND-BOND-0007 should have different ratings in alpha vs beta
    v_rating = "VEND-BOND-0007"
    a_r = alpha_map.get(v_rating)
    b_r = beta_map.get(v_rating)
    if a_r is None or b_r is None:
        fail(f"Expected {v_rating} in both feeds for rating conflict check")
    if a_r.get("rating") == b_r.get("rating"):
        fail(f"Expected conflicting ratings for {v_rating} but found same rating {a_r.get('rating')}")

    # 5. Conflicting instrument classification: VEND-BOND-0008 should differ
    v_cls = "VEND-BOND-0008"
    if alpha_map[v_cls].get("instrument_type") == beta_map[v_cls].get("instrument_type"):
        fail(f"Expected conflicting instrument_type for {v_cls}")

    # 6. Unmatched legacy record: LEGACY-UNMATCHED-0001 should exist in legacy and its CUSIP should not be in vendor files
    legacy_ids = {r["vendor_security_id"] for r in legacy}
    if "LEGACY-UNMATCHED-0001" not in legacy_ids:
        fail("Expected LEGACY-UNMATCHED-0001 in legacy CSV")
    legacy_cusips = {r["synthetic_cusip"] for r in legacy}
    vendor_cusips = {c for c in cusip_map.keys()}
    if "SYN-CUSIP-9999" in vendor_cusips:
        fail("Expected unmatched legacy CUSIP SYN-CUSIP-9999 to NOT appear in vendor feeds")

    # 7. Overlapping effective-date interval: VEND-BOND-0009 beta effective_from 30 days before alpha
    v_eff = "VEND-BOND-0009"
    a_eff = alpha_map[v_eff].get("effective_from")
    b_eff = beta_map[v_eff].get("effective_from")
    try:
        a_dt = datetime.fromisoformat(a_eff)
        b_dt = datetime.fromisoformat(b_eff)
    except Exception as e:
        fail(f"Error parsing effective_from for {v_eff}: {e}")
    delta = (a_dt - b_dt).days
    if delta <= 0 or delta > 60:
        fail(f"Expected alpha effective_from to be ~30 days after beta for {v_eff}, found difference {delta} days")

    # 8. Invalid currency code replaced with ZZZ: VEND-BOND-0010 in alpha
    v_curr = "VEND-BOND-0010"
    if alpha_map[v_curr].get("currency") != "ZZZ":
        fail(f"Expected currency ZZZ for {v_curr} in alpha, found {alpha_map[v_curr].get('currency')}")

    print("All synthetic-data validations passed.")


if __name__ == "__main__":
    main()
