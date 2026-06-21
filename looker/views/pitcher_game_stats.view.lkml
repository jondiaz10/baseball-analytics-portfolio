# =============================================================================
# pitcher_game_stats.view.lkml
# -----------------------------------------------------------------------------
# View over dbt mart `mart_pitcher_game_stats`.
# Grain: one row per pitcher_id per game_id (composite grain).
# =============================================================================

view: pitcher_game_stats {
  sql_table_name: `baseball-analytics-portfolio.marts.mart_pitcher_game_stats` ;;

  # ---------------------------------------------------------------------------
  # PRIMARY KEY
  # ---------------------------------------------------------------------------
  # Composite grain (pitcher_id + game_id) collapsed to one hashed key so
  # symmetric aggregation keeps sums/averages correct when the player join fans
  # this fact out. See batter_game_stats for the full rationale.
  dimension: pk {
    primary_key: yes
    hidden: yes
    type: string
    sql: CONCAT(${TABLE}.pitcher_id, '-', ${TABLE}.game_id) ;;
  }

  # ---------------------------------------------------------------------------
  # IDENTIFIERS (hidden)
  # ---------------------------------------------------------------------------
  dimension: pitcher_id {
    type: number
    hidden: yes
    sql: ${TABLE}.pitcher_id ;;
  }

  dimension: game_id {
    type: number
    hidden: yes
    sql: ${TABLE}.game_id ;;
  }

  # pitcher_name is carried on the mart itself (the batter mart is not). We keep
  # it visible as a convenience; the player join also supplies a name from the
  # Chadwick lookup for consistency across both Explores.
  dimension: pitcher_name {
    label: "Pitcher (mart name)"
    type: string
    sql: ${TABLE}.pitcher_name ;;
  }

  # ---------------------------------------------------------------------------
  # TIME
  # ---------------------------------------------------------------------------
  dimension_group: game {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    datatype: date
    convert_tz: no
    sql: ${TABLE}.game_date ;;
  }

  dimension: game_year {
    type: number
    sql: ${TABLE}.game_year ;;
  }

  # ---------------------------------------------------------------------------
  # CONTEXT DIMENSIONS
  # ---------------------------------------------------------------------------
  dimension: home_team {
    type: string
    sql: ${TABLE}.home_team ;;
  }

  dimension: away_team {
    type: string
    sql: ${TABLE}.away_team ;;
  }

  dimension: pitcher_throws {
    label: "Throws (L/R)"
    type: string
    sql: ${TABLE}.pitcher_throws ;;
  }

  # ---------------------------------------------------------------------------
  # ROW-LEVEL FACTS (per-game, for drill-down detail)
  # ---------------------------------------------------------------------------
  dimension: avg_pitch_velocity_mph {
    label: "Pitch Velocity (game avg, mph)"
    type: number
    value_format_name: decimal_1
    sql: ${TABLE}.avg_pitch_velocity_mph ;;
  }

  dimension: hard_hit_allowed_rate_row {
    label: "Hard-Hit Rate Allowed (this game)"
    description: "Pre-computed per-game value from the mart. For aggregations use the hard_hit_allowed_rate measure."
    type: number
    value_format_name: percent_1
    sql: ${TABLE}.hard_hit_allowed_rate ;;
  }

  # ---------------------------------------------------------------------------
  # MEASURES
  # ---------------------------------------------------------------------------

  # --- Counts ---
  measure: game_count {
    label: "Pitcher-Games"
    type: count
  }

  # --- Sums ---
  measure: total_pitches {
    label: "Pitches"
    type: sum
    sql: ${TABLE}.total_pitches ;;
  }

  measure: total_batters_faced {
    label: "Batters Faced"
    type: sum
    sql: ${TABLE}.batters_faced ;;
  }

  measure: total_strikeouts {
    label: "Strikeouts"
    type: sum
    sql: ${TABLE}.strikeouts ;;
  }

  measure: total_walks {
    label: "Walks"
    type: sum
    sql: ${TABLE}.walks ;;
  }

  measure: total_hits_allowed {
    label: "Hits Allowed"
    type: sum
    sql: ${TABLE}.hits_allowed ;;
  }

  measure: total_home_runs_allowed {
    label: "Home Runs Allowed"
    type: sum
    sql: ${TABLE}.home_runs_allowed ;;
  }

  measure: total_hard_hit_allowed {
    label: "Hard-Hit Balls Allowed"
    type: sum
    sql: ${TABLE}.hard_hit_allowed_count ;;
  }

  measure: total_batted_balls_allowed {
    label: "Batted Balls Allowed"
    type: sum
    sql: ${TABLE}.batted_balls_allowed ;;
  }

  # --- Averages ---
  measure: avg_pitch_velocity {
    label: "Pitch Velocity (avg of games, mph)"
    type: average
    value_format_name: decimal_1
    sql: ${TABLE}.avg_pitch_velocity_mph ;;
  }

  measure: avg_spin_rate {
    label: "Spin Rate (avg of games, rpm)"
    type: average
    value_format_name: decimal_0
    sql: ${TABLE}.avg_spin_rate_rpm ;;
  }

  # --- Ratio / weighted measures (DIVIDE over summed components, DRY) ---
  # K/BB ratio recomputed from totals at any aggregation level.
  measure: k_per_bb {
    label: "K/BB Ratio"
    type: number
    value_format_name: decimal_2
    sql: DIVIDE(${total_strikeouts}, ${total_walks}) ;;
  }

  measure: strikeout_rate {
    label: "Strikeout Rate (K / BF)"
    type: number
    value_format_name: percent_1
    sql: DIVIDE(${total_strikeouts}, ${total_batters_faced}) ;;
  }

  # hard_hit_allowed_rate = hard-hit allowed / batted balls allowed, from summed
  # components so it is correct at any rollup. For a PITCHER, lower is better, so
  # the threshold colors are INVERTED relative to the batter view.
  measure: hard_hit_allowed_rate {
    label: "Hard-Hit Rate Allowed"
    description: "Share of batted balls allowed at >= 95 mph, weighted via summed counts. Lower is better."
    type: number
    value_format_name: percent_1
    sql: DIVIDE(${total_hard_hit_allowed}, ${total_batted_balls_allowed}) ;;

    # ---- Liquid conditional formatting -----------------------------------
    #   {{ value }}          -> raw numeric (e.g. 0.34); branch on this.
    #   {{ rendered_value }} -> formatted output (e.g. "34.0%"); display this.
    # Green = suppressing hard contact (low rate); red = getting hit hard.
    html:
      {% if value <= 0.35 %}
        <span style="color: #ffffff; background-color: #1a9850; padding: 2px 6px; border-radius: 3px;">{{ rendered_value }}</span>
      {% elsif value <= 0.42 %}
        <span style="color: #000000; background-color: #fee08b; padding: 2px 6px; border-radius: 3px;">{{ rendered_value }}</span>
      {% else %}
        <span style="color: #ffffff; background-color: #d73027; padding: 2px 6px; border-radius: 3px;">{{ rendered_value }}</span>
      {% endif %} ;;
  }
}
