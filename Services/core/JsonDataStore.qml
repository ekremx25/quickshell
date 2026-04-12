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
                root.value = JSON.parse(text);
                root.loadedValue(root.value, root.rawText);
            } catch (e) {
                // Parse hatası: default değeri kullan, hata sinyalini path ile birlikte ilet
                root.value = root.cloneValue(root.defaultValue);
                root.failed("parse", -1, String(e) + " [path=" + root.path + "]");
                root.loadedValue(root.value, root.rawText);
            }
        }
        onSaved: {
            root.savedValue(root.value);
        }
        // Okuma/yazma hatasına dosya yolunu ekle; loglarda hangi config
        // dosyasının sorun çıkardığı anında görünür hale gelir.
        onFailed: (phase, exitCode, details) => {
            const info = details.length > 0
                ? details + " [path=" + root.path + "]"
                : "[path=" + root.path + "]";
            root.failed(phase, exitCode, info);
        }
    }
}
