-- MLB clubs from the Stats API, lightly cleaned.
-- Grain: one row per team_id (30 MLB clubs).

with source as (

    select * from {{ source('raw', 'mlb_teams') }}

)

select
    cast(team_id as int64) as team_id,
    team_name,
    team_abbrev,
    team_short_name,
    location_name,
    cast(league_id as int64) as league_id,
    league_name,
    cast(division_id as int64) as division_id,
    division_name,
    venue_name

from source
