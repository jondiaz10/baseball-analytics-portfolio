# Data Dictionary — baseball-analytics

**Generated:** 2026-07-02
**Source commit:** `164c500` (team-of-record Slice 2 — season split-by-stint)
**Scope:** Consumable model layers — dimensions, game-grain marts, the team-origin
slice of staging, and reporting. Raw (`raw.*`) is intentionally excluded.

Descriptions are pulled from each model's `schema.yml` where present. Columns with
no `schema.yml` entry carry a concise **(inferred)** description and are also listed
in the [Undocumented columns](#undocumented-columns) backlog at the end.

---

## Dimensions

### dim_team

- **Layer:** dimension
- **Grain:** one row per `team_id`
- **Purpose:** Conformed team dimension for slicing batter/pitcher reporting by team, league, and division.
- **Built on:** `stg_mlb_teams`

| Column | Type | Description |
| --- | --- | --- |
| team_id | INTEGER | MLB Stats API team id |
| team_name | STRING | Full club name (e.g., "Atlanta Braves") (inferred) |
| team_abbrev | STRING | Team abbreviation (e.g., "ATL"); matches Statcast event team codes (inferred) |
| team_short_name | STRING | Short club name (e.g., "Atlanta") (inferred) |
| location_name | STRING | Club location / city name (inferred) |
| league_id | INTEGER | MLB Stats API league id (inferred) |
| league_name | STRING | League name (American/National League) (inferred) |
| division_id | INTEGER | MLB Stats API division id (inferred) |
| division_name | STRING | Division name (e.g., "NL East") (inferred) |
| venue_name | STRING | Home venue name (inferred) |

### dim_roster_status

- **Layer:** dimension
- **Grain:** one row per `mlbam_id`
- **Purpose:** Roster / availability dimension — the full rostered player population, independent of Statcast stats, so absent/injured players are never silently dropped. Supplies **current** availability/status labels only (not team-of-record).
- **Built on:** `stg_mlb_roster_status`, `dim_team`

| Column | Type | Description |
| --- | --- | --- |
| mlbam_id | INTEGER | MLBAM player id (joins to batter_id / pitcher_id) |
| player_full_name | STRING | Player full name (inferred) |
| team_id | INTEGER | Current team id (MLB Stats API) (inferred) |
| team_abbrev | STRING | Current team abbreviation (inferred) |
| team_name | STRING | Current team full name (inferred) |
| league_name | STRING | Current league name (inferred) |
| division_name | STRING | Current division name (inferred) |
| status_code | STRING | MLB Stats API roster status code (inferred) |
| status_description | STRING | Roster status description (inferred) |
| availability | STRING | Clean availability label (Active / IL — 10-Day / Minors / ...) |
| is_active | BOOLEAN | Whether the player is currently active (inferred) |
| is_injured | BOOLEAN | Whether the player is currently on the IL (inferred) |

---

## Marts (game grain)

### mart_batter_game_stats

- **Layer:** mart
- **Grain:** one row per `batter_id` + `game_id` (batter-game)
- **Purpose:** Batter performance aggregated per game — Statcast batted-ball metrics, expected stats, swing metrics, and 2024+ bat tracking.
- **Built on:** `stg_statcast_pitches`

| Column | Type | Description |
| --- | --- | --- |
| batter_id | INTEGER | MLB player ID for the batter |
| game_id | INTEGER | MLB game identifier |
| game_date | DATE | Date of the game |
| game_year | INTEGER | Season year (inferred) |
| home_team | STRING | Home team abbreviation for the game (inferred) |
| away_team | STRING | Away team abbreviation for the game (inferred) |
| batter_team | STRING | Event-derived team-of-record for the batter on this game's date |
| batter_side | STRING | Batter handedness for the game, L/R (inferred) |
| total_pitches | INTEGER | Pitches seen by the batter in the game (inferred) |
| plate_appearances | INTEGER | Total plate appearances in the game |
| at_bats | INTEGER | At-bats (PA excluding walks, HBP, sacrifices, interference) (inferred) |
| hits | INTEGER | Total hits (singles + doubles + triples + home runs) (inferred) |
| singles | INTEGER | Singles (inferred) |
| doubles | INTEGER | Doubles (inferred) |
| triples | INTEGER | Triples (inferred) |
| home_runs | INTEGER | Home runs (inferred) |
| strikeouts | INTEGER | Strikeouts (incl. strikeout double plays) (inferred) |
| walks | INTEGER | Walks (incl. intentional) (inferred) |
| swings | INTEGER | Total swings (inferred) |
| whiffs | INTEGER | Swinging misses (inferred) |
| whiff_rate | FLOAT | Rate of swings that result in a miss |
| avg_exit_velocity_mph | FLOAT | Average exit velocity on batted balls |
| max_exit_velocity_mph | FLOAT | Max exit velocity on batted balls in the game (inferred) |
| avg_launch_angle_deg | FLOAT | Average launch angle on batted balls, degrees (inferred) |
| hard_hit_count | INTEGER | Batted balls with exit velocity >= 95 mph (inferred) |
| batted_balls | INTEGER | Balls put in play (pitch_outcome_category = 'X') (inferred) |
| hard_hit_rate | FLOAT | Rate of batted balls with exit velocity >= 95 mph |
| barrel_count | INTEGER | Barreled balls (launch_speed_angle = 6) (inferred) |
| barrel_rate | FLOAT | Rate of barreled balls (launch_speed_angle = 6) |
| avg_xba | FLOAT | Average expected batting average (inferred) |
| avg_xwoba | FLOAT | Average expected weighted on-base average |
| avg_xslg | FLOAT | Average expected slugging percentage (inferred) |
| avg_bat_speed | FLOAT | Average bat speed, mph (2024+ metric) (inferred) |
| avg_swing_length | FLOAT | Average swing length, feet (2024+ metric) (inferred) |

### mart_pitcher_game_stats

- **Layer:** mart
- **Grain:** one row per `pitcher_id` + `game_id` (pitcher-game)
- **Purpose:** Pitcher performance aggregated per game — pitch mix, velocity, command metrics, whiff rate, and contact quality allowed.
- **Built on:** `stg_statcast_pitches`

| Column | Type | Description |
| --- | --- | --- |
| pitcher_id | INTEGER | MLB player ID for the pitcher |
| pitcher_name | STRING | Pitcher full name (inferred) |
| game_id | INTEGER | MLB game identifier |
| game_date | DATE | Date of the game |
| game_year | INTEGER | Season year (inferred) |
| home_team | STRING | Home team abbreviation for the game (inferred) |
| away_team | STRING | Away team abbreviation for the game (inferred) |
| pitching_team | STRING | Event-derived team-of-record for the pitcher on this game's date |
| pitcher_throws | STRING | Pitcher throwing arm, L/R (inferred) |
| total_pitches | INTEGER | Total pitches thrown in the game |
| batters_faced | INTEGER | Distinct batters faced (inferred) |
| strikeouts | INTEGER | Strikeouts recorded (inferred) |
| walks | INTEGER | Walks allowed (incl. intentional) (inferred) |
| hits_allowed | INTEGER | Hits allowed (inferred) |
| home_runs_allowed | INTEGER | Home runs allowed (inferred) |
| avg_pitch_velocity_mph | FLOAT | Average fastball/pitch velocity |
| max_pitch_velocity_mph | FLOAT | Max pitch velocity in the game (inferred) |
| avg_spin_rate_rpm | FLOAT | Average spin rate, RPM (inferred) |
| avg_extension_ft | FLOAT | Average release extension, feet (inferred) |
| strikes | INTEGER | Pitches counted as strikes (pitch_outcome_category = 'S') (inferred) |
| balls | INTEGER | Pitches counted as balls (pitch_outcome_category = 'B') (inferred) |
| strike_pct | FLOAT | Percentage of pitches that are strikes |
| called_strikes | INTEGER | Called strikes (inferred) |
| swings | INTEGER | Swings induced (inferred) |
| whiffs | INTEGER | Swinging misses induced (inferred) |
| whiff_rate | FLOAT | Rate of swings that result in a miss |
| pct_four_seam | FLOAT | Share of pitches that are four-seam fastballs (inferred) |
| pct_sinker | FLOAT | Share of pitches that are sinkers (inferred) |
| pct_cutter | FLOAT | Share of pitches that are cutters (inferred) |
| pct_slider | FLOAT | Share of pitches that are sliders (inferred) |
| pct_sweeper | FLOAT | Share of pitches that are sweepers (inferred) |
| pct_curveball | FLOAT | Share of pitches that are curveballs (inferred) |
| pct_changeup | FLOAT | Share of pitches that are changeups (inferred) |
| pct_splitter | FLOAT | Share of pitches that are splitters (inferred) |
| pct_other | FLOAT | Share of pitches of other/unclassified types (inferred) |
| avg_exit_velocity_allowed | FLOAT | Average exit velocity allowed on batted balls (inferred) |
| avg_launch_angle_allowed | FLOAT | Average launch angle allowed, degrees (inferred) |
| hard_hit_allowed_count | INTEGER | Batted balls allowed with EV >= 95 mph (inferred) |
| batted_balls_allowed | INTEGER | Balls put in play against the pitcher (inferred) |
| hard_hit_allowed_rate | FLOAT | Rate of batted balls >= 95 mph against this pitcher |
| avg_xba_against | FLOAT | Average expected batting average against (inferred) |
| avg_xwoba_against | FLOAT | Average expected wOBA against (inferred) |

---

## Staging (team-origin only)

### stg_statcast_pitches

- **Layer:** staging
- **Grain:** one row per pitch
- **Purpose:** Cleaned and renamed Statcast pitch-level data. **Origin of team-of-record**: `batter_team` / `pitching_team` are derived here from `inning_half` + `home_team`/`away_team` and carried game-grain through the marts. (Only the team-origin columns are documented here; the model has ~100 pitch-level columns in total.)
- **Built on:** `raw.statcast_pitches`

| Column | Type | Description |
| --- | --- | --- |
| game_id | INTEGER | Unique game identifier (MLB game_pk) |
| game_date | DATE | Date of the game |
| batter_id | INTEGER | MLB player ID for the batter |
| pitcher_id | INTEGER | MLB player ID for the pitcher |
| home_team | STRING | Home team abbreviation for the game (inferred) |
| away_team | STRING | Away team abbreviation for the game (inferred) |
| inning_half | STRING | Half-inning, "Top"/"Bot"; drives team-of-record derivation (inferred) |
| batter_team | STRING | Team-of-record for the batter: `away_team` when `inning_half = 'Top'`, else `home_team` (inferred) |
| pitching_team | STRING | Team-of-record for the pitcher: `home_team` when `inning_half = 'Top'`, else `away_team` (inferred) |

---

## Reporting

### rpt_batter_game

- **Layer:** reporting
- **Grain:** one row per `batter_id` per game
- **Purpose:** Per-game batting detail (game-log / drill-down). Carries the event-derived team-of-record for the game date, resolved via `dim_team`.
- **Built on:** `mart_batter_game_stats`, `dim_team`, `dim_roster_status`, `raw.player_lookup`

| Column | Type | Description |
| --- | --- | --- |
| batter_id | INTEGER | MLBAM player id |
| batter_name | STRING | Batter full name from player_lookup (inferred) |
| batter_team | STRING | Event-derived team-of-record (abbrev) for the batter on this game's date |
| team_id | INTEGER | Team-of-record id, resolved from batter_team via dim_team (inferred) |
| team_abbrev | STRING | Team-of-record abbreviation via dim_team (inferred) |
| team_name | STRING | Team-of-record full name via dim_team (inferred) |
| league_name | STRING | League of the team-of-record (inferred) |
| division_name | STRING | Division of the team-of-record (inferred) |
| availability | STRING | Player's current availability label from dim_roster_status (inferred) |
| status_description | STRING | Player's current roster status from dim_roster_status (inferred) |
| game_date | DATE | Date of the game |
| home_team | STRING | Home team abbreviation for the game (inferred) |
| away_team | STRING | Away team abbreviation for the game (inferred) |
| batter_side | STRING | Batter handedness for the game, L/R (inferred) |
| plate_appearances | INTEGER | Plate appearances in the game (inferred) |
| batted_balls | INTEGER | Balls put in play in the game (inferred) |
| avg_exit_velocity_mph | FLOAT | Average exit velocity on batted balls (inferred) |
| max_exit_velocity_mph | FLOAT | Max exit velocity on batted balls (inferred) |
| avg_launch_angle_deg | FLOAT | Average launch angle, degrees (inferred) |
| hard_hit_rate | FLOAT | Rate of batted balls >= 95 mph (re-derived in-model) (inferred) |
| barrel_rate | FLOAT | Rate of barreled balls (re-derived in-model) (inferred) |
| avg_xwoba | FLOAT | Average expected weighted on-base average (inferred) |

### rpt_batter_season

- **Layer:** reporting
- **Grain:** one row per `batter_id` + `batter_team` (batter per team-stint)
- **Purpose:** Season-to-date batting line per batter, split by team-stint, denominator-weighted. A traded batter has one row per club; the combined season line is a downstream SUM of the summable components (rates recompute from weighted components, never averaged).
- **Built on:** `mart_batter_game_stats`, `dim_team`, `dim_roster_status`, `raw.player_lookup`
- **Note:** Team is **event-derived** (the club the batter played for, carried game-grain from the marts), trade-aware — not the current 40-man roster.

| Column | Type | Description |
| --- | --- | --- |
| batter_id | INTEGER | MLBAM player id (part of grain) |
| batter_name | STRING | Batter full name (inferred) |
| batter_team | STRING | Event-derived team-of-record (abbrev) for this stint; grain key (inferred) |
| team_id | INTEGER | Stint team id, joined from dim_team on the event abbrev (inferred) |
| team_abbrev | STRING | Stint team abbreviation, from dim_team (inferred) |
| team_name | STRING | Stint team full name (inferred) |
| league_name | STRING | Stint team league name (inferred) |
| division_name | STRING | Stint team division name (inferred) |
| availability | STRING | Current availability label (inferred) |
| status_description | STRING | Current roster status (inferred) |
| games | INTEGER | Games played in the season (inferred) |
| plate_appearances | INTEGER | Season plate appearances (inferred) |
| at_bats | INTEGER | Season at-bats (inferred) |
| hits | INTEGER | Season hits (inferred) |
| home_runs | INTEGER | Season home runs (inferred) |
| strikeouts | INTEGER | Season strikeouts (inferred) |
| walks | INTEGER | Season walks (inferred) |
| batted_balls | INTEGER | Season batted balls (inferred) |
| hard_hit_rate | FLOAT | Season rate of batted balls >= 95 mph (inferred) |
| barrel_rate | FLOAT | Season barrel rate (inferred) |
| avg_exit_velocity | FLOAT | Season average exit velocity (inferred) |
| max_exit_velocity | FLOAT | Season max exit velocity (inferred) |
| avg_launch_angle | FLOAT | Season average launch angle (inferred) |
| xwoba | FLOAT | Season expected wOBA (inferred) |
| xba | FLOAT | Season expected batting average (inferred) |
| xslg | FLOAT | Season expected slugging (inferred) |

### rpt_pitcher_pitch_mix

- **Layer:** reporting
- **Grain:** one row per `pitcher_id` + `pitching_team` + `pitch_type`
- **Purpose:** Pitch mix in long format, split by team-stint; season `pitch_pct` re-weighted by total pitches **within** the team-stint (a multi-team pitcher's usage per club is never blended across a trade).
- **Built on:** `mart_pitcher_game_stats`, `dim_team`, `dim_roster_status`
- **Note:** Team is **event-derived** (the club the pitcher threw for, carried game-grain from the marts), trade-aware — not the current 40-man roster.

| Column | Type | Description |
| --- | --- | --- |
| pitcher_id | INTEGER | MLBAM player id (part of grain) |
| pitcher_name | STRING | Pitcher full name (inferred) |
| pitching_team | STRING | Event-derived team-of-record (abbrev) for this stint; grain key (inferred) |
| team_id | INTEGER | Stint team id, joined from dim_team on the event abbrev (inferred) |
| team_abbrev | STRING | Stint team abbreviation, from dim_team (inferred) |
| team_name | STRING | Stint team full name (inferred) |
| league_name | STRING | Stint team league name (inferred) |
| division_name | STRING | Stint team division name (inferred) |
| availability | STRING | Current availability label (inferred) |
| status_description | STRING | Current roster status (inferred) |
| pitch_type | STRING | Normalized pitch-type label (four_seam, sinker, ...) |
| pitch_pct | FLOAT | Share of pitches of this type, re-weighted by total pitches (inferred) |

### rpt_pitcher_season

- **Layer:** reporting
- **Grain:** one row per `pitcher_id` + `pitching_team` (pitcher per team-stint)
- **Purpose:** Season-to-date pitching line per pitcher, split by team-stint, denominator-weighted. A traded pitcher has one row per club; the combined season line is a downstream SUM of the summable components (rates recompute from weighted components, never averaged).
- **Built on:** `mart_pitcher_game_stats`, `dim_team`, `dim_roster_status`
- **Note:** Team is **event-derived** (the club the pitcher threw for, carried game-grain from the marts), trade-aware — not the current 40-man roster.

| Column | Type | Description |
| --- | --- | --- |
| pitcher_id | INTEGER | MLBAM player id (part of grain) |
| pitcher_name | STRING | Pitcher full name (inferred) |
| pitcher_throws | STRING | Pitcher throwing arm, L/R (inferred) |
| pitching_team | STRING | Event-derived team-of-record (abbrev) for this stint; grain key (inferred) |
| team_id | INTEGER | Stint team id, joined from dim_team on the event abbrev (inferred) |
| team_abbrev | STRING | Stint team abbreviation, from dim_team (inferred) |
| team_name | STRING | Stint team full name (inferred) |
| league_name | STRING | Stint team league name (inferred) |
| division_name | STRING | Stint team division name (inferred) |
| availability | STRING | Current availability label (inferred) |
| status_description | STRING | Current roster status (inferred) |
| games | INTEGER | Games pitched in the season (inferred) |
| total_pitches | INTEGER | Season total pitches (inferred) |
| batters_faced | INTEGER | Season batters faced (inferred) |
| strikeouts | INTEGER | Season strikeouts (inferred) |
| walks | INTEGER | Season walks allowed (inferred) |
| hits_allowed | INTEGER | Season hits allowed (inferred) |
| home_runs_allowed | INTEGER | Season home runs allowed (inferred) |
| whiff_rate | FLOAT | Season whiff rate (inferred) |
| strike_pct | FLOAT | Season strike percentage (inferred) |
| avg_velocity | FLOAT | Season average pitch velocity (inferred) |
| max_velocity | FLOAT | Season max pitch velocity (inferred) |
| avg_spin_rate | FLOAT | Season average spin rate (inferred) |
| avg_extension | FLOAT | Season average release extension (inferred) |

### rpt_league_batting_kpis

- **Layer:** reporting
- **Grain:** single summary row (league-wide)
- **Purpose:** League-wide batting KPIs, denominator-weighted from `mart_batter_game_stats`. Feeds dashboard scorecards.
- **Built on:** `mart_batter_game_stats`

| Column | Type | Description |
| --- | --- | --- |
| league_avg_exit_velocity | FLOAT | League-wide average exit velocity (inferred) |
| league_avg_xwoba | FLOAT | League-wide average expected wOBA (inferred) |
| league_hard_hit_rate | FLOAT | League-wide hard-hit rate (inferred) |

### rpt_league_pitching_kpis

- **Layer:** reporting
- **Grain:** single summary row (league-wide)
- **Purpose:** League-wide pitching KPIs, denominator-weighted from `mart_pitcher_game_stats`. Feeds dashboard scorecards.
- **Built on:** `mart_pitcher_game_stats`

| Column | Type | Description |
| --- | --- | --- |
| league_avg_velocity | FLOAT | League-wide average pitch velocity (inferred) |
| league_avg_whiff_rate | FLOAT | League-wide average whiff rate (inferred) |
| league_avg_strike_pct | FLOAT | League-wide average strike percentage (inferred) |

---

## Undocumented columns

Columns with no `schema.yml` entry in their own model (the backlog for future
documentation). Names above marked **(inferred)** correspond to these.

- **dim_team:** team_name, team_abbrev, team_short_name, location_name, league_id, league_name, division_id, division_name, venue_name
- **dim_roster_status:** player_full_name, team_id, team_abbrev, team_name, league_name, division_name, status_code, status_description, is_active, is_injured
- **mart_batter_game_stats:** game_year, home_team, away_team, batter_side, total_pitches, at_bats, hits, singles, doubles, triples, home_runs, strikeouts, walks, swings, whiffs, max_exit_velocity_mph, avg_launch_angle_deg, hard_hit_count, batted_balls, barrel_count, avg_xba, avg_xslg, avg_bat_speed, avg_swing_length
- **mart_pitcher_game_stats:** pitcher_name, game_year, home_team, away_team, pitcher_throws, batters_faced, strikeouts, walks, hits_allowed, home_runs_allowed, max_pitch_velocity_mph, avg_spin_rate_rpm, avg_extension_ft, strikes, balls, called_strikes, swings, whiffs, pct_four_seam, pct_sinker, pct_cutter, pct_slider, pct_sweeper, pct_curveball, pct_changeup, pct_splitter, pct_other, avg_exit_velocity_allowed, avg_launch_angle_allowed, hard_hit_allowed_count, batted_balls_allowed, avg_xba_against, avg_xwoba_against
- **stg_statcast_pitches (team-origin shown):** home_team, away_team, inning_half, batter_team, pitching_team _(plus ~90 further pitch-level columns out of scope here)_
- **rpt_batter_game:** batter_name, team_id, team_abbrev, team_name, league_name, division_name, availability, status_description, home_team, away_team, batter_side, plate_appearances, batted_balls, avg_exit_velocity_mph, max_exit_velocity_mph, avg_launch_angle_deg, hard_hit_rate, barrel_rate, avg_xwoba
- **rpt_batter_season:** all except batter_id
- **rpt_pitcher_pitch_mix:** all except pitcher_id, pitch_type
- **rpt_pitcher_season:** all except pitcher_id
- **rpt_league_batting_kpis:** all (league_avg_exit_velocity, league_avg_xwoba, league_hard_hit_rate)
- **rpt_league_pitching_kpis:** all (league_avg_velocity, league_avg_whiff_rate, league_avg_strike_pct)
