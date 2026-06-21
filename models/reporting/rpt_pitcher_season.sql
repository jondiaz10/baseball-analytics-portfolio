-- Season-to-date pitching line per pitcher, for the dashboard's pitching tab.
-- Grain: one row per pitcher_id.
-- pitcher_name / pitcher_throws come straight from the mart (no lookup join
-- needed). Rate and velocity/spin stats are weighted by total pitches rather
-- than averaged across games.
--
-- TEAM (v1): the pitcher's CURRENT team is attached from the 40-man roster
-- (stg_mlb_rosters -> dim_team) for a clean "Team" slicer. This is the present
-- club, not necessarily the team on a given game date — a trade-aware, per-game
-- historical team is a separate V2 ticket.

with pitcher_games as (

    select * from {{ ref('mart_pitcher_game_stats') }}

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

),

status as (

    select mlbam_id, availability, status_description
    from {{ ref('dim_roster_status') }}

),

aggregated as (

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

)

select
    a.pitcher_id,
    a.pitcher_name,
    a.pitcher_throws,
    t.team_id,
    t.team_abbrev,
    t.team_name,
    t.league_name,
    t.division_name,
    s.availability,
    s.status_description,
    a.games,
    a.total_pitches,
    a.batters_faced,
    a.strikeouts,
    a.walks,
    a.hits_allowed,
    a.home_runs_allowed,
    a.whiff_rate,
    a.strike_pct,
    a.avg_velocity,
    a.max_velocity,
    a.avg_spin_rate,
    a.avg_extension

from aggregated a
left join roster r on a.pitcher_id = r.mlbam_id
left join teams t on r.team_id = t.team_id
left join status s on a.pitcher_id = s.mlbam_id
