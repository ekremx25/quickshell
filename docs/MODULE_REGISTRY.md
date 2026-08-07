# Module Registry

The bar and dock use a two-part module architecture:

- [`ModuleRegistry.js`](../Modules/bar/ModuleRegistry.js) is the source of truth for identity, metadata, capabilities, aliases and layout policy.
- [`ModuleCatalog.qml`](../Modules/bar/ModuleCatalog.qml) owns the actual QML `Component` objects and injects runtime context.

Keeping these responsibilities separate lets settings pages inspect every module without constructing UI objects or starting their services.

## Registry contract

Every registry entry has these fields:

| Field | Purpose |
|---|---|
| `id` | Stable kebab-case identifier. It must not change when the display name changes. |
| `name` | Canonical name stored in layout configuration. |
| `component` | Human-readable component key used for diagnostics. |
| `icon`, `label`, `color` | Settings UI presentation metadata. |
| `description`, `category` | Discoverability and future module-browser metadata. |
| `placements` | Supported surfaces: `bar`, `dock`, or both. |
| `settingsPage` | Settings route associated with the module; empty when none exists. |
| `services` | Runtime dependencies, documented for diagnostics. |
| `contexts` | Values that `ModuleCatalog.qml` must inject into the component. |

`validateDefinitions()` checks the schema, stable IDs, duplicate names/components, colors, placements and alias targets. `ModuleCatalog.qml` additionally calls `validateCatalog()` at runtime, so a missing visual component is reported immediately in the Quickshell log.

## Layout policy and migration

All saved names pass through the registry before use:

- unknown or unsupported modules are removed;
- legacy aliases and stable IDs resolve to the canonical name;
- a module appears in at most one active zone;
- bar and dock lists preserve the user's order;
- newly registered modules automatically appear under **Inactive**;
- the legacy single dock `modules` list migrates to `leftModules` and `rightModules`.
- normalized bar and dock configs carry `moduleSchemaVersion` for future migrations.

Layout functions return only module-list fields. Callers merge those fields into the original configuration, so theme, sizing and unrelated user settings are never discarded by a migration.

## Adding a module

1. Create the module QML and its services in `Modules/bar/<ModuleName>/`.
2. Add one complete metadata entry to `_modules` in `ModuleRegistry.js`.
3. Import the module and add its `Component` to `componentMap` in `ModuleCatalog.qml`.
4. Put every required injected value in the registry entry's `contexts` list and wire it in the catalog component.
5. Run the registry and full QML test suites.

Do not add module allow-lists to `Bar.qml`, `Dock.qml`, `SettingsBackend.qml`, or `DockDataService.qml`. Placement and migration rules belong in the registry.

## Compatibility rules

- Increment `SCHEMA_VERSION` when the registry contract or saved layout semantics change.
- Prefer adding an alias when renaming a module. Keep aliases as long as an older config can exist.
- Never repurpose an existing `id` for a different module.
- Removing a module is safe for loading: stale config entries are ignored and the remaining order is retained.

## Verification

```bash
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/
qmllint Modules/bar/ModuleCatalog.qml Modules/bar/Settings/SettingsBackend.qml Modules/bar/Dock/DockDataService.qml
```

The pure-JavaScript tests cover schema validation, aliases, ID resolution, placement capabilities, deduplication, legacy migration and the catalog contract. A live Quickshell reload remains the integration check because the catalog imports Quickshell-specific modules unavailable to the standalone Qt test runner.
