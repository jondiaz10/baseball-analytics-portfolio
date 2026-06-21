# =============================================================================
# player.view.lkml
# -----------------------------------------------------------------------------
# Player DIMENSION over the Chadwick Bureau registry (`raw.player_lookup`).
# Grain: one row per MLBAM player id. Joined many_to_one from both fact Explores
# on batter_id / pitcher_id = mlbam_id.
# =============================================================================

view: player {
  sql_table_name: `baseball-analytics-portfolio.raw.player_lookup` ;;

  # ---------------------------------------------------------------------------
  # PRIMARY KEY
  # ---------------------------------------------------------------------------
  # mlbam_id is the natural single-column key of this dimension. Declaring it as
  # primary_key tells Looker the dimension is single-valued per join key, which
  # is what makes the fact-side symmetric aggregation safe.
  dimension: mlbam_id {
    primary_key: yes
    hidden: yes
    type: number
    sql: ${TABLE}.mlbam_id ;;
  }

  # ---------------------------------------------------------------------------
  # NAME DIMENSIONS
  # ---------------------------------------------------------------------------
  dimension: first_name {
    type: string
    sql: ${TABLE}.first_name ;;
  }

  dimension: last_name {
    type: string
    sql: ${TABLE}.last_name ;;
  }

  # Display name assembled from the lookup, mirroring the dbt reporting layer's
  # CONCAT(first_name, ' ', last_name) in rpt_batter_game / rpt_batter_season.
  dimension: full_name {
    label: "Player"
    type: string
    sql: CONCAT(${TABLE}.first_name, ' ', ${TABLE}.last_name) ;;
  }

  # given_name is the player's full legal name in the Chadwick registry.
  dimension: given_name {
    type: string
    sql: ${TABLE}.given_name ;;
  }

  # ---------------------------------------------------------------------------
  # CROSS-REFERENCE IDS (hidden — external system keys, not for exploration)
  # ---------------------------------------------------------------------------
  dimension: bbref_id {
    label: "Baseball-Reference ID"
    type: string
    hidden: yes
    sql: ${TABLE}.bbref_id ;;
  }

  # fangraphs_id is stored as FLOAT in the source; CAST to INT64 for a clean
  # integer display (assumption flagged: the raw column type is FLOAT, not INT).
  dimension: fangraphs_id {
    label: "FanGraphs ID"
    type: number
    hidden: yes
    sql: CAST(${TABLE}.fangraphs_id AS INT64) ;;
  }

  # ---------------------------------------------------------------------------
  # CAREER SPAN DIMENSIONS
  # ---------------------------------------------------------------------------
  # These are FLOAT in the source (nullable year columns); CAST to INT64 so they
  # render as plain years rather than 1995.0.
  dimension: mlb_debut_year {
    type: number
    sql: CAST(${TABLE}.mlb_debut_year AS INT64) ;;
  }

  dimension: mlb_last_year {
    type: number
    sql: CAST(${TABLE}.mlb_last_year AS INT64) ;;
  }

  dimension: birth_year {
    type: number
    sql: CAST(${TABLE}.birth_year AS INT64) ;;
  }

  # ---------------------------------------------------------------------------
  # MEASURES
  # ---------------------------------------------------------------------------
  # This is a pure lookup dimension, so the only meaningful measure is a distinct
  # count of players. Ratio / html threshold measures live on the fact views,
  # where the numeric Statcast metrics actually exist.
  measure: player_count {
    label: "Distinct Players"
    type: count_distinct
    sql: ${mlbam_id} ;;
  }
}
