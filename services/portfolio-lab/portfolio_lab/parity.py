"""Write the sample dataset and the Swift parity fixtures from the research reference.

    python -m portfolio_lab.parity            write both files
    python -m portfolio_lab.parity --check    fail if either is out of date
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

from portfolio_lab import model
from portfolio_lab.sample import sample_market

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT.parents[1] / "NomadFi" / "NomadFi" / "Resources" / "PortfolioLab"
SNAPSHOT = RESOURCES / "fx-snapshot.json"
SAMPLE = RESOURCES / "sample-market.json"
FIXTURES = ROOT / "fixtures" / "parity.json"


def tidy(value):
    """Round floats to 11 significant digits and 12 decimals.

    The commit hook treats any run of 13+ digits as a possible card number, and
    the fractional part of a small float is such a run. Both limits stay far
    inside the parity tolerances.
    """
    if isinstance(value, float):
        return round(float(f"{value:.11g}"), 12)
    if isinstance(value, list):
        return [tidy(item) for item in value]
    if isinstance(value, dict):
        return {key: tidy(item) for key, item in value.items()}
    return value


def optimizer_cases(seed: int = 7) -> list[dict]:
    rng = np.random.default_rng(seed)
    cases = []
    for index, n in enumerate([2, 3, 4, 5, 6, 6]):
        factor = rng.normal(0, 0.1, (n, n))
        # Inputs are rounded before solving, so the stored answer is exact for the stored problem.
        sigma = np.array(tidy((factor @ factor.T / n + np.diag(rng.uniform(0.001, 0.02, n))).tolist()))
        mu = np.array(tidy(rng.uniform(0.0, 0.09, n).tolist()))
        costs = rng.choice([0.0, 0.001, 0.015, 0.025], n)
        previous = np.array(tidy(rng.dirichlet(np.ones(n)).tolist())) if index % 2 else np.zeros(n)
        cap = float(max(0.35, 1.2 / n))
        risk_aversion = float(rng.choice([1.2, 3.0, 8.0]))
        weights = model.optimize(mu, sigma, risk_aversion, cap, costs, previous)
        cases.append({
            "expectedReturns": mu.tolist(), "covariance": sigma.tolist(), "costs": costs.tolist(),
            "previous": previous.tolist(), "riskAversion": risk_aversion, "maxWeight": cap,
            "weights": weights.tolist(),
            "objective": model.objective(weights, mu, sigma, previous, costs, risk_aversion),
        })
    return cases


def quality_case() -> dict:
    closes = [{"month": "2024-01", "close": 10}, {"month": "2024-01", "close": 11}, {"month": "2024-02", "close": 10},
              {"month": "2024-03", "close": 10}, {"month": "2024-04", "close": 10}, {"month": "2024-06", "close": 20},
              {"month": "2024-07", "close": -1}, {"month": "2024-08", "close": 20.5}, {"month": "June", "close": 1}]
    return {"symbol": "AAA", "closes": closes, "issues": model.data_issues("AAA", closes)}


def build(snapshot: dict) -> tuple[dict, dict]:
    sample = sample_market([p["month"] for p in snapshot["fx"]["points"]])
    engine = []
    for home, profile, expectation, amount in [("CAD", "balanced", "shrunkHistorical", 5000.0),
                                               ("CAD", "cautious", "equal", 1500.0),
                                               ("CAD", "growth", "shrunkHistorical", 25000.0),
                                               ("USD", "balanced", "shrunkHistorical", 5000.0)]:
        result = model.run(sample["series"], snapshot["fx"], home, amount, profile, expectation)
        engine.append({"homeCurrency": home, "profile": profile, "expectation": expectation, "amount": amount, **result})
    fixtures = tidy({"schemaVersion": 1, "quality": quality_case(), "optimizer": optimizer_cases(), "engine": engine})
    return sample, fixtures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    options = parser.parse_args()
    sample, fixtures = build(json.loads(SNAPSHOT.read_text()))
    outputs = {SAMPLE: json.dumps(sample, indent=2) + "\n", FIXTURES: json.dumps(fixtures, indent=2) + "\n"}
    if options.check:
        stale = [str(path) for path, text in outputs.items() if not path.exists() or path.read_text() != text]
        if stale:
            print("Out of date, run python -m portfolio_lab.parity:", *stale, sep="\n  ")
            return 1
        print("Sample data and parity fixtures are current.")
        return 0
    for path, text in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        print("wrote", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
