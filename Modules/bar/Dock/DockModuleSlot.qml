import QtQuick

// Loader slot used to render a module (Weather, Volume, Tray, ...) inside
// the dock row. The Repeater's string element is auto-bound via the required
// `modelData` property.
Item {
    id: slot

    required property string modelData
    required property var moduleMap
    required property real dockScale
    required property real iconSize

    width: loader.item ? loader.item.implicitWidth : iconSize * dockScale
    height: (iconSize + 8) * dockScale

    Loader {
        id: loader
        active: true
        sourceComponent: slot.moduleMap[slot.modelData] || null
        anchors.centerIn: parent
    }
}
