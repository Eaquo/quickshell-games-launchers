import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
import Quickshell

Item {
    id: root

    // ─── Propriétés publiques ─────────────────────────────────────
    property string coverSource: ""
    property string logoSource: ""
    property string gameName: ""
    property var    colors: ({})
    property bool   coverIsWebM: coverSource.toLowerCase().endsWith(".webm")


    // ─── Signal final ─────────────────────────────────────────────
    signal done()

    // ─── Positionnement : recouvre tout le launcher ───────────────
    anchors.fill: parent
    visible: false
    z: 999
    opacity: 1

    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.Linear }
    }

    // ─── Rectangle animé (part de la carte, devient plein écran) ──
    Rectangle {
        id: animRect

        // Position/taille de départ (sera écrasé par show())
        anchors.centerIn: parent
        width: 100; height: 150
        radius: 16
        clip: true
        color: "transparent"

        // Border identique à la GameCard sélectionnée
        border.color: root.colors.color5 || "#73ff00"
        border.width: 2

        // Animations sur la géométrie
        Behavior on x      { NumberAnimation { duration: 550; easing.type: Easing.Linear } }
        Behavior on y      { NumberAnimation { duration: 550; easing.type: Easing.Linear } }
        Behavior on width  { NumberAnimation { duration: 550; easing.type: Easing.Linear } }
        Behavior on height { NumberAnimation { duration: 550; easing.type: Easing.Linear } }
        Behavior on radius { NumberAnimation { duration: 550; easing.type: Easing.Linear } }
        Behavior on border.width { NumberAnimation { duration: 400; easing.type: Easing.Linear } }
        Behavior on border.color { ColorAnimation  { duration: 400 } }

        // Cover (statique ou WebP animé)
        AnimatedImage {
            id: coverImage
            property int radius: 14
            anchors.fill: parent
            visible: !root.coverIsWebM
            source: root.coverIsWebM ? "" : root.coverSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            scale: 1
            playing: root.visible
            layer.enabled: true
            layer.effect: OpacityMask {
                id: opacityMaskInstance
                maskSource: Rectangle {
                    id: maskedRect
                    width: animRect.width
                    height: animRect.height
                    radius: animRect.radius
                }
            }
            Behavior on scale {
                NumberAnimation { duration: 1500; easing.type: Easing.Linear }
            }
        }

        // Cover WebM animée
        VideoOutput {
            id: coverVideoOutput
            anchors.fill: parent
            visible: root.coverIsWebM
            layer.enabled: root.coverIsWebM
            layer.effect: MultiEffect {
                maskEnabled: true
                maskThresholdMin: 0.5
                maskSource: ShaderEffectSource {
                    sourceItem: Rectangle {
                        width: coverVideoOutput.width
                        height: coverVideoOutput.height
                        radius: animRect.radius
                    }
                }
            }
        }

        MediaPlayer {
            id: coverVideoPlayer
            source: root.coverIsWebM ? root.coverSource : ""
            videoOutput: coverVideoOutput
            loops: MediaPlayer.Infinite
            autoPlay: root.coverIsWebM && root.visible
        }

        // Vignette dégradée
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            opacity: config?.appearance?.background_opacity ?? 0.85
            layer.enabled: config?.appearance?.blur_background ?? true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.9
                blurMax: 32
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: colors.color5 || '#73ff00'
            border.width: 2
            opacity: 0.5
        }

        // ─── Contenu central (logo + texte) ──────────────────────
        Column {
            id: centerContent
            anchors.centerIn: parent
            spacing: 16
            width: parent.width * 0.80
            opacity: 0

            Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

            // Logo SteamGridDB
            Image {
                id: logoImage
                anchors.horizontalCenter: parent.horizontalCenter
                source: root.logoSource
                visible: root.logoSource !== ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                width: parent.width * 0.60
                height: 160
                opacity: 0
                scale: 0.80
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.Linear } }
                Behavior on scale   { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
            }

            // Fallback texte
            Text {
                id: nameText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.gameName.toUpperCase()
                color: "white"
                font.pixelSize: 54
                font.bold: true
                font.letterSpacing: 6
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
                visible: root.logoSource === ""
                opacity: 0
                scale: 0.80
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
            }

            // Séparateur
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(400, parent.width)
                height: 2
                clip: true
                visible: root.logoSource === "" ? nameText.visible : logoImage.visible

                Rectangle {
                    id: separator
                    width: parent.width; height: 2; radius: 1
                    color: root.colors.color5 || "#73ff00"
                    opacity: 0.7
                    scale: 0.0
                    transformOrigin: Item.Left
                    Behavior on scale { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
                }
            }

            // "Start game..."
            Text {
                id: startText
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Start Game" + dotsStr
                color: Qt.rgba(1, 1, 1, 0.70)
                font.pixelSize: 20
                font.letterSpacing: 4
                font.family: "Open Sans Regular"
                horizontalAlignment: Text.AlignHCenter
                opacity: 0
                property string dotsStr: ""
                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            }
        }
    }

    // ─── Timers ───────────────────────────────────────────────────

    // Étape 1 : agrandir le rect pour remplir le launcher
    Timer {
        id: tExpand; interval: 80; repeat: false
        onTriggered: {
            animRect.x      = 0
            animRect.y      = 0
            animRect.width  = root.width
            animRect.height = root.height
            animRect.radius = 16
            animRect.border.width = 0
            coverImage.scale = 1.0
            if (root.coverIsWebM) coverVideoPlayer.play()
            tContent.start()
        }
    }

    // Étape 2 : affiche le contenu
    Timer {
        id: tContent; interval: 750; repeat: false
        onTriggered: {
            centerContent.opacity = 1
            if (root.logoSource !== "") {
                logoImage.opacity = 1
                logoImage.scale   = 1.0
            } else {
                nameText.opacity = 1
                nameText.scale   = 1.0
            }
            separator.scale = 1.0
            tStartText.start()
        }
    }

    // Étape 3 : "Start game..."
    Timer {
        id: tStartText; interval: 480; repeat: false
        onTriggered: {
            startText.opacity = 1
            dotsTimer.start()
        }
    }

    // Points animés
    Timer {
        id: dotsTimer; interval: 500; repeat: true
        property int tick: 0
        onTriggered: {
            tick = (tick + 1) % 4
            var s = ""
            for (var i = 0; i < tick; i++) s += "◦"
            startText.dotsStr = s
        }
    }

    // Fermeture à 5s
    Timer {
        id: closeTimer; interval: 3000; repeat: false
        onTriggered: {
            dotsTimer.stop()
            root.opacity = 0
            hideTimer.start()
        }
    }

    Timer {
        id: hideTimer; interval: 320; repeat: false
        onTriggered: {
            root.visible = false
            root.done()
        }
    }

    // ─── API publique ─────────────────────────────────────────────
    // cardX, cardY, cardW, cardH : géométrie de la GameCard dans le launcher
    // (utilise mapToItem(root, 0, 0) côté QML pour obtenir les coords)
    function show(cover, name, logo, cardX, cardY, cardW, cardH) {
        // Reset
        coverImage.scale    = 1.14
        logoImage.opacity   = 0
        logoImage.scale     = 0.80
        nameText.opacity    = 0
        nameText.scale      = 0.80
        separator.scale     = 0.0
        startText.opacity   = 0
        startText.dotsStr   = ""
        dotsTimer.tick      = 0
        centerContent.opacity = 0

        coverVideoPlayer.stop()
        root.coverSource = cover
        root.gameName    = name
        root.logoSource  = logo || ""

        // Positionne le rect sur la carte
        animRect.x      = cardX   || 0
        animRect.y      = cardY   || 0
        animRect.width  = cardW   || root.width
        animRect.height = cardH   || root.height
        animRect.radius = 12
        animRect.border.width = 2
        animRect.border.color = root.colors.color5 || "#73ff00"

        root.visible = true
        root.opacity = 1

        tExpand.start()
        closeTimer.start()
    }
}
