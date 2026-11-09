// MediaWidget.qml — Controles de media combinados: música + volumen
// Parte música: lazy (se oculta si no hay player activo)
// Parte volumen: siempre visible
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../state"
import "../components"

Item {
    id: root
    height: parent ? parent.height : 48

    readonly property bool musicVisible: MprisState.musicTitle !== ""

    // ── Ancho dinámico ──
    property real volWidth: height
    property real musicWidth: musicVisible ? controlsRow.implicitWidth + 12 : 0
    implicitWidth: musicWidth + volWidth

    // ═══════════════════════════════════════════════════════════════════════
    // ── State layer (fondo hover) ────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent; anchors.margins: 2
        radius: Style.button_radius
        color: Qt.alpha(Style.primary, _hovered ? 0.10 : 0.0)
                Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } enabled: volSection._volHovered }
    }

    property bool _hovered: false
    HoverHandler { onHoveredChanged: root._hovered = hovered }

    // ═══════════════════════════════════════════════════════════════════════
    // ── Contenido principal ──────────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════════════════
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 0

        // ── Parte música (lazy) ──────────────────────────────────────────
        Item {
            id: musicSection
            Layout.fillHeight: true
            Layout.preferredWidth: root.musicWidth
            visible: root.musicVisible
            opacity: visible ? 1.0 : 0.0

            RowLayout {
                id: controlsRow
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 4
                spacing: 4

                MprisControl {
                    height: 28
                    spacing: 4
                    iconSize: Config.fontSizeLabel
                    customRadius: 8
                    prevH: 28; prevW: 28
                    toggleH: 28; toggleW: 34
                    nextH: 28; nextW: 28
                }

                // ── Separador ──
                Rectangle {
                    width: 1; height: 20
                    Layout.alignment: Qt.AlignVCenter
                    color: Style.outline; opacity: 0.4
                }

                // ── Info: title ──
                Item {
                    id: infoContainer
                    width: 140; height: 40
                    Layout.alignment: Qt.AlignVCenter
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        horizontalAlignment: Text.AlignHCenter
                        text: MprisState.musicTitle
                        font.pixelSize: Config.fontSizeLabel; font.family: Config.uiFont
                        color: Style.on_surface; font.weight: Config.fontWeightMedium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Mouse {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            TaskbarState.popupX = root.mapToItem(null, root.width / 2, 0).x
                        }
                    }
                }
            }
        }

        // ── Separador entre música y volumen (solo si hay música) ──
        Rectangle {
            width: 1; height: 20
            Layout.alignment: Qt.AlignVCenter
            visible: root.musicVisible
            color: Style.outline; opacity: 0.3
        }

        // ── Parte volumen (siempre visible) ──────────────────────────────
        Item {
            id: volSection
            Layout.fillHeight: true
            Layout.preferredWidth: root.volWidth

            property bool _volHovered: false
            property bool _volPressed: false
            property string _tipText: AudioState.muted ? "Silenciado" : AudioState.volume + "%"

            on_VolHoveredChanged: {
                if (volSection._volHovered)
                    TaskbarState.showTip(volSection._tipText, root.mapToItem(null, root.width / 2, 0).x)
            }
            on_TipTextChanged: {
                if (volSection._volHovered)
                    TaskbarState.showTip(volSection._tipText, root.mapToItem(null, root.width / 2, 0).x)
            }

            Text {
                anchors.centerIn: parent; anchors.verticalCenterOffset: -1
                text: AudioState.muted        ? Icons.volumeMuted
                    : AudioState.volume < 33  ? Icons.volumeLow
                    : AudioState.volume < 66  ? Icons.volumeMedium
                    :                             Icons.volume
                font.pixelSize: Config.iconSize; font.family: Icons.font
                color: volSection._volHovered ? Style.primary : Style.on_surface
        Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } enabled: root._hovered }
            }

            Mouse {
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: {
                    volSection._volHovered = true
                    TaskbarState.showTip(AudioState.muted ? "Silenciado" : AudioState.volume + "%", root.mapToItem(null, root.width / 2, 0).x)
                }
                onExited: {
                    volSection._volHovered = false
                    TaskbarState.hideTip()
                }
                onPressed:  { volSection._volPressed = true  }
                onReleased: { volSection._volPressed = false }
                onCanceled: { volSection._volPressed = false }
                onClicked: (m) => {
                    if (m.button === Qt.RightButton) {
                        AudioState.audioMute()
                    } else {
                        TaskbarState.popupX = root.mapToItem(null, root.width / 2, 0).x
                    }
                }
                onWheel: (w) => {
                    var v = Math.max(0, Math.min(100, AudioState.volume + (w.angleDelta.y > 0 ? 5 : -5)))
                    AudioState.audioSetVolume(v)
                    TaskbarState.showTip(v + "%", root.mapToItem(null, root.width / 2, 0).x)
                }
            }
        }
    }
}
