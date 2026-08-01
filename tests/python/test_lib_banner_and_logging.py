#!/usr/bin/env python3
"""Unit tests for tools/lib/banner.py and tools/lib/logging.py."""

import io
import logging
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from tools.lib.banner import render_banner  # noqa: E402
from tools.lib.logging import get_logger  # noqa: E402


def test_render_banner_includes_title_and_notice():
    banner = render_banner("Port Scanner", "Fast async TCP scanner")
    assert "Port Scanner" in banner
    assert "Fast async TCP scanner" in banner
    assert "authorized" in banner.lower()


def test_render_banner_can_omit_authorized_use_notice():
    banner = render_banner("Internal Tool", authorized_use_notice=False)
    assert "authorized" not in banner.lower()


def test_get_logger_returns_configured_logger():
    stream = io.StringIO()
    log = get_logger("test.lib.logging.basic", stream=stream)
    log.info("hello world")
    assert "hello world" in stream.getvalue()


def test_get_logger_is_idempotent_no_duplicate_handlers():
    stream = io.StringIO()
    log1 = get_logger("test.lib.logging.idempotent", stream=stream)
    log2 = get_logger("test.lib.logging.idempotent", stream=stream)
    assert log1 is log2
    handler_count = len(log1.handlers)
    get_logger("test.lib.logging.idempotent", stream=stream)
    assert len(log1.handlers) == handler_count


def test_get_logger_verbose_sets_debug_level():
    log = get_logger("test.lib.logging.verbose", verbose=True)
    assert log.level == logging.DEBUG


def test_get_logger_quiet_sets_warning_level():
    log = get_logger("test.lib.logging.quiet", quiet=True)
    assert log.level == logging.WARNING
