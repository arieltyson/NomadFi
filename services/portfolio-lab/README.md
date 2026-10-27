# Portfolio Lab research and pipeline

Python side of [Portfolio Lab](../../docs/PortfolioLab.md):

- `portfolio_lab/model.py`: the research reference. It is independent of the Swift engine: NumPy for the risk model and SciPy SLSQP for the optimizer.
- `portfolio_lab/sample.py`: illustrative fund prices for the app's sample mode.
- `portfolio_lab/parity.py`: writes `fixtures/parity.json` and the bundled sample prices. `--check` fails when either is stale.
- `pipeline/fx_pipeline.py`: PySpark job that turns Bank of Canada daily USD/CAD into the month-end snapshot bundled in the app.
- `databricks.yml`: the same job as a Databricks serverless asset bundle.

```sh
uv sync --extra pipeline
uv run pytest -q
uv run python -m pipeline.fx_pipeline --snapshot ../../NomadFi/NomadFi/Resources/PortfolioLab/fx-snapshot.json
uv run python -m portfolio_lab.parity
```

PySpark 3.5 needs Java 11 or 17. Fixture floats are rounded to 12 decimals so no digit run resembles a card number to the commit hook.
