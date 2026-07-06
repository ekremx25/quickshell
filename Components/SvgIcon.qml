pragma Singleton
import QtQuick
import Qt.labs.platform

QtObject {
    readonly property string basePath: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell/assets/icons/"

    // 注册图标值
    property string previous: basePath + "previous.svg"
    property string play: basePath + "play.svg"
    property string pause: basePath + "pause.svg"
    property string next: basePath + "next.svg"
}
