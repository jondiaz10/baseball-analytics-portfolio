{{ config(materialized='table') }}

-- Conformed team dimension for slicing batter / pitcher reporting by team.
-- Grain: one row per team_id (30 MLB clubs).

with teams as (

    select * from {{ ref('stg_mlb_teams') }}

)

select
    team_id,
    team_name,
    team_abbrev,
    team_short_name,
    location_name,
    league_id,
    league_name,
    division_id,
    division_name,
    venue_name

from teams
