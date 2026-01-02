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
    property string orientation: config?.display?.orientation ?? "horizontal"
    property int gridColumns: config?.display?.grid_size?.[0] ?? 4
    property int gridRows: config?.display?.grid_size?.[1] ?? 3
    property int itemWidth: config?.display?.item_width ?? 200
    property int itemHeight: config?.display?.item_height ?? 300
    property int spacing: config?.display?.spacing ?? 20

    // Dimensions adaptées selon l'orientation
    width: (itemWidth * gridColumns) + (spacing * (gridColumns + 1))
    height: (itemHeight * gridRows) + (spacing * (gridRows + 1)) + 60


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
        if (orientation === "horizontal" && selectedIndex > 0) {
            selectedIndex--;
        } else if (orientation === "vertical" && selectedIndex % gridColumns > 0) {
            selectedIndex--;
        }
    }

    function navigateRight() {
        if (orientation === "horizontal" && selectedIndex < filteredGames.length - 1) {
            selectedIndex++;
        } else if (orientation === "vertical" && selectedIndex % gridColumns < gridColumns - 1 && selectedIndex < filteredGames.length - 1) {
            selectedIndex++;
        }
    }

    function navigateUp() {
        if (orientation === "vertical" && selectedIndex >= gridColumns) {
            selectedIndex -= gridColumns;
        }
    }

    function navigateDown() {
        if (orientation === "vertical" && selectedIndex + gridColumns < filteredGames.length) {
            selectedIndex += gridColumns;
        }
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

    // Layout adaptatif selon l'orientation
    Item {
        anchors.fill: parent
        anchors.margins: spacing

        // Layout HORIZONTAL (ColumnLayout: ListView en haut, indicateurs en bas)
        ColumnLayout {
            visible: launcher.orientation === "horizontal"
            anchors.fill: parent
            spacing: launcher.spacing

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
                    anchors.fill: parent
                    propagateComposedEvents: true
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) navigateLeft()
                        else if (wheel.angleDelta.y < 0) navigateRight()
                        wheel.accepted = true
                    }
                    onClicked: (mouse) => { mouse.accepted = false }
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
                    scale: isSelected ? 1.0 : 0.85
                    opacity: isSelected ? 1.0 : 0.6

                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    onClicked: { gamesCarouselH.currentIndex = index; launcher.forceActiveFocus(); }
                    onLaunchRequested: { launchGame(modelData); }
                }

                Rectangle {
                    visible: filteredGames.length === 0
                    anchors.centerIn: parent
                    width: 300
                    height: 200
                    color: "transparent"

                    Column {
                        anchors.centerIn: parent
                        spacing: 16
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "🎮"; font.pixelSize: 64; opacity: 0.3 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No games available"; font.pixelSize: 18; color: colors.foreground || "#ffffff"; opacity: 0.7 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Add games to games.toml or install Steam games"; font.pixelSize: 14; color: colors.foreground || "#ffffff"; opacity: 0.5 }
                    }
                }
            }

            // Indicateurs HORIZONTAUX (en bas)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: 8
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

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: filteredGames.length > 0 ? (selectedIndex + 1) + " / " + filteredGames.length : "0"
                    font.pixelSize: 12
                    color: colors.foreground || "#ffffff"
                    opacity: 0.6
                }

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

        // Layout VERTICAL (RowLayout: GridView à gauche, indicateurs à droite)
        RowLayout {
            visible: launcher.orientation === "vertical"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: launcher.spacing

            GridView {
                id: gamesCarouselV
                Layout.preferredWidth: (itemWidth * gridColumns) + (spacing * (gridColumns - 1))
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

                cellWidth: itemWidth + spacing
                cellHeight: itemHeight + spacing
                clip: true
                model: filteredGames

                currentIndex: selectedIndex
                onCurrentIndexChanged: selectedIndex = currentIndex

                MouseArea {
                    anchors.fill: parent
                    propagateComposedEvents: true
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) navigateUp()
                        else if (wheel.angleDelta.y < 0) navigateDown()
                        wheel.accepted = true
                    }
                    onClicked: (mouse) => { mouse.accepted = false }
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
                    scale: isSelected ? 1.0 : 0.85
                    opacity: isSelected ? 1.0 : 0.6

                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    onClicked: { gamesCarouselV.currentIndex = index; launcher.forceActiveFocus(); }
                    onLaunchRequested: { launchGame(modelData); }
                }

                Rectangle {
                    visible: filteredGames.length === 0
                    anchors.centerIn: parent
                    width: 300
                    height: 200
                    color: "transparent"

                    Column {
                        anchors.centerIn: parent
                        spacing: 16
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "🎮"; font.pixelSize: 64; opacity: 0.3 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No games available"; font.pixelSize: 18; color: colors.foreground || "#ffffff"; opacity: 0.7 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Add games to games.toml or install Steam games"; font.pixelSize: 14; color: colors.foreground || "#ffffff"; opacity: 0.5 }
                    }
                }
            }

            // Indicateurs VERTICAUX (à droite)
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 50
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                color: "transparent"

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    // Dots verticaux
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
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

                    // Counter
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: filteredGames.length > 0 ? (selectedIndex + 1) + "/" + filteredGames.length : "0"
                        font.pixelSize: 10
                        color: colors.foreground || "#ffffff"
                        opacity: 0.6
                    }

                    // Hints verticaux
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "↑↓"; font.pixelSize: 10; color: colors.foreground || '#15ff00'; opacity: 0.5 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "⏎"; font.pixelSize: 10; color: colors.foreground || '#15ff00'; opacity: 0.5 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Esc"; font.pixelSize: 9; color: colors.foreground || '#15ff00'; opacity: 0.5 }
                    }
                }
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
