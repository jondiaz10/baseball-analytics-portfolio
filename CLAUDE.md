# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **dbt + BigQuery** baseball analytics project. dbt models compile to SQL and run against BigQuery; `google-genai` / `google-cloud-aiplatform` (Vertex AI) are available for GenAI work but nothing uses them yet.

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

## Common commands

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
