"""
Shared logging configuration for security-engineering-lab CLI tools.

Provides one function, :func:`get_logger`, that every tool in
``tools/security/`` and ``tools/sysadmin/`` can call to get a
consistently formatted, level-aware logger instead of hand-rolling
``print()`` statements or ad-hoc ``logging.basicConfig`` calls.

Example
-------
>>> from tools.lib.logging import get_logger
>>> log = get_logger(__name__, verbose=True)
>>> log.info("Starting scan of %s", target)
"""

from __future__ import annotations

import logging
import sys
from typing import TextIO

_CONFIGURED_LOGGERS: set[str] = set()

# ANSI colors, enabled only when the configured output stream (stderr
# by default — see get_logger) is a TTY.
_COLORS = {
    "DEBUG": "\033[36m",  # cyan
    "INFO": "\033[32m",  # green
    "WARNING": "\033[33m",  # yellow
    "ERROR": "\033[31m",  # red
    "CRITICAL": "\033[41m",  # red background
}
_RESET = "\033[0m"


class _ColorFormatter(logging.Formatter):
    """Formatter that adds color to the level name when writing to a TTY."""

    def __init__(self, use_color: bool) -> None:
        super().__init__(
            fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            datefmt="%H:%M:%S",
        )
        self._use_color = use_color

    def format(self, record: logging.LogRecord) -> str:
        message = super().format(record)
        if not self._use_color:
            return message
        color = _COLORS.get(record.levelname, "")
        if not color:
            return message
        return f"{color}{message}{_RESET}"


def get_logger(
    name: str,
    *,
    verbose: bool = False,
    quiet: bool = False,
    stream: TextIO | None = None,
) -> logging.Logger:
    """
    Return a configured logger for a CLI tool.

    Idempotent: calling this repeatedly for the same ``name`` will not
    add duplicate handlers (important when a tool's ``main()`` can be
    invoked more than once, e.g. from tests).

    Args:
        name: Usually ``__name__`` of the calling module.
        verbose: If True, set level to DEBUG.
        quiet: If True, set level to WARNING (suppresses INFO). Ignored
            if ``verbose`` is also True.
        stream: Optional stream to write to (defaults to ``sys.stderr``
            so tool output on stdout stays clean for piping).

    Returns:
        A configured ``logging.Logger`` instance.
    """
    logger = logging.getLogger(name)

    if name not in _CONFIGURED_LOGGERS:
        handler = logging.StreamHandler(stream or sys.stderr)
        use_color = handler.stream.isatty() if hasattr(handler.stream, "isatty") else False
        handler.setFormatter(_ColorFormatter(use_color))
        logger.addHandler(handler)
        logger.propagate = False
        _CONFIGURED_LOGGERS.add(name)

    if verbose:
        logger.setLevel(logging.DEBUG)
    elif quiet:
        logger.setLevel(logging.WARNING)
    else:
        logger.setLevel(logging.INFO)

    return logger
