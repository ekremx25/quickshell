import QtQuick
import QtTest
import "../Modules/bar/BarDefaults.js" as BarDefaults

TestCase {
    name: "BarDefaults"

    function test_workspaces_hasRequiredKeys() {
        var w = BarDefaults.createWorkspacesConfig();
        verify(w.format !== undefined);
        verify(w.style !== undefined);
        verify(typeof w.transparent === "boolean");
        compare(w.displayMode, "role");
        verify(typeof w.workspaceCount === "number");
        verify(typeof w.showEmpty === "boolean");
        verify(typeof w.showSpecial === "boolean");
        verify(typeof w.showApps === "boolean");
        verify(typeof w.groupApps === "boolean");
        verify(typeof w.scrollEnabled === "boolean");
        verify(typeof w.wrapAround === "boolean");
        verify(typeof w.reverseScroll === "boolean");
        verify(typeof w.iconSize === "number");
        verify(typeof w.maxIcons === "number");
    }

    function test_workspaces_normalizesInvalidValues() {
        var w = BarDefaults.normalizeWorkspacesConfig({
            format: "invalid",
            displayMode: "invalid",
            workspaceCount: 99,
            iconSize: 2,
            maxIcons: "7",
            showApps: "yes"
        });

        compare(w.format, "roman");
        compare(w.displayMode, "role");
        compare(w.workspaceCount, 20);
        compare(w.iconSize, 10);
        compare(w.maxIcons, 7);
        compare(w.showApps, true);
    }

    function test_workspaces_preservesSupportedValues() {
        var w = BarDefaults.normalizeWorkspacesConfig({
            format: "arabic",
            style: "dot",
            displayMode: "occupied",
            workspaceCount: 8,
            showEmpty: false,
            reverseScroll: true
        });

        compare(w.format, "arabic");
        compare(w.style, "dot");
        compare(w.displayMode, "occupied");
        compare(w.workspaceCount, 8);
        compare(w.showEmpty, false);
        compare(w.reverseScroll, true);
    }

    function test_workspaces_returnsFreshObject() {
        var a = BarDefaults.createWorkspacesConfig();
        var b = BarDefaults.createWorkspacesConfig();
        a.format = "mutated";
        compare(b.format, "roman", "second call must not see mutations to first");
    }

    function test_barConfig_hasZones() {
        var c = BarDefaults.createBarConfig();
        verify(Array.isArray(c.left));
        verify(Array.isArray(c.center));
        verify(Array.isArray(c.right));
        verify(Array.isArray(c.inactive));
    }

    function test_barConfig_hasWorkspacesAndPosition() {
        var c = BarDefaults.createBarConfig();
        verify(c.workspaces !== undefined);
        compare(c.barPosition, "top");
    }

    function test_barConfig_returnsFreshObject() {
        var a = BarDefaults.createBarConfig();
        var b = BarDefaults.createBarConfig();
        a.left.push("Mutated");
        compare(b.left.indexOf("Mutated"), -1, "second call must not see mutations to first");
    }

    function test_barConfig_workspacesAreFresh() {
        var a = BarDefaults.createBarConfig();
        var b = BarDefaults.createBarConfig();
        a.workspaces.format = "mutated";
        compare(b.workspaces.format, "roman");
    }

    function test_clone_deepCopy() {
        var src = { a: 1, nested: { b: 2, arr: [3, 4] } };
        var copy = BarDefaults.clone(src);
        copy.nested.b = 99;
        copy.nested.arr.push(99);
        compare(src.nested.b, 2);
        compare(src.nested.arr.length, 2);
    }

    function test_clone_array() {
        var src = ["Launcher", "Calendar"];
        var copy = BarDefaults.clone(src);
        copy.push("Mutated");
        compare(src.length, 2);
    }

    function test_clone_primitive() {
        compare(BarDefaults.clone(42), 42);
        compare(BarDefaults.clone("hello"), "hello");
        compare(BarDefaults.clone(true), true);
    }
}
