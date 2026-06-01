-- Per-game batting detail for the dashboard's game-log / drill-down view.
-- Grain: one row per batter_id per game (inherited from the mart).
-- Rate stats are re-derived from this game's raw counts via SAFE_DIVIDE.
--
-- KNOWN DATA GAP: the marts carry only the game's home_team / away_team, not the
-- batter's own team, so a clean "Team" filter is not possible here. We do NOT
-- guess the batter's team from home/away. The proper fix is to derive the
-- batting side (and thus team) from inning_topbot in the staging model and carry
-- a batter_team column down through the marts.

with batter_games as (

    select * from {{ ref('mart_batter_game_stats') }}

),

players as (

    select
        mlbam_id,
        first_name,
        last_name
    from {{ source('raw', 'player_lookup') }}

)

select
    bg.batter_id,
    concat(p.first_name, ' ', p.last_name) as batter_name,
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
