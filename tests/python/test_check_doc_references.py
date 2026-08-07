#!/usr/bin/env python3
"""Unit tests for scripts/check_doc_references.py."""

import importlib.util
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
CHECK_DOC_REFERENCES_PATH = PROJECT_ROOT / "scripts" / "check_doc_references.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("check_doc_references", CHECK_DOC_REFERENCES_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules["check_doc_references"] = module
    spec.loader.exec_module(module)
    return module


check_doc_references = _load_module()


def test_looks_like_path_reference_accepts_known_extensions():
    assert check_doc_references.looks_like_path_reference("docs/attack-guide.md")
    assert check_doc_references.looks_like_path_reference("scripts/setup.sh")


def test_looks_like_path_reference_rejects_non_paths():
    assert not check_doc_references.looks_like_path_reference("v1.12")
    assert not check_doc_references.looks_like_path_reference("HARBOR_PASS")
    assert not check_doc_references.looks_like_path_reference("https://example.com/foo.md")
    assert not check_doc_references.looks_like_path_reference("two words.md")


def test_bullet_pattern_matches_bold_backtick_bullets():
    line = "- **`docs/attack-guide.md`** – Full attack-chain walkthrough for this lab"
    match = check_doc_references.BULLET_PATTERN.match(line)
    assert match is not None
    assert match.group(1) == "docs/attack-guide.md"


def test_bullet_pattern_ignores_plain_bullets():
    line = "- Just a plain bullet with `some/code.py` mentioned mid-sentence"
    assert check_doc_references.BULLET_PATTERN.match(line) is None


def test_table_pattern_matches_first_cell_backtick_filename():
    line = "| `docs/attack-guide.md` | Full attack-chain walkthrough for this lab |"
    match = check_doc_references.TABLE_PATTERN.match(line)
    assert match is not None
    assert match.group(1) == "docs/attack-guide.md"


def test_table_pattern_ignores_non_leading_backtick_cells():
    line = "| Attack Guide | see `docs/attack-guide.md` |"
    assert check_doc_references.TABLE_PATTERN.match(line) is None


def test_resolves_somewhere_finds_suffix_match_across_labs(tmp_path):
    # Simulate the repo's real convention: a parent README references
    # `docs/attack-guide.md` in shorthand, and it should resolve against
    # any lab that actually has that file, not just a literal sibling path.
    referencing_file = tmp_path / "labs" / "security" / "README.md"
    referencing_file.parent.mkdir(parents=True)
    referencing_file.write_text("placeholder")

    real_file = tmp_path / "labs" / "security" / "ad-pentest" / "docs" / "attack-guide.md"
    real_file.parent.mkdir(parents=True)
    real_file.write_text("placeholder")

    repo_files = [real_file]
    assert check_doc_references.resolves_somewhere("docs/attack-guide.md", referencing_file, repo_files)


def test_resolves_somewhere_returns_false_for_missing_file(tmp_path):
    referencing_file = tmp_path / "labs" / "security" / "README.md"
    referencing_file.parent.mkdir(parents=True)
    referencing_file.write_text("placeholder")

    repo_files = []
    assert not check_doc_references.resolves_somewhere("docs/network-map.md", referencing_file, repo_files)


def test_find_dangling_references_flags_missing_bullet_target(tmp_path):
    md_file = tmp_path / "README.md"
    md_file.write_text("- **`docs/network-map.md`** – Network topology and host details.\n")

    problems = check_doc_references.find_dangling_references(md_file, repo_files=[], verbose=False)
    assert len(problems) == 1
    assert "docs/network-map.md" in problems[0]


def test_find_dangling_references_ignores_inline_code_in_prose(tmp_path):
    md_file = tmp_path / "guide.md"
    md_file.write_text(
        "This tutorial creates a file called `app.py` and a `docker-compose.yml`\n"
        "as worked examples — neither exists in this repository.\n"
    )

    problems = check_doc_references.find_dangling_references(md_file, repo_files=[], verbose=False)
    assert problems == []


def test_main_passes_on_real_repo(monkeypatch, capsys):
    monkeypatch.setattr(sys, "argv", ["check_doc_references.py"])
    exit_code = check_doc_references.main()
    out = capsys.readouterr().out
    assert exit_code == 0, out
    assert "PASS" in out
