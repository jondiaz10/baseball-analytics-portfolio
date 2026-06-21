-- Per-game batting detail for the dashboard's game-log / drill-down view.
-- Grain: one row per batter_id per game (inherited from the mart).
-- Rate stats are re-derived from this game's raw counts via SAFE_DIVIDE.
--
-- TEAM (v1): the batter's CURRENT team is attached from the 40-man roster
-- (stg_mlb_rosters -> dim_team), giving a clean "Team" slicer. Note this is the
-- player's present club, not necessarily their team on this game's date — a
-- trade-aware, per-game historical team is a separate V2 ticket (derive the
-- batting side from inning_topbot in staging and carry batter_team through the
-- marts). The mart's home_team / away_team remain the game context.

with batter_games as (

    select * from {{ ref('mart_batter_game_stats') }}

),

players as (

    select
        mlbam_id,
        first_name,
        last_name
    from {{ source('raw', 'player_lookup') }}

),

roster as (

    select mlbam_id, team_id from {{ ref('stg_mlb_rosters') }}

),

teams as (

    select
        team_id,
        team_abbrev,
        team_name,
        league_name,
        division_name
    from {{ ref('dim_team') }}

)

select
    bg.batter_id,
    concat(p.first_name, ' ', p.last_name) as batter_name,
    t.team_id,
    t.team_abbrev,
    t.team_name,
    t.league_name,
    t.division_name,
    bg.game_date,
    bg.home_team,
    bg.away_team,
    bg.batter_side,
    bg.plate_appearances,
    bg.batted_balls,
    bg.avg_exit_velocity_mph,
    bg.max_exit_velocity_mph,
    bg.avg_launch_angle_deg,
    safe_divide(bg.hard_hit_count, bg.batted_balls) as hard_hit_rate,
    safe_divide(bg.barrel_count, bg.batted_balls) as barrel_rate,
    bg.avg_xwoba

from batter_games bg
left join players p on bg.batter_id = p.mlbam_id
left join roster r on bg.batter_id = r.mlbam_id
left join teams t on r.team_id = t.team_id
