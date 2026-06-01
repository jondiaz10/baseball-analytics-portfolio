-- League-wide batting KPIs as a single summary row for dashboard scorecards.
-- Rate stats are re-derived from raw counts / weighted by the correct
-- denominator (never an average of per-game averages).

select
    safe_divide(
        sum(avg_exit_velocity_mph * batted_balls), sum(batted_balls)
    ) as league_avg_exit_velocity,
    safe_divide(
        sum(avg_xwoba * plate_appearances), sum(plate_appearances)
    ) as league_avg_xwoba,
    safe_divide(sum(hard_hit_count), sum(batted_balls)) as league_hard_hit_rate

from {{ ref('mart_batter_game_stats') }}
