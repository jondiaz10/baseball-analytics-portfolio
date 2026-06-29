-- Mirror of the batter grain guard: team-of-record must be singular per
-- pitcher-game. A traded pitcher carries 2+ teams across a season, never within
-- a single game. Expect 0 failing rows.
select
    pitcher_id,
    game_id,
    count(distinct pitching_team) as n_teams
from {{ ref('mart_pitcher_game_stats') }}
group by pitcher_id, game_id
having count(distinct pitching_team) > 1
