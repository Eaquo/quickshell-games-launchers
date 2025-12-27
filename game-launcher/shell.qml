import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    property var config: ({
        display: {
            position: "",
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
                    onClicked: root.launcherVisible = false
                }
            }

            // Main launcher
            GameLauncher {
                id: launcher
                config: root.config

                // Position en bas au centre
                anchors {
                    bottom: parent.bottom
                    bottomMargin: root.launcherVisible ? 10 : -height
                    horizontalCenter: parent.horizontalCenter
                }

                visible: true  // Always visible but animated
                opacity: root.launcherVisible ? 1.0 : 0.0

                // Animation de slide-up depuis le bas
                Behavior on anchors.bottomMargin {
                    NumberAnimation {
                        duration: config.animations.duration_ms
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: config.animations.duration_ms
                        easing.type: Easing.OutCubic
                    }
                }

                onCloseRequested: {
                    root.launcherVisible = false
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("Game Launcher initialized")
    }
}
