#!/usr/bin/env python3
"""Unit tests for tools/lib/cli.py."""

import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from tools.lib import cli  # noqa: E402


def test_build_parser_has_verbose_and_quiet_flags():
    parser = cli.build_parser("example.py", "An example tool.")
    args = parser.parse_args(["-v"])
    assert args.verbose is True
    assert args.quiet is False

    args = parser.parse_args(["--quiet"])
    assert args.quiet is True
    assert args.verbose is False


def test_build_parser_rejects_verbose_and_quiet_together():
    parser = cli.build_parser("example.py", "An example tool.")
    with pytest.raises(SystemExit):
        parser.parse_args(["-v", "-q"])


def test_build_parser_includes_examples_in_help(capsys):
    parser = cli.build_parser(
        "example.py",
        "An example tool.",
        epilog_examples=["python3 example.py --target 10.0.0.1"],
    )
    help_text = parser.format_help()
    assert "Examples:" in help_text
    assert "python3 example.py --target 10.0.0.1" in help_text


def test_check_dependencies_detects_missing_python_package():
    missing = cli.check_dependencies(python_packages=["definitely_not_a_real_package_xyz"])
    assert len(missing) == 1
    assert missing[0].kind == "python"
    assert missing[0].name == "definitely_not_a_real_package_xyz"


def test_check_dependencies_detects_available_stdlib_module():
    missing = cli.check_dependencies(python_packages=["os", "sys"])
    assert missing == []


def test_check_dependencies_detects_missing_binary():
    missing = cli.check_dependencies(binaries=["definitely-not-a-real-binary-xyz"])
    assert len(missing) == 1
    assert missing[0].kind == "binary"


def test_require_dependencies_returns_false_without_exit_when_missing():
    ok = cli.require_dependencies(
        python_packages=["definitely_not_a_real_package_xyz"],
        exit_on_missing=False,
    )
    assert ok is False


def test_require_dependencies_exits_when_missing_and_exit_on_missing_true():
    with pytest.raises(SystemExit):
        cli.require_dependencies(
            python_packages=["definitely_not_a_real_package_xyz"],
            exit_on_missing=True,
        )


def test_require_dependencies_true_when_all_present():
    ok = cli.require_dependencies(python_packages=["os"], exit_on_missing=False)
    assert ok is True
