// VolumeWidget.qml — Icono + % en UN componente, color on_surface, sin saltos
import QtQuick
import Quickshell
import "../state"
import "../components"

Item {
    id: root

    // Ancho fijo: ícono + separador + % (o "--" máx) → nunca se mueve
    implicitWidth: Config.iconSize + 6 + Config.fontSizeLabel * 2.6 + 12
    implicitHeight: parent.height

    Row {
        id: volRow
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 0

        // Wrapper que ocupa todo el ancho de volRow para centrar volItem
        Item {
            width: parent.width
            height: parent.height

            // Wrapper: ícono + % en un solo bloque, centrado
            Item {
                id: volItem
                width: Config.iconSize + 6 + Config.fontSizeLabel * 2.6
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                // ICONO - ancho fijo para que no se mueva al cambiar de glyph
                Item {
                    id: iconBox
                    width: Config.iconSize
                    height: parent.height

                    Text {
                        id: iconText
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: AudioState.muted        ? Icons.volumeMuted
                            : AudioState.volume < 33  ? Icons.volumeLow
                            : AudioState.volume < 66  ? Icons.volumeMedium
                            :                             Icons.volume
                        font.pixelSize: Config.iconSize
                        font.family: Icons.font
                        color: AudioState.muted ? Style.outline_variant : Style.on_surface
                        opacity: AudioState.ready ? 1.0 : 0.4
                    }
                }

                // % (o "--" si está muteado) - ancho fijo para que no se mueva
                Item {
                    id: pctBox
                    x: Config.iconSize + 6
                    width: Config.fontSizeLabel * 2.6
                    height: parent.height

                    Text {
                        id: pctText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: AudioState.muted ? "--" : Math.round(AudioState.volume) + "%"
                        font.pixelSize: Config.fontSizeLabel
                        font.family: Config.ibmPlexMono
                        font.weight: Config.fontWeightMedium
                        color: AudioState.muted ? Style.outline_variant : Style.on_surface
                    }
                }

                // Interacción sobre todo el bloque
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (m) => { if (m.button === Qt.RightButton) AudioState.audioMute() }
                    onWheel: (w) => {
                        // Si está muteado, no hacer nada con el scroll
                        if (AudioState.muted) return
                        var v = Math.max(0, Math.min(100, AudioState.volume + (w.angleDelta.y > 0 ? 5 : -5)))
                        AudioState.audioSetVolume(v)
                    }
                }
            }
        }
    }
}
