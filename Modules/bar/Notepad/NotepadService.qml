import QtQuick
import Qt.labs.platform
import Quickshell
import "../../../Services/core" as Core

Item {
    id: service
    visible: false
    width: 0
    height: 0

    readonly property string configPath: Core.PathService.configPath("notes.txt")
    property string text: ""

    function load() {
        fileStore.read();
    }

    function queueSave(nextText) {
        text = nextText;
        saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 1000
        repeat: false
        onTriggered: {
            fileStore.write(service.text);
        }
    }

    Component.onCompleted: load()

    Core.TextDataStore {
        id: fileStore
        path: service.configPath
        onLoaded: text => { service.text = text; }
    }
}
