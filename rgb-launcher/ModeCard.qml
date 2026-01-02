import QtQuick
import QtQuick.Effects

Rectangle {
    id: card

    required property string modeName
    required property string modeDescription
    required property string modeIcon
    required property string colorPreview
    required property string category
    required property bool isSelected
    required property var gameColors

    signal clicked()

    radius: 12
    color: isSelected ? (gameColors.background || "#1a1a1a") : "transparent"
    border.color: isSelected ? (gameColors.color8 || '#5db841') : "transparent"
    border.width: isSelected ? 2 : 1

    // Simple scale animation
    scale: isSelected ? 1.0 : 0.9
    Behavior on scale {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    
    Behavior on color {
        ColorAnimation { duration: 200 }
    }

    // Content
    Column {
        anchors.centerIn: parent
        width: parent.width - 24
        spacing: 8

        // Icon
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: modeIcon
            font.pixelSize: 56
            color: "#ffffff"
        }

        // Name
        Text {
            width: parent.width
            text: modeName
            font.pixelSize: 16
            font.bold: true
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        // Description
        Text {
            width: parent.width
            text: modeDescription
            font.pixelSize: 10
            color: "#cccccc"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }

        // Category
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: categoryLabel.width + 16
            height: 18
            radius: 9
            color: getCategoryColor()

            Text {
                id: categoryLabel
                anchors.centerIn: parent
                text: category.toUpperCase()
                font.pixelSize: 8
                font.bold: true
                color: "#ffffff"
            }
        }
    }

    // Click handler
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            console.log("=== CARD CLICKED ===");
            console.log("Mode:", modeName);
            card.clicked();
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

    function getCategoryColor() {
        switch(category) {
            case "dynamic": return "#9333ea";
            case "animation": return "#06b6d4";
            case "static": return "#84cc16";
            case "control": return "#ef4444";
            default: return "#6b7280";
        }
    }
}
