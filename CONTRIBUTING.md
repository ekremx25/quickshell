# Contributing

Thanks for taking the time to look at this project. This document covers the workflow for bug reports, feature requests, and code contributions.

## Quick links

- **Bug reports** — open a [bug report](../../issues/new?template=bug_report.yml).
- **Feature requests** — open a [feature request](../../issues/new?template=feature_request.yml).
- **Discussions / questions** — use [GitHub Discussions](../../discussions) instead of issues.

## Reporting bugs

Before opening a bug report, please:

1. Run the latest `main` — `git pull && reload quickshell` — issues against older revisions are usually not actionable.
2. Search [existing issues](../../issues?q=is%3Aissue) to avoid duplicates.
3. Make sure the minimum dependencies are installed (see [README — Dependencies](README.md#dependencies)).
4. Capture the relevant log output:
   ```bash
   cat /run/user/$(id -u)/quickshell/by-pid/$(pgrep -x quickshell)/log.log | tail -50
   ```

A good bug report includes:

- Compositor and version (`niri --version`, `hyprctl version`, etc.)
- Quickshell version (`pacman -Qi quickshell` or git commit if built from source)
- Steps to reproduce, expected behaviour, actual behaviour
- Relevant log lines or screenshots

## Suggesting features

Open a [feature request issue](../../issues/new?template=feature_request.yml) and describe:

- The use case (what are you trying to do?)
- The proposed UX (where in the shell, how does it integrate?)
- Whether it should be cross-compositor or compositor-specific

Large features benefit from a quick design discussion in [Discussions](../../discussions) before opening a PR.

## Code contributions

### Setup

```bash
git clone https://github.com/ekremx25/quickshell ~/quickshell-dev
cd ~/quickshell-dev
# Either symlink or set XDG_CONFIG_HOME to test:
QS_CONFIG_HOME="$PWD" quickshell
```

Install the dependencies listed in the [README](README.md#dependencies). For test infrastructure additionally install:

```bash
sudo pacman -S qt6-declarative   # provides qmltestrunner
```

### Project layout

```
shell.qml                     Entry point (staged loader)
Services/                     Singletons (NightLight, CompositorService, ...)
Services/core/                Reusable atomic-write / data-store / file-watch
Modules/bar/                  Bar modules (Workspaces, Volume, Notifications, ...)
Modules/bar/Settings/         Settings dashboard pages
Modules/bar/System/           System pages (Monitors, Network, Bluetooth, ...)
Modules/OSD/                  Volume / brightness OSD
Widgets/                      Shared widgets (Theme, FilePicker)
Components/                   Tiny reusable QML components
scripts/                      Helper bash scripts
tests/                        Unit tests for pure-JS modules
```

See [README — Architecture](README.md#architecture) for more.

### Code style

- **Language** — comments, log messages, and UI strings are written in **English only** (this is a public repo).
- **QML** — 4-space indentation, `lowerCamelCase` for properties and ids, `UpperCamelCase` for type names and Components. Keep top-level files focused; if a file exceeds ~500 lines, split it into sub-components in the same directory.
- **JS modules** — `.pragma library` at the top, no `console.log` (use `Services/core/Log.js` instead), pure functions where possible (no QML/Process side effects).
- **Bash** — `set -euo pipefail`, `shellcheck`-clean, prefer argv arrays over `sh -c` interpolation.
- **Persistence** — never write config files directly; route through `Services/core/JsonDataStore.qml` or `TextDataStore.qml` so writes stay atomic.

### Adding a bar module

1. Create `Modules/bar/MyModule/MyModule.qml` (top-level visible widget).
2. Register the module in `Modules/bar/Bar.qml`'s `moduleMap` and `Component` block.
3. Register display metadata in `Modules/bar/Settings/SettingsBackend.qml` — `moduleInfo`, `barPlacementNames`, `allModuleNames` (so it appears in the Settings drag-drop picker).
4. Persist any state via a dedicated `<name>_config.json` and `Core.JsonDataStore`. Add the path to the [README — Configuration](README.md#configuration) table.
5. Add an entry to `Modules/bar/Settings/Settings.qml` if your module needs its own Settings page.

### Adding a Settings page

1. Create `Modules/bar/System/MyPage.qml` (model the structure on `LockPage.qml` or `NightLightPage.qml`).
2. Add a sidebar item to `menuCategories` in `Settings.qml`.
3. Add the page container under the existing `Sys.NightLightPage { ... }` style block, with `visible: settingsPopup.currentPage === "myKey"`.

### Tests

Pure-JS modules under `tests/` are runnable with:

```bash
qmltestrunner -input tests/
```

Add a new test by creating `tests/tst_<name>.qml` — see [tests/README.md](tests/README.md) for the convention.

### Commits

- Use the imperative mood — "Add X", "Fix Y", "Refactor Z" (not "Added", "Fixed").
- Keep the subject line under 72 characters; describe motivation in the body.
- One logical change per commit. Translation passes, refactors, and new features should each be separate commits where possible.

### Pull requests

- Fork, branch, push, open a PR against `main`.
- Reference the issue you're addressing if any (`Fixes #123`).
- Include a test plan checklist (what compositor(s) you tested on, what visible behaviour you verified).
- Be patient — this is a personal project maintained on the side.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE) of this project.
