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

    // Daemon mode: start hidden. The process stays alive in the background
    // (config + games + cover textures preloaded) and SUPER+G just toggles
    // visibility over IPC — no cold start, no cover re-decode on each open.
    property bool launcherVisible: false
    property bool configPanelVisible: false
    property bool configLoaded: false

    // IPC: `qs -c game-launcher ipc call launcher toggle|show|hide`
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.launcherVisible = !root.launcherVisible }
        function show():   void { root.launcherVisible = true }
        function hide():   void { root.launcherVisible = false }
    }

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
                    root.configLoaded = true;
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

            // Only show on the monitor Hyprland currently has focused (the
            // "active" screen). Fall back to showing everywhere if Hyprland
            // hasn't reported a focused monitor yet.
            property bool onActiveScreen: {
                const fm = Hyprland.focusedMonitor
                if (!fm || !modelData) return true
                return fm.name === modelData.name
            }

            screen: modelData
            exclusionMode: ExclusionMode.Ignore
            visible: root.launcherVisible && onActiveScreen
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

                // Re-grab keyboard focus each time the launcher is shown again
                // (daemon mode: the window is only hidden, never destroyed).
                Connections {
                    target: root
                    function onLauncherVisibleChanged() {
                        if (root.launcherVisible)
                            Qt.callLater(launcher.forceActiveFocus)
                    }
                }

                // Invisible full-screen area — click outside hides the launcher
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.launcherVisible = false
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
                    opacity: (root.launcherVisible && root.configLoaded) ? 1.0 : 0.0

                    Behavior on x       { NumberAnimation { duration: root.config.animations.duration_ms; easing.type: Easing.OutCubic } }
                    Behavior on y       { NumberAnimation { duration: root.config.animations.duration_ms; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: root.config.animations.duration_ms; easing.type: Easing.OutCubic } }

                    onCloseRequested: root.launcherVisible = false
                    onOpenConfigRequested: {
                        root.configPanelVisible = true
                        configPanel.forceActiveFocus()
                    }
                }  // End GameLauncher

                // Config panel overlay — centered on screen
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: root.configPanelVisible ? 0.45 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.configPanelVisible = false
                            launcher.forceActiveFocus()
                        }
                    }
                }

                ConfigPanel {
                    id: configPanel
                    anchors.centerIn: parent
                    config: root.config
                    colors: launcher.colors
                    visible: root.configPanelVisible
                    opacity: root.configPanelVisible ? 1.0 : 0.0
                    scale:   root.configPanelVisible ? 1.0 : 0.93
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    onCloseRequested: {
                        root.configPanelVisible = false
                        launcher.forceActiveFocus()
                    }
                    onConfigSaved: (newConfig) => {
                        root.config = newConfig
                        root.configPanelVisible = false
                        // Le démon garde les jeux en mémoire : recharge pour appliquer
                        // les réglages côté backend (type d'image SGDB, sources…)
                        launcher.loadGames()
                        launcher.forceActiveFocus()
                    }
                }
            }  // End rootItem
        }  // End PanelWindow
    }  // End Variants

    Component.onCompleted: {
        configProcess.running = true;
        console.log("Game Launcher initialized - Loading configuration...");
    }
}
