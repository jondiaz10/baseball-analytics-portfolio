# Baseball Analytics Portfolio

**End-to-end analytics engineering project:** Statcast pitch data → GCP → BigQuery → dbt → Power BI

🟢 **Live** — ingestion pipeline and dbt models complete (36/36 tests passing); Power BI is the primary BI build with the **Batter Performance** tab complete (Pitcher tab in progress). Data Studio remains a public demo.

---

## Overview

This project pulls pitch-level [Statcast](https://baseballsavant.mlb.com/) data from Baseball Savant, lands it in Google Cloud, models it with dbt on BigQuery, and surfaces per-game batter and pitcher metrics for BI. It demonstrates the full analytics engineering lifecycle: ingestion, ELT, dimensional modeling, testing, and visualization.

## Architecture

```text
Baseball Savant (Statcast) · MLB Stats API (teams/rosters/status) · Chadwick Bureau (player IDs)
        ↓  Python ingestion (pybaseball · statsapi · registry CSVs)
GCS parquet (Statcast)  +  direct DataFrame loads (reference tables)
        ↓
BigQuery raw layer
  statcast_pitches · player_lookup · mlb_teams · mlb_rosters · mlb_roster_status
        ↓
dbt staging (views)
  stg_statcast_pitches · stg_mlb_teams · stg_mlb_rosters · stg_mlb_roster_status
        ↓
dbt marts (tables)
  mart_batter_game_stats · mart_pitcher_game_stats · dim_team · dim_roster_status
        ↓
dbt reporting (views)
  rpt_* — pre-aggregated, BI-ready (+ team_* and availability columns)
        ↓
Power BI  [primary, live]   ·   Data Studio  [public demo]
```

- **Ingestion** — A config-driven Python pipeline extracts Statcast data in weekly chunks, serializes it to parquet in memory, and streams it to GCS partitioned by `year` / `month`. It then loads to BigQuery (`WRITE_APPEND` by default; `--mode full-refresh` truncates). Separate config-driven pipelines load the Chadwick Bureau player ID registry and the MLB Stats API team / roster / status reference tables (direct DataFrame loads, no GCS).
- **Transformation** — dbt models clean and reshape the raw pitch data into a staging layer, then aggregate to per-game mart tables for batters and pitchers.
- **Dimensions** — Two conformed dimensions from the MLB Stats API, joined on `mlbam_id`: **`dim_team`** (30 clubs — league / division / venue) and **`dim_roster_status`** (the full rostered player population with an `availability` label — Active / IL — 10/15/60-Day / Minors / Rehab — plus `is_active` / `is_injured`, deduped to one MLB-facing status per player). Team attributes attach to every `rpt_*` model. **Status attaches as a label only** (`availability` + `status_description`) with **no null-stat rows**: the fact grain stays clean, and the full roster — including absent / injured players who have no stats — lives in `dim_roster_status`, recoverable per-visual in Power BI via a `LEFT JOIN`. A deliberate grain-preservation choice — surface missing players *from the dimension* rather than polluting the stat models with nulls.
- **Reporting** — A thin layer of pre-aggregated dbt **views** (`reporting` dataset) that the BI tools read directly: league KPI scorecards, season-to-date batter and pitcher lines, per-game detail, and pitch mix. All rate stats are denominator-weighted (never an average of averages).
- **BI** — **Power BI** is the primary build, connected live to BigQuery; its DAX measures are reconciled to the dbt models to the decimal so the dashboard and warehouse never disagree. **Data Studio** is kept as a public demo on the same `reporting` views.

## Stack

| Layer | Tool | Purpose |
| --- | --- | --- |
| Cloud | GCP — BigQuery | Data warehouse (raw, staging, marts, reporting) |
| Cloud | GCP — Cloud Storage | Parquet landing zone |
| Transformation | dbt-core 1.11.11 + dbt-bigquery 1.11.1 | ELT modeling, testing, docs |
| Language | Python 3.12 | Ingestion pipeline |
| Libraries | pybaseball, requests (MLB Stats API), pyarrow, google-cloud-bigquery, google-cloud-bigquery-storage | Extract, serialize, load |
| Testing | pytest (mocked API calls) | Pipeline unit tests |
| BI (primary) | Power BI (DAX measures reconciled to dbt) | Primary dashboard on the `reporting` views — live BigQuery connection |
| BI (demo) | Data Studio | Public demo dashboard on the `reporting` views |
| Version control | GitHub | Source control |
| AI assistant | Claude Code (Anthropic) | Development |

## Project Structure

```text
baseball-analytics/
├── config/
│   └── pipeline_config.yaml         # bucket / project / dataset config (no hardcoded names)
├── src/                             # ingestion package
│   ├── extract/
│   │   ├── statcast_extract.py      # pull Statcast in weekly chunks
│   │   ├── player_lookup_extract.py # pull Chadwick Bureau registry
│   │   └── mlb_team_extract.py      # pull MLB Stats API teams/rosters/status
│   ├── load/
│   │   ├── gcs_loader.py            # serialize to parquet → GCS (in memory)
│   │   └── bq_loader.py             # GCS parquet → BigQuery (WRITE_APPEND)
│   └── utils/
│       └── logger.py
├── scripts/
│   ├── run_pipeline.py              # entry point: Statcast ingestion
│   ├── run_player_lookup.py         # entry point: player lookup ingestion
│   └── run_team_data.py             # entry point: MLB teams/rosters/status
├── models/                          # dbt project (lives at repo root)
│   ├── staging/
│   │   ├── stg_statcast_pitches.sql
│   │   ├── stg_mlb_teams.sql
│   │   ├── stg_mlb_rosters.sql
│   │   ├── stg_mlb_roster_status.sql
│   │   ├── sources.yml
│   │   └── schema.yml
│   ├── marts/
│   │   ├── mart_batter_game_stats.sql
│   │   ├── mart_pitcher_game_stats.sql
│   │   ├── dim_team.sql              # team dimension (30 clubs)
│   │   ├── dim_roster_status.sql     # roster/availability dimension
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
- **44,709** batted balls (balls in play; tracked foul balls excluded)
- **118** raw columns cleaned in the staging layer
- **127,526** players in the reference table
- **30** MLB teams + **8,189** rostered players (team & availability dimensions)
- **36/36** dbt tests passing

### League KPIs (2026 season-to-date, denominator-weighted)

| Metric | Value |
| --- | --- |
| Avg exit velocity | 88.2 mph |
| Hard-hit rate (95+ mph) | 39.3% |
| Barrel rate | 8.1% |
| Avg xwOBA | .320 |
| Avg pitch velocity | 89.5 mph |
| Whiff rate | 23.0% |
| Strike rate | 46.1% |

> Batted-ball metrics are computed over balls in play only (`pitch_outcome_category = 'X'`). Statcast also records exit velocity on foul balls; counting those as batted balls had deflated league exit velocity to 82.7 mph and hard-hit rate to 24.6%, so the predicate was corrected upstream in the marts.

## dbt Models

| Model | Layer | Grain | Description |
| --- | --- | --- | --- |
| `stg_statcast_pitches` | staging | one row per pitch | Cleans 118 raw columns, casts `game_date` integer → DATE, drops deprecated columns, renames for clarity, filters null pitch types — 257,220 rows |
| `stg_mlb_teams` | staging | team | Cleans MLB Stats API teams (league / division / venue) — 30 rows |
| `stg_mlb_rosters` | staging | player | 40-man player → team map, deduped to one current team per player |
| `stg_mlb_roster_status` | staging | player | fullRoster availability (Active / IL / Minors …) + `is_active`/`is_injured`, deduped — 8,189 rows |
| `mart_batter_game_stats` | mart | batter × game | Exit velocity, xwOBA, hard-hit rate, barrel rate, bat speed, and swing metrics — 17,778 rows |
| `mart_pitcher_game_stats` | mart | pitcher × game | Velocity, whiff rate, strike %, pitch-mix percentages (9 pitch types), hard-hit-allowed rate — 7,389 rows |
| `dim_team` | mart | team | Conformed team dimension (league / division / venue) — 30 rows |
| `dim_roster_status` | mart | player | Full rostered population + `availability` label, independent of stats — 8,189 rows |
| `rpt_league_batting_kpis` | reporting | 1 row | League exit velocity, xwOBA, hard-hit rate (denominator-weighted) |
| `rpt_batter_season` | reporting | batter | Season-to-date batting line, named via player_lookup; + current team & availability — 530 rows |
| `rpt_batter_game` | reporting | batter × game | Per-game batting detail for drill-down; + current team & availability — 17,778 rows |
| `rpt_league_pitching_kpis` | reporting | 1 row | League velocity, whiff rate, strike % (denominator-weighted) |
| `rpt_pitcher_season` | reporting | pitcher | Season-to-date pitching line; + current team & availability — 654 rows |
| `rpt_pitcher_pitch_mix` | reporting | pitcher × pitch type | Long-format pitch mix, weighted by pitches; + current team & availability — 5,886 rows |

All reporting models are **views** in a dedicated `reporting` BigQuery dataset, so the BI layer reads pre-shaped, pre-aggregated data with no in-dashboard math.

## Setup

### Prerequisites

- Python 3.12
- A GCP project with BigQuery + Cloud Storage enabled
- `gcloud` CLI authenticated (Application Default Credentials)

### Steps

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

# Reference tables (MLB Stats API: teams, rosters, availability/status)
python scripts/run_team_data.py
```

**Run the dbt models and tests:**

```bash
dbt build
```

## Data Sources

| Source | Data | Access |
| --- | --- | --- |
| [Baseball Savant](https://baseballsavant.mlb.com/) (Statcast) | Pitch-level tracking data | `pybaseball` |
| [Chadwick Bureau](https://github.com/chadwickbureau/register) | Player ID registry (127,526 players) | GitHub CSV |
| [MLB Stats API](https://statsapi.mlb.com/) | Teams, 40-man + full rosters, player availability/status | REST (`statsapi.mlb.com`, no auth) |

## Dashboards

### Power BI — primary build

Connected live to BigQuery through the `reporting` views. The DAX measures are reconciled to the dbt models to the decimal, so the dashboard and the warehouse never disagree on a number.

- **Batter Performance** *(complete)* — league KPI scorecards (avg exit velocity, hard-hit %, xwOBA), a qualified-hitter leaderboard (min. 50 batted balls) sortable by xwOBA, and an exit-velocity vs. launch-angle scatter color-coded by xwOBA tier and sized by batted balls, visualizing where elite production clusters in the contact-quality space.
- **Pitcher Performance** *(in progress)* — will mirror the batter tab: league KPI scorecards (avg velocity, whiff %, strike %), a whiff-rate leaderboard (min. 250 pitches), and a cross-filtering pitch-mix breakdown.

> **Published link:** *Power BI Service publish pending* (`<POWER_BI_LINK_TBD>`) — awaiting an M365 Developer tenant.

### Data Studio — public demo

A public, no-login demo on the same `reporting` views: **[MLB Statcast Analytics — 2026 Season](<DATA_STUDIO_LINK_TBD>)**.

## Built For

This project demonstrates end-to-end analytics engineering — ingestion, ELT, warehouse modeling, and BI. It was built as a portfolio piece to showcase practical skills with GCP, dbt, and Python data pipelines, from raw API extraction through tested, dimensional models ready for dashboarding.

## How This Was Built

This project was built with an AI-assisted workflow as a deliberate test of development velocity. Claude Code drove the extraction pipeline and dbt models; the reporting-layer SQL was AI-generated against the documented schema. The analytical judgment stayed human: during validation I flagged that league average exit velocity was reading 82.7 mph against a real-world ~88, traced it to tracked foul balls being miscounted as batted balls, and corrected the batted-ball predicate across both marts — restoring exit velocity to 88.2 mph and hard-hit rate to a realistic 39.3%. The takeaway: AI accelerates the build, but domain knowledge is what catches the bugs that pass every unit test.

The same rigor carries into the BI layer: in Power BI, every DAX measure on the Batter Performance tab is reconciled against its dbt counterpart to the decimal, so the warehouse and the dashboard can never quietly drift apart.
