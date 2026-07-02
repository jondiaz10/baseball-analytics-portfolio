-- Locking test for the Slice 2 season grain: rpt_pitcher_season is one row per
-- (pitcher_id, pitching_team). A traded pitcher legitimately has MULTIPLE rows;
-- this asserts the composite key is unique, NOT one-row-per-season.
select
    pitcher_id,
    pitching_team,
    count(*) as n_rows
from {{ ref('rpt_pitcher_season') }}
group by pitcher_id, pitching_team
having count(*) > 1
