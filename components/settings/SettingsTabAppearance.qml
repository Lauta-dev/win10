import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../../state"
import "../../components"

// SettingsTabAppearance — wallpaper, colores y GTK/iconos en una sola página:
// fila superior con el fondo actual (acceso a carpetas) y los controles de
// color (claro/oscuro + fuente de paleta), y debajo la galería.
Item {
    id: root
    anchors.fill: parent

    // ── Variables primero (sin magic strings abajo) ──────
    readonly property int outerMargin: 16
    readonly property int outerGap: 12
    readonly property int topH: 236
    readonly property int cardGap: 12
    readonly property int cardPad: 14
    readonly property int cardSpacing: 10
    readonly property int cardMinW: 320
    readonly property real cardWFactor: 0.4

    readonly property int chipH: 32
    readonly property int chipPad: 8
    readonly property int chipIconGap: 6

    readonly property int comboH: 32

    readonly property int segH: 34
    readonly property int segIconGap: 6
    readonly property int swatchSize: 12
    readonly property int swatchGap: 6
    readonly property int captionGap: 4

    readonly property int cellMargin: 4
    readonly property int colsWide: 4
    readonly property int colsNarrow: 3
    readonly property int colsBreak: 760
    readonly property int badgeSize: 24
    readonly property int emptyIconBox: 72
    readonly property int thumbW: 240
    readonly property int thumbH: 140
    readonly property int heroSrcW: 880
    readonly property int heroSrcH: 280
    readonly property int scrimH: 64
    readonly property int heroBtnSize: 44

    readonly property string nowLabel: "Actual"
    readonly property string heroEmptyLabel: "Elegí un fondo de la galería"
    readonly property string openDirLabel: "Abrir carpeta"
    readonly property string colorsTitle: "Apariencia"
    readonly property string modeTitle: "Modo"
    readonly property string lightLabel: "Claro"
    readonly property string darkLabel: "Oscuro"
    readonly property string sourceTitle: "Fuente"
    readonly property string gtkTitle: "Tema GTK"
    readonly property string iconTitle: "Iconos"
    readonly property string schemeTitle: "Esquema"
    readonly property string emptyTitle: "Sin imágenes"
    readonly property string emptyHint: "Añadí una carpeta para empezar"
    readonly property string emptyCta: "Añadir carpeta"

    // Fuentes de paleta disponibles. El resto del catálogo (nord, dracula…)
    // todavía no está expuesto acá.
    readonly property var colorSources: [
        { id: "chromeos", label: "ChromeOS" },
        { id: "matugen",  label: "Matugen"  }
    ]
    readonly property var themeModes: [
        { id: "light", label: root.lightLabel, icon: Icons.lightMode },
        { id: "dark",  label: root.darkLabel,  icon: Icons.darkMode  }
    ]

    readonly property color bgHero: Style.surface_container_high
    readonly property color bgCard: Style.surface_container
    readonly property color bgChip: Style.surface_container_high
    readonly property color bgPopup: Style.surface_container_highest
    readonly property color bgBadge: Style.primary
    readonly property color bgSeg: Style.surface_container_highest
    readonly property color bgSegActive: Style.primary
    readonly property color bgEmptyIcon: Style.primary_container
    readonly property color bgHeroBtn: Qt.rgba(0, 0, 0, 0.55)
    readonly property color heroVeil: Qt.rgba(0, 0, 0, 0.35)
    readonly property color borderSubtle: Style.outline_variant
    readonly property color borderActive: Style.primary
    readonly property color fgTitle: Style.on_surface
    readonly property color fgBody: Style.on_surface_variant
    readonly property color fgBadge: Style.on_primary
    readonly property color fgSeg: Style.on_surface
    readonly property color fgSegActive: Style.on_primary
    readonly property color fgEmptyIcon: Style.on_primary_container
    readonly property color fgHeroText: "white"
    readonly property color scrimFrom: Qt.rgba(0, 0, 0, 0)
    readonly property color scrimTo: Qt.rgba(0, 0, 0, 0.55)
    readonly property var swatchColors: [Style.primary, Style.secondary, Style.tertiary, Style.error]

    readonly property int cardRadius: Style.popup_radius
    readonly property int chipRadius: 8
    readonly property int badgeRadius: 8
    readonly property int emptyRadius: 16
    readonly property int segRadius: 9
    readonly property int borderW: 1
    readonly property int borderActiveW: 2

    readonly property int fsTitle: Config.fontSizeTitleSm
    readonly property int fsBody: Config.fontSizeLabel
    readonly property int fsSmall: Config.fontSizeLabelSm
    readonly property int fsCaption: Config.fontSizeCaption
    readonly property int fsIconLg: Config.fontSizeIconLg
    readonly property int fsHeroIcon: 30
    readonly property int fsHeroBtnIcon: 20
    readonly property string fontUi: Config.uiFont
    readonly property string fontIcon: Icons.font
    readonly property int wMedium: Config.fontWeightMedium
    readonly property int wBold: Config.fontWeightBold

    readonly property int durHover: Style.anim_fast
    readonly property real opacitySoft: 0.75
    readonly property real opacityOff: 0.45

    function colsFor(w) { return w >= colsBreak ? colsWide : colsNarrow }
    function baseName(p) {
        if (!p) return ""
        var parts = String(p).split("/")
        return parts[parts.length - 1]
    }
    function sourceIndex(id) {
        for (var i = 0; i < colorSources.length; i++)
            if (colorSources[i].id === id) return i
        return 0
    }
    function usingMatugen() { return ThemeState.colorTheme === "matugen" }
    function themeIndex(list, current) {
        var i = list.indexOf(current)
        return i >= 0 ? i : 0
    }

    Component.onCompleted: ThemeState.scanThemes()
    function modeActive(id) {
        return id === "dark" ? TaskbarState.darkMode : !TaskbarState.darkMode
    }

    // ── Galería: listado nativo del directorio (sin procesos ni Go) ─
    // FolderListModel filtra por extensión y ordena por nombre; en Linux
    // Qt ≥6.5 refresca solo y vigila el dir (QFileSystemWatcher interno).
    FolderListModel {
        id: wallsModel
        folder: WallpaperState.wallpaperDir !== "" ? "file://" + WallpaperState.wallpaperDir : ""
        showDirs: false
        showDotAndDotDot: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.bmp", "*.webp"]
        caseSensitive: false
        sortField: FolderListModel.Name
        sortReversed: false
    }

    // ── DirBrowser overlay ──────────────────────────────────────
    DirBrowser {
        id: wpDirBrowser
        anchors.fill: parent
        visible: false
        z: 10
        mode: "directories"
        showHeaderUseButton: true
        headerUseButtonLabel: "Usar este directorio"
        onDirectorySelected: (path) => {
            WallpaperState.saveDir(path)
            wpDirBrowser.close()
        }
    }

    // ── Layout principal: fondo + colores + galería ─────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.outerMargin
        spacing: root.outerGap

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.topH
            Layout.minimumHeight: root.topH
            Layout.maximumHeight: root.topH
            spacing: root.cardGap

            // ── Card: fondo actual ──────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: root.cardRadius
                clip: true
                color: root.bgHero
                border.color: root.borderSubtle; border.width: root.borderW

                RoundedImage {
                    id: heroImg
                    anchors.fill: parent
                    radius: root.cardRadius
                    source: WallpaperState.wallpaper !== "" ? WallpaperState.wallpaper : ""
                    sourceSize: Qt.size(root.heroSrcW, root.heroSrcH)
                }

                Column {
                    anchors.centerIn: parent; spacing: root.chipIconGap
                    visible: heroImg.status !== Image.Ready
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Icons.image
                        font.pixelSize: root.fsIconLg; font.family: root.fontIcon
                        color: Style.outline; opacity: root.opacitySoft
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: WallpaperState.wallpaper === ""
                        text: root.heroEmptyLabel
                        font.pixelSize: root.fsBody; font.family: root.fontUi
                        color: root.fgBody
                    }
                }

                // Scrim inferior para el nombre y el modo.
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: root.scrimH
                    radius: root.cardRadius
                    visible: heroImg.status === Image.Ready
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.scrimFrom }
                        GradientStop { position: 1.0; color: root.scrimTo }
                    }
                }

                // Hover: acceso al selector de carpetas.
                Rectangle {
                    anchors.fill: parent
                    radius: root.cardRadius
                    color: root.heroVeil
                    opacity: heroHover.hovered && heroImg.status === Image.Ready ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: root.durHover; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: root.heroBtnSize; height: root.heroBtnSize
                    radius: root.heroBtnSize / 2
                    color: root.bgHeroBtn
                    enabled: heroHover.hovered
                    opacity: heroHover.hovered ? 1.0 : 0.0
                    scale: heroHover.hovered ? 1.0 : 0.92
                    Behavior on opacity { NumberAnimation { duration: root.durHover; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: root.durHover; easing.type: Easing.OutCubic } }
                    Text {
                        anchors.centerIn: parent
                        text: Icons.folder
                        font.pixelSize: root.fsHeroBtnIcon; font.family: root.fontIcon
                        color: root.fgHeroText
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: root.openDirLabel
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: wpDirBrowser.open() }
                    Mouse{}
                }
                RowLayout {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.leftMargin: root.chipPad + 4; anchors.rightMargin: root.chipPad + 4
                    anchors.bottomMargin: root.chipPad
                    spacing: root.chipIconGap
                    visible: heroImg.status === Image.Ready

                    Text {
                        text: root.baseName(WallpaperState.wallpaper)
                        font.pixelSize: root.fsBody; font.weight: root.wMedium
                        font.family: root.fontUi; color: root.fgHeroText
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        Layout.preferredWidth: nowPill.implicitWidth + 20
                        Layout.preferredHeight: root.badgeSize
                        radius: root.badgeRadius
                        color: root.bgBadge
                        Row {
                            id: nowPill
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Icons.check
                                font.pixelSize: root.fsSmall; font.family: root.fontIcon
                                color: root.fgBadge
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.nowLabel
                                font.pixelSize: root.fsSmall; font.weight: root.wBold
                                font.family: root.fontUi; color: root.fgBadge
                            }
                        }
                    }
                }

                HoverHandler { id: heroHover }
            }

            // ── Card: colores ───────────────────────────────────
            Rectangle {
                Layout.preferredWidth: Math.max(root.cardMinW, Math.round(root.width * root.cardWFactor))
                Layout.fillHeight: true
                radius: root.cardRadius
                color: root.bgCard

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.cardPad
                    spacing: root.cardSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.chipIconGap
                        Text {
                            text: root.colorsTitle
                            font.pixelSize: root.fsTitle; font.weight: root.wBold
                            font.family: root.fontUi; color: root.fgTitle
                            Layout.fillWidth: true
                        }
                        Row {
                            spacing: root.swatchGap
                            Repeater {
                                model: root.swatchColors
                                delegate: Rectangle {
                                    required property var modelData
                                    width: root.swatchSize; height: root.swatchSize
                                    radius: root.swatchSize / 2
                                    color: modelData
                                }
                            }
                        }
                    }

                    Text {
                        text: root.modeTitle
                        font.pixelSize: root.fsCaption; font.weight: root.wMedium
                        font.family: root.fontUi; color: root.fgBody
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.chipIconGap

                        Repeater {
                            model: root.themeModes
                            delegate: Rectangle {
                                id: segBtn
                                required property var modelData
                                readonly property bool active: root.modeActive(modelData.id)

                                Layout.fillWidth: true
                                Layout.preferredHeight: root.segH
                                radius: root.segRadius
                                color: active ? root.bgSegActive : root.bgSeg
                                border.color: segHover.hovered && !active ? root.borderSubtle : "transparent"
                                border.width: root.borderW

                                Row {
                                    anchors.centerIn: parent
                                    spacing: root.segIconGap
                                    Text {
                                        text: segBtn.modelData.icon
                                        font.pixelSize: root.fsSmall; font.family: root.fontIcon
                                        color: segBtn.active ? root.fgSegActive : root.fgBody
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: segBtn.modelData.label
                                        font.pixelSize: root.fsSmall
                                        font.weight: segBtn.active ? root.wBold : root.wMedium
                                        font.family: root.fontUi
                                        color: segBtn.active ? root.fgSegActive : root.fgSeg
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Accessible.role: Accessible.Button
                                Accessible.name: segBtn.modelData.label
                                HoverHandler { id: segHover }
                                TapHandler {
                                    onTapped: TaskbarState.applyDarkMode(segBtn.modelData.id === "dark")
                                }
                                Mouse{}
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.cardSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.captionGap
                            Text {
                                text: root.sourceTitle
                                font.pixelSize: root.fsCaption; font.weight: root.wMedium
                                font.family: root.fontUi; color: root.fgBody
                            }
                            SettingsCombo {
                                id: sourceCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.comboH
                                model: root.colorSources.map(s => s.label)
                                currentIndex: root.sourceIndex(ThemeState.colorTheme)

                                onActivated: function(index) {
                                    ThemeState.applyShellTheme(root.colorSources[index].id)
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.captionGap
                            Text {
                                text: root.schemeTitle
                                font.pixelSize: root.fsCaption; font.weight: root.wMedium
                                font.family: root.fontUi
                                color: root.fgBody
                                opacity: root.usingMatugen() ? 1.0 : root.opacityOff
                            }
                            SettingsCombo {
                                id: schemeCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.comboH
                                model: WallpaperState.schemeTypes.map(s => s.label)
                                currentIndex: WallpaperState.schemeTypeIndex(WallpaperState.matugenSchemeType)
                                enabled: root.usingMatugen()
                                opacity: enabled ? 1.0 : root.opacityOff

                                onActivated: function(index) {
                                    WallpaperState.matugenSchemeType = WallpaperState.schemeTypes[index].id
                                    SettingsState.markDirty()
                                    if (WallpaperState.wallpaper !== "")
                                        WallpaperState.wallpaperProc.apply(WallpaperState.wallpaper)
                                }
                            }
                        }
                    }


                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.cardSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.captionGap
                            Text {
                                text: root.gtkTitle
                                font.pixelSize: root.fsCaption; font.weight: root.wMedium
                                font.family: root.fontUi; color: root.fgBody
                            }
                            SettingsCombo {
                                id: gtkCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.comboH
                                model: ThemeState.gtkThemes
                                currentIndex: root.themeIndex(ThemeState.gtkThemes, ThemeState.gtkTheme)
                                onActivated: function(index) {
                                    ThemeState.applyGtkTheme(ThemeState.gtkThemes[index])
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.captionGap
                            Text {
                                text: root.iconTitle
                                font.pixelSize: root.fsCaption; font.weight: root.wMedium
                                font.family: root.fontUi; color: root.fgBody
                            }
                            SettingsCombo {
                                id: iconCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.comboH
                                model: ThemeState.iconThemes
                                currentIndex: root.themeIndex(ThemeState.iconThemes, ThemeState.iconTheme)
                                onActivated: function(index) {
                                    ThemeState.applyIconTheme(ThemeState.iconThemes[index])
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ── Grid de wallpapers ──────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            Column {
                anchors.centerIn: parent; spacing: root.chipPad
                visible: wallsModel.count === 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.emptyIconBox; height: root.emptyIconBox; radius: root.emptyRadius
                    color: root.bgEmptyIcon
                    Text {
                        anchors.centerIn: parent; text: Icons.screenshot
                        font.pixelSize: root.fsHeroIcon; font.family: root.fontIcon
                        color: root.fgEmptyIcon
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.emptyTitle
                    font.pixelSize: root.fsTitle; font.family: root.fontUi
                    color: root.fgTitle; font.weight: root.wBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.emptyHint
                    font.pixelSize: root.fsBody; font.family: root.fontUi
                    color: root.fgBody
                }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: addCta.implicitWidth + 32; height: root.chipH + 4
                    Rectangle {
                        anchors.fill: parent; radius: root.chipRadius
                        color: Style.primary
                        opacity: addCtaH.hovered ? 1.0 : 0.9
                        Behavior on opacity { NumberAnimation { duration: root.durHover; easing.type: Easing.OutCubic } }
                    }
                    Text {
                        id: addCta
                        anchors.centerIn: parent
                        text: root.emptyCta
                        font.pixelSize: root.fsBody; font.weight: root.wMedium
                        font.family: root.fontUi; color: Style.on_primary
                    }
                    HoverHandler { id: addCtaH }
                    TapHandler { onTapped: wpDirBrowser.open() }
                    Mouse{}
                }
            }

            GridView {
                enabled: !wpDirBrowser.visible
                anchors.fill: parent
                visible: wallsModel.count > 0
                model: wallsModel
                cellWidth:  Math.floor(width / root.colsFor(width))
                cellHeight: Math.floor(cellWidth * 0.52)
                clip: true
                cacheBuffer: 150
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: wpDelegate
                    required property string filePath
                    width:  GridView.view.cellWidth
                    height: GridView.view.cellHeight

                    readonly property bool isActive: WallpaperState.wallpaper === wpDelegate.filePath

                    Rectangle {
                        id: wpCard
                        anchors.fill: parent
                        anchors.margins: root.cellMargin
                        radius: root.cardRadius
                        clip: true
                        color: root.bgHero
                        border.color: wpDelegate.isActive ? root.borderActive : root.borderSubtle
                        border.width: wpDelegate.isActive ? root.borderActiveW : root.borderW

                        RoundedImage {
                            id: wpImg
                            anchors.fill: parent
                            radius: root.cardRadius
                            source: wpDelegate.filePath
                            sourceSize: Qt.size(root.thumbW, root.thumbH)
                            // Cross-fade al estar lista: el orden de término
                            // de los decodes es independiente por imagen
                            // (peso del original); el fundido las suaviza.
                            opacity: status === Image.Ready ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation { duration: root.durHover; easing.type: Easing.OutCubic }
                            }
                            visible: status !== Image.Error
                        }

                        Column {
                            anchors.centerIn: parent; spacing: 4
                            visible: wpImg.opacity < 1.0 && wpImg.status !== Image.Error
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: wpImg.status === Image.Error ? Icons.imageBroken : Icons.image
                                font.pixelSize: root.fsIconLg; font.family: root.fontIcon
                                color: Style.outline; opacity: root.opacitySoft
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: root.cardRadius
                            color: Style.overlay_tint(0.22)
                            opacity: wpH.hovered && !wpDelegate.isActive ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: root.durHover; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            visible: wpDelegate.isActive
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.margins: root.chipPad
                            width: root.badgeSize; height: root.badgeSize
                            radius: root.badgeRadius
                            color: root.bgBadge
                            border.color: Style.surface_container_lowest; border.width: root.borderActiveW
                            Text {
                                anchors.centerIn: parent; text: Icons.check
                                font.pixelSize: root.fsSmall; font.family: root.fontIcon
                                color: root.fgBadge
                            }
                        }

                        HoverHandler { id: wpH }
                        TapHandler {
                            onTapped: WallpaperState.wallpaperProc.apply(wpDelegate.filePath)
                        }
                        Mouse{}
                    }
                }
            }
        }
    }
}
