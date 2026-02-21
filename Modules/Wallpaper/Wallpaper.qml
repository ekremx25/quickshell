import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../Services"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        bottom: true
        right: true
    }

    // Set to the lowest layer to act as the desktop background
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal

    property string currentWallpaper: ""
    
    // We use two images to cross-fade
    property bool flip: false

    Process {
        id: wallpaperFetch
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/get-active-wallpaper.sh"]
        property string rawOutput: ""
        
        stdout: SplitParser {
            onRead: (data) => wallpaperFetch.rawOutput += data
        }
        
        onExited: {
            var newWall = wallpaperFetch.rawOutput.trim();
            wallpaperFetch.rawOutput = ""
            
            if (newWall !== "" && newWall !== root.currentWallpaper) {
                root.currentWallpaper = newWall;
                
                // Cross fade logic
                if (flip) {
                    img2.source = "file://" + newWall
                    img2.opacity = 1
                    img1.opacity = 0
                } else {
                    img1.source = "file://" + newWall
                    img1.opacity = 1
                    img2.opacity = 0
                }
                flip = !flip
            }
        }
    }

    // Trigger check periodically and on startup
    Timer {
        interval: 3000 // 3 seconds interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: wallpaperFetch.running = true
    }
    
    // The background color behind the image in case of loading
    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    Image {
        id: img1
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: ""
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 1000; easing.type: Easing.InOutQuad } }
        asynchronous: true
        cache: true
    }

    Image {
        id: img2
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: ""
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 1000; easing.type: Easing.InOutQuad } }
        asynchronous: true
        cache: true
    }
}
