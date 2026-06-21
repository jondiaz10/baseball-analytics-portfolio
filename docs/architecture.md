# System Architecture

End-to-end architecture of the baseball analytics portfolio: a Python ELT pipeline
that ingests pitch-level Statcast data into BigQuery, dbt models that transform it
into BI-ready layers, and **Power BI** as the primary dashboard — with a LookML
semantic-model sample and a public Data Studio demo.

> The standalone diagram source lives in [`architecture.mmd`](./architecture.mmd).
> This diagram uses the `elk` layout engine — it renders in the Mermaid Chart
> extension and mermaid.live, but some viewers (incl. GitHub) may fall back to a
> default layout.

```mermaid
---
config:
  layout: elk
  flowchart:
    curve: stepBefore
---
flowchart TB
    subgraph SRC["🌐 External Sources"]
        direction LR
        SAVANT[/"Baseball Savant\npybaseball.statcast()"/]
        CHADWICK[/"Chadwick Bureau Register\nGitHub people-{0-f}.csv"/]
    end

    subgraph INGEST["🐍 Ingestion Pipeline — Python 3.12 / src/"]
        direction LR
        subgraph INGEST_STATCAST["Statcast Flow"]
            direction TB
            EXTRACT("extract_statcast()\n7-day chunks, rate-limited")
            GCSUP("upload_to_gcs()\nin-memory Parquet (PyArrow)")
            BQLOAD("load_to_bigquery()\nautodetect · --mode append→WRITE_APPEND / full-refresh→WRITE_TRUNCATE")
        end
        subgraph INGEST_PLAYER["Player Lookup Flow"]
            direction TB
            PLEXTRACT("extract_player_lookup()\n16 hex shards → 127,526 players")
            BQLOAD2("load_dataframe_to_bigquery()\nWRITE_TRUNCATE")
        end
    end

    subgraph GCS["☁️ Cloud Storage"]
        PARQUET[("gs://baseball-analytics-raw-data\nstatcast/year=YYYY/month=MM/*.parquet")]
    end

    subgraph RAW["🗄️ BigQuery — raw dataset"]
        direction LR
        RAWPITCH[("raw.statcast_pitches\n~257K pitches · 118 cols")]
        RAWPLAYER[("raw.player_lookup\nplayer registry")]
    end

    subgraph DBT["🔧 dbt — baseball-analytics-portfolio (BigQuery)"]
        direction TB
        subgraph STG["staging (views)"]
            STGPITCH["stg_statcast_pitches\ncleaned, 1 row / pitch"]
        end
        subgraph MARTS["marts (tables)"]
            direction LR
            MBATTER["mart_batter_game_stats\nbatter × game · 17,778"]
            MPITCHER["mart_pitcher_game_stats\npitcher × game · 7,389"]
        end
        subgraph RPT["reporting (views — BI-ready)"]
            direction LR
            RBKPI["rpt_league_batting_kpis"]
            RBSEASON["rpt_batter_season"]
            RBGAME["rpt_batter_game"]
            RPKPI["rpt_league_pitching_kpis"]
            RPSEASON["rpt_pitcher_season"]
            RPMIX["rpt_pitcher_pitch_mix"]
        end
    end

    subgraph BI["📊 Business Intelligence"]
        direction LR
        POWERBI["Power BI  ▸ PRIMARY (live)\nBatter tab · DAX measures reconciled to dbt"]
        STUDIO["Data Studio  ▸ public demo\nBatter Perf · Pitcher Arsenal"]
        LOOKML["LookML semantic model  ▸ sample\nbatter / pitcher explores + player dim\n(no live Looker instance — by choice)"]
    end

    SAVANT --> EXTRACT --> GCSUP --> PARQUET --> BQLOAD --> RAWPITCH
    CHADWICK --> PLEXTRACT --> BQLOAD2 --> RAWPLAYER

    RAWPITCH --> STGPITCH
    STGPITCH --> MBATTER
    STGPITCH --> MPITCHER

    MBATTER --> RBKPI
    MBATTER --> RBSEASON
    MBATTER --> RBGAME
    MPITCHER --> RPKPI
    MPITCHER --> RPSEASON
    MPITCHER --> RPMIX

    RAWPLAYER -.player names.-> RBSEASON
    RAWPLAYER -.player names.-> RPSEASON

    %% Data Studio (public demo) reads the pre-aggregated reporting views
    RBKPI & RBSEASON & RBGAME & RPKPI & RPSEASON & RPMIX --> STUDIO

    %% Power BI (primary) reads the per-game marts; DAX measures reconciled to dbt
    MBATTER --> POWERBI
    MPITCHER --> POWERBI
    RAWPLAYER -.player dim.-> POWERBI

    %% LookML semantic-model sample reads the same marts + player dimension
    MBATTER --> LOOKML
    MPITCHER --> LOOKML
    RAWPLAYER -.player dim.-> LOOKML

    classDef default fill:#f5f5f5,stroke:#999999,stroke-width:1px,color:#333333;
    classDef source fill:#e8f0fe,stroke:#4285f4,stroke-width:2px,color:#174ea6;
    classDef python fill:#fff4e5,stroke:#f9a825,stroke-width:2px,color:#7a5200;
    classDef storage fill:#e6f4ea,stroke:#34a853,stroke-width:2px,color:#0d652d;
    classDef staging fill:#fde8f5,stroke:#d81b60,stroke-width:2px,color:#880e4f;
    classDef mart fill:#f9d0e8,stroke:#ad1457,stroke-width:2px,color:#880e4f;
    classDef report fill:#fce8f3,stroke:#c2185b,stroke-width:2px,color:#880e4f;
    classDef bi fill:#f3e8fd,stroke:#8e24aa,stroke-width:2px,color:#4a148c;

    class SAVANT,CHADWICK source;
    class EXTRACT,PLEXTRACT,GCSUP,BQLOAD,BQLOAD2 python;
    class PARQUET,RAWPITCH,RAWPLAYER storage;
    class STGPITCH staging;
    class MBATTER,MPITCHER mart;
    class RBKPI,RBSEASON,RBGAME,RPKPI,RPSEASON,RPMIX report;
    class POWERBI,STUDIO,LOOKML bi;

    linkStyle default stroke:#999999,stroke-width:1px;
    linkStyle 17 stroke:#8e24aa,stroke-width:2px,stroke-dasharray:5;
    linkStyle 18 stroke:#8e24aa,stroke-width:2px,stroke-dasharray:5;
    linkStyle 27 stroke:#8e24aa,stroke-width:2px,stroke-dasharray:5;
    linkStyle 30 stroke:#8e24aa,stroke-width:2px,stroke-dasharray:5;
```

## Layers

| Layer | Tech | Role |
| ----- | ---- | ---- |
| **Sources** | Baseball Savant, Chadwick Bureau | Pitch-level Statcast events + player ID registry |
| **Ingestion** | Python 3.12 (`src/`, `scripts/`) | Extract → GCS (Parquet) → BigQuery `raw` |
| **Storage** | GCS + BigQuery `raw` | Partitioned Parquet landing zone; append-only raw tables |
| **Transformation** | dbt + BigQuery | `staging` (views) → `marts` (tables) → `reporting` (views) |
| **BI (primary)** | Power BI (DAX reconciled to dbt) | Live primary build — KPI cards, leaderboards, EV-vs-launch-angle scatter |
| **BI (demo)** | Data Studio | Public no-login demo on the `reporting` views |
| **BI (sample)** | LookML semantic model | Alternative semantic-model sample — batter/pitcher explores + player dim (no live Looker instance, by choice) |
