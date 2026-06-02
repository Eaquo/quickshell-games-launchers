import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: panel

    required property var config
    required property var colors

    property string accent:   colors.color5      || "#7c3aed"
    property string bg:       colors.background  || "#13131f"
    property string fg:       colors.foreground  || "#e0e0e0"
    property string bgDark:   Qt.darker(bg, 1.35)
    property string bgMid:    Qt.darker(bg, 1.15)

    signal closeRequested()
    signal configSaved(var newConfig)

    I18n { id: i18n }

    // ── Working copies ────────────────────────────────────────────────────────
    // Display
    property string  ePosition:    config?.display?.position       ?? "bottom"
    property string  eOrientation: config?.display?.orientation    ?? "horizontal"
    property int     eCols:        config?.display?.grid_size?.[0] ?? 4
    property int     eRows:        config?.display?.grid_size?.[1] ?? 1
    property int     eItemWidth:   config?.display?.item_width     ?? 200
    property int     eItemHeight:  config?.display?.item_height    ?? 300
    property int     eSpacing:     config?.display?.spacing        ?? 20
    // Appearance
    property bool    eWallust:     config?.appearance?.use_wallust          ?? true
    property string  eWallustPath: config?.appearance?.wallust_path         ?? "~/.cache/wal/wal.json"
    property bool    eMatugen:     config?.appearance?.use_matugen          ?? false
    property string  eMatugenPath: config?.appearance?.matugen_colors_path  ?? "~/.cache/matugen/game_launcher_colors.json"
    property bool    eBlur:        config?.appearance?.blur_background      ?? true
    property real    eOpacity:     config?.appearance?.background_opacity   ?? 0.85
    // Behavior
    property string  eSortBy:          config?.behavior?.sort_by              ?? "recent"
    property bool    eShowFavs:        config?.behavior?.show_favorites_first ?? true
    property bool    eCloseOnLaunch:   config?.behavior?.close_on_launch      ?? true
    property int     eDefaultSource:   config?.behavior?.default_source_index ?? 0
    property bool    eRememberSource:  config?.behavior?.remember_source      ?? true
    property bool    eBigPicture:      config?.behavior?.start_in_bigpicture  ?? false
    // Animations
    property int     eAnimDuration:    config?.animations?.duration_ms        ?? 300
    // Steam
    property bool    eSteamEnabled:    config?.steam?.enabled                 ?? true
    property var     eSteamPaths:      config?.steam?.library_paths           ?? []
    // Heroic
    property bool    eHeroicEnabled:   config?.heroic?.enabled                ?? true
    property var     eHeroicPaths:     config?.heroic?.config_paths           ?? []
    property bool    eHeroicEpic:      config?.heroic?.scan_epic              ?? true
    property bool    eHeroicGog:       config?.heroic?.scan_gog               ?? true
    property bool    eHeroicAmazon:    config?.heroic?.scan_amazon            ?? true
    property bool    eHeroicSideload:  config?.heroic?.scan_sideload          ?? true
    // Lutris
    property bool    eLutrisEnabled:   config?.lutris?.enabled                ?? false
    property string  eLutrisDb:        config?.lutris?.db_path                ?? "~/.local/share/lutris/pga.db"
    // SteamGridDB
    property bool    eSgdbEnabled:     config?.steamgriddb?.enabled           ?? true
    property string  eSgdbApiKey:      config?.steamgriddb?.api_key           ?? ""
    property string  eSgdbImageType:   config?.steamgriddb?.image_type        ?? "hero"
    property bool    eSgdbAnimated:    config?.steamgriddb?.prefer_animated   ?? true
    property bool    eSgdbFallback:    config?.steamgriddb?.fallback_to_steam ?? true
    property bool    eSgdbSortLikes:   config?.steamgriddb?.sort_by_likes     ?? true
    property int     eSgdbMinLikes:    config?.steamgriddb?.min_likes         ?? 0
    property bool    eSgdbNsfw:        config?.steamgriddb?.nsfw              ?? false
    property bool    eSgdbHumor:       config?.steamgriddb?.humor             ?? false
    property bool    eSgdbEpilepsy:    config?.steamgriddb?.epilepsy          ?? false
    property bool    eSgdbParallel:    config?.steamgriddb?.parallel_requests ?? true
    property int     eSgdbMaxWorkers:  config?.steamgriddb?.max_workers       ?? 12
    property int     eSgdbTimeout:     config?.steamgriddb?.request_timeout   ?? 3
    property int     eSgdbCacheTtl:    config?.steamgriddb?.cache_ttl_hours   ?? 48
    // Filtering
    property bool    eGamesOnly:           config?.filtering?.games_only ?? false
    property string  eExcludeCategories:   (config?.filtering?.exclude_categories ?? []).join(", ")
    property string  eExcludeKeywords:     (config?.filtering?.exclude_keywords   ?? []).join(", ")
    // Manual entries
    property var    eManualEntries: JSON.parse(JSON.stringify(config?.manual?.entries ?? []))
    property string eBoxArtDir:     config?.manual?.box_art_dir ?? "~/.config/quickshell/game-launcher/box-art"

    property bool   hasChanges:   false
    property int    activeSection: 0
    property string saveError:    ""

    property int selectedManualIdx: 0

    function manualUpdateEntry(idx, key, val) {
        var arr = JSON.parse(JSON.stringify(panel.eManualEntries))
        if (arr[idx] !== undefined) { arr[idx][key] = val; panel.eManualEntries = arr; panel.hasChanges = true }
    }
    function manualAddEntry() {
        var arr = JSON.parse(JSON.stringify(panel.eManualEntries))
        arr.push({ title: "", launch_command: "", path_box_art: "" })
        panel.eManualEntries = arr
        panel.selectedManualIdx = arr.length - 1
        panel.hasChanges = true
    }
    function manualRemoveEntry(idx) {
        var arr = JSON.parse(JSON.stringify(panel.eManualEntries))
        arr.splice(idx, 1)
        panel.eManualEntries = arr
        if (panel.selectedManualIdx >= arr.length)
            panel.selectedManualIdx = Math.max(0, arr.length - 1)
        panel.hasChanges = true
    }

    // ── Geometry ──────────────────────────────────────────────────────────────
    width: 760; height: 540
    radius: 16
    color: bg
    border.color: Qt.rgba(
        parseInt(accent.slice(1,3),16)/255,
        parseInt(accent.slice(3,5),16)/255,
        parseInt(accent.slice(5,7),16)/255, 0.35)
    border.width: 1

    focus: true
    Keys.onEscapePressed: panel.closeRequested()

    // ── Save process ──────────────────────────────────────────────────────────
    Process {
        id: saveProc
        property string out: ""
        stdout: SplitParser { onRead: data => saveProc.out += data }
        onExited: {
            try {
                const r = JSON.parse(saveProc.out)
                if (!r.ok) {
                    panel.saveError = r.error || "Save failed"
                    saveProc.out = ""
                    return
                }
                if (r.ok) {
                    panel.hasChanges = false
                    panel.saveError = ""
                    const nc = JSON.parse(JSON.stringify(panel.config))
                    if (!nc.display)     nc.display     = {}
                    if (!nc.appearance)  nc.appearance  = {}
                    if (!nc.behavior)    nc.behavior    = {}
                    if (!nc.animations)  nc.animations  = {}
                    if (!nc.steam)       nc.steam       = {}
                    if (!nc.heroic)      nc.heroic      = {}
                    if (!nc.lutris)      nc.lutris      = {}
                    if (!nc.steamgriddb) nc.steamgriddb = {}
                    if (!nc.filtering)   nc.filtering   = {}
                    nc.display.position    = panel.ePosition
                    nc.display.orientation = panel.eOrientation
                    nc.display.grid_size   = [panel.eCols, panel.eRows]
                    nc.display.item_width  = panel.eItemWidth
                    nc.display.item_height = panel.eItemHeight
                    nc.display.spacing     = panel.eSpacing
                    nc.appearance.use_wallust         = panel.eWallust
                    nc.appearance.wallust_path        = panel.eWallustPath
                    nc.appearance.use_matugen         = panel.eMatugen
                    nc.appearance.matugen_colors_path = panel.eMatugenPath
                    nc.appearance.blur_background     = panel.eBlur
                    nc.appearance.background_opacity = Math.round(panel.eOpacity * 100) / 100
                    nc.behavior.sort_by              = panel.eSortBy
                    nc.behavior.show_favorites_first = panel.eShowFavs
                    nc.behavior.close_on_launch      = panel.eCloseOnLaunch
                    nc.behavior.default_source_index = panel.eDefaultSource
                    nc.behavior.remember_source      = panel.eRememberSource
                    nc.behavior.start_in_bigpicture  = panel.eBigPicture
                    nc.animations.duration_ms        = panel.eAnimDuration
                    nc.steam.enabled                 = panel.eSteamEnabled
                    nc.steam.library_paths           = panel.eSteamPaths.filter(s => s.trim().length > 0)
                    nc.heroic.enabled                = panel.eHeroicEnabled
                    nc.heroic.scan_epic              = panel.eHeroicEpic
                    nc.heroic.scan_gog               = panel.eHeroicGog
                    nc.heroic.scan_amazon            = panel.eHeroicAmazon
                    nc.heroic.scan_sideload          = panel.eHeroicSideload
                    nc.heroic.config_paths           = panel.eHeroicPaths.filter(s => s.trim().length > 0)
                    nc.lutris.enabled                = panel.eLutrisEnabled
                    nc.lutris.db_path                = panel.eLutrisDb
                    nc.steamgriddb.enabled           = panel.eSgdbEnabled
                    nc.steamgriddb.api_key           = panel.eSgdbApiKey
                    nc.steamgriddb.image_type        = panel.eSgdbImageType
                    nc.steamgriddb.prefer_animated   = panel.eSgdbAnimated
                    nc.steamgriddb.fallback_to_steam = panel.eSgdbFallback
                    nc.steamgriddb.sort_by_likes     = panel.eSgdbSortLikes
                    nc.steamgriddb.min_likes         = panel.eSgdbMinLikes
                    nc.steamgriddb.nsfw              = panel.eSgdbNsfw
                    nc.steamgriddb.humor             = panel.eSgdbHumor
                    nc.steamgriddb.epilepsy          = panel.eSgdbEpilepsy
                    nc.steamgriddb.parallel_requests = panel.eSgdbParallel
                    nc.steamgriddb.max_workers       = panel.eSgdbMaxWorkers
                    nc.steamgriddb.request_timeout   = panel.eSgdbTimeout
                    nc.steamgriddb.cache_ttl_hours   = panel.eSgdbCacheTtl
                    nc.filtering.games_only          = panel.eGamesOnly
                    nc.filtering.exclude_categories  = panel.eExcludeCategories.split(",").map(s => s.trim()).filter(s => s.length > 0)
                    nc.filtering.exclude_keywords    = panel.eExcludeKeywords.split(",").map(s => s.trim()).filter(s => s.length > 0)
                    if (!nc.manual) nc.manual = {}
                    nc.manual.box_art_dir = panel.eBoxArtDir
                    nc.manual.entries     = JSON.parse(JSON.stringify(panel.eManualEntries))
                    panel.configSaved(nc)
                }
            } catch(e) { console.error("config save error:", e) }
            saveProc.out = ""
        }
    }

    function doSave() {
        const payload = {
            display: {
                position: ePosition, orientation: eOrientation,
                grid_size: [eCols, eRows],
                item_width: eItemWidth, item_height: eItemHeight, spacing: eSpacing
            },
            appearance: {
                use_wallust: eWallust, wallust_path: eWallustPath,
                use_matugen: eMatugen, matugen_colors_path: eMatugenPath,
                blur_background: eBlur,
                background_opacity: Math.round(eOpacity * 100) / 100
            },
            behavior: {
                sort_by: eSortBy, show_favorites_first: eShowFavs,
                close_on_launch: eCloseOnLaunch, default_source_index: eDefaultSource,
                remember_source: eRememberSource, start_in_bigpicture: eBigPicture
            },
            animations: { duration_ms: eAnimDuration },
            steam:  { enabled: eSteamEnabled,
                      library_paths: eSteamPaths.filter(s => s.trim().length > 0) },
            heroic: { enabled: eHeroicEnabled, scan_epic: eHeroicEpic, scan_gog: eHeroicGog,
                      scan_amazon: eHeroicAmazon, scan_sideload: eHeroicSideload,
                      config_paths: eHeroicPaths.filter(s => s.trim().length > 0) },
            lutris: { enabled: eLutrisEnabled, db_path: eLutrisDb },
            steamgriddb: {
                enabled: eSgdbEnabled, api_key: eSgdbApiKey, image_type: eSgdbImageType,
                prefer_animated: eSgdbAnimated, fallback_to_steam: eSgdbFallback,
                sort_by_likes: eSgdbSortLikes, min_likes: eSgdbMinLikes,
                nsfw: eSgdbNsfw, humor: eSgdbHumor, epilepsy: eSgdbEpilepsy,
                parallel_requests: eSgdbParallel, max_workers: eSgdbMaxWorkers,
                request_timeout: eSgdbTimeout, cache_ttl_hours: eSgdbCacheTtl
            },
            filtering: {
                games_only: eGamesOnly,
                exclude_categories: eExcludeCategories.split(",").map(s => s.trim()).filter(s => s.length > 0),
                exclude_keywords:   eExcludeKeywords.split(",").map(s => s.trim()).filter(s => s.length > 0)
            },
            manual: {
                box_art_dir: eBoxArtDir,
                entries: eManualEntries
            }
        }
        const writerPath = Qt.resolvedUrl("service/config_writer.py").toString().replace("file://","")
        saveProc.command = ["python3", writerPath, JSON.stringify(payload)]
        saveProc.running = true
    }

    function doDiscard() {
        ePosition    = config?.display?.position       ?? "bottom"
        eOrientation = config?.display?.orientation    ?? "horizontal"
        eCols        = config?.display?.grid_size?.[0] ?? 4
        eRows        = config?.display?.grid_size?.[1] ?? 1
        eItemWidth   = config?.display?.item_width     ?? 200
        eItemHeight  = config?.display?.item_height    ?? 300
        eSpacing     = config?.display?.spacing        ?? 20
        eWallust     = config?.appearance?.use_wallust          ?? true
        eWallustPath = config?.appearance?.wallust_path         ?? "~/.cache/wal/wal.json"
        eMatugen     = config?.appearance?.use_matugen          ?? false
        eMatugenPath = config?.appearance?.matugen_colors_path  ?? "~/.cache/matugen/game_launcher_colors.json"
        eBlur        = config?.appearance?.blur_background      ?? true
        eOpacity     = config?.appearance?.background_opacity ?? 0.85
        eSortBy         = config?.behavior?.sort_by              ?? "recent"
        eShowFavs       = config?.behavior?.show_favorites_first ?? true
        eCloseOnLaunch  = config?.behavior?.close_on_launch      ?? true
        eDefaultSource  = config?.behavior?.default_source_index ?? 0
        eRememberSource = config?.behavior?.remember_source      ?? true
        eBigPicture     = config?.behavior?.start_in_bigpicture  ?? false
        eAnimDuration   = config?.animations?.duration_ms        ?? 300
        eSteamEnabled   = config?.steam?.enabled                 ?? true
        eSteamPaths     = config?.steam?.library_paths  ?? []
        eHeroicEnabled  = config?.heroic?.enabled                ?? true
        eHeroicPaths    = config?.heroic?.config_paths ?? []
        eHeroicEpic     = config?.heroic?.scan_epic              ?? true
        eHeroicGog      = config?.heroic?.scan_gog               ?? true
        eHeroicAmazon   = config?.heroic?.scan_amazon            ?? true
        eHeroicSideload = config?.heroic?.scan_sideload          ?? true
        eLutrisEnabled  = config?.lutris?.enabled                ?? false
        eLutrisDb       = config?.lutris?.db_path                ?? "~/.local/share/lutris/pga.db"
        eSgdbEnabled    = config?.steamgriddb?.enabled           ?? true
        eSgdbApiKey     = config?.steamgriddb?.api_key           ?? ""
        eSgdbImageType  = config?.steamgriddb?.image_type        ?? "hero"
        eSgdbAnimated   = config?.steamgriddb?.prefer_animated   ?? true
        eSgdbFallback   = config?.steamgriddb?.fallback_to_steam ?? true
        eSgdbSortLikes  = config?.steamgriddb?.sort_by_likes     ?? true
        eSgdbMinLikes   = config?.steamgriddb?.min_likes         ?? 0
        eSgdbNsfw       = config?.steamgriddb?.nsfw              ?? false
        eSgdbHumor      = config?.steamgriddb?.humor             ?? false
        eSgdbEpilepsy   = config?.steamgriddb?.epilepsy          ?? false
        eSgdbParallel   = config?.steamgriddb?.parallel_requests ?? true
        eSgdbMaxWorkers = config?.steamgriddb?.max_workers       ?? 12
        eSgdbTimeout    = config?.steamgriddb?.request_timeout   ?? 3
        eSgdbCacheTtl   = config?.steamgriddb?.cache_ttl_hours   ?? 48
        eGamesOnly         = config?.filtering?.games_only          ?? false
        eExcludeCategories = (config?.filtering?.exclude_categories ?? []).join(", ")
        eExcludeKeywords   = (config?.filtering?.exclude_keywords   ?? []).join(", ")
        eManualEntries     = JSON.parse(JSON.stringify(config?.manual?.entries ?? []))
        eBoxArtDir         = config?.manual?.box_art_dir ?? "~/.config/quickshell/game-launcher/box-art"
        hasChanges = false
    }

    // 9 sections — group label shown as divider when non-empty
    property var sections: [
        { icon: "", label: i18n.t("cfg_sec_display"),    group: i18n.t("cfg_grp_launcher")  },
        { icon: "", label: i18n.t("cfg_sec_appearance"), group: ""                           },
        { icon: "", label: i18n.t("cfg_sec_behavior"),   group: ""                           },
        { icon: "", label: i18n.t("cfg_sec_animations"), group: ""                           },
        { icon: "", label: i18n.t("cfg_sec_steam"),      group: i18n.t("cfg_grp_sources")   },
        { icon: "", label: i18n.t("cfg_sec_heroic"),     group: ""                           },
        { icon: "", label: i18n.t("cfg_sec_lutris"),     group: ""                           },
        { icon: "", label: i18n.t("cfg_sec_sgdb"),       group: i18n.t("cfg_grp_artwork")   },
        { icon: "", label: i18n.t("cfg_sec_filters"),    group: i18n.t("cfg_grp_filtering") },
        { icon: "", label: i18n.t("cfg_sec_manual"),     group: ""                           },
    ]

    // ── Layout ────────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sidebar ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 172
            Layout.fillHeight: true
            color: bgDark
            radius: 16
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 16; color: bgDark }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 0

                Text {
                    text: "  Settings"
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 14; font.bold: true
                    color: fg
                    Layout.leftMargin: 4
                    Layout.topMargin: 6
                    Layout.bottomMargin: 10
                }

                // Scrollable nav list
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: navCol.implicitHeight
                    flickableDirection: Flickable.VerticalFlick

                    Column {
                        id: navCol
                        width: parent.width
                        spacing: 0

                        Repeater {
                            model: panel.sections
                            delegate: Column {
                                id: secDelegate
                                property int secIdx: index
                                width: parent ? parent.width : 0
                                spacing: 0

                                // Group divider — only when group != ""
                                Item {
                                    width: parent.width
                                    height: modelData.group !== "" ? (secDelegate.secIdx === 0 ? 22 : 30) : 0
                                    visible: height > 0
                                    Text {
                                        text: modelData.group
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 5
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.5
                                        color: Qt.rgba(
                                            parseInt(panel.fg.slice(1,3),16)/255,
                                            parseInt(panel.fg.slice(3,5),16)/255,
                                            parseInt(panel.fg.slice(5,7),16)/255, 0.30)
                                    }
                                }

                                // Nav item
                                Rectangle {
                                    id: navItem
                                    width: parent.width; height: 38; radius: 10
                                    property bool active: panel.activeSection === secDelegate.secIdx
                                    color: active
                                        ? Qt.rgba(
                                            parseInt(panel.accent.slice(1,3),16)/255,
                                            parseInt(panel.accent.slice(3,5),16)/255,
                                            parseInt(panel.accent.slice(5,7),16)/255, 0.20)
                                        : (navM.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Rectangle {
                                        visible: navItem.active; width: 3; radius: 2
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 8 }
                                        color: panel.accent
                                    }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left; anchors.leftMargin: 16
                                        spacing: 10
                                        Text {
                                            text: modelData.icon
                                            font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 12
                                            color: navItem.active ? panel.accent : Qt.rgba(
                                                parseInt(panel.fg.slice(1,3),16)/255,
                                                parseInt(panel.fg.slice(3,5),16)/255,
                                                parseInt(panel.fg.slice(5,7),16)/255, 0.40)
                                        }
                                        Text {
                                            text: modelData.label; font.pixelSize: 12
                                            color: navItem.active ? panel.fg : Qt.rgba(
                                                parseInt(panel.fg.slice(1,3),16)/255,
                                                parseInt(panel.fg.slice(3,5),16)/255,
                                                parseInt(panel.fg.slice(5,7),16)/255, 0.55)
                                        }
                                    }
                                    MouseArea {
                                        id: navM; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: panel.activeSection = secDelegate.secIdx
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Content ───────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 0

            // Title bar
            Rectangle {
                Layout.fillWidth: true; height: 52; color: "transparent"
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 16
                    Text { text: panel.sections[panel.activeSection].label; font.pixelSize: 15; font.bold: true; color: panel.fg }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: cM.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.45) }
                        MouseArea { id: cM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.closeRequested() }
                    }
                }
            }

            // Settings area — single Loader, switches sourceComponent on section change
            Flickable {
                id: settingsFlick
                Layout.fillWidth: true; Layout.fillHeight: true
                contentHeight: sectionLoader.implicitHeight + 16; clip: true

                Loader {
                    id: sectionLoader
                    width: parent.width
                    sourceComponent: {
                        switch (panel.activeSection) {
                        case 0:  return displayComp
                        case 1:  return appearComp
                        case 2:  return behaviorComp
                        case 3:  return animComp
                        case 4:  return steamComp
                        case 5:  return heroicComp
                        case 6:  return lutrisComp
                        case 7:  return sgdbComp
                        case 8:  return filterComp
                        case 9:  return manualComp
                        default: return displayComp
                        }
                    }
                }

                onContentHeightChanged: contentY = 0
            }

            // Footer
            Rectangle {
                Layout.fillWidth: true; height: 56; color: "transparent"
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }
                RowLayout {
                    anchors.fill: parent; anchors.margins: 16
                    Row {
                        visible: panel.saveError !== ""; spacing: 6
                        Rectangle { width: 7; height: 7; radius: 4; color: "#ef4444"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: panel.saveError; font.pixelSize: 12; color: "#ef4444"; maximumLineCount: 1; elide: Text.ElideRight }
                    }
                    Row {
                        visible: panel.hasChanges && panel.saveError === ""; spacing: 6
                        Rectangle { width: 7; height: 7; radius: 4; color: "#f59e0b"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: i18n.t("cfg_unsaved"); font.pixelSize: 12; color: Qt.rgba(1,1,1,0.4) }
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 90; height: 34; radius: 8; visible: panel.hasChanges
                        color: dM.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.06)
                        border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: i18n.t("cfg_discard"); font.pixelSize: 13; color: Qt.rgba(1,1,1,0.65) }
                        MouseArea { id: dM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.doDiscard() }
                    }
                    Rectangle {
                        width: 110; height: 34; radius: 8
                        color: sM.containsMouse ? Qt.lighter(panel.accent, 1.2) : panel.accent
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Row { anchors.centerIn: parent; spacing: 7
                            Text { text: ""; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 11; color: "white" }
                            Text { text: i18n.t("cfg_save"); font.pixelSize: 13; color: "white" }
                        }
                        MouseArea { id: sM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.doSave() }
                    }
                }
            }
        }
    }

    // ── Inline controls ───────────────────────────────────────────────────────

    component CfgCombo: ComboBox {
        id: cfgCombo
        property var choices: []
        model: choices
        implicitWidth: 145; implicitHeight: 32; font.pixelSize: 13
        contentItem: Text {
            leftPadding: 12; text: cfgCombo.displayText; font: cfgCombo.font
            color: panel.fg; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: cfgCombo.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.07)
            border.color: cfgCombo.pressed ? panel.accent : Qt.rgba(1,1,1,0.15); border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        indicator: Text {
            x: cfgCombo.width - width - 10; anchors.verticalCenter: parent.verticalCenter
            text: ""; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 9
            color: Qt.rgba(1,1,1,0.35)
        }
        popup: Popup {
            y: cfgCombo.height + 4; width: cfgCombo.width; padding: 4
            background: Rectangle {
                color: panel.bgDark; radius: 8
                border.color: Qt.rgba(1,1,1,0.15); border.width: 1
            }
            contentItem: ListView {
                implicitHeight: contentHeight
                model: cfgCombo.model
                clip: true
                delegate: Rectangle {
                    width: ListView.view ? ListView.view.width : cfgCombo.width
                    height: 32; radius: 6
                    color: itemMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        text: modelData; font.pixelSize: 13; color: panel.fg
                    }
                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { cfgCombo.currentIndex = index; cfgCombo.popup.close() }
                    }
                }
            }
        }
    }

    component CfgSpin: Row {
        id: spinRoot
        property int value: 1; property int min: 1; property int max: 10
        signal changed(int v)
        spacing: 4
        Rectangle {
            width: 30; height: 32; radius: 8
            color: mM.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.07)
            border.color: Qt.rgba(1,1,1,0.12); border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
            Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 16; color: panel.fg }
            MouseArea { id: mM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (spinRoot.value > spinRoot.min) {
                        spinRoot.value--
                        panel.hasChanges = true
                        spinRoot.changed(spinRoot.value)
                    }
                }
            }
        }
        Rectangle {
            width: 44; height: 32; radius: 8; color: Qt.rgba(1,1,1,0.05)
            Text { anchors.centerIn: parent; text: spinRoot.value; font.pixelSize: 13; font.bold: true; color: panel.fg }
        }
        Rectangle {
            width: 30; height: 32; radius: 8
            color: pM.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.07)
            border.color: Qt.rgba(1,1,1,0.12); border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
            Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; color: panel.fg }
            MouseArea { id: pM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (spinRoot.value < spinRoot.max) {
                        spinRoot.value++
                        panel.hasChanges = true
                        spinRoot.changed(spinRoot.value)
                    }
                }
            }
        }
    }

    component CfgText: Rectangle {
        id: ctRoot
        property string value: ""
        property int fieldWidth: 220
        signal changed(string v)
        width: fieldWidth; height: 32; radius: 8
        color: Qt.rgba(1,1,1,0.07)
        border.color: Qt.rgba(1,1,1,0.15); border.width: 1
        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        TextField {
            anchors.fill: parent; anchors.margins: 6
            text: ctRoot.value
            font.pixelSize: 12; color: panel.fg
            background: Item {}
            selectByMouse: true
            onActiveFocusChanged: {
                ctRoot.color        = activeFocus ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.07)
                ctRoot.border.color = activeFocus ? panel.accent : Qt.rgba(1,1,1,0.15)
                if (!activeFocus && text !== ctRoot.value) {
                    ctRoot.value = text
                    panel.hasChanges = true
                    ctRoot.changed(ctRoot.value)
                }
            }
            onEditingFinished: {
                if (text !== ctRoot.value) {
                    ctRoot.value = text
                    panel.hasChanges = true
                    ctRoot.changed(ctRoot.value)
                }
                focus = false
            }
            Keys.onEscapePressed: { text = ctRoot.value; focus = false }
            Connections {
                target: ctRoot
                function onValueChanged() { parent.text = ctRoot.value }
            }
        }
    }

    component CfgToggle: Rectangle {
        property bool checked: false
        signal toggled(bool v)
        width: 44; height: 24; radius: 12
        color: checked ? panel.accent : Qt.rgba(1,1,1,0.15)
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 18; height: 18; radius: 9; color: "white"
            x: parent.checked ? 22 : 4; anchors.verticalCenter: parent.verticalCenter
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { parent.toggled(!parent.checked); panel.hasChanges = true }
        }
    }

    component CfgSlider: RowLayout {
        id: slRoot
        property real   value:       0.5
        property real   from:        0
        property real   to:          1
        property int    decimals:    0
        property string unit:        ""
        property int    sliderWidth: 155
        signal changed(real v)
        spacing: 10

        function fmtVal() {
            return decimals > 0 ? value.toFixed(decimals) : Math.round(value).toString()
        }

        Slider {
            id: sl; from: slRoot.from; to: slRoot.to
            implicitWidth: slRoot.sliderWidth; implicitHeight: 28
            onMoved: { slRoot.value = value; panel.hasChanges = true; slRoot.changed(slRoot.value) }
            background: Rectangle {
                x: sl.leftPadding; y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: sl.availableWidth; height: 4; radius: 2; color: Qt.rgba(1,1,1,0.12)
                Rectangle { width: sl.visualPosition * parent.width; height: parent.height; radius: 2; color: panel.accent }
            }
            handle: Rectangle {
                x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
                y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: 16; height: 16; radius: 9; color: "white"
                border.color: panel.accent; border.width: 2
                layer.enabled: sl.pressed
            }
        }

        Binding { target: sl; property: "value"; value: slRoot.value; when: !sl.pressed }

        Rectangle {
            width: 72; height: 28; radius: 8
            color: valInput.activeFocus ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.07)
            border.color: valInput.activeFocus ? panel.accent : Qt.rgba(1,1,1,0.15)
            border.width: 1
            Behavior on color        { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }
            TextField {
                id: valInput
                anchors.centerIn: parent
                width: parent.width - 8
                Component.onCompleted: text = slRoot.fmtVal()
                font.pixelSize: 12; color: panel.fg
                horizontalAlignment: Text.AlignHCenter
                background: Item {}
                selectByMouse: true
                Connections {
                    target: slRoot
                    function onValueChanged() {
                        if (!valInput.activeFocus) valInput.text = slRoot.fmtVal()
                    }
                }
                onEditingFinished: {
                    var v = parseFloat(text)
                    if (!isNaN(v)) {
                        v = Math.max(slRoot.from, Math.min(slRoot.to, v))
                        slRoot.value = slRoot.decimals > 0 ? v : Math.round(v)
                        panel.hasChanges = true
                        slRoot.changed(slRoot.value)
                    }
                    text = slRoot.fmtVal()
                    focus = false
                }
                Keys.onEscapePressed: { text = slRoot.fmtVal(); focus = false }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                text: slRoot.unit
                font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35)
                visible: slRoot.unit !== "" && !valInput.activeFocus
            }
        }
    }

    component SRow: Item {
        id: sRow
        property string lbl: ""
        property string sub: ""
        default property alias ctrl: slot.data
        width: parent ? parent.width : 0
        height: Math.max(62, lblCol.implicitHeight + 28)

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.05) }
        RowLayout {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 24; anchors.rightMargin: 24
            spacing: 16
            Column {
                id: lblCol
                Layout.fillWidth: true; spacing: 4
                Text { text: sRow.lbl; font.pixelSize: 13; color: panel.fg; width: lblCol.width; wrapMode: Text.Wrap }
                Text { text: sRow.sub; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.35); visible: sRow.sub !== ""; width: lblCol.width; wrapMode: Text.Wrap }
            }
            Item { id: slot; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height; Layout.alignment: Qt.AlignVCenter }
        }
    }

    // Multi-line path list (one path per line)
    component CfgArea: Rectangle {
        id: caRoot
        property string value: ""
        signal changed(string v)
        width: parent ? parent.width : 0
        height: Math.max(68, areaField.implicitHeight + 18)
        radius: 8
        color: Qt.rgba(1,1,1,0.07)
        border.color: Qt.rgba(1,1,1,0.15); border.width: 1
        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        clip: true
        TextArea {
            id: areaField
            anchors.fill: parent; anchors.margins: 8
            text: caRoot.value
            font.pixelSize: 12; font.family: "monospace"; color: panel.fg
            background: Item {}
            selectByMouse: true
            wrapMode: TextArea.NoWrap
            onTextChanged: {
                if (text !== caRoot.value) {
                    caRoot.value = text
                    panel.hasChanges = true
                    caRoot.changed(text)
                }
            }
            onActiveFocusChanged: {
                caRoot.color        = activeFocus ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.07)
                caRoot.border.color = activeFocus ? panel.accent : Qt.rgba(1,1,1,0.15)
            }
            Keys.onEscapePressed: { text = caRoot.value; focus = false }
            Connections {
                target: caRoot
                function onValueChanged() { if (areaField.text !== caRoot.value) areaField.text = caRoot.value }
            }
        }
    }

    // Row with label on top + full-width control below (for path lists etc.)
    component SCol: Item {
        id: sCol
        property string lbl: ""
        property string sub: ""
        default property alias ctrl: sColSlot.data
        width: parent ? parent.width : 0
        height: sColInner.implicitHeight + 28
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.05) }
        Column {
            id: sColInner
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 24; anchors.rightMargin: 24
            anchors.top: parent.top; anchors.topMargin: 14
            spacing: 10
            Column { spacing: 4; width: parent.width
                Text { text: sCol.lbl; font.pixelSize: 13; color: panel.fg; width: parent.width; wrapMode: Text.Wrap }
                Text { text: sCol.sub; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.35); visible: sCol.sub !== ""; width: parent.width; wrapMode: Text.Wrap }
            }
            Item { id: sColSlot; width: parent.width; implicitHeight: childrenRect.height }
        }
    }

    // ── Section components ────────────────────────────────────────────────────

    // Path list editor — one editable row per path + add/remove
    component PathList: Column {
        id: pl
        property var    items: []
        property string addLabel: i18n.t("cfg_path_add")
        signal changed(var newItems)
        width: parent ? parent.width : 0
        spacing: 6

        Repeater {
            model: pl.items.length
            delegate: RowLayout {
                id: pathRow
                property int pathIdx: index
                width: pl.width; spacing: 6

                Rectangle {
                    Layout.fillWidth: true; height: 32; radius: 8
                    color: pf.activeFocus ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.07)
                    border.color: pf.activeFocus ? panel.accent : Qt.rgba(1,1,1,0.15); border.width: 1
                    Behavior on color        { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    TextField {
                        id: pf
                        anchors.fill: parent; anchors.margins: 6
                        font.pixelSize: 12; font.family: "monospace"; color: panel.fg
                        background: Item {}
                        selectByMouse: true
                        Component.onCompleted: text = pl.items[pathRow.pathIdx] ?? ""
                        Connections {
                            target: pl
                            function onItemsChanged() {
                                if (!pf.activeFocus)
                                    pf.text = pl.items[pathRow.pathIdx] ?? ""
                            }
                        }
                        function commit() {
                            const v = text
                            if (v !== (pl.items[pathRow.pathIdx] ?? "")) {
                                var arr = pl.items.slice()
                                arr[pathRow.pathIdx] = v
                                pl.changed(arr)
                            }
                        }
                        onActiveFocusChanged: if (!activeFocus) commit()
                        onEditingFinished: { commit(); focus = false }
                        Keys.onEscapePressed: { text = pl.items[pathRow.pathIdx] ?? ""; focus = false }
                    }
                }

                Rectangle {
                    width: 32; height: 32; radius: 8
                    color: pdM.containsMouse ? Qt.rgba(1,0.2,0.2,0.22) : Qt.rgba(1,1,1,0.07)
                    border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 13; color: Qt.rgba(1,0.4,0.4,0.85) }
                    MouseArea { id: pdM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var arr = pl.items.slice()
                            arr.splice(pathRow.pathIdx, 1)
                            pl.changed(arr)
                        }
                    }
                }
            }
        }

        Rectangle {
            width: 170; height: 30; radius: 8
            color: paM.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.07)
            border.color: Qt.rgba(1,1,1,0.12); border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }
            Row { anchors.centerIn: parent; spacing: 7
                Text { text: ""; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 10; color: panel.fg; anchors.verticalCenter: parent.verticalCenter }
                Text { text: pl.addLabel; font.pixelSize: 12; color: panel.fg; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { id: paM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { var arr = pl.items.slice(); arr.push(""); pl.changed(arr) }
            }
        }
    }

    Component {
        id: displayComp
        Column {
            width: parent ? parent.width : 0
            topPadding: 4
            SRow { lbl: i18n.t("cfg_position"); sub: i18n.t("cfg_position_sub")
                CfgCombo {
                    choices: ["center","top","bottom","left","right"]
                    currentIndex: Math.max(0, choices.indexOf(panel.ePosition))
                    onCurrentIndexChanged: {
                        const v = choices[currentIndex]
                        if (v && v !== panel.ePosition) { panel.ePosition = v; panel.hasChanges = true }
                    }
                }
            }
            SRow { lbl: i18n.t("cfg_orientation"); sub: i18n.t("cfg_orientation_sub")
                CfgCombo {
                    choices: ["horizontal","vertical"]
                    currentIndex: Math.max(0, choices.indexOf(panel.eOrientation))
                    onCurrentIndexChanged: {
                        const v = choices[currentIndex]
                        if (v && v !== panel.eOrientation) { panel.eOrientation = v; panel.hasChanges = true }
                    }
                }
            }
            SRow { lbl: i18n.t("cfg_cols"); sub: i18n.t("cfg_cols_sub")
                CfgSpin { value: panel.eCols; min: 1; max: 12
                    onChanged: v => panel.eCols = v
                }
            }
            SRow { lbl: i18n.t("cfg_rows"); sub: i18n.t("cfg_rows_sub")
                CfgSpin { value: panel.eRows; min: 1; max: 12
                    onChanged: v => panel.eRows = v
                }
            }
            SRow { lbl: i18n.t("cfg_card_width"); sub: i18n.t("cfg_card_width_sub")
                CfgSlider { from: 200; to: 800; value: panel.eItemWidth; unit: "px"
                    onChanged: v => panel.eItemWidth = Math.round(v)
                }
            }
            SRow { lbl: i18n.t("cfg_card_height"); sub: i18n.t("cfg_card_height_sub")
                CfgSlider { from: 100; to: 600; value: panel.eItemHeight; unit: "px"
                    onChanged: v => panel.eItemHeight = Math.round(v)
                }
            }
            SRow { lbl: i18n.t("cfg_spacing"); sub: i18n.t("cfg_spacing_sub")
                CfgSlider { from: 0; to: 60; value: panel.eSpacing; unit: "px"
                    onChanged: v => panel.eSpacing = Math.round(v)
                }
            }
        }
    }

    Component {
        id: appearComp
        Column {
            width: parent ? parent.width : 0
            topPadding: 4
            SRow { lbl: i18n.t("cfg_wallust"); sub: i18n.t("cfg_wallust_sub")
                CfgToggle {
                    checked: panel.eWallust
                    onToggled: v => {
                        panel.eWallust = v
                        if (v) panel.eMatugen = false
                    }
                }
            }
            SRow { lbl: i18n.t("cfg_wallust_path"); sub: i18n.t("cfg_wallust_path_sub")
                CfgText { value: panel.eWallustPath; fieldWidth: 240
                    onChanged: v => panel.eWallustPath = v
                }
            }
            SRow { lbl: i18n.t("cfg_matugen"); sub: i18n.t("cfg_matugen_sub")
                CfgToggle {
                    checked: panel.eMatugen
                    onToggled: v => {
                        panel.eMatugen = v
                        if (v) panel.eWallust = false
                    }
                }
            }
            SRow { lbl: i18n.t("cfg_matugen_path"); sub: i18n.t("cfg_matugen_path_sub")
                CfgText { value: panel.eMatugenPath; fieldWidth: 240
                    onChanged: v => panel.eMatugenPath = v
                }
            }

            // ── Palette preview ───────────────────────────────────────────
            Item {
                width: parent.width
                height: 54
                visible: panel.eWallust || panel.eMatugen

                property bool hasPalette: panel.colors && panel.colors.background ? true : false

                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.05) }

                // No palette loaded
                Row {
                    visible: !parent.hasPalette
                    anchors.left: parent.left; anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        text: ""
                        font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 11
                        color: Qt.rgba(1,1,1,0.22)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Palette non disponible — relancer le launcher"
                        font.pixelSize: 11; color: Qt.rgba(1,1,1,0.25)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Palette loaded — show swatches
                RowLayout {
                    visible: parent.hasPalette
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 24; anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: "Palette"
                        font.pixelSize: 11; color: Qt.rgba(1,1,1,0.35)
                        Layout.preferredWidth: 50
                    }

                    // bg
                    Rectangle {
                        Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 5
                        color: panel.colors.background || panel.bg
                        border.color: Qt.rgba(1,1,1,0.18); border.width: 1
                        ToolTip.visible: bgM.containsMouse; ToolTip.text: panel.colors.background || ""
                        MouseArea { id: bgM; anchors.fill: parent; hoverEnabled: true }
                    }
                    // fg
                    Rectangle {
                        Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 5
                        color: panel.colors.foreground || panel.fg
                        border.color: Qt.rgba(1,1,1,0.18); border.width: 1
                        ToolTip.visible: fgM.containsMouse; ToolTip.text: panel.colors.foreground || ""
                        MouseArea { id: fgM; anchors.fill: parent; hoverEnabled: true }
                    }

                    // separator
                    Item { Layout.preferredWidth: 6 }

                    // color0–15
                    Repeater {
                        model: 16
                        Rectangle {
                            required property int index
                            Layout.preferredWidth: 18; Layout.preferredHeight: 18; radius: 4
                            color: panel.colors["color" + index] || "transparent"
                            border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                            ToolTip.visible: swM.containsMouse
                            ToolTip.text: "color" + index + "  " + (panel.colors["color" + index] || "")
                            MouseArea { id: swM; anchors.fill: parent; hoverEnabled: true }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            SRow { lbl: i18n.t("cfg_blur"); sub: i18n.t("cfg_blur_sub")
                CfgToggle { checked: panel.eBlur; onToggled: v => panel.eBlur = v }
            }
            SRow { lbl: i18n.t("cfg_opacity"); sub: i18n.t("cfg_opacity_sub")
                CfgSlider { from: 0; to: 1; value: panel.eOpacity; decimals: 2
                    onChanged: v => panel.eOpacity = v
                }
            }
        }
    }

    Component {
        id: behaviorComp
        Column {
            width: parent ? parent.width : 0
            topPadding: 4
            SRow { lbl: i18n.t("cfg_sort_by"); sub: i18n.t("cfg_sort_by_sub")
                CfgCombo {
                    choices: ["recent","name","playtime"]
                    currentIndex: Math.max(0, choices.indexOf(panel.eSortBy))
                    onCurrentIndexChanged: {
                        const v = choices[currentIndex]
                        if (v && v !== panel.eSortBy) { panel.eSortBy = v; panel.hasChanges = true }
                    }
                }
            }
            SRow { lbl: i18n.t("cfg_show_favs"); sub: i18n.t("cfg_show_favs_sub")
                CfgToggle { checked: panel.eShowFavs; onToggled: v => panel.eShowFavs = v }
            }
            SRow { lbl: i18n.t("cfg_close_launch"); sub: i18n.t("cfg_close_launch_sub")
                CfgToggle { checked: panel.eCloseOnLaunch; onToggled: v => panel.eCloseOnLaunch = v }
            }
            SRow { lbl: i18n.t("cfg_default_source"); sub: i18n.t("cfg_default_source_sub")
                CfgSpin { value: panel.eDefaultSource; min: 0; max: 10
                    onChanged: v => panel.eDefaultSource = v
                }
            }
            SRow { lbl: i18n.t("cfg_remember_source"); sub: i18n.t("cfg_remember_source_sub")
                CfgToggle { checked: panel.eRememberSource; onToggled: v => panel.eRememberSource = v }
            }
            SRow { lbl: i18n.t("cfg_bigpicture"); sub: i18n.t("cfg_bigpicture_sub")
                CfgToggle { checked: panel.eBigPicture; onToggled: v => panel.eBigPicture = v }
            }
        }
    }

    Component {
        id: animComp
        Column {
            width: parent ? parent.width : 0
            topPadding: 4
            SRow { lbl: i18n.t("cfg_anim_duration"); sub: i18n.t("cfg_anim_duration_sub")
                CfgSlider { from: 0; to: 1000; value: panel.eAnimDuration; unit: "ms"
                    onChanged: v => panel.eAnimDuration = Math.round(v)
                }
            }
        }
    }

    Component {
        id: steamComp
        Column {
            width: parent ? parent.width : 0
            topPadding: 4
            SRow { lbl: i18n.t("cfg_steam_on"); sub: i18n.t("cfg_steam_on_sub")
                CfgToggle { checked: panel.eSteamEnabled; onToggled: v => panel.eSteamEnabled = v }
            }
            SCol { lbl: i18n.t("cfg_steam_paths"); sub: i18n.t("cfg_steam_paths_sub")
                PathList {
                    items: panel.eSteamPaths
                    onChanged: p => { panel.eSteamPaths = p; panel.hasChanges = true }
                }
            }
        }
    }

    Component {
        id: heroicComp
        Column {
            width: parent ? parent.width : 0
            topPadding: 4
            SRow { lbl: i18n.t("cfg_heroic_on"); sub: i18n.t("cfg_heroic_on_sub")
                CfgToggle { checked: panel.eHeroicEnabled; onToggled: v => panel.eHeroicEnabled = v }
            }
            SRow { lbl: i18n.t("cfg_heroic_epic"); sub: i18n.t("cfg_heroic_epic_sub")
                CfgToggle { checked: panel.eHeroicEpic; onToggled: v => panel.eHeroicEpic = v }
            }
            SRow { lbl: i18n.t("cfg_heroic_gog"); sub: i18n.t("cfg_heroic_gog_sub")
                CfgToggle { checked: panel.eHeroicGog; onToggled: v => panel.eHeroicGog = v }
            }
            SRow { lbl: i18n.t("cfg_heroic_amazon"); sub: i18n.t("cfg_heroic_amazon_sub")
                CfgToggle { checked: panel.eHeroicAmazon; onToggled: v => panel.eHeroicAmazon = v }
            }
            SRow { lbl: i18n.t("cfg_heroic_sideload"); sub: i18n.t("cfg_heroic_sideload_sub")
                CfgToggle { checked: panel.eHeroicSideload; onToggled: v => panel.eHeroicSideload = v }
            }
            SCol { lbl: i18n.t("cfg_heroic_paths"); sub: i18n.t("cfg_heroic_paths_sub")
                PathList {
                    items: panel.eHeroicPaths
                    onChanged: p => { panel.eHeroicPaths = p; panel.hasChanges = true }
                }
            }
        }
    }

    Component {
        id: lutrisComp
        Column {
            width: parent ? parent.width : 0
            topPadding: 4
            SRow { lbl: i18n.t("cfg_lutris_on"); sub: i18n.t("cfg_lutris_on_sub")
                CfgToggle { checked: panel.eLutrisEnabled; onToggled: v => panel.eLutrisEnabled = v }
            }
            SRow { lbl: i18n.t("cfg_lutris_db"); sub: i18n.t("cfg_lutris_db_sub")
                CfgText { value: panel.eLutrisDb; fieldWidth: 260
                    onChanged: v => panel.eLutrisDb = v
                }
            }
        }
    }

    Component {
        id: sgdbComp
        Column {
            width: parent ? parent.width : 0
            topPadding: 4
            SRow { lbl: i18n.t("cfg_sgdb_on"); sub: i18n.t("cfg_sgdb_on_sub")
                CfgToggle { checked: panel.eSgdbEnabled; onToggled: v => panel.eSgdbEnabled = v }
            }
            SRow { lbl: i18n.t("cfg_sgdb_api"); sub: i18n.t("cfg_sgdb_api_sub")
                CfgText { value: panel.eSgdbApiKey; fieldWidth: 220
                    onChanged: v => panel.eSgdbApiKey = v
                }
            }
            SRow { lbl: i18n.t("cfg_sgdb_type"); sub: i18n.t("cfg_sgdb_type_sub")
                CfgCombo {
                    choices: ["grid","hero","logo","icon"]
                    currentIndex: Math.max(0, choices.indexOf(panel.eSgdbImageType))
                    onCurrentIndexChanged: {
                        const v = choices[currentIndex]
                        if (v && v !== panel.eSgdbImageType) { panel.eSgdbImageType = v; panel.hasChanges = true }
                    }
                }
            }
            SRow { lbl: i18n.t("cfg_sgdb_animated"); sub: i18n.t("cfg_sgdb_animated_sub")
                CfgToggle { checked: panel.eSgdbAnimated; onToggled: v => panel.eSgdbAnimated = v }
            }
            SRow { lbl: i18n.t("cfg_sgdb_fallback"); sub: i18n.t("cfg_sgdb_fallback_sub")
                CfgToggle { checked: panel.eSgdbFallback; onToggled: v => panel.eSgdbFallback = v }
            }
            SRow { lbl: i18n.t("cfg_sgdb_sort_likes"); sub: i18n.t("cfg_sgdb_sort_likes_sub")
                CfgToggle { checked: panel.eSgdbSortLikes; onToggled: v => panel.eSgdbSortLikes = v }
            }
            SRow { lbl: i18n.t("cfg_sgdb_min_likes"); sub: i18n.t("cfg_sgdb_min_likes_sub")
                CfgSlider { from: 0; to: 500; value: panel.eSgdbMinLikes
                    onChanged: v => panel.eSgdbMinLikes = Math.round(v)
                }
            }
            SRow { lbl: i18n.t("cfg_sgdb_nsfw"); sub: i18n.t("cfg_sgdb_nsfw_sub")
                CfgToggle { checked: panel.eSgdbNsfw; onToggled: v => panel.eSgdbNsfw = v }
            }
            SRow { lbl: i18n.t("cfg_sgdb_humor"); sub: i18n.t("cfg_sgdb_humor_sub")
                CfgToggle { checked: panel.eSgdbHumor; onToggled: v => panel.eSgdbHumor = v }
            }
            SRow { lbl: i18n.t("cfg_sgdb_epilepsy"); sub: i18n.t("cfg_sgdb_epilepsy_sub")
                CfgToggle { checked: panel.eSgdbEpilepsy; onToggled: v => panel.eSgdbEpilepsy = v }
            }
            SRow { lbl: i18n.t("cfg_sgdb_parallel"); sub: i18n.t("cfg_sgdb_parallel_sub")
                CfgToggle { checked: panel.eSgdbParallel; onToggled: v => panel.eSgdbParallel = v }
            }
            SRow { lbl: i18n.t("cfg_sgdb_workers"); sub: i18n.t("cfg_sgdb_workers_sub")
                CfgSpin { value: panel.eSgdbMaxWorkers; min: 1; max: 32
                    onChanged: v => panel.eSgdbMaxWorkers = v
                }
            }
            SRow { lbl: i18n.t("cfg_sgdb_timeout"); sub: i18n.t("cfg_sgdb_timeout_sub")
                CfgSpin { value: panel.eSgdbTimeout; min: 1; max: 60
                    onChanged: v => panel.eSgdbTimeout = v
                }
            }
            SRow { lbl: i18n.t("cfg_sgdb_cache"); sub: i18n.t("cfg_sgdb_cache_sub")
                CfgSpin { value: panel.eSgdbCacheTtl; min: 1; max: 720
                    onChanged: v => panel.eSgdbCacheTtl = v
                }
            }
        }
    }

    Component {
        id: filterComp
        Column {
            width: parent ? parent.width : 0
            topPadding: 4
            SRow { lbl: i18n.t("cfg_games_only"); sub: i18n.t("cfg_games_only_sub")
                CfgToggle { checked: panel.eGamesOnly; onToggled: v => panel.eGamesOnly = v }
            }
            SRow { lbl: i18n.t("cfg_excl_cats"); sub: i18n.t("cfg_excl_cats_sub")
                CfgText { value: panel.eExcludeCategories; fieldWidth: 260
                    onChanged: v => panel.eExcludeCategories = v
                }
            }
            SRow { lbl: i18n.t("cfg_excl_keywords"); sub: i18n.t("cfg_excl_keywords_sub")
                CfgText { value: panel.eExcludeKeywords; fieldWidth: 260
                    onChanged: v => panel.eExcludeKeywords = v
                }
            }
        }
    }

    // ── Manual entries editor ─────────────────────────────────────────────────

    // Single-line field for manual entries
    component MField: Rectangle {
        id: mf
        property string placeholder: ""
        property string fkey: ""
        property int    eidx: -1
        width: parent ? parent.width : 0; height: 32; radius: 8
        color: mfTf.activeFocus ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.07)
        border.color: mfTf.activeFocus ? panel.accent : Qt.rgba(1,1,1,0.15); border.width: 1
        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        TextField {
            id: mfTf
            anchors.fill: parent; anchors.margins: 6
            placeholderText: mf.placeholder; font.pixelSize: 12; color: panel.fg
            background: Item {}
            selectByMouse: true
            Component.onCompleted: text = panel.eManualEntries[mf.eidx]?.[mf.fkey] ?? ""
            Connections {
                target: panel
                function onEManualEntriesChanged() {
                    if (!mfTf.activeFocus)
                        mfTf.text = panel.eManualEntries[mf.eidx]?.[mf.fkey] ?? ""
                }
                function onSelectedManualIdxChanged() {
                    mfTf.text = panel.eManualEntries[mf.eidx]?.[mf.fkey] ?? ""
                }
            }
            function commit() {
                const v = text
                if (v !== (panel.eManualEntries[mf.eidx]?.[mf.fkey] ?? ""))
                    panel.manualUpdateEntry(mf.eidx, mf.fkey, v)
            }
            onActiveFocusChanged: if (!activeFocus) commit()
            onEditingFinished: { commit(); focus = false }
            Keys.onEscapePressed: {
                text = panel.eManualEntries[mf.eidx]?.[mf.fkey] ?? ""; focus = false
            }
        }
    }

    Component {
        id: manualComp
        Item {
            width: parent ? parent.width : 0
            implicitHeight: 390

            // ── Left list ────────────────────────────────────────────────
            Rectangle {
                id: manLeftPanel
                width: 155
                anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: panel.bgDark

                Column {
                    width: parent.width
                    topPadding: 6

                    Repeater {
                        model: panel.eManualEntries.length
                        delegate: Rectangle {
                            id: manItem
                            width: parent ? parent.width : 0; height: 36; radius: 8
                            property bool active: panel.selectedManualIdx === index
                            color: active
                                ? Qt.rgba(parseInt(panel.accent.slice(1,3),16)/255,
                                          parseInt(panel.accent.slice(3,5),16)/255,
                                          parseInt(panel.accent.slice(5,7),16)/255, 0.20)
                                : (manHov.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Rectangle {
                                visible: manItem.active; width: 3; radius: 2
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 6 }
                                color: panel.accent
                            }
                            Text {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                text: panel.eManualEntries[index]?.title || ("— " + (index + 1))
                                font.pixelSize: 12
                                color: manItem.active ? panel.fg : Qt.rgba(
                                    parseInt(panel.fg.slice(1,3),16)/255,
                                    parseInt(panel.fg.slice(3,5),16)/255,
                                    parseInt(panel.fg.slice(5,7),16)/255, 0.6)
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: manHov; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.selectedManualIdx = index
                            }
                        }
                    }
                }

                // Add button
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.left: parent.left
                    anchors.right: parent.right; anchors.margins: 8
                    height: 32; radius: 8
                    color: addH.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.07)
                    border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Row { anchors.centerIn: parent; spacing: 7
                        Text { text: ""; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 10; color: panel.fg; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: i18n.t("cfg_manual_add"); font.pixelSize: 12; color: panel.fg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: addH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.manualAddEntry() }
                }

                Text {
                    visible: panel.eManualEntries.length === 0
                    anchors.top: parent.top; anchors.topMargin: 20
                    anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                    text: i18n.t("cfg_manual_empty")
                    font.pixelSize: 11; color: Qt.rgba(1,1,1,0.22)
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                }
            }

            // Divider
            Rectangle {
                anchors.left: manLeftPanel.right; width: 1
                anchors.top: parent.top; anchors.bottom: parent.bottom
                color: Qt.rgba(1,1,1,0.07)
            }

            // ── Right detail panel ───────────────────────────────────────
            Item {
                anchors.left: manLeftPanel.right; anchors.leftMargin: 1
                anchors.right: parent.right
                anchors.top: parent.top; anchors.bottom: parent.bottom
                visible: panel.eManualEntries.length > 0

                Column {
                    anchors.fill: parent; anchors.margins: 16; anchors.topMargin: 10
                    spacing: 10

                    // Box-art folder
                    Column { spacing: 4; width: parent.width
                        Text { text: i18n.t("cfg_manual_boxart_dir"); font.pixelSize: 11; color: Qt.rgba(1,1,1,0.45) }
                        CfgText { value: panel.eBoxArtDir; fieldWidth: parent.width
                            onChanged: v => panel.eBoxArtDir = v
                        }
                    }

                    // Title
                    Column { spacing: 4; width: parent.width
                        Text { text: i18n.t("cfg_manual_title_lbl"); font.pixelSize: 11; color: Qt.rgba(1,1,1,0.45) }
                        MField { fkey: "title"; eidx: panel.selectedManualIdx; placeholder: i18n.t("cfg_manual_title") }
                    }

                    // Launch command — TextArea with line wrap
                    Column { spacing: 4; width: parent.width
                        Text { text: i18n.t("cfg_manual_cmd_lbl"); font.pixelSize: 11; color: Qt.rgba(1,1,1,0.45) }
                        Rectangle {
                            width: parent.width
                            height: Math.max(56, cmdArea.implicitHeight + 16)
                            radius: 8
                            color: cmdArea.activeFocus ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.07)
                            border.color: cmdArea.activeFocus ? panel.accent : Qt.rgba(1,1,1,0.15)
                            border.width: 1; clip: true
                            Behavior on color        { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            TextArea {
                                id: cmdArea
                                anchors.fill: parent; anchors.margins: 8
                                placeholderText: i18n.t("cfg_manual_cmd")
                                font.pixelSize: 12; font.family: "monospace"; color: panel.fg
                                background: Item {}
                                selectByMouse: true
                                wrapMode: TextArea.Wrap
                                Component.onCompleted: text = panel.eManualEntries[panel.selectedManualIdx]?.launch_command ?? ""
                                Connections {
                                    target: panel
                                    function onEManualEntriesChanged() {
                                        if (!cmdArea.activeFocus)
                                            cmdArea.text = panel.eManualEntries[panel.selectedManualIdx]?.launch_command ?? ""
                                    }
                                    function onSelectedManualIdxChanged() {
                                        cmdArea.text = panel.eManualEntries[panel.selectedManualIdx]?.launch_command ?? ""
                                    }
                                }
                                function commit() {
                                    const v = text
                                    const cur = panel.eManualEntries[panel.selectedManualIdx]?.launch_command ?? ""
                                    if (v !== cur) panel.manualUpdateEntry(panel.selectedManualIdx, "launch_command", v)
                                }
                                onActiveFocusChanged: if (!activeFocus) commit()
                                Keys.onEscapePressed: {
                                    text = panel.eManualEntries[panel.selectedManualIdx]?.launch_command ?? ""
                                    focus = false
                                }
                            }
                        }
                    }

                    // Cover image
                    Column { spacing: 4; width: parent.width
                        Text { text: i18n.t("cfg_manual_cover_lbl"); font.pixelSize: 11; color: Qt.rgba(1,1,1,0.45) }
                        MField { fkey: "path_box_art"; eidx: panel.selectedManualIdx; placeholder: i18n.t("cfg_manual_cover") }
                    }

                    // Delete button
                    Rectangle {
                        width: 130; height: 32; radius: 8
                        color: delH.containsMouse ? Qt.rgba(1,0.15,0.15,0.30) : Qt.rgba(1,0.15,0.15,0.15)
                        border.color: Qt.rgba(1,0.3,0.3,0.3); border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Row { anchors.centerIn: parent; spacing: 8
                            Text { text: ""; font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 11; color: Qt.rgba(1,0.45,0.45,1); anchors.verticalCenter: parent.verticalCenter }
                            Text { text: i18n.t("cfg_manual_delete"); font.pixelSize: 13; color: Qt.rgba(1,0.45,0.45,1); anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: delH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: panel.manualRemoveEntry(panel.selectedManualIdx)
                        }
                    }
                }
            }
        }
    }
}
