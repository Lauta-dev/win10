import QtQuick
import QtQuick.Layouts
import Quickshell
import "../state"
import "../components"

FloatingWindow {
    id: root

    color: Style.surface_container_lowest

    property bool _animReady: false
    property bool isOpen: _animReady && PolkitState.isActive

    visible: isOpen
    implicitWidth: 400
    implicitHeight: 300
    title: "Autenticación requerida"
    maximumSize: Qt.size(400, 300)
    minimumSize: Qt.size(400, 300)

    property bool _submitting: false
    property string _errorText: ""
    readonly property bool _active: !_submitting && (PolkitState.flow ? PolkitState.flow.isResponseRequired : true)

    Component.onCompleted: Qt.callLater(function() { _animReady = true })

    onIsOpenChanged: {
        if (isOpen) {
            _submitting = false
            _errorText = ""
            pwdInput.text = ""
            Qt.callLater(function() { pwdInput.forceActiveFocus() })
        }
    }

    Connections {
        target: PolkitState.flow
        function onAuthenticationFailed() {
            _submitting = false
            _errorText = PolkitState.flow && PolkitState.flow.supplementaryMessage
                ? PolkitState.flow.supplementaryMessage
                : "Contraseña incorrecta"
        }
        function onSupplementaryMessageChanged() {
            if (PolkitState.flow && PolkitState.flow.supplementaryMessage) {
                _errorText = PolkitState.flow.supplementaryMessage
            }
        }
        function onAuthenticationSucceeded() {
            _submitting = false
            _errorText = ""
        }
        function onAuthenticationRequestCancelled() {
            _submitting = false
            _errorText = ""
        }
    }

    Item {
        id: wrapper
        anchors.fill: parent
        focus: true

        opacity: root.isOpen ? 1.0 : 0.0
        transform: Translate {
            y: root.isOpen ? 0 : 16
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                PolkitState.cancel()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                _submit()
                event.accepted = true
                return
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Style.surface_container_lowest

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                // ── Header ──
                Row {
                    id: headerRow
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: PolkitState.flow && PolkitState.flow.iconName ? PolkitState.flow.iconName : "\uF023"
                        font.pixelSize: 28; font.family: Icons.font
                        color: Style.on_primary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Autenticación requerida"
                        font.pixelSize: 16; font.weight: Font.Bold
                        font.family: Config.uiFont; color: Style.on_surface
                    }
                }

                // ── Mensaje ──
                Text {
                    id: msgText
                    width: parent.width
                    text: PolkitState.flow ? (PolkitState.flow.message || "Se requiere autenticación para continuar.") : ""
                    font.pixelSize: 13; font.family: Config.uiFont
                    color: Style.on_surface
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                }

                // ── Campo de contraseña ──
                AppTextInput {
                    id: pwdInput
                    width: parent.width
                    inputHeight: 44
                    inputRadius: 10
                    borderAnimMs: 80
                    fontSize: 14
                    leftPad: 12
                    rightPad: 12
                    placeholderText: PolkitState.flow ? (PolkitState.flow.inputPrompt || "Contraseña") : "Contraseña"
                    echoMode: PolkitState.flow && PolkitState.flow.responseVisible ? TextInput.Normal : TextInput.Password

                    editField.enabled: root._active
                    editField.focus: true
                    editField.KeyNavigation.tab: cancelBtn
                    editField.KeyNavigation.backtab: submitBtn
                }

                // ── Error ──
                Item {
                    width: parent.width
                    height: 40
                    clip: true

                    Text {
                        id: errorText
                        y: root._errorText ? 0 : -40
                        width: parent.width
                        text: root._errorText
                        font.pixelSize: 12; font.family: Config.uiFont
                        color: Style.danger
                        wrapMode: Text.WordWrap
                    }
                }

                // ── Botones ──
                Row {
                    anchors.right: parent.right
                    spacing: 8

                    Item {
                        id: cancelBtn
                        width: 100; height: 36
                        property bool ph: false
                        activeFocusOnTab: true
                        enabled: !_submitting

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            opacity: cancelBtn.enabled ? 1.0 : 0.4
                            color: cancelBtn.ph ? Style.surface_container_highest : Style.surface_container_high
                            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            border.width: cancelBtn.activeFocus ? 1 : 0
                            border.color: cancelBtn.activeFocus ? Style.on_surface : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            font.pixelSize: 13; font.family: Config.uiFont
                            font.weight: Font.Medium
                            color: Style.on_surface
                        }

                        Mouse {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: if (!root._submitting) cancelBtn.ph = true
                            onExited:  cancelBtn.ph = false
                            onClicked: PolkitState.cancel()
                        }

                        KeyNavigation.tab: submitBtn
                        KeyNavigation.backtab: pwdInput
                    }

                    Item {
                        id: submitBtn
                        width: 120; height: 36
                        property bool ph: false
                        activeFocusOnTab: true
                        enabled: root._active

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            opacity: submitBtn.enabled ? 1.0 : 0.4
                            color: submitBtn.ph ? Style.primary : Qt.alpha(Style.primary, 0.8)
                            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            border.width: submitBtn.activeFocus ? 2 : 0
                            border.color: submitBtn.activeFocus ? Style.on_primary : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Autenticar"
                            font.pixelSize: 13; font.family: Config.uiFont
                            font.weight: Font.Medium
                            color: Style.on_primary
                        }

                        Mouse {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: if (root._active) submitBtn.ph = true
                            onExited:  submitBtn.ph = false
                            onClicked: _submit()
                        }

                        KeyNavigation.tab: pwdInput
                        KeyNavigation.backtab: cancelBtn
                    }
                }
            }
        }
    }

    function _submit() {
        if (!PolkitState.flow || _submitting) return
        _submitting = true
        _errorText = ""
        PolkitState.submit(pwdInput.text)
    }
}
