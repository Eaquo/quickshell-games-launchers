import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtMultimedia

Rectangle {
    I18n { id: i18n }
    id: card

    property string gameName: "Game"
    property string gameImage: ""
    property string gameImageAnimated: ""
    property string gameCategory: ""
    property string gameSource: ""  // steam, manual, config
    property bool isFavorite: false
    property bool isSelected: false
    property var gameColors: ({})
    property int lastPlayed: 0  // Unix timestamp
    property real glowStrength: 0.8
    property real glowBlur: 12
    property bool hasLocalAnimated: gameImageAnimated !== "" &&
        (gameImageAnimated.startsWith("file://") || gameImageAnimated.startsWith("/"))
    property string effectiveImage: hasLocalAnimated ? gameImageAnimated : gameImage
    property bool isWebM: effectiveImage.toLowerCase().endsWith(".webm")
    property bool isAnimatedWebP: effectiveImage.toLowerCase().endsWith(".webp")
    property bool isAnimated: isWebM || isAnimatedWebP
    property real glowOpacity: 0.8

    // Source WebM gérée manuellement pour contrôler le cycle vie RAM/réseau
    property string _webmSource: ""

    signal clicked()
    signal launchRequested()
    signal favoriteToggled()

    // Libère la RAM WebM après 5s d'inactivité — navigation rapide = source encore chargée
    Timer {
        id: clearVideoTimer
        interval: 5000
        running: false
        onTriggered: {
            if (!card.isSelected) {
                videoPlayer.stop()
                card._webmSource = ""
            }
        }
    }

    onIsSelectedChanged: {
        if (card.isWebM) {
            if (isSelected) {
                clearVideoTimer.stop()
                if (card._webmSource === "") card._webmSource = card.effectiveImage
                videoPlayer.play()
            } else {
                videoPlayer.pause()
                clearVideoTimer.start()
            }
        }
    }

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

    // Glow + Shadow effect — layer uniquement sur la carte sélectionnée
    layer.enabled: isSelected
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: gameColors.color5 || "#00ffff"
        shadowOpacity: card.glowOpacity
        shadowBlur: 1.0
        shadowVerticalOffset: 8
        shadowHorizontalOffset: 0
    }

    // Breathing glow — anime card.glowOpacity, pas layer.effect directement
    SequentialAnimation {
        running: isSelected
        loops: Animation.Infinite

        NumberAnimation {
            target: card
            property: "glowOpacity"
            from: 0.8
            to: 1.2
            duration: 1500
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: card
            property: "glowOpacity"
            from: 1.2
            to: 0.8
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

            // Thumbnail statique WebP — visible aussi pendant le chargement de l'animé
            Image {
                id: thumbnailImage
                anchors.fill: parent
                anchors.margins: 2
                visible: card.isAnimatedWebP && (!card.isSelected || animCover.status !== Image.Ready)
                source: visible ? card.effectiveImage : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            // Placeholder initiales pour WebM non sélectionné
            Rectangle {
                anchors.fill: parent
                visible: card.isWebM && !card.isSelected
                color: gameColors.color8 || "#333333"
                Text {
                    anchors.centerIn: parent
                    text: gameName.substring(0, 2).toUpperCase()
                    font.pixelSize: 48
                    font.bold: true
                    font.capitalization: Font.Capitalize
                    font.family: "Open Sans Regular"
                    color: gameColors.foreground || "#ffffff"
                    opacity: 0.5
                }
            }

            // Cover statique (JPEG/PNG) — Image simple, pas d'AnimatedImage pour éviter les warnings
            Image {
                id: staticCover
                anchors.fill: parent
                anchors.margins: 2
                visible: !card.isAnimated
                source: visible ? card.effectiveImage : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                cache: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.5
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: staticCover.width
                            height: staticCover.height
                            radius: card.radius
                        }
                    }
                }

                // Fallback initiales si image absente
                Rectangle {
                    anchors.fill: parent
                    visible: staticCover.status === Image.Error || staticCover.status === Image.Null
                    color: gameColors.color8 || "#333333"
                    Text {
                        anchors.centerIn: parent
                        text: gameName.substring(0, 2).toUpperCase()
                        font.pixelSize: 48
                        font.bold: true
                        font.capitalization: Font.Capitalize
                        font.family: "Open Sans Regular"
                        color: gameColors.foreground || "#ffffff"
                        opacity: 0.5
                    }
                }
            }

            // WebP animé — AnimatedImage uniquement pour ce format, seulement quand sélectionné
            AnimatedImage {
                id: animCover
                anchors.fill: parent
                anchors.margins: 2
                visible: card.isAnimatedWebP && card.isSelected
                source: visible ? card.effectiveImage : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                cache: false
                playing: true
                paused: false

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.5
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: animCover.width
                            height: animCover.height
                            radius: card.radius
                        }
                    }
                }
            }

            // Vidéo WebM — source vidée quand non sélectionnée pour libérer le buffer RAM
            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                anchors.margins: 2
                visible: card.isWebM && card.isSelected
                layer.enabled: card.isWebM && card.isSelected
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.5
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: videoOutput.width
                            height: videoOutput.height
                            radius: card.radius
                        }
                    }
                }
            }

            MediaPlayer {
                id: videoPlayer
                source: card._webmSource
                videoOutput: videoOutput
                loops: MediaPlayer.Infinite
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
                    text: lastPlayed === 0 ? i18n.t("new_badge") : i18n.t("recent_badge")
                    font.pixelSize: 9
                    font.capitalization: Font.Capitalize
                    font.family: "Open Sans Regular"
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

            // Heart button — always visible, clickable to toggle favorite
            Rectangle {
                id: favBtn
                width: 32
                height: 32
                radius: 16
                color: card.isFavorite
                    ? (gameColors.color3 || "#ffaa00")
                    : "transparent"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                opacity: card.isFavorite ? 1.0 : (favBtnMouse.containsMouse ? 0.65 : 0.0)

                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on color   { ColorAnimation  { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 14
                    color: card.isFavorite ? "#1a1a1a" : "#ffffff"
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                MouseArea {
                    id: favBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.favoriteToggled()
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
                    if (gameSource === "epic") return gameColors.color10 || "#040000"
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
                    color: gameSource === "epic" ? "#ffffff" : (gameColors.background || '#ef2c2c2c')

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
                color: gameColors.color14 || "#555555"
                opacity: 0.9
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 8

                Text {
                    id: categoryText
                    anchors.centerIn: parent
                    text: gameCategory
                    font.pixelSize: 12
                    font.capitalization: Font.Capitalize
                    font.family: "Open Sans Regular"
                    font.bold: true
                    color: gameColors.color1 || "#ffffff"
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
                font.family: "Open Sans Regular"
                font.capitalization: Font.Capitalize
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
