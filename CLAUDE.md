# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **dbt + BigQuery** baseball analytics project with two layers:

1. **Ingestion** (`src/`, `scripts/`) — a Python pipeline that pulls pitch-level Statcast data from Baseball Savant (via `pybaseball`), stages it as parquet in GCS, and appends it to a BigQuery raw table.
2. **Transformation** (`dbt_project.yml`, `models/`, …) — dbt models that compile to SQL and run against BigQuery on top of the raw ingested data.

`google-genai` / `google-cloud-aiplatform` (Vertex AI) are available for GenAI work but nothing uses them yet.

The dbt project lives at the **repo root** (not in a subdirectory): `dbt_project.yml`, `models/`, `macros/`, `seeds/`, `snapshots/`, `tests/`, `analyses/`. The starter example models have been removed — `models/` is currently empty, so this is a blank modeling slate.

## Environment

- Python **3.12**, virtualenv at `.venv/`.
- `.envrc` activates the venv via **direnv**. If direnv isn't hooked, activate manually before running dbt:
  ```bash
  source .venv/bin/activate
  ```
- Install deps: `pip install -r requirements.txt`

## Warehouse connection

- Profile: **`baseball_analytics`** (matches `profile:` in `dbt_project.yml`), defined in `~/.dbt/profiles.yml`.
- Auth: **BigQuery `oauth`** using local Application Default Credentials (ADC). No keyfile.
- GCP project: `baseball-analytics-portfolio`; default dataset: `baseball_analytics`; location `US`.
- `dbt debug` passes. If auth fails, refresh ADC with `gcloud auth application-default login`.
- Note: `~/.dbt/profiles.yml` also contains an unrelated `dbtlearn` (Snowflake) profile from a tutorial — ignore it.

## Ingestion pipeline

Flow: **extract → GCS → BigQuery**, orchestrated by `scripts/run_pipeline.py`.

```bash
python scripts/run_pipeline.py --start-date 2024-04-01 --end-date 2024-04-07
```

Both `--start-date` and `--end-date` (YYYY-MM-DD, inclusive) are required. The script reads everything from `config/pipeline_config.yaml` — there are **no hardcoded** bucket/project/dataset names — and prints a summary (date range, rows extracted, GCS URI, BQ rows loaded).

Module layout (`src/`):
- `extract/statcast_extract.py` — `extract_statcast(start, end, chunk_size_days=7)`. Pulls in weekly chunks to respect Baseball Savant rate limits, concatenates, returns a DataFrame. pybaseball's on-disk cache is **disabled** at import (`pybaseball.cache.disable()`) because Statcast data is revised after the fact; do not re-enable it or use the batter/pitcher cache helpers.
- `load/gcs_loader.py` — `upload_to_gcs(...)`. Serializes to parquet **in memory** (pyarrow) and streams to GCS; never writes to local disk. Object path partitions by start-date: `statcast/year={YYYY}/month={MM}/statcast_{start}_{end}.parquet`. Returns the `gs://` URI.
- `load/bq_loader.py` — `load_to_bigquery(...)`. Loads the GCS parquet with `WRITE_APPEND` + schema autodetect (never `WRITE_TRUNCATE`). Returns rows loaded.
- `utils/logger.py` — `get_logger(name)`, stdout, `timestamp | level | message`.

Config keys live under `gcs:`, `bigquery:`, and `extract:` in `config/pipeline_config.yaml`. The destination is `<bigquery.project>.<bigquery.raw_dataset>.<bigquery.table>` (currently `baseball-analytics-portfolio.raw.statcast_pitches`) — that dataset and the GCS bucket must already exist; the pipeline does not create them.

Conventions enforced across the pipeline: type hints + docstrings on all functions; errors are logged at ERROR and re-raised (never silenced); all GCP auth comes from ADC (no credentials in code).

## Imports & path

`src/` is an importable package, but neither `scripts/` nor pytest puts the repo root on `sys.path` automatically. This is handled in two places — keep both:
- `scripts/run_pipeline.py` inserts the repo root before importing `src.*`.
- root `conftest.py` does the same for test runs.

So run scripts and tests **from the repo root**.

## Testing (Python)

```bash
python -m pytest                          # all Python tests
python -m pytest tests/test_extract.py -q  # a single test file
```

Tests mock the `pybaseball` call so they never hit the live API. Note `tests/` holds both these pytest files and dbt's (currently empty) test directory — they coexist (`.py` vs dbt `.sql`).

## Common commands (dbt)

Run from the repo root with the venv active.

```bash
dbt debug                     # verify warehouse connection & profile
dbt deps                      # install dbt packages (after adding packages.yml)
dbt build                     # run + test all models
dbt run                       # run models only
dbt run --select <model>      # single model; +model / model+ for upstream/downstream
dbt test                      # run all tests
dbt test --select <model>     # test a single model
dbt compile                   # compile SQL without executing
dbt docs generate && dbt docs serve
```

## Conventions

- Project-wide default materialization is **`view`** (`models:` block in `dbt_project.yml`); override per-model with `{{ config(materialized='table') }}` or per-folder in `dbt_project.yml`.
- Until at least one model exists, `dbt parse` warns about the unused `models.baseball_analytics` config path — expected, harmless, and clears once a model is added.
