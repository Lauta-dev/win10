// CpMpdDelegate.qml — Delegate del modo "mpd" del Command Palette.
// Muestra número de track, título, artista e indicador de playing.

import QtQuick
import "../../state"

Item {
    property var  itemData:  ({})
    property int  itemIndex: 0
    property bool isSelected: false
    property bool isPlaying: false
    property real progress: 0.0
    property int  panelWidth: 520
    // (playingBg retirado: el indicador es el ecualizador)
    property color textAccent: Style.primary
    property color hoverColor: Style.surface_container_highest
    // Barras visibles solo en la fila en reproducción.
    readonly property bool _showEq: isPlaying

    property real _elapsed: isPlaying ? (itemData.duration || 0) - progress * (itemData.duration || 0) : (itemData.duration || 0)

    function _fmtTime(sec) {
        var s = Math.floor(sec)
        var m = Math.floor(s / 60); s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    signal trackActivated(int position, string file)

    height: 50

    Rectangle {
        anchors { fill: parent }
        radius: 10
        property bool ph: false
        color: "transparent"

        // Fila en reproducción — wash tonal del cover
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: textAccent
            opacity: isPlaying ? 0.14 : 0.0
        }

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: hoverColor
            opacity: parent.ph && !isPlaying ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
            spacing: 10

            // Ecualizador: 4 barras en el color del cover. La caja ocupa
            // lugar siempre (filas alineadas, sin saltos); las barras solo
            // se ven y animan en la fila en reproducción.
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 16
                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    visible: _showEq
                    Repeater {
                        model: [380, 520, 440, 600]
                        delegate: Rectangle {
                            required property var modelData
                            width: 3; height: 4; radius: 1.5
                            anchors.bottom: parent.bottom
                            color: textAccent
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30

                Row {
                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width - timeText.width - 6
                        text: itemData.title ?? ""
                        font.pixelSize: Config.fontSizeBody; font.weight: Config.fontWeightMedium; font.family: Config.uiFont
                        color: isPlaying ? textAccent : (isSelected ? textAccent : Style.on_surface)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        id: timeText
                        anchors.verticalCenter: parent.verticalCenter
                        text: (isPlaying ? _fmtTime(_elapsed) : _fmtTime(itemData.duration || 0))
                        font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                        color: textAccent
                        visible: itemData.duration > 0
                    }
                }
                Text {
                    width: parent.width
                    text: itemData.artist ?? ""
                    font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                    color: isPlaying ? textAccent : Style.on_surface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text !== ""
                }
            }
        }

        HoverHandler { onHoveredChanged: parent.ph = hovered }
        TapHandler   { onTapped: trackActivated(itemData.pos ?? 0, itemData.file ?? "") }
    }
}
