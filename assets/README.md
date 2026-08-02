# Assets

Images and diagrams referenced from the repository's documentation (root `README.md`, `docs/`, and lab-specific docs).

## Categories

| Directory | Contents | Status |
|-----------|----------|--------|
| [`diagrams/`](diagrams/) | Architecture and topology diagrams (e.g. `architecture-overview.png`) used in the root `README.md` and `docs/architecture/` | Active |

The categories below aren't present yet, but are the expected homes for these
asset types if/when they're added — create the subfolder at that point rather
than ahead of time:

| Directory | Would contain |
|-----------|---------------|
| `screenshots/` | Terminal, dashboard, or UI captures illustrating a lab in a running state (e.g. Grafana dashboards, Jenkins pipelines) |
| `icons/` | Small UI/status icons referenced from documentation tables |
| `banners/` | Wide promotional or section-header images (e.g. for the top of long guides) |
| `logos/` | Project or third-party tool logos used for attribution in docs |

## Contributing

- Keep images in the subfolder that matches their type (e.g. `diagrams/` for architecture/topology diagrams). If you're adding a different kind of asset that doesn't fit an existing subfolder, create a new one that matches one of the categories above rather than dropping files at the top level.
- Use descriptive, kebab-case filenames (e.g. `architecture-overview.png`, not `image1.png`).
- Prefer PNG for diagrams and screenshots; keep files reasonably sized (compress before committing).
- Reference images from Markdown with paths relative to the referencing file, e.g. from the root `README.md`: `` ![Architecture](assets/diagrams/architecture-overview.png) ``.
