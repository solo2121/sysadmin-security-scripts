#!/usr/bin/env python3
"""Unit tests for tools/lib/validators.py."""

import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from tools.lib import validators  # noqa: E402


@pytest.mark.parametrize(
    "value,expected",
    [
        ("192.168.1.1", True),
        ("10.0.0.255", True),
        ("::1", True),
        ("999.1.1.1", False),
        ("not-an-ip", False),
        ("", False),
    ],
)
def test_is_valid_ip(value, expected):
    assert validators.is_valid_ip(value) is expected


@pytest.mark.parametrize(
    "value,expected",
    [
        ("192.168.1.0/24", True),
        ("10.0.0.0/8", True),
        ("192.168.1.5", True),  # a single host is a valid /32 network
        ("not-a-network", False),
    ],
)
def test_is_valid_network(value, expected):
    assert validators.is_valid_network(value) is expected


@pytest.mark.parametrize(
    "value,expected",
    [
        ("example.com", True),
        ("dc01.lab.local", True),
        ("localhost", True),
        ("-bad-start.com", False),
        ("", False),
        ("a" * 300, False),
    ],
)
def test_is_valid_hostname(value, expected):
    assert validators.is_valid_hostname(value) is expected


def test_is_valid_target_accepts_ip_network_and_hostname():
    assert validators.is_valid_target("10.0.0.1")
    assert validators.is_valid_target("10.0.0.0/24")
    assert validators.is_valid_target("dc01.lab.local")
    assert not validators.is_valid_target("")


@pytest.mark.parametrize(
    "value,expected",
    [
        (80, True),
        ("443", True),
        (0, False),
        (65536, False),
        ("not-a-port", False),
        (None, False),
    ],
)
def test_is_valid_port(value, expected):
    assert validators.is_valid_port(value) is expected


def test_parse_port_range_combines_singles_and_ranges():
    assert validators.parse_port_range("22,80,443") == [22, 80, 443]
    assert validators.parse_port_range("1-5") == [1, 2, 3, 4, 5]
    assert validators.parse_port_range("22, 1000-1002") == [22, 1000, 1001, 1002]


def test_parse_port_range_deduplicates_and_sorts():
    assert validators.parse_port_range("80,22,80") == [22, 80]


@pytest.mark.parametrize("bad_range", ["0-10", "70000", "abc", "10-5"])
def test_parse_port_range_rejects_invalid_input(bad_range):
    with pytest.raises(ValueError):
        validators.parse_port_range(bad_range)


def test_is_existing_file(tmp_path):
    existing = tmp_path / "file.txt"
    existing.write_text("data")
    assert validators.is_existing_file(str(existing))
    assert not validators.is_existing_file(str(tmp_path / "missing.txt"))
