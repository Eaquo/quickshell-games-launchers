import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtMultimedia

Item {
    id: bp
    I18n { id: i18n }

    // Catch-all — prevents clicks on empty areas from reaching the quit MouseArea
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }

    required property var filteredGames
    required property var colors
    property int selectedIndex: 0
    property string selectedSource: "all"
    property int favoriteCount: 0
    property var availableSources: []

    signal exitRequested()
    signal openConfigRequested()
    signal launchRequested(var game)
    signal favoriteToggleRequested(var game)
    signal sourceSelected(string src)
    signal indexChanged(int idx)
    signal launchDone()

    function showLaunch(logo, name) {
        bpLaunchOverlay.showLaunch(logo, name)
    }

    // ── Search ─────────────────────────────────────────────────────────────
    property string bpSearch: ""
    property var bpGames: {
        if (bpSearch === "") return filteredGames
        var q = bpSearch.toLowerCase()
        return filteredGames.filter(g => (g.name || "").toLowerCase().includes(q))
    }
    property int bpIndex: 0
    onBpSearchChanged: {
        var cur = currentGame
        var idx = bpGames.indexOf(cur)
        bpIndex = idx >= 0 ? idx : 0
    }
    onSelectedIndexChanged: { if (bpSearch === "") bpIndex = selectedIndex }

    property var currentGame: bpGames.length > 0 ? bpGames[bpIndex] : null

    // ── Slideshow ───────────────────────────────────────────────────────────
    property var heroImages: {
        var g = currentGame
        if (!g) return []
        if (g.images && g.images.length > 0) return g.images
        var imgs = []
        if (g.image) imgs.push(g.image)
        if (g.hero_image && g.hero_image !== g.image) imgs.push(g.hero_image)
        return imgs
    }
    property int heroSlideIndex: 0
    onCurrentGameChanged: heroSlideIndex = 0

    Timer {
        id: slideshowTimer
        interval: 6000
        running: bp.heroImages.length > 1
        repeat: true
        onTriggered: {
            heroFadeOut.start()
        }
    }

    SequentialAnimation {
        id: heroFadeOut
        NumberAnimation { target: heroImg; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InQuad }
        ScriptAction { script: { bp.heroSlideIndex = (bp.heroSlideIndex + 1) % Math.max(bp.heroImages.length, 1) } }
        NumberAnimation { target: heroImg; property: "opacity"; to: 1; duration: 400; easing.type: Easing.OutQuad }
    }

    // Hero toujours statique — slide entre image SGDB et hero Steam CDN
    property string heroSrc: heroImages.length > 0 ? heroImages[heroSlideIndex] : ""

    focus: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (bp.bpSearch !== "") { bp.bpSearch = ""; bpSearchInput.text = ""; event.accepted = true; return }
            bp.exitRequested(); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (bp.currentGame) bp.launchRequested(bp.currentGame)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            if (bp.bpIndex > 0) { bp.bpIndex--; bp.indexChanged(bp.filteredGames.indexOf(bp.currentGame)) }
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            if (bp.bpIndex < bp.bpGames.length - 1) { bp.bpIndex++; bp.indexChanged(bp.filteredGames.indexOf(bp.currentGame)) }
            event.accepted = true
        } else if (event.key === Qt.Key_F && (event.modifiers & Qt.AltModifier)) {
            if (bp.currentGame) bp.favoriteToggleRequested(bp.currentGame)
            event.accepted = true
        } else if (event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
            bpSearchInput.forceActiveFocus(); event.accepted = true
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

    function formatPlaytime(minutes) {
        if (!minutes || minutes === 0) return ""
        const h = Math.floor(minutes / 60)
        const m = minutes % 60
        if (h > 0 && m > 0) return h + "h " + m + "min"
        if (h > 0) return h + "h"
        return m + "min"
    }

    function formatLastPlayed(ts) {
        return i18n.formatDate(ts)
    }

    function formatSize(bytes) {
        if (!bytes || bytes === 0) return ""
        if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + " GB"
        if (bytes >= 1048576)    return (bytes / 1048576).toFixed(0) + " MB"
        return (bytes / 1024).toFixed(0) + " KB"
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
        source: bp.heroSrc
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: 0.18
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 48 }
    }

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
                    text: i18n.t("all")
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
                    Text { text: i18n.t("favs"); font.pixelSize: 13; font.bold: bp.selectedSource === "favorites"; font.family: "Open Sans Regular"
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

        // Right: search + game count + exit
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // Search bar — expands on focus or when text present
            Rectangle {
                id: searchBox
                property bool expanded: bpSearchInput.activeFocus || bp.bpSearch !== ""
                height: 36
                width: expanded ? 220 : 36
                radius: 18
                color: expanded ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.08)
                border.color: bpSearchInput.activeFocus ? (colors.color5 || "#73ff00") : Qt.rgba(1,1,1,0.15)
                border.width: 1
                clip: true
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color  { ColorAnimation  { duration: 150 } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf002"
                        font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 12
                        color: bpSearchInput.activeFocus ? (colors.color5 || "#73ff00") : Qt.rgba(1,1,1,0.6)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    TextInput {
                        id: bpSearchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 22
                        color: "#ffffff"
                        font.pixelSize: 13; font.family: "Open Sans Regular"
                        selectByMouse: true
                        onTextChanged: bp.bpSearch = text
                        Keys.onEscapePressed: { text = ""; bp.bpSearch = ""; bp.forceActiveFocus() }
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.IBeamCursor
                    onClicked: bpSearchInput.forceActiveFocus()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bp.bpSearch !== ""
                    ? bp.bpGames.length + " " + i18n.t("results")
                    : bp.bpGames.length + " " + i18n.t("games")
                font.pixelSize: 12; font.family: "Open Sans Regular"
                color: bp.bpSearch !== "" ? (colors.color5 || "#73ff00") : Qt.rgba(1,1,1,0.4)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Rectangle {
                width: 36; height: 36; radius: 18
                color: cfgBpM.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.08)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent; text: "\uf013"
                    font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 14
                    color: cfgBpM.containsMouse ? "#ffffff" : Qt.rgba(1,1,1,0.55)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea { id: cfgBpM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bp.openConfigRequested() }
            }

            Rectangle {
                width: 36; height: 36; radius: 18
                color: exitM.containsMouse ? Qt.rgba(1,0.2,0.2,0.35) : Qt.rgba(1,1,1,0.08)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent; text: "\uf00d"
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

        // Hero statique — Image simple, pas d'animé pour économiser les ressources
        Image {
            id: heroImg
            anchors.fill: parent
            source: bp.heroSrc
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
        }

        // Fallback initiales — dernier recours si même la cover est absente
        Rectangle {
            anchors.fill: parent
            visible: heroImg.status === Image.Error || heroImg.status === Image.Null
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
                        return i18n.t("played_on") + " " + i18n.formatDate(currentGame?.last_played || 0)
                    }
                    font.pixelSize: 13; font.family: "Open Sans Regular"
                    color: Qt.rgba(1,1,1,0.55)
                }
            }
        }

        // ── Stats panel (right side) ──────────────────────────────────────────
        Rectangle {
            id: statsPanel
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 40
            anchors.topMargin: 30
            width: 210
            height: statsList.implicitHeight + 28
            radius: 14
            color: Qt.rgba(0, 0, 0, 0.62)
            border.color: Qt.rgba(1,1,1,0.1); border.width: 1

            property bool hasPlaytime:    (currentGame?.playtime_minutes || 0) > 0
            property bool hasLastPlayed:  (currentGame?.last_played      || 0) > 0
            property bool hasSize:        (currentGame?.size_bytes        || 0) > 0
            property bool hasLastUpdated: (currentGame?.last_updated      || 0) > 0
            visible: hasPlaytime || hasLastPlayed || hasSize || hasLastUpdated

            Column {
                id: statsList
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 0

                // ── Temps de jeu ──
                Column {
                    width: parent.width
                    spacing: 3
                    visible: statsPanel.hasPlaytime
                    topPadding: 0
                    bottomPadding: statsPanel.hasLastPlayed || statsPanel.hasSize || statsPanel.hasLastUpdated ? 14 : 0
                    Row {
                        spacing: 6
                        Text { text: ""; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 10
                               color: bp.accentRgba(0.85); anchors.verticalCenter: parent.verticalCenter }
                        Text { text: i18n.t("playtime"); font.pixelSize: 10; font.family: "Open Sans Regular"
                               color: Qt.rgba(1,1,1,0.4); anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: bp.formatPlaytime(currentGame?.playtime_minutes || 0)
                        font.pixelSize: 20; font.bold: true; font.family: "Open Sans Regular"
                        color: "#ffffff"
                    }
                }

                Rectangle {
                    width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.1)
                    visible: statsPanel.hasPlaytime && (statsPanel.hasLastPlayed || statsPanel.hasSize || statsPanel.hasLastUpdated)
                }

                // ── Dernière session ──
                Column {
                    width: parent.width
                    spacing: 3
                    visible: statsPanel.hasLastPlayed
                    topPadding: statsPanel.hasPlaytime ? 14 : 0
                    bottomPadding: statsPanel.hasSize || statsPanel.hasLastUpdated ? 14 : 0
                    Row {
                        spacing: 6
                        Text { text: ""; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 10
                               color: bp.accentRgba(0.85); anchors.verticalCenter: parent.verticalCenter }
                        Text { text: i18n.t("last_session"); font.pixelSize: 10; font.family: "Open Sans Regular"
                               color: Qt.rgba(1,1,1,0.4); anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: bp.formatLastPlayed(currentGame?.last_played || 0)
                        font.pixelSize: 13; font.bold: true; font.family: "Open Sans Regular"
                        color: Qt.rgba(1,1,1,0.9); wrapMode: Text.WordWrap; width: parent.width
                    }
                }

                Rectangle {
                    width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.1)
                    visible: statsPanel.hasLastPlayed && (statsPanel.hasSize || statsPanel.hasLastUpdated)
                }

                // ── Taille installée ──
                Column {
                    width: parent.width
                    spacing: 3
                    visible: statsPanel.hasSize
                    topPadding: (statsPanel.hasPlaytime || statsPanel.hasLastPlayed) ? 14 : 0
                    bottomPadding: statsPanel.hasLastUpdated ? 14 : 0
                    Row {
                        spacing: 6
                        Text { text: ""; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 10
                               color: bp.accentRgba(0.85); anchors.verticalCenter: parent.verticalCenter }
                        Text { text: i18n.t("install_size"); font.pixelSize: 10; font.family: "Open Sans Regular"
                               color: Qt.rgba(1,1,1,0.4); anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: bp.formatSize(currentGame?.size_bytes || 0)
                        font.pixelSize: 16; font.bold: true; font.family: "Open Sans Regular"
                        color: "#ffffff"
                    }
                }

                Rectangle {
                    width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.1)
                    visible: statsPanel.hasSize && statsPanel.hasLastUpdated
                }

                // ── Dernière mise à jour ──
                Column {
                    width: parent.width
                    spacing: 3
                    visible: statsPanel.hasLastUpdated
                    topPadding: (statsPanel.hasPlaytime || statsPanel.hasLastPlayed || statsPanel.hasSize) ? 14 : 0
                    bottomPadding: 0
                    Row {
                        spacing: 6
                        Text { text: ""; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 10
                               color: bp.accentRgba(0.85); anchors.verticalCenter: parent.verticalCenter }
                        Text { text: i18n.t("last_update"); font.pixelSize: 10; font.family: "Open Sans Regular"
                               color: Qt.rgba(1,1,1,0.4); anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text {
                        text: bp.formatLastPlayed(currentGame?.last_updated || 0)
                        font.pixelSize: 13; font.bold: true; font.family: "Open Sans Regular"
                        color: Qt.rgba(1,1,1,0.9); wrapMode: Text.WordWrap; width: parent.width
                    }
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
                        text: i18n.t("launch")
                        font.pixelSize: 15; font.bold: true; font.family: "Open Sans Regular"
                        color: "#0d0d0d"
                    }
                }
                MouseArea { id: launchM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (bp.currentGame) bp.launchRequested(bp.currentGame) }
            }
        }
    }

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
                onClicked: if (bp.bpIndex > 0) { bp.bpIndex--; bp.indexChanged(bp.filteredGames.indexOf(bp.currentGame)) } }
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
                onClicked: if (bp.bpIndex < bp.bpGames.length - 1) { bp.bpIndex++; bp.indexChanged(bp.filteredGames.indexOf(bp.currentGame)) } }
        }

        ListView {
            id: stripList
            anchors.fill: parent
            anchors.leftMargin: 36; anchors.rightMargin: 36
            anchors.topMargin: 10; anchors.bottomMargin: 10
            orientation: ListView.Horizontal
            spacing: 8
            model: bp.bpGames
            currentIndex: bp.bpIndex
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 250
            preferredHighlightBegin: width / 2 - 96
            preferredHighlightEnd: width / 2 + 96
            clip: true

            onCurrentIndexChanged: {
                if (currentIndex !== bp.bpIndex) {
                    bp.bpIndex = currentIndex
                    bp.indexChanged(bp.filteredGames.indexOf(bp.currentGame))
                }
            }

            MouseArea {
                anchors.fill: parent; propagateComposedEvents: true; focus: false
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0 && bp.bpIndex > 0) { bp.bpIndex--; bp.indexChanged(bp.filteredGames.indexOf(bp.currentGame)) }
                    else if (wheel.angleDelta.y < 0 && bp.bpIndex < bp.bpGames.length - 1) { bp.bpIndex++; bp.indexChanged(bp.filteredGames.indexOf(bp.currentGame)) }
                    wheel.accepted = true
                }
                onClicked: (mouse) => mouse.accepted = false
            }

            delegate: Item {
                property bool isSelected: index === bp.bpIndex
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

                    property bool thumbHasAnim: {
                        var a = modelData.image_animated || ""
                        return a !== "" && a.toLowerCase().endsWith(".webp")
                    }

                    // Cover statique (toujours visible sauf si animée active)
                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: modelData.image || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: !(isSelected && stripCard.thumbHasAnim)

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

                    // Cover animée — uniquement sur le thumbnail sélectionné
                    AnimatedImage {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: (isSelected && stripCard.thumbHasAnim) ? (modelData.image_animated || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        playing: isSelected
                        visible: isSelected && stripCard.thumbHasAnim

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
                        onClicked: { bp.bpIndex = index; bp.indexChanged(bp.filteredGames.indexOf(bp.bpGames[index])) }
                        onDoubleClicked: bp.launchRequested(modelData)
                    }
                }
            }
        }
    }

    // ── BP Launch overlay ────────────────────────────────────────────────────
    Item {
        id: bpLaunchOverlay
        anchors.fill: parent
        visible: false
        z: 200

        property string logoSrc: ""
        property string gameTitle: ""

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.88)
        }

        Column {
            anchors.centerIn: parent
            spacing: 28
            width: parent.width * 0.6

            Image {
                id: bpLaunchLogo
                anchors.horizontalCenter: parent.horizontalCenter
                source: bpLaunchOverlay.logoSrc
                visible: bpLaunchOverlay.logoSrc !== "" && status === Image.Ready
                fillMode: Image.PreserveAspectFit
                width: Math.min(480, parent.width)
                height: 200
                asynchronous: true
                opacity: 0
                scale: 0.88
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.06 } }
            }

            Text {
                id: bpLaunchName
                anchors.horizontalCenter: parent.horizontalCenter
                text: bpLaunchOverlay.gameTitle.toUpperCase()
                visible: bpLaunchOverlay.logoSrc === "" || bpLaunchLogo.status !== Image.Ready
                color: "#ffffff"
                font.pixelSize: 52; font.bold: true; font.family: "Open Sans Regular"
                font.letterSpacing: 5
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
                opacity: 0
                scale: 0.88
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.06 } }
            }

            Text {
                id: bpStartText
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.t("start_game") + bpDotsStr
                color: Qt.rgba(1,1,1,0.6)
                font.pixelSize: 18; font.letterSpacing: 4; font.family: "Open Sans Regular"
                horizontalAlignment: Text.AlignHCenter
                opacity: 0
                property string bpDotsStr: ""
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }

        Timer {
            id: bpShowContent; interval: 200; repeat: false
            onTriggered: {
                bpLaunchLogo.opacity = 1; bpLaunchLogo.scale = 1.0
                bpLaunchName.opacity = 1; bpLaunchName.scale = 1.0
                bpShowStart.start()
            }
        }
        Timer {
            id: bpShowStart; interval: 350; repeat: false
            onTriggered: { bpStartText.opacity = 1; bpDotsTimer.start() }
        }
        Timer {
            id: bpDotsTimer; interval: 500; repeat: true
            property int tick: 0
            onTriggered: {
                tick = (tick + 1) % 4
                var s = ""
                for (var i = 0; i < tick; i++) s += "◦"
                bpStartText.bpDotsStr = s
            }
        }
        Timer {
            id: bpCloseTimer; interval: 3700; repeat: false
            onTriggered: {
                bpDotsTimer.stop()
                bpFadeOut.start()
            }
        }
        NumberAnimation {
            id: bpFadeOut
            target: bpLaunchOverlay; property: "opacity"
            from: 1; to: 0; duration: 300
            onStopped: {
                bpLaunchOverlay.visible = false
                bpLaunchOverlay.opacity = 1
                bp.launchDone()
            }
        }

        function showLaunch(logo, name) {
            logoSrc = logo || ""
            gameTitle = name || ""
            bpLaunchLogo.opacity = 0; bpLaunchLogo.scale = 0.88
            bpLaunchName.opacity = 0; bpLaunchName.scale = 0.88
            bpStartText.opacity = 0; bpStartText.bpDotsStr = ""
            bpDotsTimer.tick = 0
            visible = true
            bpShowContent.start()
            bpCloseTimer.start()
        }
    }

    // Entrance animation
    NumberAnimation on opacity {
        from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic
        running: true
    }
}
