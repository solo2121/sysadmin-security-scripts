# tools/lib — Shared CLI Utilities

Standard-library-only helper modules for the scripts under
[`tools/security/`](../security/) and [`tools/sysadmin/`](../sysadmin/).
Extracted so common concerns (argument parsing, logging, subprocess
execution, input validation, banners) aren't reimplemented slightly
differently in every tool.

This package performs **no** network scanning, exploitation, or
credential handling itself — it's plumbing that individual tools build
on top of.

## Modules

| Module | Purpose |
|---|---|
| [`cli.py`](cli.py) | `build_parser()` for consistent `-v/-q` flags and `--help` examples; `check_dependencies()` / `require_dependencies()` for Python-package and binary checks |
| [`logging.py`](logging.py) | `get_logger()` — colorized, idempotent logger setup |
| [`subprocess.py`](subprocess.py) | `run_command()` — safe (`shell=True`-free), timeout-bounded subprocess wrapper returning a structured `CommandResult` |
| [`validators.py`](validators.py) | IP/network/hostname/port validation and `parse_port_range()` |
| [`banner.py`](banner.py) | `render_banner()` — shared startup banner with the standard authorized-use notice |

## Requirements

- Python 3.12+
- No third-party dependencies (standard library only)

## Usage example

```python
from tools.lib.cli import build_parser, require_dependencies
from tools.lib.logging import get_logger
from tools.lib.validators import is_valid_target

parser = build_parser(
    "my-tool.py",
    "Short description of what this tool does.",
    epilog_examples=["python3 my-tool.py --target 10.0.0.0/24"],
)
parser.add_argument("--target", required=True)
args = parser.parse_args()

log = get_logger(__name__, verbose=args.verbose, quiet=args.quiet)

if not is_valid_target(args.target):
    log.error("Invalid target: %s", args.target)
    raise SystemExit(1)

require_dependencies(binaries=["nmap"])
log.info("Starting scan of %s", args.target)
```

## Testing

Unit tests live in [`tests/python/`](../../tests/python/):
`test_lib_cli.py`, `test_lib_subprocess.py`, `test_lib_validators.py`,
`test_lib_banner_and_logging.py`. Run with:

```bash
pytest tests/python/ -v -k lib
```

## Adopting this in an existing tool

This package is additive — existing tools in `tools/security/` and
`tools/sysadmin/` keep working unchanged. Adopt it incrementally when
you're already touching a tool for another reason:

1. Replace hand-rolled `argparse.ArgumentParser()` setup with
   `build_parser()`.
2. Replace `print()`-based status messages with a `get_logger()`
   instance.
3. Replace raw `subprocess.run(..., shell=True)` calls with
   `run_command()` (drop `shell=True` — pass args as a list).
4. Replace inline IP/port regex checks with `tools.lib.validators`.

Avoid large rewrites in a single PR — prefer one tool per change so
diffs stay reviewable.
