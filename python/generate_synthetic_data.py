"""Synthetic data generator for the interview security-master prototype.

Creates two vendor JSON feeds and one legacy CSV in `data/` when executed.
The output is deterministic (fixed random seed) and deliberately injects a small
set of documented data problems for downstream DQ and reconciliation tests.

Run: python python/generate_synthetic_data.py
"""
from __future__ import annotations

import csv
import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, List, Any

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
DATA_DIR.mkdir(exist_ok=True)

SEED = 42
random.seed(SEED)

COUNTS = {
    "bond": 10,
    "loan": 8,
    "clo": 5,
    "abs": 4,
    "private": 3,
}

TOTAL = sum(COUNTS.values())

ISSUERS = [f"SYN-ISSUER-{i:03d}" for i in range(1, TOTAL + 5)]
CURRENCIES = ["USD", "EUR", "GBP", "JPY"]
RATINGS = ["AAA", "AA", "A", "BBB", "BB", "B", "CCC", "D"]
RATING_AGENCIES = ["SYN-SP", "SYN-MOODY", "SYN-FITCH"]

def iso(d: datetime) -> str:
    return d.strftime("%Y-%m-%d")


def make_dates(idx: int) -> (str, str):
    start = datetime(2010, 1, 1) + timedelta(days=365 * (idx % 10))
    # maturities 1-12 years after issue
    mat = start + timedelta(days=365 * (5 + (idx % 8)))
    return iso(start), iso(mat)


def build_instruments() -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    i = 1
    def mk(idn, itype):
        issuer = ISSUERS[idn % len(ISSUERS)]
        issue_date, maturity_date = make_dates(idn)
        coupon_rate = None
        coupon_type = None
        if itype == "bond":
            coupon_rate = round(3.0 + (idn % 7) * 0.5, 2)
            coupon_type = "Fixed"
        elif itype == "clo":
            coupon_type = "Floating"
        seniority = random.choice(["Senior Secured", "Senior Unsecured", "Subordinated"]) if itype in ("bond", "loan", "private") else None
        secured_flag = True if seniority == "Senior Secured" else False
        currency = random.choice(CURRENCIES)
        rec = {
            "vendor_security_id": f"VEND-{itype.upper()}-{idn:04d}",
            "issuer_name": issuer,
            "instrument_name": f"{issuer} {itype.upper()} {idn:04d}",
            "instrument_type": itype.upper(),
            "synthetic_cusip": f"SYN-CUSIP-{idn:04d}",
            "synthetic_isin": f"SYN-ISIN-{idn:04d}",
            "currency": currency,
            "issue_date": issue_date,
            "maturity_date": maturity_date,
            "coupon_rate": coupon_rate,
            "coupon_type": coupon_type,
            "seniority": seniority,
            "secured_flag": secured_flag,
            "credit_status": random.choice(["PERFORMING", "WATCHLIST", "DISTRESSED", "DEFAULTED"]),
            "rating": random.choice(RATINGS),
            "rating_agency": random.choice(RATING_AGENCIES),
            "effective_from": issue_date,
            "source_system": None,
            "ingestion_timestamp": datetime.now(timezone.utc).isoformat(),
        }
        return rec

    # create by type counts
    for t, c in COUNTS.items():
        for _ in range(c):
            rows.append(mk(i, t))
            i += 1
    return rows


