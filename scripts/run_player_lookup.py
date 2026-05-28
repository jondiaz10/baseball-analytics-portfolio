"""Entry point: extract the Chadwick player registry and load it to BigQuery."""

import sys
from pathlib import Path

import yaml

# Ensure the repo root is importable when run as
# `python scripts/run_player_lookup.py`.
_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from src.extract.player_lookup_extract import extract_player_lookup  # noqa: E402
from src.load.bq_loader import load_dataframe_to_bigquery  # noqa: E402
from src.utils.logger import get_logger  # noqa: E402

logger = get_logger(__name__)

_CONFIG_PATH = _REPO_ROOT / "config" / "pipeline_config.yaml"
_WRITE_DISPOSITION = "WRITE_TRUNCATE"


def load_config(config_path: Path = _CONFIG_PATH) -> dict:
    """Load the pipeline configuration from YAML.

    Args:
        config_path: Path to the YAML config file.

    Returns:
        The parsed configuration as a nested dictionary.
    """
    with open(config_path, "r") as f:
        return yaml.safe_load(f)


def run() -> None:
    """Run the player_lookup extract -> BigQuery pipeline."""
    config = load_config()
    bq_project = config["bigquery"]["project"]
    ref_cfg = config["reference_tables"]["player_lookup"]
    bq_dataset = ref_cfg["dataset"]
    bq_table = ref_cfg["table"]

    df = extract_player_lookup()
    rows_extracted = len(df)

    rows_loaded = load_dataframe_to_bigquery(
        df,
        project=bq_project,
        dataset=bq_dataset,
        table=bq_table,
        write_disposition=_WRITE_DISPOSITION,
    )

    _print_summary(
        rows_extracted=rows_extracted,
        destination=f"{bq_project}.{bq_dataset}.{bq_table}",
        write_disposition=_WRITE_DISPOSITION,
        rows_loaded=rows_loaded,
    )


def _print_summary(
    rows_extracted: int,
    destination: str,
    write_disposition: str,
    rows_loaded: int,
) -> None:
    """Print a human-readable run summary to stdout.

    Args:
        rows_extracted: Rows returned by the Chadwick extract.
        destination: Fully qualified BigQuery destination ``project.dataset.table``.
        write_disposition: BigQuery write disposition used for the load.
        rows_loaded: Rows loaded into BigQuery.
    """
    print("\n=== Player Lookup Pipeline ===")
    print(f"Rows extracted: {rows_extracted}")
    print(f"Loaded to:      {destination}")
    print(f"Write mode:     {write_disposition} (full refresh)")
    print(f"Rows loaded:    {rows_loaded}")


def main() -> None:
    """Run the player_lookup pipeline."""
    run()


if __name__ == "__main__":
    main()
