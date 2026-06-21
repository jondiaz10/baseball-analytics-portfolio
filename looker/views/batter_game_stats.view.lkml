# =============================================================================
# batter_game_stats.view.lkml
# -----------------------------------------------------------------------------
# View over dbt mart `mart_batter_game_stats`.
# Grain: one row per batter_id per game_id (composite grain).
# =============================================================================

view: batter_game_stats {
  sql_table_name: `baseball-analytics-portfolio.marts.mart_batter_game_stats` ;;

  # ---------------------------------------------------------------------------
  # PRIMARY KEY
  # ---------------------------------------------------------------------------
  # The mart grain is composite (batter_id + game_id), but Looker needs a SINGLE
  # primary_key field for symmetric aggregation. When this fact fans out across
  # the player join, Looker hashes this PK so summed/averaged measures are not
  # double-counted. CONCAT of the two grain keys produces that one unique key.
  dimension: pk {
    primary_key: yes
    hidden: yes
    type: string
    sql: CONCAT(${TABLE}.batter_id, '-', ${TABLE}.game_id) ;;
  }

  # ---------------------------------------------------------------------------
  # IDENTIFIERS (hidden — used for joins/grain, not for end-user exploration)
  # ---------------------------------------------------------------------------
  dimension: batter_id {
    type: number
    hidden: yes
    sql: ${TABLE}.batter_id ;;
  }

  dimension: game_id {
    type: number
    hidden: yes
    sql: ${TABLE}.game_id ;;
  }

  # ---------------------------------------------------------------------------
  # TIME
  # ---------------------------------------------------------------------------
  dimension_group: game {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    datatype: date
    convert_tz: no            # game_date is a plain DATE; no tz conversion.
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

  dimension: batter_side {
    label: "Batter Side (L/R)"
    type: string
    sql: ${TABLE}.batter_side ;;
  }

  # ---------------------------------------------------------------------------
  # ROW-LEVEL FACTS (per-game values; exposed for drill-down detail tables)
  # ---------------------------------------------------------------------------
  dimension: avg_exit_velocity_mph {
    label: "Exit Velocity (game avg, mph)"
    type: number
    value_format_name: decimal_1
    sql: ${TABLE}.avg_exit_velocity_mph ;;
  }

  dimension: max_exit_velocity_mph {
    label: "Max Exit Velocity (mph)"
    type: number
    value_format_name: decimal_1
    sql: ${TABLE}.max_exit_velocity_mph ;;
  }

  dimension: hard_hit_rate_row {
    label: "Hard-Hit Rate (this game)"
    description: "Pre-computed per-game hard-hit rate from the mart. For aggregations use the hard_hit_rate measure instead."
    type: number
    value_format_name: percent_1
    sql: ${TABLE}.hard_hit_rate ;;
  }

  # ---------------------------------------------------------------------------
  # MEASURES
  # ---------------------------------------------------------------------------

  # --- Counts ---
  measure: game_count {
    label: "Player-Games"
    type: count
    description: "Number of batter-game rows (each row = one player in one game)."
  }

  # --- Sums (additive volume metrics) ---
  measure: total_plate_appearances {
    label: "Plate Appearances"
    type: sum
    sql: ${TABLE}.plate_appearances ;;
  }

  measure: total_at_bats {
    label: "At Bats"
    type: sum
    sql: ${TABLE}.at_bats ;;
  }

  measure: total_hits {
    label: "Hits"
    type: sum
    sql: ${TABLE}.hits ;;
  }

  measure: total_home_runs {
    label: "Home Runs"
    type: sum
    sql: ${TABLE}.home_runs ;;
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

  measure: total_batted_balls {
    label: "Batted Balls"
    type: sum
    sql: ${TABLE}.batted_balls ;;
  }

  measure: total_hard_hit {
    label: "Hard-Hit Balls"
    description: "Batted balls with exit velocity >= 95 mph."
    type: sum
    sql: ${TABLE}.hard_hit_count ;;
  }

  measure: total_barrels {
    label: "Barrels"
    type: sum
    sql: ${TABLE}.barrel_count ;;
  }

  # --- Averages ---
  # Simple average of the per-game exit velocity. NOTE: this averages an
  # already-averaged column (equal weight per game). For batted-ball-weighted
  # exit velocity, weight by batted_balls (as rpt_batter_season.sql does).
  measure: avg_exit_velocity {
    label: "Exit Velocity (avg of games, mph)"
    type: average
    value_format_name: decimal_1
    sql: ${TABLE}.avg_exit_velocity_mph ;;
  }

  measure: avg_xwoba {
    label: "xwOBA (avg of games)"
    type: average
    value_format_name: decimal_3
    sql: ${TABLE}.avg_xwoba ;;
  }

  # --- Ratio / weighted measures (DIVIDE over summed components, DRY) ---
  # batting_average = hits / at_bats, summed across the explored grain.
  # References the existing measures rather than re-pulling ${TABLE} columns.
  measure: batting_average {
    label: "Batting Average"
    type: number
    value_format_name: decimal_3
    sql: DIVIDE(${total_hits}, ${total_at_bats}) ;;
  }

  # hard_hit_rate = hard-hit balls / batted balls. Built from the summed
  # component measures so it stays correct at ANY aggregation level (player,
  # team, month) — the rate is recomputed from totals, never averaged-of-rates.
  measure: hard_hit_rate {
    label: "Hard-Hit Rate"
    description: "Share of batted balls hit >= 95 mph, weighted via summed counts."
    type: number
    value_format_name: percent_1
    sql: DIVIDE(${total_hard_hit}, ${total_batted_balls}) ;;

    # ---- Liquid conditional formatting -----------------------------------
    # Color-codes the cell by hard-hit-rate threshold (league avg ~38-42%).
    #   {{ value }}          -> the RAW numeric result (e.g. 0.415) — branch on
    #                           this for the numeric threshold comparisons.
    #   {{ rendered_value }} -> the value AFTER value_format_name is applied
    #                           (e.g. "41.5%") — display this so the cell keeps
    #                           its formatted percent while we recolor it.
    html:
      {% if value >= 0.45 %}
        <span style="color: #ffffff; background-color: #1a9850; padding: 2px 6px; border-radius: 3px;">{{ rendered_value }}</span>
      {% elsif value >= 0.38 %}
        <span style="color: #000000; background-color: #fee08b; padding: 2px 6px; border-radius: 3px;">{{ rendered_value }}</span>
      {% else %}
        <span style="color: #ffffff; background-color: #d73027; padding: 2px 6px; border-radius: 3px;">{{ rendered_value }}</span>
      {% endif %} ;;
  }
}
