"""Logging utilities for the ingestion pipeline."""

import logging
import sys

_LOG_FORMAT = "%(asctime)s | %(levelname)s | %(message)s"


def get_logger(name: str) -> logging.Logger:
    """Return a logger configured to write to stdout.

    The logger emits records at INFO level using the format
    ``timestamp | level | message``. Repeated calls with the same ``name``
    return the same logger without adding duplicate handlers.

    Args:
        name: Name of the logger, typically ``__name__`` of the caller.

    Returns:
        A configured :class:`logging.Logger` instance.
    """
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(logging.Formatter(_LOG_FORMAT))
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
        logger.propagate = False
    return logger
