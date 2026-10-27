import os
import sys

import pytest

pyspark = pytest.importorskip("pyspark")

from pyspark.sql import SparkSession  # noqa: E402

from pipeline import fx_pipeline  # noqa: E402


@pytest.fixture(scope="module")
def spark():
    os.environ.setdefault("PYSPARK_PYTHON", sys.executable)
    session = (SparkSession.builder.master("local[1]").appName("portfolio-lab-tests")
               .config("spark.sql.session.timeZone", "UTC").config("spark.ui.enabled", "false").getOrCreate())
    session.sparkContext.setLogLevel("ERROR")
    yield session
    session.stop()


def observation(day, value):
    return {"d": day, "FXUSDCAD": {"v": value}} if value is not None else {"d": day, "FXUSDCAD": {}}


PAYLOAD = {"observations": [
    observation("2026-07-30", "1.3700"),
    observation("2026-07-31", "1.3750"),
    observation("2026-07-31", "1.3999"),   # duplicate day: first value wins
    observation("2026-08-28", "1.3866"),
    observation("2026-08-31", None),       # holiday row with no value
    observation("2026-09-29", "-1"),       # bad print
    observation("2026-09-28", "1.4168"),
    observation("not-a-date", "1.40"),
    observation("2026-10-26", "1.4025"),   # current month is incomplete
]}


def test_month_end_closes_skip_rejected_rows_and_the_current_month(spark):
    result = fx_pipeline.run(spark, PAYLOAD, None, "2026-10-27T12:00:00+00:00")
    assert result["fx"]["points"] == [
        {"month": "2026-07", "close": 1.375},
        {"month": "2026-08", "close": 1.3866},
        {"month": "2026-09", "close": 1.4168},
    ]
    reasons = {(row["date"], row["reason"]) for row in result["rejectedObservations"]}
    assert reasons == {("2026-07-31", "duplicate"), ("2026-08-31", "missingRate"), ("2026-09-29", "nonpositive"),
                       ("not-a-date", "unreadableDate")}


def test_snapshot_carries_attribution_terms_and_model_settings(spark):
    result = fx_pipeline.run(spark, PAYLOAD, None, "2026-10-27T12:00:00+00:00")
    assert result["source"]["terms"] == "https://www.bankofcanada.ca/terms/"
    assert "Bank of Canada" in result["source"]["attribution"]
    assert "free of charge" in result["source"]["attribution"]
    assert [m["id"] for m in result["conversionMethods"]] == ["bank", "brokerage", "norbertsGambit"]
    assert result["model"]["minimumMonths"] == 24


def test_parquet_history_round_trips(spark, tmp_path):
    fx_pipeline.run(spark, PAYLOAD, str(tmp_path / "fx"), "2026-10-27T12:00:00+00:00")
    rows = spark.read.parquet(str(tmp_path / "fx")).orderBy("month").collect()
    assert [row["month"] for row in rows] == ["2026-07", "2026-08", "2026-09", "2026-10"]
