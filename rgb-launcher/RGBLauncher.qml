import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io



Rectangle {
    id: launcher

    required property var config
    property var modesData: []
    property var filteredModes: []
    property var colors: ({})
    property int selectedIndex: 0
    property int currentBrightness: 100
    property var loadedConfig: ({})

    // Config values
    property int itemWidth: config?.display?.item_width ?? 280
    property int itemHeight: config?.display?.item_height ?? 320
    property int spacing: config?.display?.spacing ?? 20
    property var screen: Quickshell.screens[0]

    width: itemWidth + (spacing * 2) + 100
    height: screen.height * 0.9

    color: colors.background || "#1a1a1a"
    opacity: 0.95
    radius: 16
    border.color: colors.color5 || "#00ffff"
    border.width: 2

    signal closeRequested()

    focus: true
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
            launchMode()
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            navigateUp()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            navigateDown()
            event.accepted = true
        }
    }

    function filterModes() {
        filteredModes = modesData.slice();
        if (selectedIndex >= filteredModes.length) {
            selectedIndex = Math.max(0, filteredModes.length - 1);
        }
    }

    function navigateUp() {
        if (selectedIndex > 0) {
            selectedIndex--;
            modesCarousel.positionViewAtIndex(selectedIndex, ListView.Center);
        }
    }

    function navigateDown() {
        if (selectedIndex < filteredModes.length - 1) {
            selectedIndex++;
            modesCarousel.positionViewAtIndex(selectedIndex, ListView.Center);
        }
    }

    property bool pendingClose: false

    function launchMode() {
        if (filteredModes.length === 0) return;

        const mode = filteredModes[selectedIndex];
        console.log("Launching RGB mode:", mode.name);

        // Extract mode argument from command
        // e.g., "python3 ... fixed_vert" -> "fixed_vert"
        const cmdParts = mode.command.split(" ");
        const modeArg = cmdParts[cmdParts.length - 1];

        console.log("Mode argument:", modeArg);

        // Check if we should close after launching
        const shouldClose = loadedConfig?.behavior?.close_on_launch ?? false;
        pendingClose = shouldClose;

        // Use wrapper script to launch mode in detached session
        const wrapperScript = Qt.resolvedUrl("./launch_rgb_mode.sh");
        modeProcess.command = [wrapperScript, modeArg];
        modeProcess.running = true;
    }

    // Process for launching RGB modes
    Process {
        id: modeProcess
        running: false

        stdout: SplitParser {
            onRead: data => console.log("Mode output:", data)
        }

        stderr: SplitParser {
            onRead: data => console.error("Mode error:", data)
        }

        onExited: code => {
            console.log("Mode process exited with code:", code);
            running = false;

            // Close launcher if pendingClose is true and process succeeded
            if (pendingClose && code === 0) {
                console.log("Closing launcher after successful mode launch");
                Qt.callLater(closeRequested);
            } else if (pendingClose && code !== 0) {
                console.error("Mode launch failed, keeping launcher open");
                pendingClose = false;
            }
        }
    }

    function loadModes() {
        modesProcess.running = true;
    }

    // Process to load modes from backend
    Process {
        id: modesProcess
        command: ["python3", "backend.py"]
        running: false
        workingDirectory: Qt.resolvedUrl(".").toString().replace("file://", "")

        property string jsonBuffer: ""

        stdout: SplitParser {
            onRead: data => {
                modesProcess.jsonBuffer += data;
            }
        }

        stderr: SplitParser {
            onRead: data => console.error("Backend stderr:", data)
        }

        onRunningChanged: {
            if (!running && jsonBuffer) {
                try {
                    const result = JSON.parse(jsonBuffer);
                    modesData = result.modes || [];
                    colors = result.colors || {};
                    currentBrightness = result.brightness || 100;
                    loadedConfig = result.config || {};
                    filterModes();
                    console.log("Loaded", modesData.length, "RGB modes");
                    console.log("Loaded config, close_on_launch:", loadedConfig?.behavior?.close_on_launch);

                    // After modes are loaded, read active sequence
                    Qt.callLater(function() {
                        sequenceReader.running = true;
                    });
                } catch (e) {
                    console.error("Failed to parse modes JSON:", e);
                    console.error("Buffer was:", jsonBuffer);
                }
                jsonBuffer = "";
            }
        }
    }

    // Process to read active sequence
    Process {
        id: sequenceReader
        command: [
            "cat",
            Qt.resolvedUrl("./script/sequence.txt")
                .toString()
                .replace("file://", "")
        ]
        running: false

        property string sequenceBuffer: ""

        stdout: SplitParser {
            onRead: data => {
                sequenceReader.sequenceBuffer += data;
            }
        }

        onRunningChanged: {
            if (!running && sequenceBuffer) {
                const activeSequence = sequenceBuffer.trim();
                console.log("Active sequence from file:", activeSequence);
                selectModeBySequence(activeSequence);
                sequenceBuffer = "";
            }
        }
    }

    function selectModeBySequence(sequence) {
        // Find matching mode based on sequence name
        for (let i = 0; i < filteredModes.length; i++) {
            const mode = filteredModes[i];
            const cmdParts = mode.command.split(" ");
            const modeArg = cmdParts[cmdParts.length - 1];

            if (modeArg === sequence || sequence === mode.name.toLowerCase()) {
                selectedIndex = i;
                modesCarousel.positionViewAtIndex(i, ListView.Center);
                console.log("Selected mode:", mode.name, "at index", i);
                break;
            }
        }
    }

    Component.onCompleted: {
        console.log("=== RGBLauncher Component Started ===");
        console.log("Item width:", itemWidth, "Item height:", itemHeight);
        loadModes();
        forceActiveFocus();
        console.log("=== Loading modes from backend ===");
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: spacing
        spacing: launcher.spacing

        // Modes carousel
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: itemWidth

            ListView {
                id: modesCarousel
                anchors.fill: parent

                model: filteredModes
                orientation: ListView.Vertical
                spacing: launcher.spacing
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 300
                preferredHighlightBegin: height / 2 - itemHeight / 2
                preferredHighlightEnd: height / 2 + itemHeight / 2
                snapMode: ListView.SnapToItem
                clip: true

                delegate: Item {
                    width: itemWidth
                    height: itemHeight

                    Rectangle {
                        id: card
                        width: itemWidth
                        height: itemHeight

                        radius: 12
                        color: index === selectedIndex ? "#2a2a2a" : "#1a1a1a"
                        border.color: index === selectedIndex ? (colors.color5 || "#B89D41") : "#444444"
                        border.width: index === selectedIndex ? 2 : 1

                        scale: index === selectedIndex ? 1.0 : 0.9
                        Behavior on scale {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }

                        Behavior on border.color {
                            ColorAnimation { duration: 200 }
                        }

                        // Glow + Shadow effect
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: index === selectedIndex ? (colors.color5 || "#967B53") : "#80000000"
                            shadowOpacity: index === selectedIndex ? 0.8 : 0.5
                            shadowBlur: index === selectedIndex ? 1.0 : 0.4
                            shadowVerticalOffset: index === selectedIndex ? 8 : 4
                            shadowHorizontalOffset: 0
                        }

                    Column {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        width: parent.width - 24
                        spacing: 8

                        // Icon
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            font.pixelSize: 56
                            font.family: modelData.icon_font || ""
                            color: {
                                if (modelData.icon_color) {
                                    return colors[modelData.icon_color] || "#ffffff"
                                }
                                return "#ffffff"
                            }
                        }

                        // Name
                        Text {
                            width: parent.width
                            text: modelData.name
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        // Description
                        Text {
                            width: parent.width
                            text: modelData.description
                            font.pixelSize: 10
                            color: "#cccccc"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                        }

                        // Category badge
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: categoryLabel.width + 16
                            height: 18
                            radius: 9
                            color: getCategoryColor(modelData.category)

                            Text {
                                id: categoryLabel
                                anchors {
                                    horizontalCenter: parent.horizontalCenter
                                    verticalCenter: parent.verticalCenter
                                }
                                text: modelData.category.toUpperCase()
                                font.pixelSize: 8
                                font.bold: true
                                color: "#ffffff"
                            }
                        }
                    }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                console.log("Card clicked:", modelData.name);
                                selectedIndex = index;
                                launchMode();
                            }

                            onPressed: {
                                card.opacity = 0.8;
                            }

                            onReleased: {
                                card.opacity = 1.0;
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: 100 }
                        }
                    }
                }

                // Empty state
                Rectangle {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    width: parent.width
                    height: parent.height
                    color: "transparent"
                    visible: filteredModes.length === 0

                    Column {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 16

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "💡"
                            font.pixelSize: 64
                            opacity: 0.3
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No RGB modes available"
                            font.pixelSize: 18
                            color: colors.foreground || "#ffffff"
                            opacity: 0.7
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Check your config.toml"
                            font.pixelSize: 14
                            color: colors.foreground || "#ffffff"
                            opacity: 0.5
                        }
                    }
                }
            }

            // Mouse wheel support
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                propagateComposedEvents: true

                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        navigateUp()
                    } else if (wheel.angleDelta.y < 0) {
                        navigateDown()
                    }
                    wheel.accepted = true
                }
            }
        }

        // Brightness slider
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 80
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.5)
            border.color: colors.color4 || "#888888"
            border.width: 1

            Timer {
                id: brightnessDebounce
                interval: 300
                onTriggered: {
                    saveBrightness(currentBrightness);
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Active mode indicator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.3)
                    border.color: colors.color5 || "#00ffff"
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: filteredModes.length > 0 ? filteredModes[selectedIndex].icon : "💡"
                            font.pixelSize: 28
                            color: "#ffffff"
                        }

                        Text {
                            width: 60
                            text: filteredModes.length > 0 ? filteredModes[selectedIndex].name : "..."
                            font.pixelSize: 8
                            color: colors.foreground || "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: colors.color4 || "#444444"
                }

                Text {
                    text: "🔆"
                    font.pixelSize: 20
                    color: colors.foreground || "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: currentBrightness + "%"
                    font.pixelSize: 14
                    font.bold: true
                    color: colors.foreground || "#ffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                Slider {
                    id: brightnessSlider
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter
                    orientation: Qt.Vertical
                    from: 10
                    to: 100
                    value: currentBrightness
                    stepSize: 5

                    onValueChanged: {
                        currentBrightness = Math.round(value);
                        brightnessDebounce.restart();
                    }

                    onPressedChanged: {
                        if (!pressed) {
                            brightnessDebounce.stop();
                            saveBrightness(currentBrightness);
                        }
                    }
                    
                    handle: Rectangle {
                        x: brightnessSlider.leftPadding + brightnessSlider.availableWidth / 2 - width / 2
                        y: brightnessSlider.topPadding + brightnessSlider.visualPosition * (brightnessSlider.availableHeight - height)
                        width: 20
                        height: 20
                        radius: 10
                        color: brightnessSlider.pressed ? (colors.color6 || "#ffffff") : (colors.color5 || "#00ffff")
                        border.color: colors.foreground || "#ffffff"
                        border.width: 2
                    }
                }

                Text {
                    text: (selectedIndex + 1) + "/" + filteredModes.length
                    font.pixelSize: 12
                    color: colors.foreground || "#ffffff"
                    opacity: 0.7
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // Mouse wheel support for brightness control
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton

                onWheel: (wheel) => {
                    const delta = wheel.angleDelta.y > 0 ? 5 : -5;
                    const newValue = Math.max(10, Math.min(100, brightnessSlider.value + delta));
                    brightnessSlider.value = newValue;

                    wheel.accepted = true;
                }
            }
        }
    }

    function getCategoryColor(category) {
        switch(category) {
            case "dynamic": return "#9333ea";
            case "animation": return "#06b6d4";
            case "static": return "#84cc16";
            case "control": return "#ef4444";
            default: return "#6b7280";
        }
    }

    // Process for brightness control
    Process {
        id: brightnessProcess
        running: false

        stdout: SplitParser {
            onRead: data => console.log("Brightness output:", data)
        }

        stderr: SplitParser {
            onRead: data => console.error("Brightness error:", data)
        }

        onExited: code => {
            console.log("Brightness applied, exit code:", code);
            running = false;
        }
    }

    function saveBrightness(brightness) {
        console.log("Saving and applying brightness:", brightness);

        const cmd = "echo " + brightness + " > $HOME/.config/quickshell/rgb-launcher/script/brightness.txt";

        brightnessProcess.command = ["bash", "-c", cmd];
        brightnessProcess.running = true;
    }
}
