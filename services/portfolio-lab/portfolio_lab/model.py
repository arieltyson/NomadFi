"""Research reference for Portfolio Lab.

Written independently of the Swift engine: NumPy for the risk model and
SciPy SLSQP (with a buy/sell split for the cost term) for the optimizer,
where Swift uses accelerated proximal gradient. Parity fixtures generated
from this module are what the Swift tests check against.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy.optimize import minimize

COVARIANCE_SHRINKAGE = 0.5
MEAN_SHRINKAGE = 0.5
MINIMUM_MONTHS = 24
CASH_SYMBOL = "CASH"
RISK_AVERSION = {"cautious": 8.0, "balanced": 3.0, "growth": 1.2}
CONVERSION_METHODS = [
    {"id": "bank", "name": "Bank conversion", "spreadPercent": 2.5, "flatFee": 0.0},
    {"id": "brokerage", "name": "Brokerage auto-conversion", "spreadPercent": 1.5, "flatFee": 0.0},
    {"id": "norbertsGambit", "name": "Norbert's Gambit", "spreadPercent": 0.1, "flatFee": 20.0},
]


def month_index(month: str) -> int | None:
    parts = month.split("-")
    if len(month) != 7 or len(parts) != 2 or len(parts[0]) != 4 or len(parts[1]) != 2:
        return None
    if not (parts[0].isdigit() and parts[1].isdigit()):
        return None
    year, number = int(parts[0]), int(parts[1])
    return year * 12 + number - 1 if 1 <= number <= 12 else None


def month_name(index: int) -> str:
    return f"{index // 12:04d}-{index % 12 + 1:02d}"


ISSUE_ORDER = ["duplicate", "missing", "nonpositive", "jump", "stale", "unreadableMonth"]


def data_issues(symbol: str, closes: list[dict], max_abs_return: float = 0.5, max_stale: int = 3) -> list[dict]:
    issues, seen, rows = [], set(), []
    for item in closes:
        index = month_index(item["month"])
        if index is None:
            issues.append((item["month"], "unreadableMonth"))
        elif index in seen:
            issues.append((item["month"], "duplicate"))
        else:
            seen.add(index)
            rows.append((index, float(item["close"])))
    rows.sort()
    if rows:
        present = {index for index, _ in rows}
        issues += [(month_name(i), "missing") for i in range(rows[0][0], rows[-1][0] + 1) if i not in present]
    previous, repeats = None, 0
    for index, close in rows:
        month = month_name(index)
        if not np.isfinite(close) or close <= 0:
            issues.append((month, "nonpositive"))
            continue
        if previous is not None:
            if abs(close / previous - 1) > max_abs_return:
                issues.append((month, "jump"))
            repeats = repeats + 1 if close == previous else 0
            if repeats >= max_stale:
                issues.append((month, "stale"))
        previous = close
    issues.sort(key=lambda item: (item[0], ISSUE_ORDER.index(item[1])))
    return [{"symbol": symbol, "month": month, "kind": kind} for month, kind in issues]


def _usable(closes: list[dict]) -> dict[int, float]:
    result: dict[int, float] = {}
    for item in closes:
        index = month_index(item["month"])
        if index is None or index in result:
            continue
        close = float(item["close"])
        result[index] = close if np.isfinite(close) and close > 0 else np.nan
    return {k: v for k, v in result.items() if not np.isnan(v)}


def home_currency_panel(series: list[dict], fx: dict | None, home: str):
    if not series:
        raise ValueError("noAssets")
    rates = _usable(fx["points"]) if fx else {}
    valued = []
    for item in series:
        closes, currency = _usable(item["closes"]), item["asset"]["currency"]
        if currency == home:
            valued.append(closes)
            continue
        if fx is None:
            raise ValueError(f"unsupportedCurrency:{currency}")
        if (currency, home) == (fx["base"], fx["quote"]):
            convert = lambda close, rate: close * rate  # noqa: E731
        elif (currency, home) == (fx["quote"], fx["base"]):
            convert = lambda close, rate: close / rate  # noqa: E731
        else:
            raise ValueError(f"unsupportedCurrency:{currency}")
        valued.append({i: convert(c, rates[i]) for i, c in closes.items() if i in rates})
    common = sorted(set.intersection(*(set(v) for v in valued)))
    months, returns = [], []
    for previous, current in zip(common, common[1:]):
        if current == previous + 1:
            months.append(month_name(current))
            returns.append([v[current] / v[previous] - 1 for v in valued])
    if len(months) < MINIMUM_MONTHS:
        raise ValueError(f"insufficientHistory:{len(months)}")
    return months, [item["asset"]["symbol"] for item in series], np.array(returns)


def risk_model(returns: np.ndarray, expectation: str):
    covariance = np.cov(returns, rowvar=False, ddof=1) * 12
    covariance = np.atleast_2d(covariance)
    off_diagonal = ~np.eye(len(covariance), dtype=bool)
    covariance[off_diagonal] *= 1 - COVARIANCE_SHRINKAGE
    annual = returns.mean(axis=0) * 12
    if expectation == "shrunkHistorical":
        expected = (1 - MEAN_SHRINKAGE) * annual + MEAN_SHRINKAGE * annual.mean()
    else:
        expected = np.full_like(annual, annual.mean())
    return expected, covariance


def per_unit_costs(assets: list[dict], home: str, method: dict, amount: float, commission_percent: float) -> np.ndarray:
    rate = method["spreadPercent"] / 100 + (method["flatFee"] / amount if amount > 0 else 0)
    return np.array([0.0 if a["kind"] == "cash" else commission_percent / 100 + (0 if a["currency"] == home else rate)
                     for a in assets])


def objective(w, mu, sigma, previous, costs, risk_aversion) -> float:
    return float(mu @ w - risk_aversion * w @ sigma @ w - costs @ np.abs(w - previous))


def optimize(mu, sigma, risk_aversion: float, max_weight: float, costs=None, previous=None) -> np.ndarray:
    mu, sigma = np.asarray(mu, float), np.asarray(sigma, float)
    n = len(mu)
    if n * max_weight < 1 - 1e-12:
        raise ValueError("infeasibleCap")
    costs = np.zeros(n) if costs is None else np.asarray(costs, float)
    w0 = np.zeros(n) if previous is None else np.asarray(previous, float)

    def weights(x):
        return w0 + x[:n] - x[n:]

    def negative(x):
        w = weights(x)
        return -(mu @ w - risk_aversion * w @ sigma @ w - costs @ x[:n] - costs @ x[n:])

    def gradient(x):
        g = -(mu - 2 * risk_aversion * sigma @ weights(x))
        return np.concatenate([g + costs, -g + costs])

    trade = np.hstack([np.eye(n), -np.eye(n)])
    constraints = [
        {"type": "eq", "fun": lambda x: weights(x).sum() - 1, "jac": lambda x: np.concatenate([np.ones(n), -np.ones(n)])},
        {"type": "ineq", "fun": weights, "jac": lambda x: trade},
        {"type": "ineq", "fun": lambda x: max_weight - weights(x), "jac": lambda x: -trade},
    ]
    start = np.full(n, 1 / n)
    x0 = np.concatenate([np.maximum(start - w0, 0), np.maximum(w0 - start, 0)])
    result = minimize(negative, x0, jac=gradient, bounds=[(0, 1)] * (2 * n), constraints=constraints,
                      method="SLSQP", options={"ftol": 1e-15, "maxiter": 2000})
    if not result.success:
        raise RuntimeError(result.message)
    w = np.clip(weights(result.x), 0, max_weight)
    w[w < 1e-12] = 0
    return w / w.sum()


@dataclass
class Backtest:
    points: list[dict]
    initial_cost: float
    total_cost: float
    annual_return: float
    annual_volatility: float
    max_drawdown: float


def backtest(months: list[str], returns: np.ndarray, weights: np.ndarray, amount: float, costs: np.ndarray,
             rebalance_every: int = 12) -> Backtest:
    holdings = np.zeros(len(weights))

    def rebalance(value: float) -> float:
        nonlocal holdings
        cost = float(costs @ np.abs(weights * value - holdings))
        holdings = weights * (value - cost)
        return cost

    start = month_name(month_index(months[0]) - 1)
    points = [{"month": start, "value": amount}]
    initial = rebalance(amount)
    total = initial
    for i, row in enumerate(returns):
        holdings = holdings * (1 + row)
        value = float(holdings.sum())
        if rebalance_every > 0 and (i + 1) % rebalance_every == 0 and i + 1 < len(returns):
            total += rebalance(value)
            value = float(holdings.sum())
        points.append({"month": months[i], "value": value})
    values = np.array([p["value"] for p in points])
    monthly = values[1:] / values[:-1] - 1
    peak = np.maximum.accumulate(values)
    return Backtest(points, initial, total, float((values[-1] / amount) ** (12 / len(monthly)) - 1),
                    float(monthly.std(ddof=1) * np.sqrt(12)), float((values / peak - 1).min()))


def run(series: list[dict], fx: dict | None, home: str, amount: float, profile: str = "balanced",
        expectation: str = "shrunkHistorical", cash_rate: float | None = 0.02, max_weight: float = 0.6,
        commission_percent: float = 0.0, rebalance_every: int = 12, methods: list[dict] | None = None) -> dict:
    months, symbols, returns = home_currency_panel(series, fx, home)
    mu, sigma = risk_model(returns, expectation)
    assets = [item["asset"] for item in series]
    if cash_rate is not None:
        assets = assets + [{"symbol": CASH_SYMBOL, "name": "Cash", "currency": home, "kind": "cash"}]
        mu = np.append(mu, cash_rate)
        sigma = np.pad(sigma, ((0, 1), (0, 1)))
        returns = np.hstack([returns, np.full((len(returns), 1), (1 + cash_rate) ** (1 / 12) - 1)])
    scenarios = []
    for method in methods or CONVERSION_METHODS:
        costs = per_unit_costs(assets, home, method, amount, commission_percent)
        w = optimize(mu, sigma, RISK_AVERSION[profile], max_weight, costs)
        result = backtest(months, returns, w, amount, costs, rebalance_every)
        scenarios.append({
            "conversion": method["id"],
            "weights": w.tolist(),
            "foreignShare": float(sum(x for x, a in zip(w, assets) if a["currency"] != home)),
            "expectedReturn": float(mu @ w),
            "expectedVolatility": float(np.sqrt(max(w @ sigma @ w, 0))),
            "objective": objective(w, mu, sigma, np.zeros(len(w)), costs, RISK_AVERSION[profile]),
            "initialCost": result.initial_cost,
            "totalCost": result.total_cost,
            "endingValue": result.points[-1]["value"],
            "annualReturn": result.annual_return,
            "annualVolatility": result.annual_volatility,
            "maxDrawdown": result.max_drawdown,
        })
    return {"months": months, "symbols": [a["symbol"] for a in assets], "scenarios": scenarios}
