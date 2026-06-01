-- Season-to-date pitching line per pitcher, for the dashboard's pitching tab.
-- Grain: one row per pitcher_id.
-- pitcher_name / pitcher_throws come straight from the mart (no lookup join
-- needed). Rate and velocity/spin stats are weighted by total pitches rather
-- than averaged across games.
--
-- KNOWN DATA GAP: the marts carry only the game's home_team / away_team, not the
-- pitcher's own team, so a clean "Team" filter is not possible here. We do NOT
-- guess the pitcher's team from home/away. The proper fix is to derive the
-- pitching side (and thus team) from inning_topbot in the staging model and
-- carry a pitcher_team column down through the marts.

with pitcher_games as (

    select * from {{ ref('mart_pitcher_game_stats') }}

)

select
    pitcher_id,
    pitcher_name,
    pitcher_throws,

    -- volume (additive across games)
    count(distinct game_id) as games,
    sum(total_pitches) as total_pitches,
    sum(batters_faced) as batters_faced,
    sum(strikeouts) as strikeouts,
    sum(walks) as walks,
    sum(hits_allowed) as hits_allowed,
    sum(home_runs_allowed) as home_runs_allowed,

    -- command (weighted by their denominators)
    safe_divide(sum(whiffs), sum(swings)) as whiff_rate,
    safe_divide(sum(strikes), sum(total_pitches)) as strike_pct,

    -- pitch quality (weighted by total pitches)
    safe_divide(
        sum(avg_pitch_velocity_mph * total_pitches), sum(total_pitches)
    ) as avg_velocity,
    max(max_pitch_velocity_mph) as max_velocity,
    safe_divide(
        sum(avg_spin_rate_rpm * total_pitches), sum(total_pitches)
    ) as avg_spin_rate,
    safe_divide(
        sum(avg_extension_ft * total_pitches), sum(total_pitches)
    ) as avg_extension

from pitcher_games
group by pitcher_id, pitcher_name, pitcher_throws
