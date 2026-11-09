// MprisWidget.qml — Control MPRIS compacto para el lado izquierdo
// de la barra: [vinilo] [título] [prev · toggle · next].
import QtQuick
import Quickshell
import "../state"
import "../components"

Item {
    id: root
    implicitWidth: contentRow.implicitWidth + 4

    // Sin track activo no hay widget (los players idle no cuentan).
    readonly property bool hasTrack: MprisState.musicTitle !== ""
    visible: hasTrack

    Row {
        id: contentRow
        anchors.fill: parent
        anchors.margins: 2
        spacing: 6

        // ── Vinilo + título/artista (clic → popup de música) ────
        Item {
            id: infoArea
            width: infoRow.implicitWidth
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            Row {
                id: infoRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                spacing: 6

                // ── Vinilo (portada) ────────────────────────────
                Item {
                    id: disc
                    width: contentRow.height
                    height: width
                    anchors.verticalCenter: parent.verticalCenter

                    // Base: sin carátula lista se ve el disco con la nota.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#121212"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)

                        Text {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: Icons.musicNote
                            font.pixelSize: Config.fontSizeBodySm
                            font.family: Icons.font
                            color: Qt.rgba(1, 1, 1, 0.5)
                        }
                    }

                    RoundedImage {
                        id: art
                        anchors.fill: parent
                        radius: width / 2
                        source: root.hasTrack ? (MprisState.musicArtUrl || "") : ""
                        sourceSize: Qt.size(96, 96)
                        visible: status === Image.Ready
                    }

                    // Agujero del eje
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6; height: 6; radius: 3
                        color: Style.surface_container_lowest
                        opacity: 0.9
                        visible: art.status === Image.Ready
                    }
                }

                // ── Título (se recorta con … si no entra) ───────
                // Sin marquee: una animación continua a 60 fps obliga a
                // repintar toda la superficie de la barra cada frame
                // (~12% de un core, medido con perf: prepareAlphaBatches).
                Text {
                    id: titleText
                    anchors.verticalCenter: parent.verticalCenter
                    width: 130
                    text: MprisState.musicTitle
                    elide: Text.ElideRight
                    font.pixelSize: Config.fontSizeBodySm
                    font.family: Config.uiFont
                    font.weight: Config.fontWeightMedium
                    color: Style.on_surface
                }
            }

            Mouse {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    TaskbarState.closePanel("controlcenter")
                    TaskbarState.popupX = root.mapToItem(null, root.width / 2, 0).x
                    if (TaskbarState.panel === "music") TaskbarState.closePanel()
                    else TaskbarState.openPanel("music")
                }
            }
        }

        // ── Controles ───────────────────────────────────────────
        MprisControl {
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            customRadius: -1
            iconSize: 14
            prevW: 26;  prevH: 26
            toggleW: 30; toggleH: 26
            nextW: 26;  nextH: 26
            playing: MprisState.musicPlaying
        }
    }
}
