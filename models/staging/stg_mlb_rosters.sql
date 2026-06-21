-- MLB 40-man rosters from the Stats API — the player -> team mapping.
-- Grain: one row per mlbam_id (a player's CURRENT team).
--
-- A player can momentarily appear on two clubs' 40-man rosters around a
-- transaction. We collapse to one team per player so this stays a clean
-- many-to-one dimension for the player joins downstream. v1 = current team
-- only; trade-aware, per-game historical team is a separate V2 ticket.

with source as (

    select * from {{ source('raw', 'mlb_rosters') }}

)

select
    cast(mlbam_id as int64) as mlbam_id,
    player_full_name,
    cast(team_id as int64) as team_id,
    jersey_number,
    position_code,
    position_name,
    position_type,
    status_code,
    status_description

from source
-- Deterministic dedup to one team per player (keeps the lowest team_id).
qualify row_number() over (
    partition by mlbam_id order by team_id
) = 1
