import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

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
        command: ["python3", Qt.resolvedUrl("backend.py").toString().replace("file://", "")]
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
                x: implicitWidth - root.config.display.item_width

                // Position dynamique selon config.display.position
                anchors {
                    // Vertical positioning
                    top: (root.config.display.position === "top") ? parent.top : undefined
                    topMargin: (root.config.display.position === "top")
                        ? (root.launcherVisible ? 40 : height)
                        : root.config.display.item_width

                    bottom: (root.config.display.position === "bottom") ? parent.bottom : undefined
                    bottomMargin: (root.config.display.position === "bottom")
                        ? (root.launcherVisible ? 10 : -height)
                        : 0

                    left: (root.config.display.position === "left") ? parent.left : undefined
                    leftMargin: (root.config.display.position === "left")
                        ? (root.launcherVisible ? 10 : -100)
                        : x + root.config.display.item_width

                    right: (root.config.display.position === "right") ? parent.right : undefined
                    rightMargin: (root.config.display.position === "right")
                        ? (root.launcherVisible ? 10 : height)
                        : x

                    verticalCenter: (root.config.display.position === "center" ||
                                    root.config.display.position === "left" ||
                                    root.config.display.position === "right")
                        ? parent.verticalCenter
                        : undefined

                    

                    horizontalCenter: (root.config.display.position === "center" ||
                                      root.config.display.position === "top" ||
                                      root.config.display.position === "bottom")
                        ? parent.horizontalCenter
                        : undefined
                }

                visible: true  // Always visible but animated
                opacity: root.launcherVisible ? 1.0 : 0.0

                // Animations avec transitions fluides
                Behavior on anchors.bottomMargin {
                    NumberAnimation {
                        duration: root.config.animations.duration_ms
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on anchors.topMargin {
                    NumberAnimation {
                        duration: root.config.animations.duration_ms
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on anchors.leftMargin {
                    NumberAnimation {
                        duration: root.config.animations.duration_ms
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on anchors.rightMargin {
                    NumberAnimation {
                        duration: root.config.animations.duration_ms
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.config.animations.duration_ms
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
        configProcess.running = true;
        console.log("Game Launcher initialized - Loading configuration...");
    }
}
