import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    PanelWindow {
        id: panelWindow

        property var screen: Quickshell.screens[0]

        visible: true
        mask: Region { item: launcher }
        color: "transparent"

        implicitWidth: screen.width
        implicitHeight: screen.height

        property bool launcherVisible: true

        // Transparent background
        Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        RGBLauncher {
            id: launcher

            anchors {
                right: parent.right
                rightMargin: root.launcherVisible ? 10 : -width
                verticalCenter: parent.verticalCenter

                Behavior on rightMargin {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }

            config: ({})
            onCloseRequested: {
                Qt.quit()
            }

            Component.onCompleted: {
                console.log("RGB Launcher initialized")
            }
        }
    }

    property bool launcherVisible: true

    Component.onCompleted: {
        panelWindow.screen = Quickshell.screens[0]
        panelWindow.launcherVisible = Qt.binding(() => root.launcherVisible)
    }
}
