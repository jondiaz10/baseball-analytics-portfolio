-- Locking test for the Slice 2 season grain: rpt_batter_season is one row per
-- (batter_id, batter_team). A traded batter legitimately has MULTIPLE rows (one
-- per club) -- this asserts the composite key is unique, NOT one-row-per-season.
--
-- This test BITES the old grain: pre-Slice-2, batter_team was not selected and a
-- traded player collapsed to a single current-team row, so grouping by
-- (batter_id, batter_team) could never expose duplicates; post-change it guards
-- that no (batter, club) pair is emitted twice.
select
    batter_id,
    batter_team,
    count(*) as n_rows
from {{ ref('rpt_batter_season') }}
group by batter_id, batter_team
having count(*) > 1
