"""Tests for the Statcast extraction step."""

from unittest.mock import patch

import pandas as pd

from src.extract.statcast_extract import extract_statcast


@patch("src.extract.statcast_extract.pybaseball.statcast")
def test_extract_statcast_returns_dataframe_with_rows(mock_statcast) -> None:
    """extract_statcast returns a non-empty DataFrame for a known range.

    The pybaseball call is mocked so the test does not hit Baseball Savant.
    """
    mock_statcast.return_value = pd.DataFrame(
        {
            "game_date": ["2024-04-01", "2024-04-02", "2024-04-03"],
            "pitch_type": ["FF", "SL", "CH"],
            "release_speed": [95.1, 88.4, 84.7],
        }
    )

    result = extract_statcast("2024-04-01", "2024-04-03")

    assert isinstance(result, pd.DataFrame)
    assert len(result) == 3
    mock_statcast.assert_called_once_with(start_dt="2024-04-01", end_dt="2024-04-03")
