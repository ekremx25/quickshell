import QtQuick
import QtTest
import "../Modules/bar/ModuleRegistry.js" as ModuleRegistry

TestCase {
    name: "ModuleRegistry"

    function test_definitions_haveRequiredFields() {
        var definitions = ModuleRegistry.definitions();
        verify(definitions.length > 0);

        for (var i = 0; i < definitions.length; ++i) {
            var entry = definitions[i];
            verify(typeof entry.id === "string" && entry.id.length > 0);
            verify(typeof entry.name === "string" && entry.name.length > 0);
            verify(typeof entry.component === "string" && entry.component.length > 0);
            verify(typeof entry.icon === "string");
            verify(typeof entry.label === "string" && entry.label.length > 0);
            verify(typeof entry.description === "string" && entry.description.length > 0);
            verify(typeof entry.category === "string" && entry.category.length > 0);
            verify(typeof entry.color === "string" && entry.color.length > 0);
            verify(Array.isArray(entry.placements));
            verify(entry.placements.length > 0);
            verify(typeof entry.settingsPage === "string");
            verify(Array.isArray(entry.services));
            verify(Array.isArray(entry.contexts));
        }
    }

    function test_schemaAndDefinitionsValidate() {
        compare(ModuleRegistry.schemaVersion(), 1);
        var report = ModuleRegistry.validateDefinitions();
        verify(report.valid, report.errors.join("\n"));
        compare(report.errors.length, 0);
        compare(report.count, ModuleRegistry.allNames().length);
    }

    function test_names_areUnique() {
        var names = ModuleRegistry.allNames();
        var ids = ModuleRegistry.allIds();
        compare(names.length, ids.length);
        var seen = ({});
        for (var i = 0; i < names.length; ++i) {
            verify(!seen[names[i]], "Duplicate module name: " + names[i]);
            seen[names[i]] = true;
        }

        seen = ({});
        for (var j = 0; j < ids.length; ++j) {
            verify(!seen[ids[j]], "Duplicate module id: " + ids[j]);
            seen[ids[j]] = true;
        }
    }

    function test_components_areUnique() {
        var definitions = ModuleRegistry.definitions();
        var seen = ({});
        for (var i = 0; i < definitions.length; ++i) {
            var component = definitions[i].component;
            verify(!seen[component], "Duplicate component key: " + component);
            seen[component] = true;
        }
    }

    function test_placements_areKnown() {
        var definitions = ModuleRegistry.definitions();
        for (var i = 0; i < definitions.length; ++i) {
            var placements = definitions[i].placements;
            for (var j = 0; j < placements.length; ++j) {
                verify(placements[j] === "bar" || placements[j] === "dock");
            }
        }
    }

    function test_barAndDockCapabilities() {
        verify(ModuleRegistry.supportsPlacement("Calendar", "bar"));
        verify(ModuleRegistry.supportsPlacement("Calendar", "dock"));
        verify(ModuleRegistry.supportsPlacement("Workspaces", "bar"));
        verify(ModuleRegistry.supportsPlacement("Workspaces", "dock"));
        verify(ModuleRegistry.supportsPlacement("NightLight", "bar"));
        verify(!ModuleRegistry.supportsPlacement("NightLight", "dock"));
        verify(ModuleRegistry.supportsPlacement("Media", "dock"));
        verify(!ModuleRegistry.supportsPlacement("Media", "bar"));
    }

    function test_groupAssignmentUsesPlacementPolicy() {
        verify(ModuleRegistry.canAssignToGroup("Workspaces", "left"));
        verify(ModuleRegistry.canAssignToGroup("Workspaces", "dockRight"));
        verify(!ModuleRegistry.canAssignToGroup("Equalizer", "dockLeft"));
        verify(ModuleRegistry.canAssignToGroup("Equalizer", "inactive"));
        verify(!ModuleRegistry.canAssignToGroup("Unknown", "inactive"));
        verify(!ModuleRegistry.canAssignToGroup("Calendar", "unknown"));
    }

    function test_moduleInfoComesFromDefinitions() {
        var info = ModuleRegistry.moduleInfo();
        compare(info.Workspaces.label, "Workspaces");
        compare(info.Workspaces.settingsPage, "workspaces");
        verify(info.Workspaces.placements.indexOf("dock") !== -1);
        verify(info.Workspaces.services.indexOf("WorkspacesService") !== -1);
        compare(info.Media.component, "MediaWidget");
    }

    function test_legacyAliasIsCanonicalized() {
        compare(ModuleRegistry.canonicalName("RAM"), "RamModule");
        compare(ModuleRegistry.canonicalName("memory"), "RamModule");
        compare(ModuleRegistry.canonicalName("night-light"), "NightLight");
        compare(ModuleRegistry.canonicalName("Calendar"), "Calendar");
        compare(ModuleRegistry.canonicalName(null), "");
    }

    function test_normalizeNamesFiltersAndDeduplicates() {
        var normalized = ModuleRegistry.normalizeNames(
            ["Calendar", "Calendar", "RAM", "Unknown", "Media"],
            "bar"
        );
        compare(normalized.length, 2);
        compare(normalized[0], "Calendar");
        compare(normalized[1], "RamModule");
    }

    function test_normalizeNamesSharesSeenAcrossZones() {
        var seen = ({});
        var left = ModuleRegistry.normalizeNames(["Weather", "Calendar"], "dock", seen);
        var right = ModuleRegistry.normalizeNames(["Calendar", "Media"], "dock", seen);
        compare(left.length, 2);
        compare(right.length, 1);
        compare(right[0], "Media");
    }

    function test_normalizeZoneMapPreservesOrderAndDeduplicates() {
        var zones = ModuleRegistry.normalizeZoneMap({
            left: ["Calendar", "RAM", "Unknown"],
            right: ["Calendar", "Volume"]
        }, ["left", "right"], "bar");

        compare(zones.left.join(","), "Calendar,RamModule");
        compare(zones.right.join(","), "Volume");
    }

    function test_normalizeBarLayoutReservesDockModules() {
        var layout = ModuleRegistry.normalizeBarLayout({
            left: ["Calendar", "Calendar"],
            center: ["Workspaces"],
            right: ["Media"],
            inactive: ["RAM", "Unknown", "Equalizer"]
        }, ["Weather", "Workspaces"]);

        compare(layout.left.join(","), "Calendar");
        compare(layout.center.length, 0);
        compare(layout.right.length, 0);
        compare(layout.inactive[0], "RamModule");
        compare(layout.inactive[1], "Equalizer");
        verify(layout.inactive.indexOf("Weather") === -1);
        verify(layout.inactive.indexOf("Workspaces") === -1);
        verify(layout.inactive.indexOf("Media") !== -1);
    }

    function test_normalizeDockLayoutMigratesLegacyConfig() {
        var layout = ModuleRegistry.normalizeDockLayout({
            modules: ["Calendar", "Weather", "Launcher", "Media", "Calendar"]
        });

        compare(layout.leftModules.join(","), "Weather");
        compare(layout.rightModules.join(","), "Calendar,Media");
    }

    function test_definitionValidatorReportsBrokenSchema() {
        var broken = ModuleRegistry.definitions();
        broken[1].id = broken[0].id;
        broken[2].placements = ["desktop"];
        var report = ModuleRegistry.validateDefinitions(broken, {});

        verify(!report.valid);
        verify(report.errors.join("\n").indexOf("Duplicate module id") !== -1);
        verify(report.errors.join("\n").indexOf("unknown placement") !== -1);
    }

    function test_catalogContractReportsMissingAndUnknownEntries() {
        var catalog = ({});
        var names = ModuleRegistry.allNames();
        for (var i = 0; i < names.length; ++i) catalog[names[i]] = true;

        var healthy = ModuleRegistry.validateCatalog(catalog);
        verify(healthy.valid, healthy.errors.join("\n"));

        delete catalog.Calendar;
        catalog.Unregistered = true;
        var broken = ModuleRegistry.validateCatalog(catalog);
        verify(!broken.valid);
        verify(broken.errors.join("\n").indexOf("Calendar") !== -1);
        verify(broken.warnings.join("\n").indexOf("Unregistered") !== -1);
    }

    function test_returnedDefinitionsAreCloned() {
        var first = ModuleRegistry.definitions();
        first[0].name = "Changed";
        first[0].placements.push("invalid");

        var second = ModuleRegistry.definitions();
        compare(second[0].name, "Launcher");
        verify(second[0].placements.indexOf("invalid") === -1);
    }
}
