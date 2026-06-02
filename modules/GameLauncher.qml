import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Rectangle {
    id: launcher
    I18n { id: i18n }

    // Catch-all — prevents clicks on empty areas from reaching the quit MouseArea
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: {} }

    required property var config
    property var gamesData: []
    property var filteredGames: []
    property var colors: ({})
    property int selectedIndex: 0
    property string searchText: ""
    property string selectedSource: "all"
    property bool isLoading: false

    // Config values
    property string orientation: config?.display?.orientation ?? "horizontal"
    property int gridColumns: config?.display?.grid_size?.[0] ?? 1
    property int gridRows: config?.display?.grid_size?.[1] ?? 3
    property int effectiveRows: orientation === "horizontal" ? 1 : gridRows
    property int itemWidth: config?.display?.item_width ?? 200
    property int itemHeight: config?.display?.item_height ?? 300
    property int spacing: config?.display?.spacing ?? 20

    property int sidebarWidth: 68
    property bool bigPictureMode: config?.behavior?.start_in_bigpicture ?? false
    property int screenW: 1920
    property int screenH: 1080
    property int favoriteCount: {
        var n = 0
        for (var i = 0; i < gamesData.length; i++)
            if (gamesData[i] && gamesData[i].favorite) n++
        return n
    }

    width: bigPictureMode ? screenW
        : orientation === "vertical"
            ? sidebarWidth + spacing * 3 + (itemWidth + spacing) * gridColumns + 50
            : sidebarWidth + spacing + (itemWidth * gridColumns) + (spacing * (gridColumns + 1))
    height: bigPictureMode ? screenH : (itemHeight * effectiveRows) + (spacing * (effectiveRows + 1)) + 60 + (2 * spacing)

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

    onGridColumnsChanged: console.log("→ gridColumns =", gridColumns)
    onGridRowsChanged:    console.log("→ gridRows =", gridRows)
    onOrientationChanged: console.log("→ orientation =", orientation)

    Component.onCompleted: {
        console.log("GameLauncher ready — gridColumns:", gridColumns, "gridRows:", gridRows, "orientation:", orientation)
        launcher.forceActiveFocus()
        loadGames()
        gamepadService.running = true
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
                Qt.quit()
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
        } else if (event.key === Qt.Key_F && (event.modifiers & Qt.AltModifier) && !searchField.activeFocus) {
            toggleFavorite(null); event.accepted = true
        } else if (event.key === Qt.Key_F5 && !gamesProcess.running) {
            loadGames(); event.accepted = true
        } else if (event.key === Qt.Key_B && (event.modifiers & Qt.AltModifier)) {
            launcher.bigPictureMode = !launcher.bigPictureMode
            if (launcher.bigPictureMode) bpView.forceActiveFocus()
            else launcher.forceActiveFocus()
            event.accepted = true
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

    Keys.onEscapePressed: Qt.quit()

    onSearchTextChanged:   filterGames()
    readonly property string _backendPath: Qt.resolvedUrl("service/backend.py").toString().replace("file://", "")

    onSelectedSourceChanged: {
        filterGames()
        if (config?.behavior?.remember_source ?? false) {
            saveStateProcess.command = ["python3", _backendPath, "save-state", "last_source", selectedSource]
            saveStateProcess.running = true
        }
    }

    onSelectedIndexChanged: {
        if (config?.behavior?.remember_source ?? false) {
            const game = filteredGames[selectedIndex]
            if (game) {
                const k = game.appid ? String(game.appid) + ":" + (game.source || "")
                                     : game.name + ":" + (game.source || "")
                saveGameProcess.command = ["python3", _backendPath, "save-state", "last_game", k]
                saveGameProcess.running = true
            }
        }
    }

    signal closeRequested()
    signal openConfigRequested()

    Process {
        id: gamesProcess
        command: ["python3", Qt.resolvedUrl("service/backend.py").toString().replace("file://", "")]
        running: false
        property string output: ""
        stdout: SplitParser { onRead: data => gamesProcess.output += data }
        onExited: {
            launcher.isLoading = false
            try {
                const result = JSON.parse(gamesProcess.output)
                gamesData = result.games || []
                colors = result.colors || {}
                filterGames()

                const behavior = result.config?.behavior || {}
                const rememberSource = behavior.remember_source ?? false
                const defaultIdx = Math.max(0, behavior.default_source_index ?? 0)

                if (rememberSource && result.last_source) {
                    selectedSource = result.last_source
                } else if (defaultIdx > 0) {
                    const seen = {}, sources = []
                    for (const g of result.games || []) {
                        const s = g.source || ""
                        if (s && !seen[s]) { seen[s] = true; sources.push(s) }
                    }
                    selectedSource = sources[defaultIdx - 1] || "all"
                }

                if (rememberSource && result.last_game) {
                    const games = result.games || []
                    const src = selectedSource
                    let filtered = games.slice()
                    if (src === "favorites") filtered = filtered.filter(g => g.favorite)
                    else if (src !== "all") filtered = filtered.filter(g => (g.source || "") === src)
                    const idx = filtered.findIndex(g => {
                        const k = g.appid ? String(g.appid) + ":" + (g.source || "")
                                          : g.name + ":" + (g.source || "")
                        return k === result.last_game
                    })
                    if (idx >= 0) selectedIndex = idx
                }
            } catch (e) {
                console.error("Failed to parse games data:", e)
            }
            gamesProcess.output = ""
        }
    }

    function loadGames() { launcher.isLoading = true; gamesProcess.running = true }

    function filterGames() {
        let result = gamesData.slice()
        if (selectedSource === "favorites")
            result = result.filter(g => g.favorite)
        else if (selectedSource !== "all")
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
        else if (orientation === "vertical" && selectedIndex > 0) selectedIndex--
    }
    function navigateRight() {
        if (orientation === "horizontal" && selectedIndex < filteredGames.length - 1) selectedIndex++
        else if (orientation === "vertical" && selectedIndex < filteredGames.length - 1) selectedIndex++
    }
    function navigateUp() {
        if (orientation === "vertical" && selectedIndex >= gridColumns) selectedIndex -= gridColumns
    }
    function navigateDown() {
        if (orientation === "vertical" && selectedIndex + gridColumns < filteredGames.length) selectedIndex += gridColumns
        else if (orientation === "vertical" && selectedIndex < filteredGames.length - 1) selectedIndex = filteredGames.length - 1
    }
    function launchSelectedGame() {
        if (filteredGames.length === 0) return
        launchGame(filteredGames[selectedIndex])
    }
    function navigateSource(direction) {
        var sources = ["all"]
        if (favoriteCount > 0) sources.push("favorites")
        sources = sources.concat(availableSources)
        var current = sources.indexOf(selectedSource)
        if (current < 0) current = 0
        if (direction === "up")
            current = (current - 1 + sources.length) % sources.length
        else
            current = (current + 1) % sources.length
        selectedSource = sources[current]
        selectedIndex = 0
    }

    function toggleFavorite(game) {
        if (!game) {
            if (filteredGames.length === 0) return
            game = filteredGames[selectedIndex]
        }
        var gameName   = game.name
        var gameSource = game.source || ""
        var newFav = !game.favorite
        // Optimistic local update
        var updated = []
        for (var i = 0; i < gamesData.length; i++) {
            if (gamesData[i].name === game.name && gamesData[i].source === game.source) {
                var copy = {}
                for (var k in gamesData[i]) copy[k] = gamesData[i][k]
                copy.favorite = newFav
                updated.push(copy)
            } else {
                updated.push(gamesData[i])
            }
        }
        gamesData = updated
        // If we just removed the last favorite while on the favorites tab, go back to "all"
        if (selectedSource === "favorites" && !newFav) {
            var stillHasFav = false
            for (var j = 0; j < gamesData.length; j++)
                if (gamesData[j].favorite) { stillHasFav = true; break }
            if (!stillHasFav) selectedSource = "all"
        }
        filterGames()
        // Follow the game to its new position after reorder (favorites first, etc.)
        var newIdx = filteredGames.findIndex(function(g) {
            return g.name === gameName && (g.source || "") === gameSource
        })
        if (newIdx >= 0) selectedIndex = newIdx
        // Persist to file
        toggleFavoriteProcess.command = [
            "python3",
            Qt.resolvedUrl("service/backend.py").toString().replace("file://", ""),
            "toggle",
            game.name,
            game.source || ""
        ]
        toggleFavoriteProcess.running = true
    }

    Process {
        id: launchProcess
        running: false
    }

    Process {
        id: toggleFavoriteProcess
        running: false
        stdout: SplitParser { onRead: data => {} }
    }

    Process {
        id: saveStateProcess
        running: false
    }

    Process {
        id: saveGameProcess
        running: false
    }

    function launchGame(game, cardItem) {
        launchProcess.command = ["sh", "-c", "setsid " + game.exec + " &"]
        launchProcess.running = true
        launcher.enabled = false
        if (launcher.bigPictureMode) {
            bpView.showLaunch(game.logo || "", game.name || "")
        } else if (config?.behavior?.close_on_launch ?? true) {
            launchOverlay.colors = colors
            var pos = cardItem ? cardItem.mapToItem(launcher, 0, 0) : null
            launchOverlay.show(
                game.image || "",
                game.name || "",
                game.logo || "",
                pos ? pos.x : 0,
                pos ? pos.y : 0,
                cardItem ? cardItem.width : launcher.width,
                cardItem ? cardItem.height : launcher.height
            )
        }
    }

    Process {
    id: gamepadService
    command: ["/usr/bin/python3", Qt.resolvedUrl("service/gamepad.py").toString().replace("file://", "")]
    running: false   // ← false, on démarre dans onCompleted

    stdout: SplitParser {
        onRead: function(line) {
            try {
                var evt = JSON.parse(line)
                if (evt.type === "button") {
                    gamepadHandler.handle(evt.action)
                }
            } catch(e) {}
        }
    }
}

    // ── Handler des actions manette ────────────────────────────────────────────
    QtObject {
        id: gamepadHandler

        function handle(action) {
            switch(action) {
                case "left":
                    navigateLeft()
                    break
                case "right":
                    navigateRight()
                    break
                case "select":
                    launchSelectedGame()
                    break
                case "close":
                    launcher.closeRequested()
                    break
                case "toggle":
                    launcher.visible = !launcher.visible
                    break
                case "bigpicture":
                    launcher.bigPictureMode = !launcher.bigPictureMode
                    if (launcher.bigPictureMode) bpView.forceActiveFocus()
                    else launcher.forceActiveFocus()
                    break
                case "up":
                    if (orientation === "vertical") navigateUp()
                    else navigateSource("up")
                    break
                case "down":
                    if (orientation === "vertical") navigateDown()
                    else navigateSource("down")
                    break
                case "source_prev":
                    navigateSource("up")
                    break
                case "source_next":
                    navigateSource("down")
                    break
                case "favorite":
                    toggleFavorite(null)
                    break
            }
        }
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
                            text: i18n.t("all")
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

                // Bouton Favoris — visible uniquement si au moins 1 favori
                Rectangle {
                    visible: launcher.favoriteCount > 0
                    width: parent.width
                    height: width
                    radius: 22
                    color: launcher.selectedSource === "favorites"
                        ? Qt.rgba(
                            parseInt((colors.color5||"#73ff00").slice(1,3),16)/255,
                            parseInt((colors.color5||"#73ff00").slice(3,5),16)/255,
                            parseInt((colors.color5||"#73ff00").slice(5,7),16)/255,
                            0.22)
                        : (favSrcMouse.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent")
                    border.color: launcher.selectedSource === "favorites" ? (colors.color5 || "#73ff00") : "transparent"
                    border.width: 2
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ""
                            font.family: "Font Awesome 7 Free Solid"
                            font.pixelSize: 18
                            color: launcher.selectedSource === "favorites" ? (colors.color5||"#73ff00") : (colors.foreground||"#ffffff")
                            opacity: launcher.selectedSource === "favorites" ? 1.0 : 0.45
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: i18n.t("favs")
                            font.pixelSize: 9
                            font.bold: launcher.selectedSource === "favorites"
                            font.family: "Open Sans Regular"
                            color: launcher.selectedSource === "favorites" ? (colors.color5||"#73ff00") : (colors.foreground||"#ffffff")
                            opacity: launcher.selectedSource === "favorites" ? 1.0 : 0.4
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    Rectangle {
                        visible: launcher.selectedSource === "favorites"
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.topMargin: -3; anchors.rightMargin: -3
                        width: 18; height: 18; radius: 9
                        color: colors.color5 || "#73ff00"
                        Text { anchors.centerIn: parent; text: launcher.favoriteCount; font.pixelSize: 8; font.bold: true; color: "#1a1a1a" }
                    }

                    MouseArea {
                        id: favSrcMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { launcher.selectedSource = "favorites"; launcher.forceActiveFocus() }
                    }
                }

                // Séparateur favs / sources (visible si favoris présents)
                Rectangle {
                    visible: launcher.favoriteCount > 0
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

            // Settings button — bottom-right of sidebar
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.bottomMargin: 8
                anchors.rightMargin: 8
                width: 32; height: 32; radius: 10
                color: gearMouse.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: "\uf013"
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 15
                    color: colors.foreground || "#ffffff"
                    opacity: gearMouse.containsMouse ? 0.85 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    id: gearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launcher.openConfigRequested()
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
                    placeholderText: i18n.t("search")
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

                // Big Picture toggle button
                Rectangle {
                    id: bigPictureBtn
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32; height: 32; radius: 16
                    color: launcher.bigPictureMode
                        ? (colors.color5 || "#73ff00")
                        : (bpMouse.containsMouse ? Qt.rgba(1,1,1,0.18) : Qt.rgba(1,1,1,0.08))
                    border.color: launcher.bigPictureMode ? "transparent" : Qt.rgba(1,1,1,0.2)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "\uf26c"
                        font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 14
                        color: launcher.bigPictureMode ? "#1a1a1a" : (colors.foreground || "#ffffff")
                    }
                    MouseArea {
                        id: bpMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            launcher.bigPictureMode = !launcher.bigPictureMode
                            if (launcher.bigPictureMode) bpView.forceActiveFocus()
                            else launcher.forceActiveFocus()
                        }
                    }
                }

                Rectangle {
                    id: clearBtn
                    anchors.right: bigPictureBtn.left; anchors.rightMargin: 4
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
                    cacheBuffer: itemWidth
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
                        gameImageAnimated: Math.abs(index - selectedIndex) <= 1 ? (modelData.image_animated || "") : ""
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
                        onLaunchRequested: { launchGame(modelData, this) }
                        onFavoriteToggled: toggleFavorite(modelData)
                    }

                    Rectangle {
                        visible: filteredGames.length === 0
                        anchors.centerIn: parent; width: 300; height: 200; color: "transparent"

                        // Chargement — points qui sautent
                        Row {
                            visible: launcher.isLoading
                            anchors.centerIn: parent
                            spacing: 14
                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    width: 12; height: 12; radius: 6
                                    color: colors.color5 || "#00ffff"
                                    y: 0
                                    SequentialAnimation on y {
                                        loops: Animation.Infinite
                                        running: launcher.isLoading
                                        PauseAnimation  { duration: index * 160 }
                                        NumberAnimation { to: -18; duration: 350; easing.type: Easing.OutCubic }
                                        NumberAnimation { to:   0; duration: 350; easing.type: Easing.InCubic }
                                        PauseAnimation  { duration: (2 - index) * 160 }
                                    }
                                }
                            }
                        }

                        // Aucun jeu trouvé
                        Column {
                            visible: !launcher.isLoading
                            anchors.centerIn: parent; spacing: 16
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "🎮"; font.pixelSize: 64; opacity: 0.3 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: i18n.t("no_games"); font.pixelSize: 18; color: colors.foreground||"#ffffff"; opacity: 0.7 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: launcher.searchText !== "" ? i18n.t("try_other") : i18n.t("no_games_source"); font.pixelSize: 14; color: colors.foreground||"#ffffff"; opacity: 0.5 }
                        }
                    }
                }

                // Indicateurs bas
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 40; color: "transparent"
                    QtObject {
                        id: hd
                        property int vis: Math.min(10, filteredGames.length || 1)
                        property int step: 16
                        property int visW: vis * step
                        property int maxX: Math.max(0, filteredGames.length * step - visW)
                        property int scrollTo: Math.min(maxX, Math.max(0, selectedIndex * step + 4 - visW / 2))
                    }
                    Row {
                        anchors.centerIn: parent; spacing: 12
                        Rectangle {
                            width: hd.visW; height: 8; clip: true; color: "transparent"
                            Row {
                                spacing: 8
                                x: -hd.scrollTo
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Repeater {
                                    model: filteredGames.length
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
                        }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: filteredGames.length > 0 ? (selectedIndex + 1) + " / " + filteredGames.length : "0"; font.pixelSize: 12; color: colors.foreground||"#ffffff"; opacity: 0.6 }
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: i18n.t("help_horiz"); font.pixelSize: 11; color: colors.foreground||'#15ff00'; opacity: 0.5 }
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
                    Layout.preferredWidth: (itemWidth + spacing) * gridColumns
                    Layout.maximumWidth: (itemWidth + spacing) * gridColumns
                    Layout.maximumHeight: (itemHeight + spacing) * effectiveRows
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    cellWidth: itemWidth + spacing; cellHeight: itemHeight + spacing
                    clip: true; model: filteredGames
                    interactive: false
                    cacheBuffer: itemHeight
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
                        gameImageAnimated: Math.abs(index - selectedIndex) <= gridColumns ? (modelData.image_animated || "") : ""
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
                        onLaunchRequested: { launchGame(modelData, this) }
                        onFavoriteToggled: toggleFavorite(modelData)
                    }
                }

                Rectangle {
                    Layout.fillHeight: true; Layout.preferredWidth: 50
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter; color: "transparent"
                    Column {
                        anchors.centerIn: parent; spacing: 12
                        QtObject {
                            id: vd
                            property int vis: Math.min(10, filteredGames.length || 1)
                            property int step: 16
                            property int visH: vis * step
                            property int maxY: Math.max(0, filteredGames.length * step - visH)
                            property int scrollTo: Math.min(maxY, Math.max(0, selectedIndex * step + 4 - visH / 2))
                        }
                        Rectangle {
                            width: 8; height: vd.visH; clip: true; color: "transparent"
                            anchors.horizontalCenter: parent.horizontalCenter
                            Column {
                                spacing: 8
                                y: -vd.scrollTo
                                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Repeater {
                                    model: filteredGames.length
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

    // ── BIG PICTURE OVERLAY ──────────────────────────────────────────────────
    BigPictureView {
        id: bpView
        anchors.fill: parent
        visible: launcher.bigPictureMode
        filteredGames: launcher.filteredGames
        colors: launcher.colors
        selectedIndex: launcher.selectedIndex
        selectedSource: launcher.selectedSource
        favoriteCount: launcher.favoriteCount
        availableSources: launcher.availableSources

        onExitRequested: {
            launcher.bigPictureMode = false
            launcher.forceActiveFocus()
        }
        onOpenConfigRequested: launcher.openConfigRequested()
        onLaunchRequested: (game) => launchGame(game, null)
        onFavoriteToggleRequested: (game) => toggleFavorite(game)
        onSourceSelected: (src) => { launcher.selectedSource = src }
        onIndexChanged: (idx) => { launcher.selectedIndex = idx }
        onLaunchDone: Qt.quit()
    }

    // Entrance animation
    ParallelAnimation {
        running: true
        NumberAnimation { target: launcher; property: "scale";   from: 0.8; to: 1.0; duration: config?.animations?.duration_ms ?? 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: launcher; property: "opacity"; from: 0;   to: 1.0; duration: config?.animations?.duration_ms ?? 300; easing.type: Easing.OutCubic }
    }
    LaunchOverlay {
        id: launchOverlay
        onDone: Qt.quit()
    }
}
