-- MLB roster STATUS from the Stats API fullRoster feed — every rostered player
-- with their current availability (Active / IL flavors / Minors / etc.).
-- Grain: one row per mlbam_id.
--
-- This is the FULL rostered population (incl. 60-Day IL, who are dropped from
-- the 40-man), so no player is silently missing. A handful of players appear
-- on two clubs' full rosters around a move; we keep the MLB-facing status
-- (Active / IL) over a minors assignment, then break ties by team_id.

with source as (

    select * from {{ source('raw', 'mlb_roster_status') }}

),

typed as (

    select
        cast(mlbam_id as int64) as mlbam_id,
        player_full_name,
        cast(team_id as int64) as team_id,
        status_code,
        status_description,

        -- Clean, display-ready availability label. Keeps the IL flavor (the
        -- 10-Day vs 60-Day distinction matters for "small sample" context).
        case status_code
            when 'A'   then 'Active'
            when 'D7'  then 'IL — 7-Day'
            when 'D10' then 'IL — 10-Day'
            when 'D15' then 'IL — 15-Day'
            when 'D60' then 'IL — 60-Day'
            when 'ILF' then 'IL — Full Season'
            when 'RA'  then 'Rehab Assignment'
            when 'RM'  then 'Minors'
            when 'RES' then 'Minors'
            when 'DEV' then 'Minors'
            when 'DES' then 'Designated for Assignment'
            when 'RST' then 'Restricted List'
            when 'NYR' then 'Not Yet Reported'
            when 'TI'  then 'Temporary Inactive'
            when 'ADM' then 'Administrative Leave'
            when 'IN'  then 'Ineligible'
            when 'MIL' then 'Military Leave'
            when 'SU'  then 'Suspended'
            else coalesce(status_description, 'Unknown')
        end as availability,

        status_code = 'A' as is_active,
        status_code in ('D7', 'D10', 'D15', 'D60', 'ILF', 'RA') as is_injured

    from source

)

select *
from typed
-- One row per player: prefer an MLB-facing status (Active / IL) over a minors
-- assignment when a player shows up on two clubs, then break ties by team_id.
qualify row_number() over (
    partition by mlbam_id
    order by
        case
            when status_code = 'A' then 0
            when status_code in ('D7', 'D10', 'D15', 'D60', 'ILF', 'RA') then 1
            else 2
        end,
        team_id
) = 1
