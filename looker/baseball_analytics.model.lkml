# =============================================================================
# baseball_analytics.model.lkml
# -----------------------------------------------------------------------------
# Maps the dbt star schema to a Looker semantic model:
#   - two per-game FACTS (batter / pitcher game stats) from the `marts` dataset
#   - one shared player DIMENSION (Chadwick lookup) from the `raw` dataset
# Each Explore is anchored on a fact and joins the player dimension many_to_one.
# =============================================================================

# Placeholder connection name — point this at a real BigQuery connection in a
# live Looker instance. Not wired to a warehouse here.
connection: "bigquery_connection"

# Pull in every view file (one per mart fact + the player dimension).
include: "/views/*.view.lkml"

# -----------------------------------------------------------------------------
# Explore: batter performance per game, with player names joined in.
# -----------------------------------------------------------------------------
explore: batter_game_stats {
  label: "Batting — Per Game"
  description: "Batter Statcast metrics at one-row-per-batter-per-game grain, with player names from the Chadwick lookup."

  join: player {
    # The fact has many rows (one per game) for a single player, so the join
    # from fact -> dimension is many_to_one. Declaring this lets Looker know
    # the dimension's fields are single-valued per join key.
    relationship: many_to_one
    type: left_outer
    sql_on: ${batter_game_stats.batter_id} = ${player.mlbam_id} ;;
    # Symmetric aggregation: because batter_game_stats.pk is its declared
    # primary_key, any sum/average measure on the fact stays correct even though
    # the join fans the dimension out across many game rows. Looker hashes the
    # fact PK so a player's totals are never double-counted in the rollup.
  }
}

# -----------------------------------------------------------------------------
# Explore: pitcher performance per game, with player names joined in.
# -----------------------------------------------------------------------------
explore: pitcher_game_stats {
  label: "Pitching — Per Game"
  description: "Pitcher Statcast metrics at one-row-per-pitcher-per-game grain, joined to the player dimension."

  join: player {
    relationship: many_to_one
    type: left_outer
    sql_on: ${pitcher_game_stats.pitcher_id} = ${player.mlbam_id} ;;
  }
}
