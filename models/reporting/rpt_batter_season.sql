-- Season-to-date batting line per batter, SPLIT BY TEAM STINT.
-- Grain: one row per (batter_id, batter_team).
--
-- WHY split-by-stint (grain change from Slice 1):
--   Team-of-record is now the event-derived team the batter actually played for
--   (batter_team, carried game-grain through mart_batter_game_stats), NOT the
--   current 40-man club. A traded player played for >1 club this season, so his
--   season line legitimately splits into one row per club. We do NOT synthesize
--   a combined "TOT" row -- the combined season line is recovered downstream by
--   SUMMING the additive components across a player's stint rows (see below).
--
-- WHY team enters the GROUP BY:
--   batter_team is no longer constant per batter over the season (it changes on a
--   trade), so it is a grain-defining key, not a lookup attribute. It must sit in
--   the GROUP BY; adding it is what produces the per-stint rows.
--
-- WHY rates are WEIGHTED, not averaged (invariant preserved from the old grain):
--   Every rate is sum(metric * denom) / sum(denom) over the games IN THIS STINT.
--   Because team is in the GROUP BY, the weighting now re-computes strictly within
--   the stint -- a stint's xwOBA is its own PA-weighted xwOBA, never blended with
--   the other club's. Summing components across stints and re-dividing reproduces
--   the true combined-season rate; averaging the two stint rates would not.
-- The old current-roster path (stg_mlb_rosters -> dim_team join on player id, with
-- no date predicate) is DELETED here -- it was the Slice 1 bug living on at season
-- grain, stamping the present club on every historical game.

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

),

aggregated as (

    select
        batter_id,
        -- Grain key: the event-derived team the batter played for. In the GROUP BY
        -- so a traded player produces one row per club (his stint with that club).
        batter_team,

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
    group by batter_id, batter_team

)

select
    a.batter_id,
    concat(p.first_name, ' ', p.last_name) as batter_name,
    a.batter_team,
    t.team_id,
    t.team_abbrev,
    t.team_name,
    t.league_name,
    t.division_name,
    s.availability,
    s.status_description,
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
-- Join dim_team on the EVENT team (abbrev), exactly as rpt_batter_game does, so
-- team_id/name/league/division describe the club of THIS stint -- trade-aware.
left join teams t on a.batter_team = t.team_abbrev
-- Availability is CURRENT-state (present roster/IL status), player-grain by design.
-- It therefore broadcasts to every stint row of a traded player -- a conscious
-- choice: it is a "where is he now" label, not a per-stint historical attribute.
left join status s on a.batter_id = s.mlbam_id
