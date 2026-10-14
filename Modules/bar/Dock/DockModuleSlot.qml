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

    width: loader.item ? Math.max(loader.item.implicitWidth, loader.item.width) : iconSize * dockScale
    height: Math.max((iconSize + 8) * dockScale, loader.item ? Math.max(loader.item.implicitHeight, loader.item.height) : 0)

    Loader {
        id: loader
        active: true
        sourceComponent: slot.moduleMap[slot.modelData] || null
        anchors.centerIn: parent
    }
}