def inject_problems(alpha: List[Dict], beta: List[Dict], legacy_rows: List[Dict]) -> List[str]:
    notes: List[str] = []
    # 1. Missing primary identifier: remove CUSIP/ISIN from one record (idx 4)
    target = 4
    rec = alpha[target - 1]
    rec["synthetic_cusip"] = None
    rec["synthetic_isin"] = None
    notes.append(f"Missing primary identifier in {rec['vendor_security_id']} (alpha)")

    # 2. Duplicated identifier: duplicate CUSIP for VEND-BOND-0003 -> VEND-BOND-0005
    dup_cusip = alpha[2]["synthetic_cusip"]
    # assign the duplicated CUSIP only (do not touch ISIN) to the record at index 4 (VEND-BOND-0005)
    alpha[4]["synthetic_cusip"] = dup_cusip
    beta[4]["synthetic_cusip"] = dup_cusip
    notes.append(f"Duplicated synthetic_cusip {dup_cusip} across records")

    # 3. Maturity date before issue date: set for idx 5
    bad = alpha[5]
    bad["maturity_date"] = bad["issue_date"]  # equal first
    # then set earlier
    bad_dt = datetime.strptime(bad["issue_date"], "%Y-%m-%d")
    bad["maturity_date"] = (bad_dt - timedelta(days=30)).strftime("%Y-%m-%d")
    notes.append(f"Maturity before issue for {bad['vendor_security_id']}")

    # 4. Conflicting vendor rating: idx 6 alpha vs beta
    idx = 6
    alpha[idx]["rating"] = "B+"
    beta[idx]["rating"] = "A-"
    notes.append(f"Conflicting vendor rating for {alpha[idx]['vendor_security_id']}")

    # 5. Conflicting instrument classification: idx 7
    idx2 = 7
    alpha[idx2]["instrument_type"] = "CLO_TRANCHE"
    beta[idx2]["instrument_type"] = "CLO"
    notes.append(f"Conflicting instrument_type for {alpha[idx2]['vendor_security_id']}")

    # 6. Unmatched legacy record: add a legacy row with no matching CUSIP
    legacy_rows.append({
        "vendor_security_id": "LEGACY-UNMATCHED-0001",
        "synthetic_cusip": "SYN-CUSIP-9999",
        "issuer_name": "SYN-ISSUER-999",
        "instrument_name": "LEGACY ORPHAN",
        "instrument_type": "BOND",
        "rating": "BB",
        "rating_agency": "SYN-SP",
        "source_system": "LEGACY",
    })
    notes.append("Added unmatched legacy record SYN-CUSIP-9999")

    # 7. Overlapping effective-date interval: create two overlapping effective_from entries for same security idx 8
    idx3 = 8
    alpha[idx3]["effective_from"] = alpha[idx3]["issue_date"]
    # make beta effective_from 30 days before alpha's effective_from to force overlap
    dt = datetime.strptime(alpha[idx3]["effective_from"], "%Y-%m-%d") - timedelta(days=30)
    beta[idx3]["effective_from"] = dt.strftime("%Y-%m-%d")
    notes.append(f"Overlapping effective dates for {alpha[idx3]['vendor_security_id']}")

    # 8. Invalid currency code: set one record to ZZZ (idx 9)
    idx4 = 9
    alpha[idx4]["currency"] = "ZZZ"
    notes.append(f"Invalid currency code ZZZ for {alpha[idx4]['vendor_security_id']}")

    return notes


def write_json_lines(path: Path, rows: List[Dict[str, Any]], source_system: str) -> None:
    with path.open("w", encoding="utf-8") as fh:
        for r in rows:
            r_out = dict(r)
            r_out["source_system"] = source_system
            r_out["ingestion_timestamp"] = datetime.now(timezone.utc).isoformat()
            fh.write(json.dumps(r_out) + "\n")


def write_legacy_csv(path: Path, rows: List[Dict[str, Any]]) -> None:
    fieldnames = [
        "vendor_security_id",
        "synthetic_cusip",
        "issuer_name",
        "instrument_name",
        "instrument_type",
        "rating",
        "rating_agency",
        "source_system",
    ]
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for r in rows:
            writer.writerow({k: r.get(k, "") for k in fieldnames})


def main() -> None:
    instruments = build_instruments()
    # create two vendor views: alpha gets full canonical instruments, beta will be a slightly
    # different view (subset + conflicts) to exercise reconciliation logic.
    alpha = [dict(r) for r in instruments]
    # beta will be same base but with different ingestion timestamps and some differences
    beta = [dict(r) for r in instruments]
    legacy_rows: List[Dict[str, Any]] = []
    for r in instruments:
        legacy_rows.append(
            {
                "vendor_security_id": r["vendor_security_id"],
                "synthetic_cusip": r["synthetic_cusip"],
                "issuer_name": r["issuer_name"],
                "instrument_name": r["instrument_name"],
                "instrument_type": r["instrument_type"],
                "rating": r["rating"],
                "rating_agency": r["rating_agency"],
                "source_system": "LEGACY",
            }
        )

    notes = inject_problems(alpha, beta, legacy_rows)

    # write files
    alpha_path = DATA_DIR / "vendor_alpha.json"
    beta_path = DATA_DIR / "vendor_beta.json"
    legacy_path = DATA_DIR / "legacy_security_master.csv"
    write_json_lines(alpha_path, alpha, "VENDOR_ALPHA")
    write_json_lines(beta_path, beta, "VENDOR_BETA")
    write_legacy_csv(legacy_path, legacy_rows)

    # summary
    print("Synthetic data generation complete.")
    print(f"Seed: {SEED}")
    print(f"Vendor alpha rows: {len(alpha)} -> {alpha_path}")
    print(f"Vendor beta rows:  {len(beta)} -> {beta_path}")
    print(f"Legacy CSV rows:   {len(legacy_rows)} -> {legacy_path}")
    print("\nInjected deterministic problems:")
    for n in notes:
        print(" -", n)


if __name__ == "__main__":
    main()
