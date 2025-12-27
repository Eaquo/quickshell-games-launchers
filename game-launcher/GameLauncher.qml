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

    // Config values
    property int gridColumns: config?.display?.grid_size?.[0] ?? 4
    property int gridRows: config?.display?.grid_size?.[1] ?? 3
    property int itemWidth: config?.display?.item_width ?? 200
    property int itemHeight: config?.display?.item_height ?? 300
    property int spacing: config?.display?.spacing ?? 20

    width: (itemWidth * gridColumns) + (spacing * (gridColumns + 1))
    height: itemHeight + (spacing * 2) + 100 // +100 for footer with dots and info

    color: "transparent"
    radius: 16

    // Background with blur
    Rectangle {
        id: background
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

    // Keyboard navigation
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            launcher.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            launchSelectedGame()
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            navigateLeft()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            navigateRight()
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            navigateUp()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            navigateDown()
            event.accepted = true
        }
    }

    signal closeRequested()

    // Process for loading games
    Process {
        id: gamesProcess
        command: ["python3", Qt.resolvedUrl("backend.py").toString().replace("file://", "")]
        running: false

        property string output: ""

        stdout: SplitParser {
            onRead: data => gamesProcess.output += data
        }

        onExited: {
            try {
                const result = JSON.parse(gamesProcess.output);
                gamesData = result.games || [];
                colors = result.colors || {};
                filterGames();
            } catch (e) {
                console.error("Failed to parse games data:", e);
                console.error("Output was:", gamesProcess.output);
            }
            gamesProcess.output = "";
        }
    }

    function loadGames() {
        gamesProcess.running = true;
    }

    function filterGames() {
        filteredGames = gamesData.slice(); // Clone array

        // Reset selection if out of bounds
        if (selectedIndex >= filteredGames.length) {
            selectedIndex = Math.max(0, filteredGames.length - 1);
        }
    }

    function navigateLeft() {
        if (selectedIndex > 0) {
            selectedIndex--;
        }
    }

    function navigateRight() {
        if (selectedIndex < filteredGames.length - 1) {
            selectedIndex++;
        }
    }

    function navigateUp() {
        // Navigation haut/bas désactivée pour le carrousel horizontal
    }

    function navigateDown() {
        // Navigation haut/bas désactivée pour le carrousel horizontal
    }

    function launchSelectedGame() {
        if (filteredGames.length === 0) return;

        const game = filteredGames[selectedIndex];
        launchGame(game);
    }

    // Process for launching games
    Process {
        id: launchProcess
        running: false
    }

    function launchGame(game) {
        console.log("Launching game:", game.name, "with command:", game.exec);

        launchProcess.command = ["sh", "-c", game.exec];
        launchProcess.running = true;

        if (config?.behavior?.close_on_launch ?? true) {
            launcher.closeRequested();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: spacing
        spacing: launcher.spacing

        // Games carousel (horizontal)
        ListView {
            id: gamesCarousel
            Layout.fillWidth: true
            Layout.fillHeight: true

            orientation: ListView.Horizontal
            spacing: launcher.spacing
            clip: true

            model: filteredGames

            // Smooth scrolling
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 300
            preferredHighlightBegin: width / 2 - itemWidth / 2
            preferredHighlightEnd: width / 2 + itemWidth / 2

            currentIndex: selectedIndex

            onCurrentIndexChanged: {
                selectedIndex = currentIndex
            }

            // Support de la molette de souris
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true

                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        // Molette vers le haut = jeu précédent (gauche)
                        navigateLeft()
                    } else if (wheel.angleDelta.y < 0) {
                        // Molette vers le bas = jeu suivant (droite)
                        navigateRight()
                    }
                    wheel.accepted = true
                }

                onClicked: (mouse) => {
                    mouse.accepted = false  // Laisser passer les clics aux cartes
                }
            }

            delegate: GameCard {
                width: itemWidth
                height: itemHeight

                gameName: modelData.name || "Unknown"
                gameImage: modelData.image || ""
                gameCategory: modelData.category || ""
                gameSource: modelData.source || ""
                isFavorite: modelData.favorite || false
                isSelected: index === selectedIndex
                gameColors: colors
                lastPlayed: modelData.last_played || 0

                // Scale effect for non-selected items
                scale: isSelected ? 1.0 : 0.85
                opacity: isSelected ? 1.0 : 0.6

                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }

                onClicked: {
                    gamesCarousel.currentIndex = index
                    launcher.forceActiveFocus();
                }

                onLaunchRequested: {
                    launchGame(modelData);
                }
            }

            // Empty state
            Rectangle {
                visible: filteredGames.length === 0
                anchors.centerIn: parent
                width: 300
                height: 200
                color: "transparent"

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🎮"
                        font.pixelSize: 64
                        opacity: 0.3
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No games available"
                        font.pixelSize: 18
                        color: colors.foreground || "#ffffff"
                        opacity: 0.7
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Add games to games.toml or install Steam games"
                        font.pixelSize: 14
                        color: colors.foreground || "#ffffff"
                        opacity: 0.5
                    }
                }
            }
        }

        // Position indicator (dots) + Info
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "transparent"

            Row {
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: Math.min(filteredGames.length, 10) // Max 10 dots

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: colors.color5 || "#00ffff"
                        opacity: index === selectedIndex ? 1.0 : 0.3

                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }

                        scale: index === selectedIndex ? 1.3 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 200 }
                        }
                    }
                }
            }

            // Game counter
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: filteredGames.length > 0 ? (selectedIndex + 1) + " / " + filteredGames.length : "0"
                font.pixelSize: 12
                color: colors.foreground || "#ffffff"
                opacity: 0.6
            }

            // Keyboard hints
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "← → Navigate  ⏎ Launch  Esc Close"
                font.pixelSize: 11
                color: colors.foreground || '#15ff00'
                opacity: 0.5
            }
        }
    }

    // Entrance animation
    ParallelAnimation {
        id: entranceAnimation
        running: true

        NumberAnimation {
            target: launcher
            property: "scale"
            from: 0.8
            to: 1.0
            duration: config?.animations?.duration_ms ?? 300
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: launcher
            property: "opacity"
            from: 0
            to: 1
            duration: config?.animations?.duration_ms ?? 300
            easing.type: Easing.OutCubic
        }
    }
}
