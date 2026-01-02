import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    PanelWindow {
        property var screen: Quickshell.screens[0]

        visible: true
        color: "transparent"

        implicitWidth: screen.width
        implicitHeight: screen.height

        Rectangle {
            width: 400
            height: 600
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            color: "#1a1a1a"
            border.color: "#ff0000"
            border.width: 3

            Column {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                spacing: 20

                Text {
                    text: "TEST QUICKSHELL"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#ffffff"
                }

                Text {
                    text: "🎨 Icon Test"
                    font.pixelSize: 48
                    color: "#00ff00"
                }

                Rectangle {
                    width: 200
                    height: 50
                    color: "#2a2a2a"
                    border.color: "#ffff00"
                    border.width: 2

                    Text {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        text: "CLICK ME"
                        color: "#ffffff"
                        font.pixelSize: 16
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            console.log("====== CLICK DETECTED ======");
                        }
                    }
                }
            }
        }
    }
}
