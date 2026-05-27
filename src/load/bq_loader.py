"""Load parquet files from GCS into BigQuery."""

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
