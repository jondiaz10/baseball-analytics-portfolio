-- Staging model for raw Statcast pitch-level data.
-- Drops deprecated columns, corrects data types, and standardizes column names.

with source as (

    select * from {{ source('raw', 'statcast_pitches') }}

),

renamed as (

    select
        -- identifiers
        game_pk as game_id,
        date(timestamp_seconds(safe_cast(game_date / 1000000000 as int64))) as game_date,
        game_year,
        game_type,
        at_bat_number,
        pitch_number,

        -- players
        batter as batter_id,
        pitcher as pitcher_id,
        player_name as pitcher_name,
        stand as batter_side,
        p_throws as pitcher_throws,
        age_bat,
        age_pit,

        -- team and game context
        home_team,
        away_team,
        inning,
        inning_topbot as inning_half,
        outs_when_up,
        balls,
        strikes,
        on_1b,
        on_2b,
        on_3b,
        home_score,
        away_score,
        bat_score,
        fld_score,
        post_home_score,
        post_away_score,
        post_bat_score,
        post_fld_score,
        home_score_diff,
        bat_score_diff,
        home_win_exp,
        bat_win_exp,
        delta_home_win_exp,
        delta_run_exp,
        delta_pitcher_run_exp,

        -- pitch characteristics
        pitch_type,
        pitch_name,
        release_speed as pitch_velocity_mph,
        effective_speed as effective_velocity_mph,
        release_spin_rate as spin_rate_rpm,
        spin_axis,
        release_extension as extension_ft,
        release_pos_x as release_pos_x_ft,
        release_pos_y as release_pos_y_ft,
        release_pos_z as release_pos_z_ft,
        pfx_x,
        pfx_z,
        plate_x,
        plate_z,
        zone,
        vx0,
        vy0,
        vz0,
        ax,
        ay,
        az,
        api_break_z_with_gravity,
        api_break_x_arm,
        api_break_x_batter_in,
        arm_angle,
        sz_top,
        sz_bot,
        if_fielding_alignment,
        of_fielding_alignment,

        -- pitch outcome
        -- NOTE: `zone` is selected once with pitch characteristics above;
        -- BigQuery disallows repeating a column in the same SELECT, so it is
        -- not duplicated here.
        type as pitch_outcome_category,
        description as pitch_description,
        des as play_description,
        events,

        -- batted ball
        bb_type as batted_ball_type,
        launch_speed as exit_velocity_mph,
        safe_cast(launch_angle as float64) as launch_angle_deg,
        hit_distance_sc as hit_distance_ft,
        hc_x,
        hc_y,
        hit_location,
        launch_speed_angle,
        bat_speed,
        swing_length,
        attack_angle,
        attack_direction,
        swing_path_tilt,
        intercept_ball_minus_batter_pos_x_inches,
        intercept_ball_minus_batter_pos_y_inches,
        hyper_speed,

        -- expected stats
        estimated_ba_using_speedangle as xba,
        estimated_woba_using_speedangle as xwoba,
        estimated_slg_using_speedangle as xslg,
        woba_value,
        woba_denom,
        babip_value,
        iso_value,

        -- fielders
        fielder_2,
        fielder_3,
        fielder_4,
        fielder_5,
        fielder_6,
        fielder_7,
        fielder_8,
        fielder_9,

        -- scheduling context
        n_thruorder_pitcher,
        n_priorpa_thisgame_player_at_bat,
        pitcher_days_since_prev_game,
        batter_days_since_prev_game,
        pitcher_days_until_next_game,
        batter_days_until_next_game

    from source
    where pitch_type is not null

)

select * from renamed
