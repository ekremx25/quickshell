# Tests

Unit tests for the pure-JavaScript modules under `Modules/` and `Services/`.

## Running

```bash
/usr/lib/qt6/bin/qmltestrunner -input tests/
```

> **Note:** the unversioned `qmltestrunner` on PATH is the Qt 5 binary on Arch
> (provided by `qt5-declarative`), which rejects Qt 6 imports. Always use the
> Qt 6 path explicitly. For a shorter command, alias it:
>
> ```bash
> alias qts='QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner'
> ```

Single file:

```bash
/usr/lib/qt6/bin/qmltestrunner tests/tst_MonitorLayoutLogic.qml
```

## Requirements

- `qt6-declarative` (provides `/usr/lib/qt6/bin/qmltestrunner`)

## Conventions

- One test file per module: `tests/tst_<ModuleName>.qml`.
- Imports follow the relative path from `tests/` to the module under test.
- Each test case maps to one `function test_<scenario>()`.
- Helper functions go above the `function test_*` definitions.
- Use `compare()` for equality, `verify()` for booleans, `fuzzyCompare()` for floats.

## Coverage scope

These tests cover **pure JavaScript** modules — functions that take inputs and
return values without touching QML, Process, or singletons. They are fast,
deterministic, and CI-friendly. UI behaviour (drag-drop, popovers, animations)
is intentionally out of scope for unit tests; if you need to verify visible
behaviour, do it manually and document it in your PR's test plan.
