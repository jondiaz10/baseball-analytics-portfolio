-- Locking test for the Slice 2 pitch-mix grain: rpt_pitcher_pitch_mix is one row
-- per (pitcher_id, pitching_team, pitch_type). A traded pitcher has a full set of
-- pitch-type rows PER club; this asserts the composite key is unique.
select
    pitcher_id,
    pitching_team,
    pitch_type,
    count(*) as n_rows
from {{ ref('rpt_pitcher_pitch_mix') }}
group by pitcher_id, pitching_team, pitch_type
having count(*) > 1
