# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

This project is **not yet scaffolded**. The only files present are `requirements.txt`, `.envrc`, and the `.venv/`. There is no `dbt_project.yml`, no models, and no application code yet. Treat early tasks as greenfield setup, and update this file as real structure lands.

## Stack

The dependency set in `requirements.txt` defines the intended architecture:

- **dbt-core + dbt-bigquery** — the data transformation layer. Analytics is expected to be built as dbt models compiled to SQL and run against BigQuery.
- **BigQuery** is the warehouse (`google-cloud-bigquery`, `pandas-gbq`, `db-dtypes`, `pyarrow`).
- **pandas / numpy** — local dataframe work and loading data to/from BigQuery.
- **google-genai + google-cloud-aiplatform (Vertex AI)** — GenAI/LLM integration is in scope.

Not a git repository yet (`git init` if version control is needed).

## Environment

- Python **3.12**, virtualenv at `.venv/`.
- `.envrc` activates the venv (`source .venv/bin/activate`) — it relies on **direnv**. If direnv isn't installed/hooked, activate manually:
  ```bash
  source .venv/bin/activate
  ```
- Install deps: `pip install -r requirements.txt`

## dbt profile (IMPORTANT)

dbt resolves connections from `~/.dbt/profiles.yml`. That file currently contains only an **unrelated Snowflake "dbtlearn" profile** left over from a tutorial — it is **not** for this project and must not be used. A BigQuery profile must be created before any dbt command will work, e.g.:

```yaml
baseball_analytics:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth        # or service-account with keyfile
      project: <gcp-project-id>
      dataset: <bq-dataset>
      threads: 4
      location: US
```

The profile name here must match the `profile:` declared in the project's `dbt_project.yml` once it exists.

## Common commands (once a dbt project exists)

```bash
dbt init baseball_analytics   # scaffold the project (run once)
dbt debug                     # verify warehouse connection & profile
dbt deps                      # install dbt packages
dbt build                     # run + test all models
dbt run                       # run models only
dbt run --select <model>      # run a single model (and +model / model+ for graph selectors)
dbt test                      # run all tests
dbt test --select <model>     # test a single model
dbt compile                   # compile SQL without executing
dbt docs generate && dbt docs serve
```
