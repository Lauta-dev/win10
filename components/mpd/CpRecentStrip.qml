// CpRecentStrip.qml — Tira horizontal con los últimos temas sumados a la
// biblioteca (MpdState.recentSongs, daemon "recent"). Va arriba de la cola
// en la raíz del modo mpd. Click → agrega y reproduce. Solo mouse (no entra
// en la navegación por teclado del palette).
import QtQuick
import "../../state"
import ".."

Item {
    id: root

    property var items: []
    // Tinte del cover (defaults: tema global)
    property color accent: Style.primary
    property color textAccent: Style.primary
    // Cargando: muestra 5 tarjetas esqueleto para no mover la lista
    // cuando llegan los datos.
    property bool loading: false

    signal trackRequested(string file)

    implicitHeight: 126

    readonly property int _shown: Math.min(5, Math.max(items.length, loading ? 5 : 0))

    Column {
        anchors.fill: parent
        anchors.leftMargin: 14; anchors.rightMargin: 14
        anchors.topMargin: 8
        spacing: 6

        Text {
            width: parent.width
            text: "Agregados recientes"
            font.pixelSize: Config.fontSizeCaption; font.weight: Config.fontWeightMedium
            font.family: Config.uiFont
            color: Style.on_surface_variant
        }

        Row {
            id: row
            width: parent.width
            height: 94
            spacing: 8

            Repeater {
                model: root._shown
                delegate: Rectangle {
                    required property int index
                    property var entry: root.items[index] || {}
                    property bool _skeleton: !entry.file
                    property string artSource: (entry.art || "") !== "" ? ("file://" + entry.art).replace(/#/g, "%23") : ""
                    property bool hasArt: artSource !== ""
                    width: Math.max(60, (row.width - 4 * row.spacing) / Math.max(1, root._shown))
                    height: row.height
                    radius: 10
                    color: Qt.alpha(root.accent, 0.10)
                    clip: true
                    border.color: Qt.alpha(root.accent, 0.35)
                    border.width: 1

                    // Cover a bleed + gradiente inferior para el texto.
                    RoundedImage {
                        anchors.fill: parent
                        radius: 10
                        source: artSource
                        sourceSize: Qt.size(Math.max(1, Math.round(parent.width * 2)), 0)
                    }
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * 0.62
                        visible: hasArt
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.78) }
                        }
                    }

                    property bool ph: false
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Qt.alpha(root.accent, 0.22)
                        opacity: parent.ph ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }

                    Column {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8; anchors.rightMargin: 8; anchors.bottomMargin: 7
                        spacing: 1

                        Text {
                            visible: !hasArt
                            text: Icons.musicNote
                            font.pixelSize: 20
                            font.family: Icons.font
                            color: root.textAccent
                        }
                        Text {
                            width: parent.width
                            text: entry.title ?? ""
                            font.pixelSize: Config.fontSizeLabelSm; font.weight: Config.fontWeightMedium; font.family: Config.uiFont
                            color: hasArt ? "#FFFFFF" : Style.on_surface
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Text {
                            width: parent.width
                            text: entry.artist ?? ""
                            font.pixelSize: Config.fontSizeCaption; font.family: Config.uiFont
                            color: hasArt ? Qt.rgba(1, 1, 1, 0.8) : Style.on_surface_variant
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            visible: text !== ""
                        }
                    }

                    HoverHandler { onHoveredChanged: parent.ph = hovered }
                    TapHandler { onTapped: { if (entry.file) root.trackRequested(entry.file) } }
                }
            }
        }
    }
}
