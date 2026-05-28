"""Extract the Chadwick Bureau player registry directly from the source CSVs."""

import pandas as pd

from src.utils.logger import get_logger

logger = get_logger(__name__)

# The Chadwick "people" registry is published as 16 hex-sharded CSV files on
# GitHub. pybaseball's chadwick_register() wraps these but trims the schema to
# 8 columns; we read them directly so birth_country, name_given, and the pro_*
# debut years are preserved.
_CHADWICK_URL = (
    "https://raw.githubusercontent.com/chadwickbureau/register/master/data/"
    "people-{shard}.csv"
)
_SHARDS = list("0123456789abcdef")

_COLUMN_RENAMES = {
    "key_mlbam": "mlbam_id",
    "key_fangraphs": "fangraphs_id",
    "key_bbref": "bbref_id",
    "name_last": "last_name",
    "name_first": "first_name",
    "name_given": "given_name",
    "pro_played_first": "mlb_debut_year",
    "pro_played_last": "mlb_last_year",
    "birth_year": "birth_year",
}


def extract_player_lookup() -> pd.DataFrame:
    """Pull the Chadwick Bureau player registry and shape it for our warehouse.

    The Chadwick registry contains every MLB player ever along with crosswalks
    to MLBAM, FanGraphs, and Baseball-Reference IDs. We fetch all 16 hex shards
    of the published CSV, filter to rows that have a ``key_mlbam`` value (the
    ID Statcast uses), and project the columns the downstream marts need.

    Returns:
        A DataFrame with columns ``mlbam_id`` (int), ``fangraphs_id``,
        ``bbref_id``, ``last_name``, ``first_name``, ``given_name``,
        ``mlb_debut_year``, ``mlb_last_year``, ``birth_year``.

    Raises:
        Exception: Any error reading a Chadwick shard is logged and re-raised.
    """
    logger.info("Fetching Chadwick Bureau player registry (%d shards)", len(_SHARDS))

    frames: list[pd.DataFrame] = []
    for shard in _SHARDS:
        url = _CHADWICK_URL.format(shard=shard)
        try:
            shard_df = pd.read_csv(url, low_memory=False)
        except Exception:
            logger.error("Failed to fetch Chadwick shard %s", url)
            raise
        frames.append(shard_df)

    registry = pd.concat(frames, ignore_index=True)
    total_rows = len(registry)
    logger.info("Chadwick registry returned %d total rows", total_rows)

    with_mlbam = registry[registry["key_mlbam"].notna()].copy()
    logger.info("Filtered to %d rows with non-null key_mlbam", len(with_mlbam))

    projected = with_mlbam[list(_COLUMN_RENAMES.keys())].rename(
        columns=_COLUMN_RENAMES
    )

    # key_mlbam arrives as float (NaNs upstream); cast to nullable Int64,
    # drop any rows that failed the cast, then to plain int.
    projected["mlbam_id"] = pd.to_numeric(
        projected["mlbam_id"], errors="coerce"
    ).astype("Int64")
    projected = projected.dropna(subset=["mlbam_id"]).copy()
    projected["mlbam_id"] = projected["mlbam_id"].astype("int64")

    logger.info("Returning %d player_lookup rows", len(projected))
    return projected
