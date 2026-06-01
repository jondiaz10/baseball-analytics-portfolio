"""Entry point: extract Statcast data, stage it in GCS, load it into BigQuery."""

import argparse
import sys
from pathlib import Path

import yaml

# Ensure the repo root is importable when run as `python scripts/run_pipeline.py`.
_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from src.extract.statcast_extract import extract_statcast  # noqa: E402
from src.load.bq_loader import load_to_bigquery  # noqa: E402
from src.load.gcs_loader import upload_to_gcs  # noqa: E402
from src.utils.logger import get_logger  # noqa: E402

logger = get_logger(__name__)

_CONFIG_PATH = _REPO_ROOT / "config" / "pipeline_config.yaml"

# Map the user-facing --mode flag to a BigQuery write disposition.
_MODE_TO_WRITE_DISPOSITION = {
    "append": "WRITE_APPEND",
    "full-refresh": "WRITE_TRUNCATE",
}


def load_config(config_path: Path = _CONFIG_PATH) -> dict:
    """Load the pipeline configuration from YAML.

    Args:
        config_path: Path to the YAML config file.

    Returns:
        The parsed configuration as a nested dictionary.
    """
    with open(config_path, "r") as f:
        return yaml.safe_load(f)


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments.

    Returns:
        Parsed arguments with ``start_date`` and ``end_date`` attributes.
    """
    parser = argparse.ArgumentParser(
        description=(
            "Extract pitch-level Statcast data, stage it as parquet in GCS, "
            "and append it to BigQuery."
        )
    )
    parser.add_argument(
        "--start-date",
        required=True,
        help="First date to ingest, inclusive (YYYY-MM-DD).",
    )
    parser.add_argument(
        "--end-date",
        required=True,
        help="Last date to ingest, inclusive (YYYY-MM-DD).",
    )
    parser.add_argument(
        "--mode",
        choices=sorted(_MODE_TO_WRITE_DISPOSITION),
        default="append",
        help=(
            "Load mode. 'append' (default) appends rows to the table "
            "(WRITE_APPEND); 'full-refresh' wipes the table before loading "
            "(WRITE_TRUNCATE)."
        ),
    )
    return parser.parse_args()


def run(start_date: str, end_date: str, mode: str = "append") -> None:
    """Run the full extract -> GCS -> BigQuery pipeline for a date range.

    Args:
        start_date: First date to ingest, formatted ``YYYY-MM-DD``.
        end_date: Last date to ingest, formatted ``YYYY-MM-DD``.
        mode: Load mode, either ``"append"`` (WRITE_APPEND) or
            ``"full-refresh"`` (WRITE_TRUNCATE).
    """
    config = load_config()
    bucket = config["gcs"]["bucket"]
    bq_project = config["bigquery"]["project"]
    bq_dataset = config["bigquery"]["raw_dataset"]
    bq_table = config["bigquery"]["table"]
    chunk_size_days = config["extract"]["chunk_size_days"]
    write_disposition = _MODE_TO_WRITE_DISPOSITION[mode]

    df = extract_statcast(start_date, end_date, chunk_size_days=chunk_size_days)
    rows_extracted = len(df)

    if df.empty:
        logger.info("No data extracted for %s to %s; nothing to load.", start_date, end_date)
        _print_summary(start_date, end_date, mode, rows_extracted, gcs_uri=None, rows_loaded=0)
        return

    gcs_uri = upload_to_gcs(df, bucket, start_date, end_date)
    rows_loaded = load_to_bigquery(
        gcs_uri, bq_project, bq_dataset, bq_table, write_disposition=write_disposition
    )

    _print_summary(start_date, end_date, mode, rows_extracted, gcs_uri, rows_loaded)


def _print_summary(
    start_date: str,
    end_date: str,
    mode: str,
    rows_extracted: int,
    gcs_uri: str | None,
    rows_loaded: int,
) -> None:
    """Print a human-readable run summary to stdout.

    Args:
        start_date: Ingestion range start.
        end_date: Ingestion range end.
        mode: Load mode used for the run.
        rows_extracted: Rows pulled from Statcast.
        gcs_uri: Destination GCS URI, or ``None`` if nothing was uploaded.
        rows_loaded: Rows appended to BigQuery.
    """
    print("\n=== Pipeline summary ===")
    print(f"Date range:      {start_date} to {end_date}")
    print(f"Mode:            {mode}")
    print(f"Rows extracted:  {rows_extracted}")
    print(f"GCS URI:         {gcs_uri or '(none — no data)'}")
    print(f"BQ rows loaded:  {rows_loaded}")


def main() -> None:
    """Parse arguments and run the pipeline."""
    args = parse_args()
    run(args.start_date, args.end_date, args.mode)


if __name__ == "__main__":
    main()
