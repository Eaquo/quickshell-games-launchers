import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import "./modules/"

ShellRoot {
    id: root

    property var config: ({
        display: {
            position: "bottom",
            orientation: "horizontal",
            grid_size: [4, 1],
            item_width: 500,
            item_height: 300,
            spacing: 20
        },
        appearance: {
            use_wallust: true,
            blur_background: true,
            background_opacity: 0.85
        },
        behavior: {
            close_on_launch: true
        },
        animations: {
            enabled: true,
            duration_ms: 300
        }
    })

    property bool launcherVisible: true  // Visible for testing - TODO: add IPC toggle

    // Load config from backend
    Process {
        id: configProcess
        command: ["python3", Qt.resolvedUrl("modules/service/backend.py").toString().replace("file://", "")]
        running: false

        property string output: ""

        stdout: SplitParser {
            onRead: data => configProcess.output += data
        }

        onExited: {
            try {
                const result = JSON.parse(configProcess.output);
                if (result.config) {
                    root.config = result.config;
                    console.log("Config loaded:", JSON.stringify(result.config.display));
                }
            } catch (e) {
                console.error("Failed to parse config:", e);
            }
            configProcess.output = "";
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: launcherWindow
            property var modelData

            screen: modelData
            exclusionMode: ExclusionMode.Ignore
            visible: root.launcherVisible
            color: "transparent"

            implicitWidth: screen.width
            implicitHeight: screen.height
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Root item to capture keyboard events
            Item {
                id: rootItem
                anchors.fill: parent
                focus: true

                Component.onCompleted: rootItem.forceActiveFocus()


                // Dim background overlay
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: root.launcherVisible ? 0.6 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // root.launcherVisible = false
                            // rootItem.forceActiveFocus()
                            onClosing: Qt.quit()
                        }
                    }
                }

                GameLauncher {
                    id: launcher
                    config: root.config
                    screenW: launcherWindow.screen.width
                    screenH: launcherWindow.screen.height

                    x: {
                        const pos = root.config.display.position
                        const sw  = launcherWindow.screen.width
                        if (launcher.bigPictureMode)  return 0
                        if (pos === "left")            return root.launcherVisible ? 10 : -width
                        if (pos === "right")           return root.launcherVisible ? sw - width - 10 : sw
                        return (sw - width) / 2   // center | top | bottom
                    }

                    y: {
                        const pos = root.config.display.position
                        const sh  = launcherWindow.screen.height
                        const mid = (sh - height) / 2
                        if (launcher.bigPictureMode)  return 0
                        if (pos === "top")             return root.launcherVisible ? 10 : -height
                        if (pos === "bottom")          return root.launcherVisible ? sh - height - 10 : sh
                        return mid   // left | right | center
                    }

                    visible: true
                    opacity: root.launcherVisible ? 1.0 : 0.0

                    Behavior on x       { NumberAnimation { duration: root.config.animations.duration_ms; easing.type: Easing.OutCubic } }
                    Behavior on y       { NumberAnimation { duration: root.config.animations.duration_ms; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: root.config.animations.duration_ms; easing.type: Easing.OutCubic } }

                    onCloseRequested: root.launcherVisible = false
                }  // End GameLauncher
            }  // End rootItem
        }  // End PanelWindow
    }  // End Variants

    Component.onCompleted: {
        configProcess.running = true;
        console.log("Game Launcher initialized - Loading configuration...");
    }
}
