"""Bank of Canada FX pipeline for Portfolio Lab (PySpark).

Ingests daily USD/CAD observations from the Bank of Canada Valet API (or a
saved response), validates them, reduces them to month-end closes, writes a
Parquet history, and publishes the snapshot the iOS app bundles.

Runs the same way on a laptop, in GitHub Actions, on Amazon EMR or as a
Databricks job: only --input/--parquet paths change (file:, s3a:, dbfs:).

    python -m pipeline.fx_pipeline --snapshot ../../NomadFi/NomadFi/Resources/PortfolioLab/fx-snapshot.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request
from datetime import UTC, datetime
from pathlib import Path

from pyspark.sql import DataFrame, SparkSession, Window
from pyspark.sql import functions as F

# A Databricks spark_python_task runs this file directly, so make the package importable.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from portfolio_lab.model import CONVERSION_METHODS, COVARIANCE_SHRINKAGE, MEAN_SHRINKAGE, MINIMUM_MONTHS  # noqa: E402

SERIES = "FXUSDCAD"
VALET_URL = f"https://www.bankofcanada.ca/valet/observations/{SERIES}/json?start_date=2017-01-01"
ATTRIBUTION = ("Exchange rates: Bank of Canada (FXUSDCAD). NomadFi reduced the daily rates to the last "
               "business day of each month. This data is available free of charge at bankofcanada.ca.")


def fetch_valet(url: str = VALET_URL) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": "NomadFi-PortfolioLab-Pipeline/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def observations(spark: SparkSession, payload: dict) -> DataFrame:
    rows = [(item.get("d"), (item.get(SERIES) or {}).get("v")) for item in payload.get("observations", [])]
    return spark.createDataFrame(rows, "date string, raw string")


def validate(daily: DataFrame) -> tuple[DataFrame, DataFrame]:
    """Typed, deduplicated, positive rates, plus a table of what was rejected and why."""
    typed = (daily
             .withColumn("day", F.to_date("date", "yyyy-MM-dd"))
             .withColumn("rate", F.col("raw").cast("double")))
    reasons = (F.when(F.col("day").isNull(), "unreadableDate")
               .when(F.col("rate").isNull(), "missingRate")
               .when(F.col("rate") <= 0, "nonpositive"))
    flagged = typed.withColumn("reason", reasons)
    rejected = flagged.where(F.col("reason").isNotNull()).select("date", "raw", "reason")
    clean = flagged.where(F.col("reason").isNull())
    first = Window.partitionBy("day").orderBy(F.monotonically_increasing_id())
    ranked = clean.withColumn("copy", F.row_number().over(first))
    duplicates = ranked.where("copy > 1").select("date", "raw", F.lit("duplicate").alias("reason"))
    return ranked.where("copy = 1").select("day", "rate"), rejected.unionByName(duplicates)


def month_end(daily: DataFrame) -> DataFrame:
    """The last observation in each calendar month."""
    by_month = Window.partitionBy("month").orderBy(F.col("day").desc())
    return (daily
            .withColumn("month", F.date_format("day", "yyyy-MM"))
            .withColumn("rank", F.row_number().over(by_month))
            .where("rank = 1")
            .select("month", F.col("day").alias("asOf"), F.col("rate").alias("close"))
            .orderBy("month"))


def snapshot(monthly: DataFrame, rejected: DataFrame, generated_at: str) -> dict:
    rows = monthly.collect()
    today = datetime.fromisoformat(generated_at).strftime("%Y-%m")
    # The current month is incomplete, so its "close" would move: publish complete months only.
    points = [{"month": r["month"], "close": round(r["close"], 6)} for r in rows if r["month"] < today]
    return {
        "schemaVersion": 1,
        "generatedAt": generated_at,
        "source": {
            "name": "Bank of Canada",
            "series": SERIES,
            "url": "https://www.bankofcanada.ca/rates/exchange/",
            "terms": "https://www.bankofcanada.ca/terms/",
            "attribution": ATTRIBUTION,
        },
        "fx": {"base": "USD", "quote": "CAD", "points": points},
        "rejectedObservations": [row.asDict() for row in rejected.orderBy("date").collect()],
        "conversionMethods": CONVERSION_METHODS,
        "model": {"covarianceShrinkage": COVARIANCE_SHRINKAGE, "meanShrinkage": MEAN_SHRINKAGE,
                  "minimumMonths": MINIMUM_MONTHS},
    }


def run(spark: SparkSession, payload: dict, parquet: str | None, generated_at: str) -> dict:
    daily, rejected = validate(observations(spark, payload))
    monthly = month_end(daily).cache()
    if parquet:
        monthly.write.mode("overwrite").parquet(parquet)
    return snapshot(monthly, rejected, generated_at)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", help="saved Valet JSON response instead of calling the API")
    parser.add_argument("--parquet", help="where to write month-end history (file:, s3a: or dbfs: path)")
    parser.add_argument("--snapshot", required=True, help="where to write the app snapshot JSON")
    options = parser.parse_args()

    payload = json.loads(Path(options.input).read_text()) if options.input else fetch_valet()
    if "DATABRICKS_RUNTIME_VERSION" in os.environ:
        # Databricks (including serverless Free Edition) provides the session.
        spark = SparkSession.builder.getOrCreate()
    else:
        # Workers must run the same interpreter as the driver, or PySpark refuses to start.
        os.environ.setdefault("PYSPARK_PYTHON", sys.executable)
        spark = (SparkSession.builder.appName("portfolio-lab-fx").master("local[*]")
                 .config("spark.sql.session.timeZone", "UTC").config("spark.ui.enabled", "false").getOrCreate())
        spark.sparkContext.setLogLevel("ERROR")
    generated = datetime.now(UTC).replace(microsecond=0).isoformat()
    result = run(spark, payload, options.parquet, generated)
    Path(options.snapshot).parent.mkdir(parents=True, exist_ok=True)
    Path(options.snapshot).write_text(json.dumps(result, indent=2) + "\n")
    points = result["fx"]["points"]
    if "DATABRICKS_RUNTIME_VERSION" not in os.environ:
        spark.stop()
    print(f"{len(points)} month-end rates ({points[0]['month']} to {points[-1]['month']}), "
          f"{len(result['rejectedObservations'])} observations rejected -> {options.snapshot}")


if __name__ == "__main__":
    main()
