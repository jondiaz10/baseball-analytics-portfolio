-- Pitch-mix in long format for the dashboard, SPLIT BY TEAM STINT (one row per
-- pitcher per team per pitch type), so it drives a stacked bar / heat map without
-- per-type columns. The per-game pct_* columns are UNNESTed into (pitch_type, pct),
-- then the season pitch_pct is re-weighted by total pitches per game.
--
-- TEAM (team-of-record): the event-derived club the pitcher threw for
-- (pitching_team, carried game-grain through mart_pitcher_game_stats), replacing
-- the old "v1 CURRENT team" 40-man roster join (the Slice 1 bug at season grain).
--
-- WHY team enters the GROUP BY -- and why it matters MORE here: pitching_team is a
-- grain key (it changes on a trade). Adding it means the re-weight
-- safe_divide(sum(pct * total_pitches), sum(total_pitches)) re-weights strictly
-- WITHIN a team-stint. A pitcher whose four-seam usage differs by club gets a
-- separate, correctly-weighted four_seam% per club; the two are never blended into
-- a meaningless cross-team average. No synthetic combined row -- the overall mix is
-- recovered downstream by pitch-weighting the stint rows.

with pitcher_games as (

    select * from {{ ref('mart_pitcher_game_stats') }}

),

teams as (

    select
        team_id,
        team_abbrev,
        team_name,
        league_name,
        division_name
    from {{ ref('dim_team') }}

),

status as (

    select mlbam_id, availability, status_description
    from {{ ref('dim_roster_status') }}

),

unpivoted as (

    select
        pg.pitcher_id,
        pg.pitcher_name,
        pg.pitching_team,
        pg.total_pitches,
        mix.pitch_type,
        mix.pct
    from pitcher_games pg,
    unnest([
        struct('four_seam' as pitch_type, pg.pct_four_seam as pct),
        struct('sinker'    as pitch_type, pg.pct_sinker    as pct),
        struct('cutter'    as pitch_type, pg.pct_cutter    as pct),
        struct('slider'    as pitch_type, pg.pct_slider    as pct),
        struct('sweeper'   as pitch_type, pg.pct_sweeper   as pct),
        struct('curveball' as pitch_type, pg.pct_curveball as pct),
        struct('changeup'  as pitch_type, pg.pct_changeup  as pct),
        struct('splitter'  as pitch_type, pg.pct_splitter  as pct),
        struct('other'     as pitch_type, pg.pct_other     as pct)
    ]) as mix

),

aggregated as (

    select
        pitcher_id,
        pitcher_name,
        pitching_team,
        pitch_type,
        -- Re-weight WITHIN team-stint: pitching_team is in the GROUP BY, so this
        -- pitch-weighted mean is computed over only the games at this club and is
        -- never blended across a trade.
        safe_divide(sum(pct * total_pitches), sum(total_pitches)) as pitch_pct

    from unpivoted
    group by pitcher_id, pitcher_name, pitching_team, pitch_type

)

select
    a.pitcher_id,
    a.pitcher_name,
    a.pitching_team,
    t.team_id,
    t.team_abbrev,
    t.team_name,
    t.league_name,
    t.division_name,
    s.availability,
    s.status_description,
    a.pitch_type,
    a.pitch_pct

from aggregated a
-- Join dim_team on the EVENT team (abbrev), mirroring rpt_batter_game.
left join teams t on a.pitching_team = t.team_abbrev
-- Availability is current-state, player-grain; broadcasts to all of a pitcher's
-- stint rows by design.
left join status s on a.pitcher_id = s.mlbam_id
