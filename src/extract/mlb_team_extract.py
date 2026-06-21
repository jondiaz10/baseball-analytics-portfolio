"""Extract MLB team and 40-man roster data from the MLB Stats API.

The MLB Stats API (``statsapi.mlb.com``) is public and needs no auth. We pull
two small reference datasets:

* the 30 MLB clubs (team dimension), and
* each club's 40-man roster (the player -> team mapping).

Roster type is **40Man** on purpose: the active (26-man) roster drops players
who are injured (IL) or recently traded, which would leave gaps in the player ->
team mapping. The 40-man keeps them attached to their club.

The MLBAM player id returned here (``person.id``) is the same id Statcast uses
for ``batter`` / ``pitcher`` and that ``raw.player_lookup`` stores as
``mlbam_id`` — so team data joins cleanly onto the existing models.
"""

import pandas as pd
import requests

from src.utils.logger import get_logger

logger = get_logger(__name__)

# Public MLB Stats API. sportId=1 scopes the teams endpoint to MLB.
_TEAMS_URL = "https://statsapi.mlb.com/api/v1/teams?sportId=1"
_ROSTER_URL = "https://statsapi.mlb.com/api/v1/teams/{team_id}/roster?rosterType={roster_type}"

# Network timeout (seconds) for every Stats API request.
_TIMEOUT = 30


def extract_teams() -> pd.DataFrame:
    """Pull the 30 MLB clubs as a team dimension.

    Returns:
        A DataFrame with one row per team and columns ``team_id``,
        ``team_name`` (full club name), ``team_abbrev``, ``team_short_name``,
        ``location_name``, ``league_id``, ``league_name``, ``division_id``,
        ``division_name``, ``venue_name``.

    Raises:
        Exception: Any error fetching or parsing the teams feed is logged and
            re-raised.
    """
    logger.info("Fetching MLB teams from Stats API")
    try:
        resp = requests.get(_TEAMS_URL, timeout=_TIMEOUT)
        resp.raise_for_status()
        teams = resp.json().get("teams", [])
    except Exception:
        logger.error("Failed to fetch MLB teams from %s", _TEAMS_URL)
        raise

    rows: list[dict] = []
    for team in teams:
        league = team.get("league", {}) or {}
        division = team.get("division", {}) or {}
        venue = team.get("venue", {}) or {}
        rows.append(
            {
                "team_id": team.get("id"),
                "team_name": team.get("name"),
                "team_abbrev": team.get("abbreviation"),
                "team_short_name": team.get("teamName"),
                "location_name": team.get("locationName"),
                "league_id": league.get("id"),
                "league_name": league.get("name"),
                "division_id": division.get("id"),
                "division_name": division.get("name"),
                "venue_name": venue.get("name"),
            }
        )

    df = pd.DataFrame(rows)
    logger.info("Returning %d MLB teams", len(df))
    return df


def extract_rosters(
    team_ids: list[int], roster_type: str = "40Man"
) -> pd.DataFrame:
    """Pull each club's roster and return a player -> team mapping.

    Args:
        team_ids: MLB team ids to fetch rosters for (from :func:`extract_teams`).
        roster_type: MLB Stats API roster type. Defaults to ``"40Man"`` so that
            injured / recently traded players stay mapped to their club.

    Returns:
        A DataFrame with one row per roster spot and columns ``mlbam_id``,
        ``player_full_name``, ``team_id``, ``jersey_number``, ``position_code``,
        ``position_name``, ``position_type``, ``status_code``,
        ``status_description``. A player can in principle appear under more than
        one club around a transaction; de-duplication to one team per player is
        handled downstream in ``stg_mlb_rosters``.

    Raises:
        Exception: Any error fetching or parsing a roster feed is logged and
            re-raised.
    """
    logger.info(
        "Fetching %s rosters for %d teams", roster_type, len(team_ids)
    )

    rows: list[dict] = []
    for team_id in team_ids:
        url = _ROSTER_URL.format(team_id=team_id, roster_type=roster_type)
        try:
            resp = requests.get(url, timeout=_TIMEOUT)
            resp.raise_for_status()
            roster = resp.json().get("roster", [])
        except Exception:
            logger.error("Failed to fetch roster for team %s (%s)", team_id, url)
            raise

        for spot in roster:
            person = spot.get("person", {}) or {}
            position = spot.get("position", {}) or {}
            status = spot.get("status", {}) or {}
            rows.append(
                {
                    "mlbam_id": person.get("id"),
                    "player_full_name": person.get("fullName"),
                    "team_id": team_id,
                    "jersey_number": spot.get("jerseyNumber"),
                    "position_code": position.get("code"),
                    "position_name": position.get("name"),
                    "position_type": position.get("type"),
                    "status_code": status.get("code"),
                    "status_description": status.get("description"),
                }
            )

    df = pd.DataFrame(rows)

    # mlbam_id should always be present; drop and cast to a clean int so it
    # joins to the integer batter_id / pitcher_id keys downstream.
    df = df.dropna(subset=["mlbam_id"]).copy()
    df["mlbam_id"] = df["mlbam_id"].astype("int64")

    logger.info("Returning %d roster rows", len(df))
    return df
