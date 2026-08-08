# =============================================================================
# Makefile — security-engineering-lab developer convenience wrapper
# =============================================================================
# These targets wrap the existing tooling documented in CONTRIBUTING.md and
# used in .github/workflows/ci.yml. They do not change project behavior —
# each target simply runs the same commands a contributor would run by hand.
#
# Requires: pip install -r requirements-dev.txt
# =============================================================================

.PHONY: help lint test validate validate-repo security docs docs-refs coverage prereq format typecheck

help:
	@echo "Available targets:"
	@echo "  make lint          - shellcheck (errors) + flake8 (informational)"
	@echo "  make format        - ruff check + black --check (informational, opt-in)"
	@echo "  make typecheck     - mypy (informational, opt-in)"
	@echo "  make test          - run pytest and bats unit test suites"
	@echo "  make coverage      - run pytest with coverage report"
	@echo "  make validate      - vagrant validate on all three lab Vagrantfiles"
	@echo "  make validate-repo - repository structure/docs/Vagrantfile health check (scripts/validate_lab.py)"
	@echo "  make security      - bandit (informational) + detect-secrets scan"
	@echo "  make docs          - markdown link check across the repo"
	@echo "  make docs-refs     - catch dangling filenames in doc index bullets/tables (scripts/check_doc_references.py)"
	@echo "  make prereq        - run scripts/check-prerequisites.sh"

lint:
	@echo "==> shellcheck (errors only)"
	@find . -name "*.sh" -not -path "./.git/*" -print0 | \
		xargs -0 -n1 shellcheck --severity=error \
		--exclude=SC1091,SC2086,SC2034,SC2155,SC2164,SC2181,SC2207
	@echo "==> flake8 (informational)"
	@flake8 --max-line-length=120 \
		--extend-ignore=E501,W503,E302,E303,W291,W293,E711,E712,E128,W292,F401,E722,F811,E305 \
		--exclude=.git,__pycache__ $$(find . -name "*.py" -not -path "./.git/*") || true

format:
	@echo "==> ruff check (informational)"
	@ruff check . || true
	@echo "==> black --check (informational)"
	@black --check . || true

typecheck:
	@echo "==> mypy (informational — opt-in, not yet enforced repo-wide)"
	@mypy tools/lib || true

test:
	@echo "==> pytest"
	pytest tests/python/ -v
	@echo "==> bats"
	bats tests/bash/

coverage:
	@echo "==> pytest with coverage (minimum 80%, matches CI)"
	pytest tests/python/ -v --cov=. --cov-report=term-missing --cov-fail-under=80

validate:
	@echo "==> vagrant validate (ad-pentest)"
	cd labs/security/ad-pentest && vagrant validate
	@echo "==> vagrant validate (ad-pentest-vlan)"
	cd labs/security/ad-pentest-vlan && vagrant validate
	@echo "==> vagrant validate (devops-linux-lab)"
	cd labs/infrastructure/devops-linux-lab && vagrant validate

validate-repo:
	@echo "==> repository health validation (scripts/validate_lab.py)"
	python3 scripts/validate_lab.py

security:
	@echo "==> bandit (informational only — see SECURITY.md for intentional findings)"
	@bandit --recursive --severity-level medium --confidence-level medium \
		--exclude ./.git --format txt $$(find . -name "*.py" -not -path "./.git/*") || true
	@echo "==> detect-secrets scan"
	detect-secrets scan --baseline .secrets.baseline

docs:
	@echo "==> markdown-link-check (informational only)"
	@find . -name "*.md" -not -path "./.git/*" -print0 | \
		xargs -0 -n1 -I{} markdown-link-check --config .markdown-link-check.json {} || true

docs-refs:
	@echo "==> doc reference check (blocks — catches dangling filenames markdown-link-check can't see)"
	python3 scripts/check_doc_references.py

prereq:
	./scripts/check-prerequisites.sh
