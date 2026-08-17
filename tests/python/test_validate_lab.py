#!/usr/bin/env python3
"""Unit tests for scripts/validate_lab.py."""

import importlib.util
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
VALIDATE_LAB_PATH = PROJECT_ROOT / "scripts" / "validate_lab.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("validate_lab", VALIDATE_LAB_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules["validate_lab"] = module
    spec.loader.exec_module(module)
    return module


validate_lab = _load_module()


def test_discover_vagrantfiles_finds_all_labs():
    found = {str(p.relative_to(PROJECT_ROOT)) for p in validate_lab.discover_vagrantfiles()}
    assert found == {
        "labs/security/active-directory/base/Vagrantfile",
        "labs/security/active-directory/base/virtualbox/Vagrantfile",
        "labs/security/active-directory/vlan-segmented/Vagrantfile",
        "labs/security/active-directory/vlan-segmented/virtualbox/Vagrantfile",
        # devops-linux-lab uses one unified Vagrantfile supporting both
        # KVM/libvirt and VirtualBox (selected via --provider), unlike
        # the two AD labs above which each ship a separate Vagrantfile
        # per provider.
        "labs/infrastructure/devops-linux-lab/Vagrantfile",
    }


def test_check_repository_structure_passes_on_real_repo():
    result = validate_lab.check_repository_structure()
    assert result.passed, result.detail


def test_check_lab_readmes_passes_on_real_repo():
    result = validate_lab.check_lab_readmes()
    assert result.passed, result.detail


def test_check_python_tools_syntax_passes_on_real_repo():
    result = validate_lab.check_python_tools_syntax()
    assert result.passed, result.detail


def test_check_vagrant_syntax_skip_flag_short_circuits():
    result = validate_lab.check_vagrant_syntax(skip=True)
    assert result.passed
    assert "skipped" in result.detail


def test_check_documentation_consistency_passes_on_real_repo():
    result = validate_lab.check_documentation_consistency()
    assert result.passed, result.detail


def test_run_all_checks_returns_all_check_names(monkeypatch):
    results = validate_lab.run_all_checks(skip_vagrant=True)
    names = {r.name for r in results}
    assert names == {
        "Repository structure",
        "Lab documentation",
        "Python tool syntax",
        "Vagrant configuration",
        "Documentation consistency",
    }


def test_main_returns_zero_when_all_checks_pass(monkeypatch, capsys):
    monkeypatch.setattr(sys, "argv", ["validate_lab.py", "--skip-vagrant"])
    exit_code = validate_lab.main()
    assert exit_code == 0
    out = capsys.readouterr().out
    assert "PASS: Repository structure" in out
