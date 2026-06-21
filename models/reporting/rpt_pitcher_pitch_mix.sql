-- Pitch-mix in long format for the dashboard (one row per pitcher per pitch
-- type), so it can drive a stacked bar / heat map without per-type columns.
-- The per-game pct_* columns are UNNESTed into (pitch_type, pct), then the
-- season pitch_pct is re-weighted by total pitches per game.
--
-- TEAM (v1): the pitcher's CURRENT team is attached from the 40-man roster
-- (stg_mlb_rosters -> dim_team) for a clean "Team" slicer.

with pitcher_games as (

    select * from {{ ref('mart_pitcher_game_stats') }}

),

roster as (

    select mlbam_id, team_id from {{ ref('stg_mlb_rosters') }}

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

unpivoted as (

    select
        pg.pitcher_id,
        pg.pitcher_name,
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
        pitch_type,
        safe_divide(sum(pct * total_pitches), sum(total_pitches)) as pitch_pct

    from unpivoted
    group by pitcher_id, pitcher_name, pitch_type

)

select
    a.pitcher_id,
    a.pitcher_name,
    t.team_id,
    t.team_abbrev,
    t.team_name,
    t.league_name,
    t.division_name,
    a.pitch_type,
    a.pitch_pct

from aggregated a
left join roster r on a.pitcher_id = r.mlbam_id
left join teams t on r.team_id = t.team_id
