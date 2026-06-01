-- League-wide pitching KPIs as a single summary row for dashboard scorecards.
-- Rate stats are re-derived from raw counts / weighted by the correct
-- denominator (never an average of per-game averages).

select
    safe_divide(
        sum(avg_pitch_velocity_mph * total_pitches), sum(total_pitches)
    ) as league_avg_velocity,
    safe_divide(sum(whiffs), sum(swings)) as league_avg_whiff_rate,
    safe_divide(sum(strikes), sum(total_pitches)) as league_avg_strike_pct

from {{ ref('mart_pitcher_game_stats') }}
