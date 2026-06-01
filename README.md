# Baseball Analytics Portfolio

**End-to-end analytics engineering project:** Statcast pitch data → GCP → BigQuery → dbt → Dashboard

🟡 **In Progress** — ingestion pipeline and dbt models complete, dashboard in progress

---

## Overview

This project pulls pitch-level [Statcast](https://baseballsavant.mlb.com/) data from Baseball Savant, lands it in Google Cloud, models it with dbt on BigQuery, and surfaces per-game batter and pitcher metrics for BI. It demonstrates the full analytics engineering lifecycle: ingestion, ELT, dimensional modeling, testing, and visualization.

## Architecture

```
Baseball Savant API → Python (pybaseball) → GCP Cloud Storage (parquet)
        ↓
BigQuery raw layer (statcast_pitches, player_lookup)
        ↓
dbt staging layer (stg_statcast_pitches)
        ↓
dbt mart layer (mart_batter_game_stats, mart_pitcher_game_stats)
        ↓
dbt reporting layer (rpt_* views — pre-aggregated, BI-ready)
        ↓
Data Studio Dashboard  [In Progress]
```

- **Ingestion** — A config-driven Python pipeline extracts Statcast data in weekly chunks, serializes it to parquet in memory, and streams it to GCS partitioned by `year` / `month`. It then appends to BigQuery via `WRITE_APPEND` (never truncates). A separate pipeline loads the Chadwick Bureau player ID registry.
- **Transformation** — dbt models clean and reshape the raw pitch data into a staging layer, then aggregate to per-game mart tables for batters and pitchers.
- **Reporting** — A thin layer of pre-aggregated dbt **views** (`reporting` dataset) that the BI tool reads directly: league KPI scorecards, season-to-date batter and pitcher lines, per-game detail, and pitch mix. All rate stats are denominator-weighted (never an average of averages).

## Stack

| Layer | Tool | Purpose |
|---|---|---|
| Cloud | GCP — BigQuery | Data warehouse (raw, staging, marts, reporting) |
| Cloud | GCP — Cloud Storage | Parquet landing zone |
| Transformation | dbt-core 1.11.11 + dbt-bigquery 1.11.1 | ELT modeling, testing, docs |
| Language | Python 3.12 | Ingestion pipeline |
| Libraries | pybaseball, pyarrow, google-cloud-bigquery, google-cloud-bigquery-storage | Extract, serialize, load |
| Testing | pytest (mocked API calls) | Pipeline unit tests |
| BI | Data Studio | Dashboard *(in progress)* |
| Version control | GitHub | Source control |
| AI assistant | Claude Code (Anthropic) | Development |

## Project Structure

```
baseball-analytics/
├── config/
│   └── pipeline_config.yaml         # bucket / project / dataset config (no hardcoded names)
├── src/                             # ingestion package
│   ├── extract/
│   │   ├── statcast_extract.py      # pull Statcast in weekly chunks
│   │   └── player_lookup_extract.py # pull Chadwick Bureau registry
│   ├── load/
│   │   ├── gcs_loader.py            # serialize to parquet → GCS (in memory)
│   │   └── bq_loader.py             # GCS parquet → BigQuery (WRITE_APPEND)
│   └── utils/
│       └── logger.py
├── scripts/
│   ├── run_pipeline.py              # entry point: Statcast ingestion
│   └── run_player_lookup.py         # entry point: player lookup ingestion
├── models/                          # dbt project (lives at repo root)
│   ├── staging/
│   │   ├── stg_statcast_pitches.sql
│   │   ├── sources.yml
│   │   └── schema.yml
│   ├── marts/
│   │   ├── mart_batter_game_stats.sql
│   │   ├── mart_pitcher_game_stats.sql
│   │   └── schema.yml
│   └── reporting/                   # BI-ready pre-aggregated views
│       ├── rpt_league_batting_kpis.sql
│       ├── rpt_batter_season.sql
│       ├── rpt_batter_game.sql
│       ├── rpt_league_pitching_kpis.sql
│       ├── rpt_pitcher_season.sql
│       ├── rpt_pitcher_pitch_mix.sql
│       └── schema.yml
├── tests/                           # pytest (Python) + dbt tests
│   └── test_extract.py
├── notebooks/
│   └── data_profiling.ipynb
├── macros/  ·  seeds/  ·  snapshots/  ·  analyses/
├── dbt_project.yml
├── requirements.txt
└── conftest.py
```

## Key Metrics

- **258,154** pitches extracted (full 2026 season-to-date, Mar 27 – May 31)
- **257,220** pitches in the cleaned staging layer (null pitch types filtered)
- **118** raw columns cleaned in the staging layer
- **127,526** players in the reference table
- **24/24** dbt tests passing

## dbt Models

| Model | Layer | Grain | Description |
|---|---|---|---|
| `stg_statcast_pitches` | staging | one row per pitch | Cleans 118 raw columns, casts `game_date` integer → DATE, drops deprecated columns, renames for clarity, filters null pitch types — 257,220 rows |
| `mart_batter_game_stats` | mart | batter × game | Exit velocity, xwOBA, hard-hit rate, barrel rate, bat speed, and swing metrics — 17,778 rows |
| `mart_pitcher_game_stats` | mart | pitcher × game | Velocity, whiff rate, strike %, pitch-mix percentages (9 pitch types), hard-hit-allowed rate — 7,389 rows |
| `rpt_league_batting_kpis` | reporting | 1 row | League exit velocity, xwOBA, hard-hit rate (denominator-weighted) |
| `rpt_batter_season` | reporting | batter | Season-to-date batting line, named via player_lookup — 530 rows |
| `rpt_batter_game` | reporting | batter × game | Per-game batting detail for drill-down — 17,778 rows |
| `rpt_league_pitching_kpis` | reporting | 1 row | League velocity, whiff rate, strike % (denominator-weighted) |
| `rpt_pitcher_season` | reporting | pitcher | Season-to-date pitching line — 654 rows |
| `rpt_pitcher_pitch_mix` | reporting | pitcher × pitch type | Long-format pitch mix, weighted by pitches — 5,886 rows |

All reporting models are **views** in a dedicated `reporting` BigQuery dataset, so the BI layer reads pre-shaped, pre-aggregated data with no in-dashboard math.

## Setup

**Prerequisites**
- Python 3.12
- A GCP project with BigQuery + Cloud Storage enabled
- `gcloud` CLI authenticated (Application Default Credentials)

**Steps**

```bash
# 1. Clone
git clone https://github.com/<your-username>/baseball-analytics.git
cd baseball-analytics

# 2. Create and activate a virtualenv
python3.12 -m venv .venv
source .venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Authenticate to GCP
gcloud auth application-default login
```

Configure the dbt profile named **`baseball_analytics`** in `~/.dbt/profiles.yml` (BigQuery, `oauth` auth, location `US`), then verify the connection:

```bash
dbt debug
```

**Run the ingestion pipeline** (dates inclusive, `YYYY-MM-DD`):

```bash
# Incremental append (default)
python scripts/run_pipeline.py --start-date 2026-03-27 --end-date 2026-05-31

# Full refresh — wipes the raw table before loading (WRITE_TRUNCATE)
python scripts/run_pipeline.py --start-date 2026-03-27 --end-date 2026-05-31 --mode full-refresh

# Reference table (Chadwick Bureau player registry)
python scripts/run_player_lookup.py
```

**Run the dbt models and tests:**

```bash
dbt build
```

## Data Sources

| Source | Data | Access |
|---|---|---|
| [Baseball Savant](https://baseballsavant.mlb.com/) (Statcast) | Pitch-level tracking data | `pybaseball` |
| [Chadwick Bureau](https://github.com/chadwickbureau/register) | Player ID registry (127,526 players) | GitHub CSV |

## Dashboard

Live dashboard: `<DATA_STUDIO_LINK_TBD>` *(in progress)*

Data Studio reads the `reporting` views directly. The dashboard has two tabs: a **Batting** tab (league KPI scorecards, a sortable season leaderboard, and per-game drill-down) and a **Pitching** tab (league KPI scorecards, a season leaderboard, and a per-pitcher pitch-mix breakdown).

## Built For

This project demonstrates end-to-end analytics engineering — ingestion, ELT, warehouse modeling, and BI. It was built as a portfolio piece to showcase practical skills with GCP, dbt, and Python data pipelines, from raw API extraction through tested, dimensional models ready for dashboarding.

## How This Was Built

The codebase was developed with [Claude Code](https://claude.com/claude-code) as a pair-programming tool, working incrementally across the stack: the Python extraction/load pipeline, the dbt staging and mart models, and this BI-ready reporting layer. Each step followed the same loop — define the contract, implement against the real warehouse, then validate with `dbt test` and direct row-count and value checks in BigQuery before moving on. The result is a single, reviewable git history rather than generated boilerplate.
