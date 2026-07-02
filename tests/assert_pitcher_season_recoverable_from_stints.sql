-- Interview-proof recoverability test (pitchers).
--
-- Same invariant as the batter version: additive components summed across a
-- pitcher's per-team stint rows must equal his ground-truth season total taken
-- directly from the mart. Proven for every pitcher; a multi-team pitcher (one of
-- the traded population) is the case this protects. Weighted rates (velocity,
-- whiff%, strike%) are excluded -- they recover by re-dividing summed components,
-- not by summing rates.
with from_stints as (
    select
        pitcher_id,
        sum(total_pitches)     as total_pitches,
        sum(batters_faced)     as batters_faced,
        sum(strikeouts)        as k,
        sum(walks)             as bb,
        sum(hits_allowed)      as hits_allowed,
        sum(home_runs_allowed) as hr_allowed,
        sum(games)             as games
    from {{ ref('rpt_pitcher_season') }}
    group by pitcher_id
),

from_mart as (
    select
        pitcher_id,
        sum(total_pitches)      as total_pitches,
        sum(batters_faced)      as batters_faced,
        sum(strikeouts)         as k,
        sum(walks)              as bb,
        sum(hits_allowed)       as hits_allowed,
        sum(home_runs_allowed)  as hr_allowed,
        count(distinct game_id) as games
    from {{ ref('mart_pitcher_game_stats') }}
    group by pitcher_id
)

select
    s.pitcher_id
from from_stints s
join from_mart m using (pitcher_id)
where s.total_pitches != m.total_pitches
   or s.batters_faced != m.batters_faced
   or s.k             != m.k
   or s.bb            != m.bb
   or s.hits_allowed  != m.hits_allowed
   or s.hr_allowed    != m.hr_allowed
   or s.games         != m.games
