import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Rectangle {
    id: card

    property string gameName: "Game"
    property string gameImage: ""
    property string gameCategory: ""
    property string gameSource: ""  // steam, manual, config
    property bool isFavorite: false
    property bool isSelected: false
    property var gameColors: ({})
    property int lastPlayed: 0  // Unix timestamp

    signal clicked()
    signal launchRequested()

    width: 220
    height: 300
    radius: 16

    color: gameColors.background || "#1a1a1a"
    border.color: isSelected ? (gameColors.color5 || "#00ffff") : "transparent"
    border.width: isSelected ? 3 : 0

    // Scale animation on selection
    scale: isSelected ? 1.05 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }

    // Glow + Shadow effect
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: isSelected ? (gameColors.color5 || "#00ffff") : "#80000000"
        shadowOpacity: isSelected ? 0.8 : 0.5
        shadowBlur: isSelected ? 1.0 : 0.4
        shadowVerticalOffset: isSelected ? 8 : 4
        shadowHorizontalOffset: 0
    }

    // Breathing animation when selected
    SequentialAnimation {
        running: isSelected
        loops: Animation.Infinite

        NumberAnimation {
            target: card.layer.effect
            property: "shadowBlur"
            from: isSelected ? 0.8 : 0.4
            to: isSelected ? 1.2 : 0.4
            duration: 1500
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: card.layer.effect
            property: "shadowBlur"
            from: isSelected ? 1.2 : 0.4
            to: isSelected ? 0.8 : 0.4
            duration: 1500
            easing.type: Easing.InOutSine
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        focus: false  // Don't steal focus from launcher

        onClicked: card.clicked()
        onDoubleClicked: card.launchRequested()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 0

        // Cover Image
        Rectangle {
            width: parent.width
            height: parent.height - 60
            radius: card.radius
            color: "#2a2a2a"
            clip: true

            Image {
                id: coverImage
                anchors.fill: parent
                anchors.margins: 2  // Déborde légèrement pour meilleur effet visuel
                source: gameImage
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                cache: true

                // Applique les coins arrondis directement à l'image
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.5
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: coverImage.width
                            height: coverImage.height
                            radius: card.radius
                        }
                    }
                }

                // Fallback for missing images
                Rectangle {
                    anchors.fill: parent
                    visible: coverImage.status === Image.Error || coverImage.status === Image.Null
                    color: gameColors.color8 || "#333333"

                    Text {
                        anchors.centerIn: parent
                        text: gameName.substring(0, 2).toUpperCase()
                        font.pixelSize: 48
                        font.bold: true
                        color: gameColors.foreground || "#ffffff"
                        opacity: 0.5
                    }
                }
            }

            // Status badges (NOUVEAU/RÉCENT)
            Rectangle {
                id: statusBadge
                visible: lastPlayed === 0 || isRecent()
                height: 22
                width: badgeText.width + 12
                radius: 11
                color: lastPlayed === 0 ? "#ff3366" : "#33ff66"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 8
                opacity: 0.95

                function isRecent() {
                    if (lastPlayed === 0) return false
                    const now = Date.now() / 1000  // Convert to seconds
                    const daysSince = (now - lastPlayed) / 86400
                    return daysSince < 2  // Last 2 days
                }

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: lastPlayed === 0 ? "NEW" : "RECENT"
                    font.pixelSize: 9
                    font.bold: true
                    color: "#1a1a1a"
                }

                // Pulse animation for NEW badge
                SequentialAnimation {
                    running: lastPlayed === 0
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: statusBadge
                        property: "scale"
                        from: 1.0
                        to: 1.1
                        duration: 800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: statusBadge
                        property: "scale"
                        from: 1.1
                        to: 1.0
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                }
            }

            // Favorite star
            Rectangle {
                visible: isFavorite
                width: 32
                height: 32
                radius: 16
                color: gameColors.color3 || "#ffaa00"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8

                Text {
                    anchors.centerIn: parent
                    text: "★"
                    font.pixelSize: 20
                    color: "#1a1a1a"
                }
            }

            // Platform badge (bottom-left)
            Rectangle {
                visible: gameSource !== ""
                height: 28
                width: 28
                radius: 14
                color: getPlatformColor()
                opacity: 0.95
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: 8

                function getPlatformColor() {
                    if (gameSource === "steam") return gameColors.color8 || "#5A1E80"
                    if (gameSource === "epic") return gameColors.color0 || "#040000"
                    if (gameSource === "gog") return gameColors.color9 || "#7828AA"
                    if (gameSource === "amazon") return gameColors.color11 || "#92502D"
                    if (gameSource === "heroic") return gameColors.color13 || "#C8A46E"
                    if (gameSource === "config") return gameColors.color13 || "#C8A46E"
                    if (gameSource === "manual") return gameColors.color9 || "#7828AA"
                    return gameColors.color5 || "#967B53"
                }

                Text {
                    anchors.centerIn: parent
                    text: getPlatformIcon()
                    font.pixelSize: 14
                    font.family: getPlatformFont()
                    color: gameSource === "epic" ? "#ffffff" : (gameColors.background || "#040000")

                    function getPlatformFont() {
                        // Steam and Amazon use Brands font
                        if (gameSource === "steam" || gameSource === "amazon") {
                            return "Font Awesome 7 Brands"
                        }
                        return "Font Awesome 7 Free Solid"
                    }

                    function getPlatformIcon() {
                        if (gameSource === "steam") return "\uf1b6"     // fa-steam
                        if (gameSource === "epic") return "\uf794"      // fa-shopping-cart (store)
                        if (gameSource === "gog") return "\uf520"       // fa-compact-disc
                        if (gameSource === "amazon") return "\uf270"    // fa-amazon
                        if (gameSource === "heroic") return "\uf6d7"    // fa-dragon (Heroic)
                        if (gameSource === "config") return "\uf135"    // fa-rocket (launcher)
                        if (gameSource === "manual") return "\uf11b"    // fa-gamepad
                        return "\uf11b"  // fa-gamepad (default)
                    }
                }
            }

            // Category badge (bottom-right if platform exists, otherwise bottom-left)
            Rectangle {
                visible: gameCategory !== ""
                height: 24
                width: categoryText.width + 16
                radius: 12
                color: gameColors.color2 || "#555555"
                opacity: 0.9
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 8

                Text {
                    id: categoryText
                    anchors.centerIn: parent
                    text: gameCategory
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    color: gameColors.background || "#ffffff"
                }
            }
        }

        // Game Name
        Rectangle {
            width: parent.width
            height: 60
            radius: card.radius
            color: "transparent"

            Text {
                anchors.fill: parent
                anchors.margins: 12
                text: gameName
                font.pixelSize: 14
                font.bold: true
                color: gameColors.foreground || "#ffffff"
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Hover effect
    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: gameColors.color1 || "#00ffff"
        opacity: mouseArea.containsMouse ? 0.1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }
}
