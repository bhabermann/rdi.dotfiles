# Repository Guidelines

## Project Structure & Module Organization
This repository is a Bash-based dotfiles system for WSL. Keep changes scoped to the component they affect.

- `setup`: main entrypoint (`install`, `verify`, `update`, `uninstall`)
- `scripts/`: top-level action scripts invoked by `setup`
- `lib/`: shared logic (common helpers, dependency DAG, rollback/import, action wrappers)
- Component installers: `docker-wsl/`, `update-corporate-ca/`, `git/`, `shell/`, `homebrew/`, `cli-tools/`, `dev-tools/`
- `dev-tools/config/versions.yaml`: managed tool/runtime versions
- `test-cycle.sh` and `Dockerfile.test`: installation cycle validation

## Build, Test, and Development Commands
Run from repo root in WSL Bash:

```bash
./setup install            # install default component set
./setup verify             # run smoke tests for installed components
./setup update             # update installed components
./setup uninstall          # interactive uninstall flow
./setup uninstall vfox     # uninstall a specific component
./test-cycle.sh            # install/uninstall/idempotency cycle test
```

Use `--verbose` when debugging (example: `./setup --verbose install`).

## Coding Style & Naming Conventions
- Shell scripts must start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- `.editorconfig` enforces UTF-8, LF, final newline, and **2-space indentation** for `*.sh`.
- Prefer small reusable functions in `lib/` over duplicating logic in component installers.
- Naming patterns:
  - Functions: `snake_case`
  - Script files: action-oriented kebab/snake style (for example `install-*.sh`, `update-corporate-ca`)

## Testing Guidelines
There is no unit-test framework here; validation is integration/smoke-test based.

- Primary check: `./setup verify`
- Regression cycle: `./test-cycle.sh`
- For risky installer changes, also validate in containerized flow using `Dockerfile.test`.

Include manual verification notes in PRs for cross-boundary behavior (WSL + Windows wrappers).

## Commit & Pull Request Guidelines
Follow the existing Conventional Commit style seen in history:
- `feat: ...`, `fix: ...`, `refactor: ...`, `docs: ...`, `test: ...`, `ci: ...`

PRs should include:
- clear summary of affected components/paths
- why the change is needed
- test evidence (command output summary, e.g., `./setup verify`, `./test-cycle.sh`)
- screenshots only when output/UI behavior in Windows terminals is relevant

Keep commits focused and avoid mixing unrelated component changes.
