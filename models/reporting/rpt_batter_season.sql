-- Season-to-date batting line per batter, for the dashboard's batting tab.
-- Grain: one row per batter_id.
-- Rate/expected stats are weighted by their correct denominators (batted balls,
-- plate appearances, at bats) rather than averaged across games.

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

aggregated as (

    select
        batter_id,

        -- volume (additive across games)
        count(distinct game_id) as games,
        sum(plate_appearances) as plate_appearances,
        sum(at_bats) as at_bats,
        sum(hits) as hits,
        sum(home_runs) as home_runs,
        sum(strikeouts) as strikeouts,
        sum(walks) as walks,
        sum(batted_balls) as batted_balls,

        -- contact quality (weighted by batted balls)
        safe_divide(sum(hard_hit_count), sum(batted_balls)) as hard_hit_rate,
        safe_divide(sum(barrel_count), sum(batted_balls)) as barrel_rate,
        safe_divide(
            sum(avg_exit_velocity_mph * batted_balls), sum(batted_balls)
        ) as avg_exit_velocity,
        max(max_exit_velocity_mph) as max_exit_velocity,
        safe_divide(
            sum(avg_launch_angle_deg * batted_balls), sum(batted_balls)
        ) as avg_launch_angle,

        -- expected stats (weighted by their natural denominators)
        safe_divide(
            sum(avg_xwoba * plate_appearances), sum(plate_appearances)
        ) as xwoba,
        safe_divide(sum(avg_xba * at_bats), sum(at_bats)) as xba,
        safe_divide(sum(avg_xslg * at_bats), sum(at_bats)) as xslg

    from batter_games
    group by batter_id

)

select
    a.batter_id,
    concat(p.first_name, ' ', p.last_name) as batter_name,
    a.games,
    a.plate_appearances,
    a.at_bats,
    a.hits,
    a.home_runs,
    a.strikeouts,
    a.walks,
    a.batted_balls,
    a.hard_hit_rate,
    a.barrel_rate,
    a.avg_exit_velocity,
    a.max_exit_velocity,
    a.avg_launch_angle,
    a.xwoba,
    a.xba,
    a.xslg

from aggregated a
left join players p on a.batter_id = p.mlbam_id
