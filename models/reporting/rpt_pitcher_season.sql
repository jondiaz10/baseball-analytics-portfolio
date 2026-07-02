-- Season-to-date pitching line per pitcher, SPLIT BY TEAM STINT.
-- Grain: one row per (pitcher_id, pitching_team).
--
-- WHY split-by-stint: team-of-record is the event-derived club the pitcher threw
-- for (pitching_team, carried game-grain through mart_pitcher_game_stats), not the
-- current 40-man club. A traded pitcher splits into one row per club; there is no
-- synthetic combined row -- the season total is a downstream SUM over the stints.
--
-- WHY team enters the GROUP BY: pitching_team changes on a trade, so it is a
-- grain-defining key rather than a lookup attribute; adding it to the GROUP BY is
-- what produces the per-stint rows.
--
-- WHY rates are WEIGHTED, not averaged: every rate is sum(metric * denom)/sum(denom)
-- over the games in this stint (velocity/spin/extension by total_pitches, whiff by
-- swings, strike% by pitches). With team in the GROUP BY the weighting recomputes
-- strictly within the stint, so a stint's velocity is its own pitch-weighted mean,
-- never blended with the other club's. Summing components across stints and
-- re-dividing reproduces the true combined-season rate.
--
-- The old current-roster path (stg_mlb_rosters -> dim_team on player id, no date
-- predicate) is DELETED here -- the "v1 CURRENT team" was the Slice 1 bug at season
-- grain, stamping the present club on every historical game.
-- pitcher_name / pitcher_throws still come straight from the mart (no lookup).

with pitcher_games as (

    select * from {{ ref('mart_pitcher_game_stats') }}

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
        -- Grain key: the event-derived team the pitcher threw for. In the GROUP BY
        -- so a traded pitcher produces one row per club (his stint with that club).
        pitching_team,

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
    group by pitcher_id, pitcher_name, pitcher_throws, pitching_team

)

select
    a.pitcher_id,
    a.pitcher_name,
    a.pitcher_throws,
    a.pitching_team,
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
-- Join dim_team on the EVENT team (abbrev), mirroring rpt_batter_game, so the
-- team attributes describe the club of THIS stint -- trade-aware.
left join teams t on a.pitching_team = t.team_abbrev
-- Availability is CURRENT-state, player-grain by design; it broadcasts to every
-- stint row of a traded pitcher (a "where is he now" label, not per-stint history).
left join status s on a.pitcher_id = s.mlbam_id
