# Tools

Standalone scripts and utilities that are useful on their own, independent of any specific lab environment under `labs/`. Each subfolder has its own README with a full directory map and usage notes.

| Directory | Contents |
|-----------|----------|
| [`security/`](security/README.md) | Reconnaissance, network analysis, exploitation, audit, and wireless security scripts for authorized lab use |
| [`sysadmin/`](sysadmin/README.md) | Linux administration scripts for monitoring, hardening, and day-2 operations utilities |
| [`lib/`](lib/README.md) | Shared, standard-library-only CLI utilities (argparse scaffolding, logging, safe subprocess execution, input validation, banners) used by scripts in `security/` and `sysadmin/` |

## Contributing

New tools should go under the subfolder that matches their purpose (`security/` or `sysadmin/`), in the most specific existing category directory. If a script doesn't fit an existing category, propose a new one in your pull request rather than adding a flat file at the top level — see [`CONTRIBUTING.md`](../CONTRIBUTING.md).
