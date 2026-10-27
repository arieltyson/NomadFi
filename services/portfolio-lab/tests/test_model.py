import numpy as np
import pytest

from portfolio_lab import model
from portfolio_lab.parity import quality_case
from portfolio_lab.sample import sample_market


def months(count, start="2020-01"):
    first = model.month_index(start)
    return [model.month_name(first + i) for i in range(count)]


def series(symbol, currency, values, start="2020-01"):
    return {"asset": {"symbol": symbol, "name": symbol, "currency": currency, "kind": "equity"},
            "closes": [{"month": m, "close": v} for m, v in zip(months(len(values), start), values)]}


def test_calendar_round_trips_and_rejects_malformed_months():
    assert model.month_name(model.month_index("2024-12")) == "2024-12"
    for bad in ["2024-13", "2024-1", "24-01", "2024/01", "2024-00"]:
        assert model.month_index(bad) is None


def test_flags_every_vendor_problem_in_month_order():
    found = [f"{i['month']} {i['kind']}" for i in quality_case()["issues"]]
    assert found == ["2024-01 duplicate", "2024-04 stale", "2024-05 missing", "2024-06 jump", "2024-07 nonpositive",
                     "June unreadableMonth"]


def test_converts_foreign_funds_both_ways():
    fx = {"base": "USD", "quote": "CAD", "points": series("FX", "", [1.30 + 0.01 * i for i in range(30)])["closes"]}
    usd, cad = series("VTI", "USD", [100] * 30), series("XIC", "CAD", [50] * 30)
    _, _, in_cad = model.home_currency_panel([usd, cad], fx, "CAD")
    assert in_cad[0, 0] == pytest.approx(1.31 / 1.30 - 1, abs=1e-15)
    _, _, in_usd = model.home_currency_panel([usd, cad], fx, "USD")
    assert in_usd[0, 1] == pytest.approx(1.30 / 1.31 - 1, abs=1e-15)


def test_refuses_short_history():
    with pytest.raises(ValueError, match="insufficientHistory:9"):
        model.home_currency_panel([series("VTI", "USD", list(range(1, 11)))], None, "USD")


def test_optimizer_matches_closed_form_costs_and_caps():
    w = model.optimize([0.02, 0.01], np.diag([0.04, 0.04]), 1.0, 1.0)
    assert w[0] == pytest.approx(0.5625, abs=1e-7)
    stay = model.optimize([0.02, 0.01], np.diag([0.04, 0.04]), 1.0, 1.0, costs=[0.1, 0.1], previous=[0.5, 0.5])
    assert stay == pytest.approx([0.5, 0.5], abs=1e-7)
    capped = model.optimize([0.05, 0, 0, 0], np.eye(4) * 0.01, 1.0, 0.4)
    assert capped == pytest.approx([0.4, 0.2, 0.2, 0.2], abs=1e-7)


def test_backtest_drift_costs_and_rebalance():
    result = model.backtest(["2024-01", "2024-02"], np.array([[0.10, -0.10], [0, 0.02]]), np.array([0.5, 0.5]),
                            1000.0, np.array([0.001, 0.001]), rebalance_every=1)
    assert result.initial_cost == pytest.approx(1.0)
    after = 999.0 - 0.001 * (abs(499.5 - 549.45) + abs(499.5 - 449.55))
    assert result.points[1]["value"] == pytest.approx(after)
    assert result.points[-1]["value"] == pytest.approx(after * 1.01)
    assert result.points[0]["month"] == "2023-12"


def test_expensive_conversion_keeps_more_money_at_home():
    sample = sample_market(months(96))
    fx = {"base": "USD", "quote": "CAD", "points": [{"month": m, "close": 1.3} for m in months(96)]}
    result = model.run(sample["series"], fx, "CAD", 5000.0)
    share = {s["conversion"]: s["foreignShare"] for s in result["scenarios"]}
    assert share["bank"] <= share["brokerage"] + 1e-9 <= share["norbertsGambit"] + 2e-9
    for scenario in result["scenarios"]:
        assert sum(scenario["weights"]) == pytest.approx(1.0)
