"""Entry point: extract MLB teams + 40-man rosters and load them to BigQuery.

Mirrors ``run_player_lookup.py`` — both are small current-state reference tables
loaded directly from a DataFrame with ``WRITE_TRUNCATE`` (no GCS round trip).
"""

import sys
from pathlib import Path

import yaml

# Ensure the repo root is importable when run as
# `python scripts/run_team_data.py`.
_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from src.extract.mlb_team_extract import extract_rosters, extract_teams  # noqa: E402
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
    """Run the MLB team + roster extract -> BigQuery pipeline."""
    config = load_config()
    bq_project = config["bigquery"]["project"]
    teams_cfg = config["reference_tables"]["mlb_teams"]
    rosters_cfg = config["reference_tables"]["mlb_rosters"]
    status_cfg = config["reference_tables"]["mlb_roster_status"]

    teams_df = extract_teams()
    team_ids = teams_df["team_id"].dropna().astype("int64").tolist()

    # 40-man roster drives the player -> team mapping (dim_team join).
    rosters_df = extract_rosters(team_ids, roster_type="40Man")
    # fullRoster carries every rostered player WITH status (incl. 60-Day IL,
    # who are dropped from the 40-man), driving the roster/status dimension.
    status_df = extract_rosters(team_ids, roster_type="fullRoster")

    teams_loaded = load_dataframe_to_bigquery(
        teams_df,
        project=bq_project,
        dataset=teams_cfg["dataset"],
        table=teams_cfg["table"],
        write_disposition=_WRITE_DISPOSITION,
    )
    rosters_loaded = load_dataframe_to_bigquery(
        rosters_df,
        project=bq_project,
        dataset=rosters_cfg["dataset"],
        table=rosters_cfg["table"],
        write_disposition=_WRITE_DISPOSITION,
    )
    status_loaded = load_dataframe_to_bigquery(
        status_df,
        project=bq_project,
        dataset=status_cfg["dataset"],
        table=status_cfg["table"],
        write_disposition=_WRITE_DISPOSITION,
    )

    _print_summary(
        teams_extracted=len(teams_df),
        rosters_extracted=len(rosters_df),
        status_extracted=len(status_df),
        teams_destination=f"{bq_project}.{teams_cfg['dataset']}.{teams_cfg['table']}",
        rosters_destination=f"{bq_project}.{rosters_cfg['dataset']}.{rosters_cfg['table']}",
        status_destination=f"{bq_project}.{status_cfg['dataset']}.{status_cfg['table']}",
        teams_loaded=teams_loaded,
        rosters_loaded=rosters_loaded,
        status_loaded=status_loaded,
    )


def _print_summary(
    teams_extracted: int,
    rosters_extracted: int,
    status_extracted: int,
    teams_destination: str,
    rosters_destination: str,
    status_destination: str,
    teams_loaded: int,
    rosters_loaded: int,
    status_loaded: int,
) -> None:
    """Print a human-readable run summary to stdout.

    Args:
        teams_extracted: Rows returned by the teams extract.
        rosters_extracted: Rows returned by the 40-man rosters extract.
        status_extracted: Rows returned by the fullRoster status extract.
        teams_destination: Fully qualified BigQuery destination for teams.
        rosters_destination: Fully qualified BigQuery destination for rosters.
        status_destination: Fully qualified BigQuery destination for roster status.
        teams_loaded: Rows loaded into the teams table.
        rosters_loaded: Rows loaded into the rosters table.
        status_loaded: Rows loaded into the roster status table.
    """
    print("\n=== MLB Team Data Pipeline ===")
    print(f"Teams extracted:   {teams_extracted}")
    print(f"Loaded to:         {teams_destination}")
    print(f"Rows loaded:       {teams_loaded}")
    print(f"Rosters extracted: {rosters_extracted} (40-man)")
    print(f"Loaded to:         {rosters_destination}")
    print(f"Rows loaded:       {rosters_loaded}")
    print(f"Status extracted:  {status_extracted} (fullRoster, with status)")
    print(f"Loaded to:         {status_destination}")
    print(f"Rows loaded:       {status_loaded}")
    print(f"Write mode:        {_WRITE_DISPOSITION} (full refresh)")


def main() -> None:
    """Run the MLB team data pipeline."""
    run()


if __name__ == "__main__":
    main()
