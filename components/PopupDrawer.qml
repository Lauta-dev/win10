import QtQuick
import QtQuick.Layouts
import Quickshell
import "../state"

// PopupDrawer — Sidebar por secciones estilo settings: encabezado
// small-caps por grupo + filas compactas [ICON] [LABEL].
// La activa lleva pill de fondo; las inactivas van atenuadas.
// Sin colapsar ni botón toggle.
Column {
    id: drawer

    // ── API ──────────────────────────────────────────────
    // sections: [{ header: "Texto" ("" = sin encabezado),
    //              titles: [...], icons: [...] }]
    // El índice de tab es plano (sección tras sección).
    property var sections: []
    property bool compact: false
    property int activeTab: 0
    signal tabSelected(int index)

    // ── Variables primero (sin magic strings abajo) ──────
    readonly property int drawerW: compact ? 168 : 224
    readonly property int rowH: compact ? 38 : 44
    readonly property int rowGap: 2
    readonly property int rowRadius: 10
    readonly property int iconX: compact ? 12 : 14
    readonly property int fsIcon: compact ? 18 : 20
    readonly property int labelX: compact ? 40 : 46
    readonly property int labelRight: 12
    readonly property int headerTop: 14
    readonly property int headerBottom: 4
    readonly property int headerLeft: 14
    readonly property int sectionGap: 6

    readonly property color bgRowActive: Style.secondary_container
    readonly property color bgRowHover: Style.secondary_container
    readonly property color fgIconActive: Style.on_secondary_container
    readonly property color fgIconIdle: Style.on_surface_variant
    readonly property color fgLabelActive: Style.on_secondary_container
    readonly property color fgLabelIdle: Style.on_surface_variant
    readonly property color fgHeader: Style.on_surface_variant

    readonly property int fsHeader: Config.fontSizeCaption
    readonly property int fsLabel: Config.fontSizeBodySm
    readonly property string fontUi: Config.uiFont
    readonly property string fontIcon: Icons.font
    readonly property int wActive: Config.fontWeightBold
    readonly property int wIdle: Config.fontWeightNormal

    readonly property int durHover: 120
    readonly property real opacityHoverIdle: 0.35
    readonly property real opacityHoverActive: 0.9

    // Índice plano donde empieza cada sección.
    function _offset(s) {
        var n = 0
        for (var i = 0; i < s; i++)
            n += (drawer.sections[i] && drawer.sections[i].titles)
                ? drawer.sections[i].titles.length : 0
        return n
    }

    // ── Contenedor ───────────────────────────────────────
    Layout.fillHeight: true
    Layout.preferredWidth: drawer.drawerW
    spacing: drawer.sectionGap

    Repeater {
        model: drawer.sections.length
        delegate: Column {
            required property int index
            readonly property var sec: drawer.sections[index] ?? {}
            readonly property var secTitles: sec.titles ?? []
            readonly property var secIcons: sec.icons ?? []
            readonly property int base: drawer._offset(index)
            width: parent.width
            spacing: drawer.rowGap

            // Encabezado de sección (se omite si viene vacío).
            Item {
                width: parent.width
                height: (sec.header ?? "") !== ""
                    ? headerText.height + drawer.headerTop + drawer.headerBottom : 0
                visible: (sec.header ?? "") !== ""
                Text {
                    id: headerText
                    x: drawer.headerLeft
                    y: drawer.headerTop
                    width: parent.width - drawer.headerLeft - drawer.labelRight
                    text: sec.header ?? ""
                    font.pixelSize: drawer.fsHeader
                    font.weight: drawer.wActive
                    font.family: drawer.fontUi
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2
                    color: drawer.fgHeader
                    opacity: 0.6
                    elide: Text.ElideRight
                }
            }

            Repeater {
                model: secTitles.length
                delegate: Item {
                    required property int index
                    readonly property int flat: base + index
                    readonly property bool current: drawer.activeTab === flat
                    width: parent.width; height: drawer.rowH

                    Rectangle {
                        anchors.fill: parent; radius: drawer.rowRadius
                        color: drawer.bgRowActive
                        opacity: current ? (rowHov.hovered ? drawer.opacityHoverActive : 1.0) : (rowHov.hovered ? drawer.opacityHoverIdle : 0.0)
                        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }
                    // Icono desnudo (sin chip), x fijo
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: drawer.iconX
                        text: secIcons[index] ?? ""
                        font.pixelSize: drawer.fsIcon; font.family: drawer.fontIcon
                        color: current ? drawer.fgIconActive : drawer.fgIconIdle
                    }
                    // Label
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: drawer.labelX
                        width: parent.width - drawer.labelX - drawer.labelRight
                        text: secTitles[index] ?? ""
                        font.pixelSize: drawer.fsLabel
                        font.weight: current ? drawer.wActive : drawer.wIdle
                        font.family: drawer.fontUi
                        color: current ? drawer.fgLabelActive : drawer.fgLabelIdle
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    HoverHandler { id: rowHov }
                    TapHandler { onTapped: drawer.tabSelected(flat) }
                }
            }
        }
    }
}
