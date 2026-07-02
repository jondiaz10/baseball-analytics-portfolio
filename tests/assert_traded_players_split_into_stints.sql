-- Non-vacuity guard for the Slice 2 grain change.
--
-- The uniqueness + recoverability tests would all pass VACUOUSLY if no player were
-- ever traded (split-by-stint would be indistinguishable from one-row-per-season).
-- This asserts the split actually materializes: at least one batter AND at least
-- one pitcher must appear under 2+ distinct event teams. Slice 1 verified traded
-- players are present in the loaded data (e.g. Joey Bart PIT->ATL), so a zero here
-- means the grain change silently collapsed stints -- the test fails loudly.
--
-- Returns a row (fail) only when a side has zero multi-team players.
select 'batter' as side, count(*) as multi_team_players
from (
    select batter_id
    from {{ ref('rpt_batter_season') }}
    group by batter_id
    having count(distinct batter_team) > 1
)
having count(*) = 0

union all

select 'pitcher' as side, count(*) as multi_team_players
from (
    select pitcher_id
    from {{ ref('rpt_pitcher_season') }}
    group by pitcher_id
    having count(distinct pitching_team) > 1
)
having count(*) = 0
