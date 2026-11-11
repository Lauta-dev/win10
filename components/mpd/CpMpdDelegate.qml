// CpMpdDelegate.qml — Delegate de la lista MPD.
// Muestra título, artista y duración; la fila sonando se marca con
// wash del cover (o pill sólida con playingBg). Sin hover propio:
// la selección la pinta la pill del PanelList (focus único).

import QtQuick
import "../../state"

Item {
    property var  itemData:  ({})
    property int  itemIndex: 0
    property bool isSelected: false
    property bool isPlaying: false
    property real progress: 0.0
    property int  panelWidth: 520
    // Bg sólido para la fila en reproducción (opt-in, default off).
    property bool playingBg: false
    property color textAccent: Style.primary
    property color hoverColor: Style.surface_container_highest

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
        color: "transparent"

        // Fila en reproducción — wash tonal del cover; con playingBg se
        // vuelve pill sólida (tono acento) que la distingue del resto.
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: playingBg ? hoverColor : textAccent
            opacity: isPlaying ? (playingBg ? 1.0 : 0.14) : 0.0
        }

        Column {
            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
            spacing: 1

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

        TapHandler   { onTapped: trackActivated(itemData.pos ?? 0, itemData.file ?? "") }
    }
}
