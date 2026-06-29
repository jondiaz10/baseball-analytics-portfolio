-- Team-of-record must be singular per batter-game. A traded player legitimately
-- carries 2+ teams across a season, but never within a single game. This locks
-- the team-of-record fix at game grain. Expect 0 failing rows.
select
    batter_id,
    game_id,
    count(distinct batter_team) as n_teams
from {{ ref('mart_batter_game_stats') }}
group by batter_id, game_id
having count(distinct batter_team) > 1
