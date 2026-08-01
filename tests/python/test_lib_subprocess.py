#!/usr/bin/env python3
"""Unit tests for tools/lib/subprocess.py."""

import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from tools.lib.subprocess import CommandExecutionError, run_command  # noqa: E402


def test_run_command_captures_stdout():
    result = run_command([sys.executable, "-c", "print('hello')"])
    assert result.ok
    assert result.stdout.strip() == "hello"


def test_run_command_captures_nonzero_exit_without_raising_by_default():
    result = run_command([sys.executable, "-c", "import sys; sys.exit(3)"])
    assert result.returncode == 3
    assert result.ok is False


def test_run_command_raises_when_check_true_and_exit_nonzero():
    with pytest.raises(CommandExecutionError):
        run_command([sys.executable, "-c", "import sys; sys.exit(1)"], check=True)


def test_run_command_raises_on_missing_binary():
    with pytest.raises(CommandExecutionError):
        run_command(["definitely-not-a-real-binary-xyz"])


def test_run_command_raises_on_timeout():
    with pytest.raises(CommandExecutionError):
        run_command(
            [sys.executable, "-c", "import time; time.sleep(5)"],
            timeout=0.1,
        )


def test_run_command_rejects_empty_args():
    with pytest.raises(ValueError):
        run_command([])
