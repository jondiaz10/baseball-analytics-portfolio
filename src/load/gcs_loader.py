"""Upload extracted DataFrames to Google Cloud Storage as parquet."""

import io
from datetime import datetime

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from google.cloud import storage

from src.utils.logger import get_logger

logger = get_logger(__name__)

_DATE_FORMAT = "%Y-%m-%d"
_BYTES_PER_MB = 1024 * 1024


def upload_to_gcs(
    df: pd.DataFrame, bucket_name: str, start_date: str, end_date: str
) -> str:
    """Serialize a DataFrame to parquet and upload it to GCS.

    The DataFrame is converted to parquet bytes in memory (via pyarrow) and
    streamed directly to GCS without touching local disk. The object is
    partitioned by the year and month of ``start_date``:
    ``statcast/year={YYYY}/month={MM}/statcast_{start_date}_{end_date}.parquet``.

    Authentication is handled by Application Default Credentials.

    Args:
        df: The pitch-level data to upload.
        bucket_name: Target GCS bucket name (no ``gs://`` prefix).
        start_date: Range start, formatted ``YYYY-MM-DD``; drives partitioning.
        end_date: Range end, formatted ``YYYY-MM-DD``.

    Returns:
        The full ``gs://bucket/path`` URI of the uploaded object.

    Raises:
        Exception: Any error during serialization or upload is logged and
            re-raised.
    """
    try:
        start = datetime.strptime(start_date, _DATE_FORMAT)
        blob_path = (
            f"statcast/year={start.year:04d}/month={start.month:02d}/"
            f"statcast_{start_date}_{end_date}.parquet"
        )

        buffer = io.BytesIO()
        table = pa.Table.from_pandas(df)
        pq.write_table(table, buffer)
        parquet_bytes = buffer.getvalue()

        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_path)
        blob.upload_from_string(parquet_bytes, content_type="application/octet-stream")

        gcs_uri = f"gs://{bucket_name}/{blob_path}"
        size_mb = len(parquet_bytes) / _BYTES_PER_MB
        logger.info("Uploaded %.2f MB to %s", size_mb, gcs_uri)
        return gcs_uri
    except Exception:
        logger.error("Failed to upload parquet to bucket %s", bucket_name)
        raise
