// NotesSidebar.qml — Bloc de notas simple: una nota con autoguardado
// en ventana normal (SSD, igual que Settings). Sin tabs, sin browser,
// sin filetype: lo complejo va en mousepad. Todo cuadrado, sin radius.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../state"

import "../components"

FloatingWindow {
    id: root

    property bool _animReady: false
    readonly property bool isOpen: _animReady && TaskbarState.showNotesSidebar
    Component.onCompleted: Qt.callLater(function() { _animReady = true })

    title: "Notas"
    visible: root.isOpen
    onClosed: TaskbarState.showNotesSidebar = false
    implicitWidth: {
        var saved = SettingsState.notesPanelW || 0
        var w = saved > 0 ? saved : 560
        return Math.min(screen.width - 32, Math.max(320, Math.min(760, w)))
    }
    implicitHeight: Math.min(screen.height - Config.taskbarHeight - 32, 620)
    color: "transparent"

    onIsOpenChanged: {
        if (isOpen)
            Qt.callLater(function() { textArea.forceActiveFocus() })
    }

    Rectangle {
        anchors.fill: parent
        color: Style.surface_container_lowest

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Editor ────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Style.surface_container_low

                NoteTextArea {
                    id: textArea
                    anchors.fill: parent
                    anchors.margins: 12
                    contentMargin: 0
                    text: NotesState.content
                    placeholderText: "Escribí tus notas acá..."
                    fontSize: SettingsState.notesFontSize
                    fontFamily: "JetBrainsMono Nerd Font"
                    showBorder: false
                    tabInsertsSpaces: true
                    tabSize: 2
                    slashCommands: true
                    listContinuation: true
                    highlightTheme: "Atom One Dark"
                    showLineNumbers: true
                    highlightCurrentLine: true
                    highlightFileName: "nota.md"
                    onTextChanged: NotesState.content = text
                    onEscapePressed: TaskbarState.showNotesSidebar = false
                }
            }

            // ── Footer tonal M3: línea actual + stepper segmentado ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: Style.surface_container

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 4

                    // "Línea N / total" con el número actual en primary (énfasis M3).
                    Row {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Línea "
                            font.pixelSize: Config.fontSizeBody
                            font.family: Config.uiFont
                            color: Style.on_surface_variant
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: textArea.currentLine
                            font.pixelSize: Config.fontSizeBody
                            font.family: Config.uiFont
                            font.bold: true
                            color: Style.primary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: " / " + textArea.lineCount
                            font.pixelSize: Config.fontSizeBody
                            font.family: Config.uiFont
                            color: Style.on_surface_variant
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width - x)
                        }
                    }

                    // Stepper A- / A+ como botón segmentado M3 (persistente vía SettingsState).
                    Rectangle {
                        Layout.preferredWidth: 84
                        Layout.preferredHeight: 26
                        radius: Style.radius_pill
                        color: Style.surface_container_high

                        Row {
                            anchors.fill: parent
                            Repeater {
                                model: [
                                    { label: "A-", delta: -1 },
                                    { label: "A+", delta: 1 }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: 42
                                    height: 26
                                    topLeftRadius: index === 0 ? Style.radius_pill : 0
                                    bottomLeftRadius: index === 0 ? Style.radius_pill : 0
                                    topRightRadius: index === 1 ? Style.radius_pill : 0
                                    bottomRightRadius: index === 1 ? Style.radius_pill : 0
                                    color: segHover.hovered ? Style.surface_container_highest : Qt.alpha(Style.surface_container_highest, 0)
                                    Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.modelData.label
                                        font.pixelSize: Config.fontSizeBodySm
                                        font.family: Config.uiFont
                                        font.bold: true
                                        color: Style.on_surface_variant
                                    }
                                    HoverHandler { id: segHover }
                                    TapHandler {
                                        onTapped: {
                                            var v = Math.max(10, Math.min(28, SettingsState.notesFontSize + parent.modelData.delta))
                                            if (v !== SettingsState.notesFontSize) {
                                                SettingsState.notesFontSize = v
                                                SettingsState.markDirty()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Divisor central del segmentado.
                        Rectangle {
                            anchors.centerIn: parent
                            width: 1
                            height: 14
                            color: Style.outline_variant
                        }
                    }
                }
            }
        }
    }
}
