{{ config(materialized='table') }}

-- Pitcher performance aggregated to one row per pitcher per game.
-- Grain: pitcher_id + game_id.

with pitches as (

    select * from {{ ref('stg_statcast_pitches') }}
    where pitch_type is not null

),

pitcher_stats as (

    select
        -- identifiers
        pitcher_id,
        max(pitcher_name) as pitcher_name,
        game_id,
        game_date,
        game_year,
        home_team,
        away_team,
        max(pitcher_throws) as pitcher_throws,

        -- volume
        count(*) as total_pitches,
        count(distinct at_bat_number) as batters_faced,

        -- outcomes
        count(distinct case
            when events in ('strikeout', 'strikeout_double_play')
            then at_bat_number end) as strikeouts,
        count(distinct case
            when events in ('walk', 'intent_walk')
            then at_bat_number end) as walks,
        count(distinct case
            when events in ('single', 'double', 'triple', 'home_run')
            then at_bat_number end) as hits_allowed,
        count(distinct case
            when events = 'home_run' then at_bat_number end) as home_runs_allowed,

        -- pitch quality
        avg(pitch_velocity_mph) as avg_pitch_velocity_mph,
        max(pitch_velocity_mph) as max_pitch_velocity_mph,
        avg(spin_rate_rpm) as avg_spin_rate_rpm,
        avg(extension_ft) as avg_extension_ft,

        -- command
        countif(pitch_outcome_category = 'S') as strikes,
        countif(pitch_outcome_category = 'B') as balls,
        countif(pitch_description = 'called_strike') as called_strikes,
        countif(pitch_description in (
            'hit_into_play', 'swinging_strike', 'foul', 'foul_tip',
            'swinging_strike_blocked', 'missed_bunt', 'foul_bunt', 'bunt_foul_tip'
        )) as swings,
        countif(pitch_description in (
            'swinging_strike', 'swinging_strike_blocked', 'missed_bunt', 'bunt_foul_tip'
        )) as whiffs,

        -- pitch mix (intermediate counts; surfaced as percentages below)
        countif(pitch_type = 'FF') as cnt_four_seam,
        countif(pitch_type = 'SI') as cnt_sinker,
        countif(pitch_type = 'FC') as cnt_cutter,
        countif(pitch_type = 'SL') as cnt_slider,
        countif(pitch_type = 'ST') as cnt_sweeper,
        countif(pitch_type = 'CU') as cnt_curveball,
        countif(pitch_type = 'CH') as cnt_changeup,
        countif(pitch_type = 'FS') as cnt_splitter,
        countif(pitch_type not in (
            'FF', 'SI', 'FC', 'SL', 'ST', 'CU', 'CH', 'FS'
        )) as cnt_other,

        -- contact allowed
        avg(exit_velocity_mph) as avg_exit_velocity_allowed,
        avg(launch_angle_deg) as avg_launch_angle_allowed,
        countif(exit_velocity_mph >= 95) as hard_hit_allowed_count,
        countif(exit_velocity_mph is not null) as batted_balls_allowed,

        -- expected stats against
        avg(xba) as avg_xba_against,
        avg(xwoba) as avg_xwoba_against

    from pitches
    group by pitcher_id, game_id, game_date, game_year, home_team, away_team

)

select
    -- identifiers
    pitcher_id,
    pitcher_name,
    game_id,
    game_date,
    game_year,
    home_team,
    away_team,
    pitcher_throws,

    -- volume
    total_pitches,
    batters_faced,

    -- outcomes
    strikeouts,
    walks,
    hits_allowed,
    home_runs_allowed,

    -- pitch quality
    avg_pitch_velocity_mph,
    max_pitch_velocity_mph,
    avg_spin_rate_rpm,
    avg_extension_ft,

    -- command
    strikes,
    balls,
    safe_divide(strikes, total_pitches) as strike_pct,
    called_strikes,
    swings,
    whiffs,
    safe_divide(whiffs, swings) as whiff_rate,

    -- pitch mix
    safe_divide(cnt_four_seam, total_pitches) as pct_four_seam,
    safe_divide(cnt_sinker, total_pitches) as pct_sinker,
    safe_divide(cnt_cutter, total_pitches) as pct_cutter,
    safe_divide(cnt_slider, total_pitches) as pct_slider,
    safe_divide(cnt_sweeper, total_pitches) as pct_sweeper,
    safe_divide(cnt_curveball, total_pitches) as pct_curveball,
    safe_divide(cnt_changeup, total_pitches) as pct_changeup,
    safe_divide(cnt_splitter, total_pitches) as pct_splitter,
    safe_divide(cnt_other, total_pitches) as pct_other,

    -- contact allowed
    avg_exit_velocity_allowed,
    avg_launch_angle_allowed,
    hard_hit_allowed_count,
    batted_balls_allowed,
    safe_divide(hard_hit_allowed_count, batted_balls_allowed) as hard_hit_allowed_rate,

    -- expected stats against
    avg_xba_against,
    avg_xwoba_against

from pitcher_stats
