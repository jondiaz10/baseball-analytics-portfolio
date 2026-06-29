-- Per-game batting detail for the dashboard's game-log / drill-down view.
-- Grain: one row per batter_id per game (inherited from the mart).
-- Rate stats are re-derived from this game's raw counts via SAFE_DIVIDE.
--
-- TEAM (team-of-record): the batter's team ON THIS GAME'S DATE, derived from the
-- event in staging (inning_topbot + home/away) and carried through the mart as
-- batter_team. dim_team is joined on the event abbreviation to attach team_id /
-- name / league / division, so this is trade-aware: a traded player shows each
-- club on the games actually played there. dim_roster_status now supplies the
-- CURRENT availability / status label only (current-roster surfacing), NOT team.

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

teams as (

    select
        team_id,
        team_abbrev,
        team_name,
        league_name,
        division_name
    from {{ ref('dim_team') }}

),

status as (

    select mlbam_id, availability, status_description
    from {{ ref('dim_roster_status') }}

)

select
    bg.batter_id,
    concat(p.first_name, ' ', p.last_name) as batter_name,
    bg.batter_team,
    t.team_id,
    t.team_abbrev,
    t.team_name,
    t.league_name,
    t.division_name,
    s.availability,
    s.status_description,
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
left join teams t on bg.batter_team = t.team_abbrev
left join status s on bg.batter_id = s.mlbam_id
