import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtMultimedia

Item {
    id: bp

    required property var filteredGames
    required property var colors
    property int selectedIndex: 0
    property string selectedSource: "all"
    property int favoriteCount: 0
    property var availableSources: []

    signal exitRequested()
    signal launchRequested(var game)
    signal favoriteToggleRequested(var game)
    signal sourceSelected(string src)
    signal indexChanged(int idx)

    property var currentGame: filteredGames.length > 0 ? filteredGames[selectedIndex] : null

    focus: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            bp.exitRequested(); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (bp.currentGame) bp.launchRequested(bp.currentGame)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            if (bp.selectedIndex > 0) bp.indexChanged(bp.selectedIndex - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            if (bp.selectedIndex < bp.filteredGames.length - 1) bp.indexChanged(bp.selectedIndex + 1)
            event.accepted = true
        } else if (event.key === Qt.Key_F && (event.modifiers & Qt.AltModifier)) {
            if (bp.currentGame) bp.favoriteToggleRequested(bp.currentGame)
            event.accepted = true
        }
    }

    function sourceInfo(src) {
        const map = {
            "steam":   { icon: "", font: "Font Awesome 7 Brands",    label: "Steam"   },
            "epic":    { icon: "", font: "Font Awesome 7 Free Solid", label: "Epic"    },
            "gog":     { icon: "", font: "Font Awesome 7 Free Solid", label: "GOG"     },
            "amazon":  { icon: "", font: "Font Awesome 7 Brands",     label: "Amazon"  },
            "heroic":  { icon: "", font: "Font Awesome 7 Free Solid", label: "Heroic"  },
            "manual":  { icon: "", font: "Font Awesome 7 Free Solid", label: "Manual"  },
            "desktop": { icon: "", font: "Font Awesome 7 Free Solid", label: "Desktop" },
            "config":  { icon: "", font: "Font Awesome 7 Free Solid", label: "Config"  },
        }
        return map[src] || { icon: "", font: "Font Awesome 7 Free Solid", label: src }
    }

    function accentRgba(a) {
        return Qt.rgba(
            parseInt((colors.color5 || "#73ff00").slice(1,3), 16) / 255,
            parseInt((colors.color5 || "#73ff00").slice(3,5), 16) / 255,
            parseInt((colors.color5 || "#73ff00").slice(5,7), 16) / 255,
            a)
    }

    // ── Solid background ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#080808"
    }

    // ── Hero image (blurred background) ─────────────────────────────────────
    Image {
        id: heroBg
        anchors.fill: parent
        source: currentGame?.image || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: 0.18
        visible: !heroIsWebM
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 48 }
    }

    property bool heroIsWebM: (currentGame?.image || "").toLowerCase().endsWith(".webm")

    // ── TOP BAR ─────────────────────────────────────────────────────────────
    Rectangle {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 64
        color: Qt.rgba(0, 0, 0, 0.6)

        // Source tabs (left)
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // ALL
            Rectangle {
                height: 36; width: allTxt.width + 22; radius: 18
                color: bp.selectedSource === "all" ? bp.accentRgba(0.22) : (allM.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent")
                border.color: bp.selectedSource === "all" ? (colors.color5 || "#73ff00") : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    id: allTxt
                    anchors.centerIn: parent
                    text: "All"
                    font.pixelSize: 13; font.bold: bp.selectedSource === "all"; font.family: "Open Sans Regular"
                    color: bp.selectedSource === "all" ? (colors.color5 || "#73ff00") : Qt.rgba(1,1,1,0.7)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea { id: allM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bp.sourceSelected("all") }
            }

            // FAVORITES (si présents)
            Rectangle {
                visible: bp.favoriteCount > 0
                height: 36; width: favRow.width + 22; radius: 18
                color: bp.selectedSource === "favorites" ? bp.accentRgba(0.22) : (favM.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent")
                border.color: bp.selectedSource === "favorites" ? (colors.color5 || "#73ff00") : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Row { id: favRow; anchors.centerIn: parent; spacing: 6
                    Text { text: ""; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 11
                        color: bp.selectedSource === "favorites" ? (colors.color5 || "#73ff00") : Qt.rgba(1,1,1,0.7) }
                    Text { text: "Favs"; font.pixelSize: 13; font.bold: bp.selectedSource === "favorites"; font.family: "Open Sans Regular"
                        color: bp.selectedSource === "favorites" ? (colors.color5 || "#73ff00") : Qt.rgba(1,1,1,0.7) }
                }
                MouseArea { id: favM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bp.sourceSelected("favorites") }
            }

            // Sources
            Repeater {
                model: bp.availableSources
                Rectangle {
                    property string src: modelData
                    property var info: bp.sourceInfo(src)
                    property bool active: bp.selectedSource === src
                    height: 36; width: srcRow.width + 22; radius: 18
                    color: active ? bp.accentRgba(0.22) : (srcM.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent")
                    border.color: active ? (colors.color5 || "#73ff00") : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Row { id: srcRow; anchors.centerIn: parent; spacing: 6
                        Text { text: info.icon; font.family: info.font; font.pixelSize: 12
                            color: active ? (colors.color5 || "#73ff00") : Qt.rgba(1,1,1,0.7) }
                        Text { text: info.label; font.pixelSize: 13; font.bold: active; font.family: "Open Sans Regular"
                            color: active ? (colors.color5 || "#73ff00") : Qt.rgba(1,1,1,0.7) }
                    }
                    MouseArea { id: srcM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bp.sourceSelected(src) }
                }
            }
        }

        // Right: game count + exit button
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bp.filteredGames.length + " jeux"
                font.pixelSize: 12; font.family: "Open Sans Regular"
                color: Qt.rgba(1,1,1,0.4)
            }

            Rectangle {
                width: 36; height: 36; radius: 18
                color: exitM.containsMouse ? Qt.rgba(1,0.2,0.2,0.35) : Qt.rgba(1,1,1,0.08)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 14
                    color: exitM.containsMouse ? "#ff6666" : Qt.rgba(1,1,1,0.75)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea { id: exitM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bp.exitRequested() }
            }
        }
    }

    // ── HERO AREA ────────────────────────────────────────────────────────────
    Item {
        id: heroArea
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: gameStrip.top

        // Hero image (static / webp)
        AnimatedImage {
            id: heroImg
            anchors.fill: parent
            source: bp.heroIsWebM ? "" : (currentGame?.image || "")
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            playing: true
            visible: !bp.heroIsWebM

            Behavior on source {
                // fade transition on game change
            }
        }

        // Hero WebM
        VideoOutput {
            id: heroVideo
            anchors.fill: parent
            visible: bp.heroIsWebM
        }
        MediaPlayer {
            id: heroPlayer
            source: bp.heroIsWebM ? (currentGame?.image || "") : ""
            videoOutput: heroVideo
            loops: MediaPlayer.Infinite
            onSourceChanged: if (source !== "") play()
        }

        // Fallback (no image)
        Rectangle {
            anchors.fill: parent
            visible: (!bp.heroIsWebM && heroImg.status !== Image.Ready) || (bp.heroIsWebM && heroVideo.source === "")
            color: "#111111"
            Text {
                anchors.centerIn: parent
                text: (currentGame?.name || "").substring(0, 2).toUpperCase()
                font.pixelSize: 160; font.bold: true; font.family: "Open Sans Regular"
                color: colors.foreground || "#ffffff"
                opacity: 0.08
            }
        }

        // Top dark gradient
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 80
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.55) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Bottom dark gradient (for text readability)
        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            height: 260
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.96) }
            }
        }

        // ── Game info (bottom-left) ─────────────────────────────────────────
        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 52
            anchors.bottomMargin: 36
            spacing: 10

            // Platform badge
            Rectangle {
                visible: currentGame?.source !== ""
                height: 26; width: platRow.width + 16; radius: 13
                color: Qt.rgba(1,1,1,0.12)
                border.color: Qt.rgba(1,1,1,0.2); border.width: 1
                Row {
                    id: platRow
                    anchors.centerIn: parent; spacing: 6
                    Text {
                        text: bp.sourceInfo(currentGame?.source || "").icon
                        font.family: bp.sourceInfo(currentGame?.source || "").font
                        font.pixelSize: 11; color: Qt.rgba(1,1,1,0.8)
                    }
                    Text {
                        text: bp.sourceInfo(currentGame?.source || "").label
                        font.pixelSize: 11; font.family: "Open Sans Regular"
                        color: Qt.rgba(1,1,1,0.8)
                    }
                }
            }

            // Game name
            Text {
                id: gameName
                text: currentGame?.name || ""
                font.pixelSize: 54; font.bold: true; font.family: "Open Sans Regular"
                color: "#ffffff"
                style: Text.Outline; styleColor: Qt.rgba(0,0,0,0.3)
                maximumLineCount: 2; wrapMode: Text.WordWrap
                width: Math.min(implicitWidth, heroArea.width - 400)

                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: gameName; property: "opacity"; to: 0; duration: 100 }
                        NumberAnimation { target: gameName; property: "opacity"; to: 1; duration: 200 }
                    }
                }
            }

            // Last played / NEW badge
            Row {
                spacing: 10
                Rectangle {
                    visible: currentGame?.last_played === 0
                    height: 20; width: newTxt.width + 12; radius: 10
                    color: "#ff3366"
                    Text { id: newTxt; anchors.centerIn: parent; text: "NEW"; font.pixelSize: 9; font.bold: true; color: "#ffffff" }
                }
                Text {
                    visible: (currentGame?.last_played || 0) > 0
                    text: {
                        if (!currentGame || !currentGame.last_played) return ""
                        const d = new Date(currentGame.last_played * 1000)
                        return "Joué le " + d.toLocaleDateString()
                    }
                    font.pixelSize: 13; font.family: "Open Sans Regular"
                    color: Qt.rgba(1,1,1,0.55)
                }
            }
        }

        // ── Action buttons (bottom-right) ───────────────────────────────────
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 52
            anchors.bottomMargin: 40
            spacing: 14

            // Favorite button
            Rectangle {
                width: 52; height: 52; radius: 26
                color: currentGame?.favorite
                    ? (colors.color3 || "#ffaa00")
                    : (favHeroM.containsMouse ? Qt.rgba(1,1,1,0.18) : Qt.rgba(0,0,0,0.55))
                border.color: currentGame?.favorite ? "transparent" : Qt.rgba(1,1,1,0.25)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: "\uf004"
                    font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 20
                    color: currentGame?.favorite ? "#1a1a1a" : "#ffffff"
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                MouseArea { id: favHeroM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (bp.currentGame) bp.favoriteToggleRequested(bp.currentGame) }
            }

            // Launch button
            Rectangle {
                id: launchBtn
                height: 52; width: launchRow.width + 36; radius: 26
                color: launchM.containsMouse
                    ? (colors.color5 || "#73ff00")
                    : bp.accentRgba(0.82)
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    id: launchRow
                    anchors.centerIn: parent; spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 16
                        color: "#0d0d0d"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "LANCER"
                        font.pixelSize: 15; font.bold: true; font.family: "Open Sans Regular"
                        color: "#0d0d0d"
                    }
                }
                MouseArea { id: launchM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (bp.currentGame) bp.launchRequested(bp.currentGame) }
            }
        }
    }

    // ── GAME STRIP (bottom) ──────────────────────────────────────────────────
    Rectangle {
        id: gameStrip
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 152
        color: Qt.rgba(0, 0, 0, 0.72)

        // Left arrow
        Rectangle {
            id: leftArrow
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 64; radius: 6; z: 2
            color: leftArrowM.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
            visible: stripList.contentX > 0
            Text {
                anchors.centerIn: parent; text: ""
                font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 13
                color: Qt.rgba(1,1,1,0.7)
            }
            MouseArea { id: leftArrowM; anchors.fill: parent; hoverEnabled: true
                onClicked: if (bp.selectedIndex > 0) bp.indexChanged(bp.selectedIndex - 1) }
        }

        // Right arrow
        Rectangle {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 64; radius: 6; z: 2
            color: rightArrowM.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
            visible: stripList.contentX < stripList.contentWidth - stripList.width
            Text {
                anchors.centerIn: parent; text: ""
                font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 13
                color: Qt.rgba(1,1,1,0.7)
            }
            MouseArea { id: rightArrowM; anchors.fill: parent; hoverEnabled: true
                onClicked: if (bp.selectedIndex < bp.filteredGames.length - 1) bp.indexChanged(bp.selectedIndex + 1) }
        }

        ListView {
            id: stripList
            anchors.fill: parent
            anchors.leftMargin: 36; anchors.rightMargin: 36
            anchors.topMargin: 10; anchors.bottomMargin: 10
            orientation: ListView.Horizontal
            spacing: 8
            model: bp.filteredGames
            currentIndex: bp.selectedIndex
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 250
            preferredHighlightBegin: width / 2 - 96
            preferredHighlightEnd: width / 2 + 96
            clip: true

            onCurrentIndexChanged: {
                if (currentIndex !== bp.selectedIndex)
                    bp.indexChanged(currentIndex)
            }

            MouseArea {
                anchors.fill: parent; propagateComposedEvents: true; focus: false
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0 && bp.selectedIndex > 0) bp.indexChanged(bp.selectedIndex - 1)
                    else if (wheel.angleDelta.y < 0 && bp.selectedIndex < bp.filteredGames.length - 1) bp.indexChanged(bp.selectedIndex + 1)
                    wheel.accepted = true
                }
                onClicked: (mouse) => mouse.accepted = false
            }

            delegate: Item {
                property bool isSelected: index === bp.selectedIndex
                width: isSelected ? 186 : 155
                height: stripList.height
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                Rectangle {
                    id: stripCard
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    radius: 10
                    color: "#1a1a1a"
                    border.color: isSelected ? (colors.color5 || "#73ff00") : "transparent"
                    border.width: isSelected ? 2 : 0
                    scale: isSelected ? 1.0 : 0.88
                    opacity: isSelected ? 1.0 : 0.55
                    clip: true

                    Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    // Cover
                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: modelData.image || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskThresholdMin: 0.5
                            maskSource: ShaderEffectSource {
                                sourceItem: Rectangle {
                                    width: stripCard.width; height: stripCard.height; radius: stripCard.radius
                                }
                            }
                        }
                    }

                    // Name overlay (bottom)
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                        height: 32; radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.85) }
                        }
                        Text {
                            anchors { fill: parent; margins: 6; bottomMargin: 4 }
                            text: modelData.name || ""
                            font.pixelSize: 9; font.family: "Open Sans Regular"
                            color: "#ffffff"; elide: Text.ElideRight
                            verticalAlignment: Text.AlignBottom
                        }
                    }

                    // Favorite dot
                    Rectangle {
                        visible: modelData.favorite
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.margins: 5
                        width: 8; height: 8; radius: 4
                        color: colors.color3 || "#ffaa00"
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: bp.indexChanged(index)
                        onDoubleClicked: bp.launchRequested(modelData)
                    }
                }
            }
        }
    }

    // Entrance animation
    NumberAnimation on opacity {
        from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic
        running: true
    }
}
