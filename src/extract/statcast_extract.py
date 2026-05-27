"""Extract pitch-level Statcast data from Baseball Savant via pybaseball."""

from datetime import datetime, timedelta

import pandas as pd
import pybaseball

from src.utils.logger import get_logger

logger = get_logger(__name__)

_DATE_FORMAT = "%Y-%m-%d"

# Statcast data is mutated by ongoing Savant updates, so caching would serve
# stale rows. Disable pybaseball's on-disk cache for this pipeline.
pybaseball.cache.disable()


def _chunk_date_ranges(
    start_date: str, end_date: str, chunk_size_days: int
) -> list[tuple[str, str]]:
    """Split an inclusive date range into consecutive chunks.

    Args:
        start_date: First date to include, formatted ``YYYY-MM-DD``.
        end_date: Last date to include, formatted ``YYYY-MM-DD``.
        chunk_size_days: Maximum number of days per chunk.

    Returns:
        A list of ``(chunk_start, chunk_end)`` string tuples covering the range.
    """
    start = datetime.strptime(start_date, _DATE_FORMAT)
    end = datetime.strptime(end_date, _DATE_FORMAT)

    chunks: list[tuple[str, str]] = []
    cursor = start
    while cursor <= end:
        chunk_end = min(cursor + timedelta(days=chunk_size_days - 1), end)
        chunks.append((cursor.strftime(_DATE_FORMAT), chunk_end.strftime(_DATE_FORMAT)))
        cursor = chunk_end + timedelta(days=1)
    return chunks


def extract_statcast(
    start_date: str, end_date: str, chunk_size_days: int = 7
) -> pd.DataFrame:
    """Pull pitch-level Statcast data for an inclusive date range.

    Data is requested in chunks of ``chunk_size_days`` to stay within Baseball
    Savant's rate limits. Each chunk is logged with its date span and row count.
    Chunks that return no data are skipped. All non-empty chunks are concatenated
    into a single DataFrame.

    Args:
        start_date: First date to pull, formatted ``YYYY-MM-DD``.
        end_date: Last date to pull, formatted ``YYYY-MM-DD``.
        chunk_size_days: Number of days to request per chunk. Defaults to 7.

    Returns:
        A DataFrame of all pitches in the range, or an empty DataFrame if the
        entire range returned no data.

    Raises:
        Exception: Any error raised by the underlying pybaseball call is logged
            and re-raised.
    """
    logger.info("Extracting Statcast data from %s to %s", start_date, end_date)
    chunks = _chunk_date_ranges(start_date, end_date, chunk_size_days)

    frames: list[pd.DataFrame] = []
    for chunk_start, chunk_end in chunks:
        try:
            chunk_df = pybaseball.statcast(start_dt=chunk_start, end_dt=chunk_end)
        except Exception:
            logger.error(
                "Failed to extract Statcast chunk %s to %s", chunk_start, chunk_end
            )
            raise

        rows = 0 if chunk_df is None else len(chunk_df)
        logger.info("Chunk %s to %s returned %d rows", chunk_start, chunk_end, rows)
        if chunk_df is not None and not chunk_df.empty:
            frames.append(chunk_df)

    if not frames:
        logger.info("No Statcast data returned for %s to %s", start_date, end_date)
        return pd.DataFrame()

    full_df = pd.concat(frames, ignore_index=True)
    logger.info("Extracted %d total rows across %d chunks", len(full_df), len(frames))
    return full_df
