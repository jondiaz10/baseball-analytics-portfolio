"""Load parquet files from GCS into BigQuery."""

import pandas as pd
from google.cloud import bigquery

from src.utils.logger import get_logger

logger = get_logger(__name__)


def load_to_bigquery(gcs_uri: str, project: str, dataset: str, table: str) -> int:
    """Load a parquet file from GCS into a BigQuery table.

    The load appends to the destination table (``WRITE_APPEND``) and lets
    BigQuery autodetect the schema from the parquet file. Authentication is
    handled by Application Default Credentials.

    Args:
        gcs_uri: Source object URI, e.g. ``gs://bucket/path/file.parquet``.
        project: GCP project that owns the destination dataset.
        dataset: BigQuery dataset name.
        table: Destination table name within ``dataset``.

    Returns:
        The number of rows in the destination table after the load completes.

    Raises:
        Exception: Any error during the load job is logged and re-raised.
    """
    try:
        client = bigquery.Client(project=project)
        table_ref = f"{project}.{dataset}.{table}"

        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.PARQUET,
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
            autodetect=True,
        )

        load_job = client.load_table_from_uri(
            gcs_uri, table_ref, job_config=job_config
        )
        load_job.result()  # Wait for completion; raises on failure.

        rows_loaded = load_job.output_rows or 0
        logger.info("Loaded %d rows into %s", rows_loaded, table_ref)
        return rows_loaded
    except Exception:
        logger.error("Failed to load %s into BigQuery", gcs_uri)
        raise


def load_dataframe_to_bigquery(
    df: pd.DataFrame,
    project: str,
    dataset: str,
    table: str,
    write_disposition: str = "WRITE_TRUNCATE",
) -> int:
    """Load a pandas DataFrame directly into a BigQuery table.

    Bypasses GCS — appropriate for small reference tables where the round trip
    through object storage is unnecessary overhead. The schema is autodetected
    from the DataFrame. Authentication is handled by Application Default
    Credentials.

    Args:
        df: DataFrame to load.
        project: GCP project that owns the destination dataset.
        dataset: BigQuery dataset name.
        table: Destination table name within ``dataset``.
        write_disposition: BigQuery write disposition string. Defaults to
            ``"WRITE_TRUNCATE"`` (full refresh), which is the right behavior
            for reference tables.

    Returns:
        The number of rows loaded into the destination table.

    Raises:
        Exception: Any error during the load job is logged and re-raised.
    """
    try:
        client = bigquery.Client(project=project)
        table_ref = f"{project}.{dataset}.{table}"

        job_config = bigquery.LoadJobConfig(
            write_disposition=write_disposition,
            autodetect=True,
        )

        load_job = client.load_table_from_dataframe(
            df, table_ref, job_config=job_config
        )
        load_job.result()  # Wait for completion; raises on failure.

        rows_loaded = load_job.output_rows or 0
        logger.info(
            "Loaded %d rows into %s (write_disposition=%s)",
            rows_loaded,
            table_ref,
            write_disposition,
        )
        return rows_loaded
    except Exception:
        logger.error(
            "Failed to load DataFrame into %s.%s.%s", project, dataset, table
        )
        raise
