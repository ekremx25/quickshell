import QtQuick
import "."

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string path: ""
    property var defaultValue: ({})
    property var value: ({})
    property string rawText: ""

    // Schema versioning:
    // - schemaVersion: the version number this store expects (default 0 = unversioned)
    // - migrate(data, fromVersion): override to convert older configs to the current schema.
    //   Example:
    //     schemaVersion: 2
    //     function migrate(data, from) {
    //         if (from < 1) data.newField = "default";
    //         if (from < 2) data.renamedField = data.oldField; delete data.oldField;
    //         return data;
    //     }
    property int schemaVersion: 0

    function migrate(data, fromVersion) {
        // Subclasses should override. Default: no transformation.
        return data;
    }

    // Validates the loaded data. Returns a corrected copy if invalid values are found.
    // Subclasses can override:
    //   function validate(data) {
    //       if (data.timeout < 0) data.timeout = 0;
    //       if (data.timeout > 3600) data.timeout = 3600;
    //       return data;
    //   }
    function validate(data) {
        return data;
    }

    signal loadedValue(var value, string rawText)
    signal savedValue(var value)
    signal failed(string phase, int exitCode, string details)

    function cloneValue(source) {
        try {
            return JSON.parse(JSON.stringify(source));
        } catch (e) {
            return source;
        }
    }

    function load() {
        textStore.read();
    }

    function save(nextValue) {
        root.value = nextValue;
        root.rawText = JSON.stringify(nextValue, null, 2);
        textStore.write(root.rawText);
    }

    TextDataStore {
        id: textStore
        path: root.path
        onLoaded: text => {
            root.rawText = text;
            if (text.trim().length === 0) {
                root.value = root.cloneValue(root.defaultValue);
                root.loadedValue(root.value, root.rawText);
                return;
            }

            try {
                var parsed = JSON.parse(text);

                // Schema version check: if the config's version is below our expectation, migrate it.
                var fileVersion = (typeof parsed._schemaVersion === "number") ? parsed._schemaVersion : 0;
                if (root.schemaVersion > 0 && fileVersion < root.schemaVersion) {
                    parsed = root.migrate(parsed, fileVersion);
                    parsed._schemaVersion = root.schemaVersion;
                    // Persist the migration result to disk immediately.
                    root.rawText = JSON.stringify(parsed, null, 2);
                    textStore.write(root.rawText);
                }

                root.value = root.validate(parsed);
                root.loadedValue(root.value, root.rawText);
            } catch (e) {
                // Parse error: fall back to default, emit failure signal with the path for context.
                root.value = root.cloneValue(root.defaultValue);
                root.failed("parse", -1, String(e) + " [path=" + root.path + "]");
                root.loadedValue(root.value, root.rawText);
            }
        }
        onSaved: {
            root.savedValue(root.value);
        }
        // Attach the file path to read/write errors so logs immediately reveal
        // which config file is misbehaving.
        onFailed: (phase, exitCode, details) => {
            const info = details.length > 0
                ? details + " [path=" + root.path + "]"
                : "[path=" + root.path + "]";
            root.failed(phase, exitCode, info);
        }
    }
}
