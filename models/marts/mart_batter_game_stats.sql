{{ config(materialized='table') }}

-- Batter performance aggregated to one row per batter per game.
-- Grain: batter_id + game_id.

with pitches as (

    select * from {{ ref('stg_statcast_pitches') }}
    where pitch_type is not null

),

batter_stats as (

    select
        -- identifiers
        batter_id,
        game_id,
        game_date,
        game_year,
        home_team,
        away_team,
        -- Event-derived team-of-record; constant per batter-game, so it joins the
        -- grouping key and does not change the (batter_id, game_id) grain.
        batter_team,
        max(batter_side) as batter_side,

        -- volume
        count(*) as total_pitches,
        count(distinct case when events is not null then at_bat_number end)
            as plate_appearances,
        count(distinct case
            when events not in (
                'walk', 'intent_walk', 'hit_by_pitch', 'sac_fly',
                'sac_bunt', 'sac_fly_double_play', 'catcher_interf'
            ) then at_bat_number end) as at_bats,

        -- outcomes
        count(distinct case
            when events in ('single', 'double', 'triple', 'home_run')
            then at_bat_number end) as hits,
        count(distinct case when events = 'single' then at_bat_number end) as singles,
        count(distinct case when events = 'double' then at_bat_number end) as doubles,
        count(distinct case when events = 'triple' then at_bat_number end) as triples,
        count(distinct case when events = 'home_run' then at_bat_number end) as home_runs,
        count(distinct case
            when events in ('strikeout', 'strikeout_double_play')
            then at_bat_number end) as strikeouts,
        count(distinct case
            when events in ('walk', 'intent_walk')
            then at_bat_number end) as walks,

        -- swing metrics (pitch-level)
        countif(pitch_description in (
            'hit_into_play', 'swinging_strike', 'foul', 'foul_tip',
            'swinging_strike_blocked', 'missed_bunt', 'foul_bunt', 'bunt_foul_tip'
        )) as swings,
        countif(pitch_description in (
            'swinging_strike', 'swinging_strike_blocked', 'missed_bunt', 'bunt_foul_tip'
        )) as whiffs,

        -- batted ball metrics
        -- A "batted ball" is a ball put in play (pitch_outcome_category = 'X').
        -- We gate on that rather than exit_velocity_mph IS NOT NULL because
        -- Statcast also records exit velocity on fouls, which are not in play.
        avg(if(pitch_outcome_category = 'X', exit_velocity_mph, null)) as avg_exit_velocity_mph,
        max(if(pitch_outcome_category = 'X', exit_velocity_mph, null)) as max_exit_velocity_mph,
        avg(if(pitch_outcome_category = 'X', launch_angle_deg, null)) as avg_launch_angle_deg,
        countif(pitch_outcome_category = 'X' and exit_velocity_mph >= 95) as hard_hit_count,
        countif(pitch_outcome_category = 'X') as batted_balls,
        countif(pitch_outcome_category = 'X' and launch_speed_angle = 6) as barrel_count,

        -- expected stats
        avg(xba) as avg_xba,
        avg(xwoba) as avg_xwoba,
        avg(xslg) as avg_xslg,

        -- bat tracking (2024+ metrics, null for older data)
        avg(bat_speed) as avg_bat_speed,
        avg(swing_length) as avg_swing_length

    from pitches
    group by batter_id, game_id, game_date, game_year, home_team, away_team, batter_team

)

select
    -- identifiers
    batter_id,
    game_id,
    game_date,
    game_year,
    home_team,
    away_team,
    batter_team,
    batter_side,

    -- volume
    total_pitches,
    plate_appearances,
    at_bats,

    -- outcomes
    hits,
    singles,
    doubles,
    triples,
    home_runs,
    strikeouts,
    walks,

    -- swing metrics
    swings,
    whiffs,
    safe_divide(whiffs, swings) as whiff_rate,

    -- batted ball metrics
    avg_exit_velocity_mph,
    max_exit_velocity_mph,
    avg_launch_angle_deg,
    hard_hit_count,
    batted_balls,
    safe_divide(hard_hit_count, batted_balls) as hard_hit_rate,
    barrel_count,
    safe_divide(barrel_count, batted_balls) as barrel_rate,

    -- expected stats
    avg_xba,
    avg_xwoba,
    avg_xslg,

    -- bat tracking
    avg_bat_speed,
    avg_swing_length

from batter_stats
