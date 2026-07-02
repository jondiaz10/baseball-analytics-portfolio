-- Interview-proof recoverability test (batters).
--
-- Invariant: the combined season line is RECOVERABLE downstream by summing the
-- additive components across a player's per-team stint rows. We prove it for
-- EVERY batter (not just one hardcoded name) by comparing:
--   (a) stint-sums: additive counts summed across rpt_batter_season stint rows, vs
--   (b) the ground-truth season total aggregated directly from the mart by player.
-- If any batter's stint-sum disagrees with his true season total, the split lost or
-- duplicated events -- the test returns that row and fails. Joey Bart (PIT->ATL) is
-- the canonical case: PIT stint + ATL stint must sum back to his full-season PA/AB/
-- H/HR/batted_balls. (Rates are intentionally excluded -- they are weighted, not
-- additive; their recovery is re-dividing the summed components, not summing rates.)
with from_stints as (
    select
        batter_id,
        sum(plate_appearances) as pa,
        sum(at_bats)           as ab,
        sum(hits)              as hits,
        sum(home_runs)         as hr,
        sum(strikeouts)        as k,
        sum(walks)             as bb,
        sum(batted_balls)      as batted_balls,
        sum(games)             as games
    from {{ ref('rpt_batter_season') }}
    group by batter_id
),

from_mart as (
    select
        batter_id,
        sum(plate_appearances)   as pa,
        sum(at_bats)             as ab,
        sum(hits)                as hits,
        sum(home_runs)           as hr,
        sum(strikeouts)          as k,
        sum(walks)               as bb,
        sum(batted_balls)        as batted_balls,
        count(distinct game_id)  as games
    from {{ ref('mart_batter_game_stats') }}
    group by batter_id
)

select
    s.batter_id
from from_stints s
join from_mart m using (batter_id)
where s.pa           != m.pa
   or s.ab           != m.ab
   or s.hits         != m.hits
   or s.hr           != m.hr
   or s.k            != m.k
   or s.bb           != m.bb
   or s.batted_balls != m.batted_balls
   or s.games        != m.games
