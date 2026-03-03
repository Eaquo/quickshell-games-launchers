import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Rectangle {
    id: launcher

    required property var config
    property var gamesData: []
    property var filteredGames: []
    property var colors: ({})
    property int selectedIndex: 0
    property string searchText: ""
    property string selectedSource: "all"

    // Config values
    property string orientation: config?.display?.orientation ?? "horizontal"
    property int gridColumns: config?.display?.grid_size?.[0] ?? 4
    property int gridRows: config?.display?.grid_size?.[1] ?? 3
    property int itemWidth: config?.display?.item_width ?? 200
    property int itemHeight: config?.display?.item_height ?? 300
    property int spacing: config?.display?.spacing ?? 20

    property int sidebarWidth: 68

    width: sidebarWidth + spacing + (itemWidth * gridColumns) + (spacing * (gridColumns + 1))
    height: (itemHeight * gridRows) + (spacing * (gridRows + 1)) + 60 + 44 + spacing

    focus: true
    activeFocusOnTab: true
    color: "transparent"
    radius: 16

    // Background with blur
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: colors.background || "#1a1a1a"
        opacity: config?.appearance?.background_opacity ?? 0.85
        layer.enabled: config?.appearance?.blur_background ?? true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.8
            blurMax: 32
        }
    }

    // Border
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: colors.color5 || '#73ff00'
        border.width: 2
        opacity: 0.5
    }

    Component.onCompleted: {
        launcher.forceActiveFocus()
        loadGames()
    }

    // Available sources computed from data
    property var availableSources: {
        const seen = {}
        const out = []
        for (const g of gamesData) {
            const s = g.source || ""
            if (s && !seen[s]) { seen[s] = true; out.push(s) }
        }
        return out
    }

    function sourceInfo(src) {
        const map = {
            "steam":   { icon: "\uf1b6", font: "Font Awesome 7 Brands",    label: "Steam"   },
            "epic":    { icon: "\uf794", font: "Font Awesome 7 Free Solid", label: "Epic"    },
            "gog":     { icon: "\uf520", font: "Font Awesome 7 Free Solid", label: "GOG"     },
            "amazon":  { icon: "\uf270", font: "Font Awesome 7 Brands",     label: "Amazon"  },
            "heroic":  { icon: "\uf6d7", font: "Font Awesome 7 Free Solid", label: "Heroic"  },
            "manual":  { icon: "\uf11b", font: "Font Awesome 7 Free Solid", label: "Manual"  },
            "desktop": { icon: "\uf108", font: "Font Awesome 7 Free Solid", label: "Desktop" },
            "config":  { icon: "\uf135", font: "Font Awesome 7 Free Solid", label: "Config"  },
        }
        return map[src] || { icon: "\uf11b", font: "Font Awesome 7 Free Solid", label: src }
    }

    // Keyboard navigation
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (searchText !== "") {
                searchText = ""
                searchField.clear()
            } else {
                launcher.closeRequested()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!searchField.activeFocus) launchSelectedGame()
            event.accepted = true
        } else if (event.key === Qt.Key_Left && !searchField.activeFocus) {
            navigateLeft(); event.accepted = true
        } else if (event.key === Qt.Key_Right && !searchField.activeFocus) {
            navigateRight(); event.accepted = true
        } else if (event.key === Qt.Key_Up && !searchField.activeFocus) {
            navigateUp(); event.accepted = true
        } else if (event.key === Qt.Key_Down && !searchField.activeFocus) {
            navigateDown(); event.accepted = true
        } else if (event.key === Qt.Key_Backspace && !searchField.activeFocus) {
            if (searchText.length > 0) {
                searchText = searchText.slice(0, -1)
                searchField.text = searchText
            }
            event.accepted = true
        } else if (event.text && event.text.length > 0 && !event.modifiers && !searchField.activeFocus) {
            searchText += event.text
            searchField.text = searchText
            searchField.forceActiveFocus()
            event.accepted = true
        }
    }

    onSearchTextChanged:   filterGames()
    onSelectedSourceChanged: filterGames()

    signal closeRequested()

    Process {
        id: gamesProcess
        command: ["python3", Qt.resolvedUrl("service/backend.py").toString().replace("file://", "")]
        running: false
        property string output: ""
        stdout: SplitParser { onRead: data => gamesProcess.output += data }
        onExited: {
            try {
                const result = JSON.parse(gamesProcess.output)
                gamesData = result.games || []
                colors = result.colors || {}
                filterGames()
            } catch (e) {
                console.error("Failed to parse games data:", e)
            }
            gamesProcess.output = ""
        }
    }

    function loadGames() { gamesProcess.running = true }

    function filterGames() {
        let result = gamesData.slice()
        if (selectedSource !== "all")
            result = result.filter(g => (g.source || "") === selectedSource)
        if (searchText.trim() !== "") {
            const q = searchText.toLowerCase()
            result = result.filter(g =>
                (g.name || "").toLowerCase().includes(q) ||
                (g.category || "").toLowerCase().includes(q)
            )
        }
        filteredGames = result
        if (selectedIndex >= filteredGames.length)
            selectedIndex = Math.max(0, filteredGames.length - 1)
    }

    function navigateLeft() {
        if (orientation === "horizontal" && selectedIndex > 0) selectedIndex--
        else if (orientation === "vertical" && selectedIndex % gridColumns > 0) selectedIndex--
    }
    function navigateRight() {
        if (orientation === "horizontal" && selectedIndex < filteredGames.length - 1) selectedIndex++
        else if (orientation === "vertical" && selectedIndex % gridColumns < gridColumns - 1 && selectedIndex < filteredGames.length - 1) selectedIndex++
    }
    function navigateUp() {
        if (orientation === "vertical" && selectedIndex >= gridColumns) selectedIndex -= gridColumns
    }
    function navigateDown() {
        if (orientation === "vertical" && selectedIndex + gridColumns < filteredGames.length) selectedIndex += gridColumns
    }
    function launchSelectedGame() {
        if (filteredGames.length === 0) return
        launchGame(filteredGames[selectedIndex])
    }

    Process {
        id: launchProcess
        running: false
    }

    function launchGame(game) {
        launchProcess.command = ["sh", "-c", game.exec]
        launchProcess.running = true
        if (config?.behavior?.close_on_launch ?? true) launcher.closeRequested()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // LAYOUT PRINCIPAL
    // ═══════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        anchors.margins: spacing

        // ── SIDEBAR GAUCHE ───────────────────────────────────────────────────
        Rectangle {
            id: sidebar
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: sidebarWidth - spacing
            radius: 12
            color: "transparent"
            border.color: "transparent"
            border.width: 1

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 0
                spacing: 4

                // Bouton ALL
                Rectangle {
                    width: parent.width
                    height: width
                    radius: 22
                    color: selectedSource === "all"
                        ? Qt.rgba(
                            parseInt((colors.color5||"#73ff00").slice(1,3),16)/255,
                            parseInt((colors.color5||"#73ff00").slice(3,5),16)/255,
                            parseInt((colors.color5||"#73ff00").slice(5,7),16)/255,
                            0.22)
                        : (allMouse.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent")
                    border.color: selectedSource === "all" ? (colors.color5 || "#73ff00") : "transparent"
                    border.width: 2
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "⊞"
                            font.pixelSize: 20
                            color: selectedSource === "all" ? (colors.color5||"#73ff00") : (colors.foreground||"#ffffff")
                            opacity: selectedSource === "all" ? 1.0 : 0.45
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "All"
                            font.pixelSize: 9
                            font.bold: selectedSource === "all"
                            font.family: "Open Sans Regular"
                            color: selectedSource === "all" ? (colors.color5||"#73ff00") : (colors.foreground||"#ffffff")
                            opacity: selectedSource === "all" ? 1.0 : 0.4
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    Rectangle {
                        visible: selectedSource === "all"
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.topMargin: -3; anchors.rightMargin: -3
                        width: 18; height: 18; radius: 9
                        color: colors.color5 || "#73ff00"
                        Text { anchors.centerIn: parent; text: gamesData.length; font.pixelSize: 8; font.bold: true; color: "#1a1a1a" }
                    }

                    MouseArea {
                        id: allMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { launcher.selectedSource = "all"; launcher.forceActiveFocus() }
                    }
                }

                // Séparateur
                Rectangle {
                    width: parent.width * 0.6
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                // Boutons par source
                Repeater {
                    model: availableSources

                    Rectangle {
                        property string src: modelData
                        property bool active: launcher.selectedSource === src
                        property int count: gamesData.filter(g => g.source === src).length
                        property var info: launcher.sourceInfo(src)

                        width: parent.width
                        height: width
                        radius: 22
                        color: active
                            ? Qt.rgba(
                                parseInt((colors.color5||"#73ff00").slice(1,3),16)/255,
                                parseInt((colors.color5||"#73ff00").slice(3,5),16)/255,
                                parseInt((colors.color5||"#73ff00").slice(5,7),16)/255,
                                0.22)
                            : (srcMouse.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent")
                        border.color: active ? (colors.color5||"#73ff00") : "transparent"
                        border.width: 2
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: info.icon
                                font.family: info.font
                                font.pixelSize: 20
                                color: active ? (colors.color5||"#73ff00") : (colors.foreground||"#ffffff")
                                opacity: active ? 1.0 : 0.45
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: info.label
                                font.pixelSize: 9
                                font.bold: active
                                font.family: "Open Sans Regular"
                                color: active ? (colors.color5||"#73ff00") : (colors.foreground||"#ffffff")
                                opacity: active ? 1.0 : 0.4
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        // Badge count actif
                        Rectangle {
                            visible: active
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.topMargin: -3; anchors.rightMargin: -3
                            width: 18; height: 18; radius: 9
                            color: colors.color5 || "#73ff00"
                            Text { anchors.centerIn: parent; text: count; font.pixelSize: 8; font.bold: true; color: "#1a1a1a" }
                        }

                        // Tooltip au survol
                        Rectangle {
                            visible: srcMouse.containsMouse && !active
                            anchors.left: parent.right; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: tipTxt.width + 16; height: 26; radius: 8
                            color: "#1a1a1a"
                            border.color: Qt.rgba(1,1,1,0.2); border.width: 1
                            z: 999
                            Text {
                                id: tipTxt
                                anchors.centerIn: parent
                                text: info.label + " (" + count + ")"
                                font.pixelSize: 11; font.family: "Open Sans Regular"; color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: srcMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { launcher.selectedSource = src; launcher.forceActiveFocus() }
                        }
                    }
                }
            }
        }
        // ── FIN SIDEBAR ──────────────────────────────────────────────────────

        // ── ZONE CONTENU PRINCIPALE ──────────────────────────────────────────
        Item {
            id: mainContent
            anchors.left: sidebar.right
            anchors.leftMargin: spacing
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // Barre de recherche
            Rectangle {
                id: searchBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                radius: 22
                color: Qt.rgba(
                    parseInt((colors.background||"#1a1a1a").slice(1,3),16)/255,
                    parseInt((colors.background||"#1a1a1a").slice(3,5),16)/255,
                    parseInt((colors.background||"#1a1a1a").slice(5,7),16)/255,
                    0.6)
                border.color: searchField.activeFocus ? (colors.color5||"#73ff00") : Qt.rgba(1,1,1,0.15)
                border.width: searchField.activeFocus ? 2 : 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 15
                    color: colors.foreground || "#ffffff"
                    opacity: 0.5
                }

                TextField {
                    id: searchField
                    anchors.left: parent.left; anchors.leftMargin: 38
                    anchors.right: clearBtn.left; anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 4
                    placeholderText: "Rechercher un jeu…"
                    placeholderTextColor: Qt.rgba(1,1,1,0.3)
                    color: colors.foreground || "#ffffff"
                    font.pixelSize: 14
                    font.family: "Open Sans Regular"
                    background: Item {}
                    Keys.onEscapePressed: { launcher.searchText = ""; searchField.clear(); launcher.forceActiveFocus() }
                    Keys.onReturnPressed:  { launcher.launchSelectedGame() }
                    Keys.onUpPressed:      { launcher.navigateUp();    launcher.forceActiveFocus() }
                    Keys.onDownPressed:    { launcher.navigateDown();  launcher.forceActiveFocus() }
                    Keys.onLeftPressed:    { launcher.navigateLeft();  launcher.forceActiveFocus() }
                    Keys.onRightPressed:   { launcher.navigateRight(); launcher.forceActiveFocus() }
                    onTextChanged: launcher.searchText = text
                }

                Rectangle {
                    id: clearBtn
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 13
                    visible: launcher.searchText !== ""
                    color: clearMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: colors.foreground||"#ffffff"; opacity: 0.7 }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { launcher.searchText = ""; searchField.clear(); launcher.forceActiveFocus() }
                    }
                }
            }

            // Layout HORIZONTAL
            ColumnLayout {
                visible: launcher.orientation === "horizontal"
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: searchBar.bottom; anchors.bottom: parent.bottom
                anchors.topMargin: spacing
                spacing: spacing

                ListView {
                    id: gamesCarouselH
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: launcher.spacing
                    clip: true
                    model: filteredGames
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 300
                    preferredHighlightBegin: width / 2 - itemWidth / 2
                    preferredHighlightEnd: width / 2 + itemWidth / 2
                    currentIndex: selectedIndex
                    onCurrentIndexChanged: selectedIndex = currentIndex

                    MouseArea {
                        anchors.fill: parent; propagateComposedEvents: true; focus: false
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0) navigateLeft()
                            else navigateRight()
                            launcher.forceActiveFocus(); wheel.accepted = true
                        }
                        onClicked: (mouse) => { launcher.forceActiveFocus(); mouse.accepted = false }
                    }

                    delegate: GameCard {
                        width: itemWidth; height: itemHeight
                        gameName: modelData.name || "Unknown"
                        gameImage: modelData.image || ""
                        gameCategory: modelData.category || ""
                        gameSource: modelData.source || ""
                        isFavorite: modelData.favorite || false
                        isSelected: index === selectedIndex
                        gameColors: colors
                        lastPlayed: modelData.last_played || 0
                        scale: isSelected ? 1.0 : 0.85
                        opacity: isSelected ? 1.0 : 0.6
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        onClicked: { gamesCarouselH.currentIndex = index; launcher.forceActiveFocus() }
                        onLaunchRequested: { launchGame(modelData) }
                    }

                    Rectangle {
                        visible: filteredGames.length === 0
                        anchors.centerIn: parent; width: 300; height: 200; color: "transparent"
                        Column {
                            anchors.centerIn: parent; spacing: 16
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "🎮"; font.pixelSize: 64; opacity: 0.3 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Aucun jeu trouvé"; font.pixelSize: 18; color: colors.foreground||"#ffffff"; opacity: 0.7 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: launcher.searchText !== "" ? "Essaie un autre terme" : "Aucun jeu dans cette source"; font.pixelSize: 14; color: colors.foreground||"#ffffff"; opacity: 0.5 }
                        }
                    }
                }

                // Indicateurs bas
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 40; color: "transparent"
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Repeater {
                            model: Math.min(filteredGames.length, 10)
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: colors.color5 || "#00ffff"
                                opacity: index === selectedIndex ? 1.0 : 0.3
                                scale: index === selectedIndex ? 1.3 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Behavior on scale { NumberAnimation { duration: 200 } }
                            }
                        }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: filteredGames.length > 0 ? (selectedIndex + 1) + " / " + filteredGames.length : "0"; font.pixelSize: 12; color: colors.foreground||"#ffffff"; opacity: 0.6 }
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "← → Navigate  ⏎ Launch  Esc Close"; font.pixelSize: 11; color: colors.foreground||'#15ff00'; opacity: 0.5 }
                }
            }

            // Layout VERTICAL
            RowLayout {
                visible: launcher.orientation === "vertical"
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: searchBar.bottom; anchors.bottom: parent.bottom
                anchors.topMargin: spacing
                spacing: spacing

                GridView {
                    id: gamesCarouselV
                    Layout.preferredWidth: (itemWidth * gridColumns) + (spacing * (gridColumns - 1))
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    cellWidth: itemWidth + spacing; cellHeight: itemHeight + spacing
                    clip: true; model: filteredGames
                    currentIndex: selectedIndex
                    onCurrentIndexChanged: selectedIndex = currentIndex

                    MouseArea {
                        anchors.fill: parent; propagateComposedEvents: true; focus: false
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0) navigateUp()
                            else navigateDown()
                            launcher.forceActiveFocus(); wheel.accepted = true
                        }
                        onClicked: (mouse) => { launcher.forceActiveFocus(); mouse.accepted = false }
                    }

                    delegate: GameCard {
                        width: itemWidth; height: itemHeight
                        gameName: modelData.name || "Unknown"
                        gameImage: modelData.image || ""
                        gameCategory: modelData.category || ""
                        gameSource: modelData.source || ""
                        isFavorite: modelData.favorite || false
                        isSelected: index === selectedIndex
                        gameColors: colors
                        lastPlayed: modelData.last_played || 0
                        scale: isSelected ? 1.0 : 0.85
                        opacity: isSelected ? 1.0 : 0.6
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        onClicked: { gamesCarouselV.currentIndex = index; launcher.forceActiveFocus() }
                        onLaunchRequested: { launchGame(modelData) }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true; Layout.preferredWidth: 50
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter; color: "transparent"
                    Column {
                        anchors.centerIn: parent; spacing: 12
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                            Repeater {
                                model: Math.min(filteredGames.length, 10)
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: colors.color5||"#00ffff"
                                    opacity: index === selectedIndex ? 1.0 : 0.3
                                    scale: index === selectedIndex ? 1.3 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                    Behavior on scale { NumberAnimation { duration: 200 } }
                                }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: filteredGames.length > 0 ? (selectedIndex+1)+"/"+filteredGames.length : "0"; font.pixelSize: 10; color: colors.foreground||"#ffffff"; opacity: 0.6 }
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "↑↓"; font.pixelSize: 10; color: colors.foreground||'#15ff00'; opacity: 0.5 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "⏎";  font.pixelSize: 10; color: colors.foreground||'#15ff00'; opacity: 0.5 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Esc"; font.pixelSize: 9;  color: colors.foreground||'#15ff00'; opacity: 0.5 }
                        }
                    }
                }
            }
        }
    }

    // Entrance animation
    ParallelAnimation {
        running: true
        NumberAnimation { target: launcher; property: "scale";   from: 0.8; to: 1.0; duration: config?.animations?.duration_ms ?? 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: launcher; property: "opacity"; from: 0;   to: 1.0; duration: config?.animations?.duration_ms ?? 300; easing.type: Easing.OutCubic }
    }
}
