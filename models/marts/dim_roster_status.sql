{{ config(materialized='table') }}

-- Roster / availability dimension: the FULL rostered player population keyed by
-- mlbam_id, INDEPENDENT of whether a player has Statcast stats this season.
-- Grain: one row per mlbam_id.
--
-- This dimension exists so absent / injured players are never silently dropped.
-- It is deliberately NOT joined into the stat marts; the rpt_* models only
-- ATTACH a status label to players who already have stats (grain unchanged).
-- Power BI can LEFT JOIN this dimension per-visual to surface the full roster
-- (e.g. a 60-Day IL star with no stats yet). Roster-driven stat rows are a
-- separate follow-up.

with status as (

    select * from {{ ref('stg_mlb_roster_status') }}

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
    s.mlbam_id,
    s.player_full_name,
    s.team_id,
    t.team_abbrev,
    t.team_name,
    t.league_name,
    t.division_name,
    s.status_code,
    s.status_description,
    s.availability,
    s.is_active,
    s.is_injured

from status s
left join teams t on s.team_id = t.team_id
