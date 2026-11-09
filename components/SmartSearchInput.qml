import QtQuick
import "../state"
import "../components"

Item {
    id: root

    implicitHeight: root.inputHeight

    property string text:        ""
    property string placeholder: "Buscar…"
    property color  bgColor:     Style.surface_container_low
    property color  borderActive: Qt.alpha(Style.primary, 0.45)
    // Contador integrado a la derecha (vacío = oculto).
    property string counterText: ""

    // ── Estilo (defaults = look actual; todo sobreescribible) ───────────────
    property int    inputHeight: 44
    property real   inputRadius: 12
    property color  borderIdle: Style.outline_variant
    property real   borderWidth: 0
    property real   borderWidthActive: 0
    property real   fontSize: 14
    property string fontFamily: Config.uiFont
    property color  textColor: Style.on_surface
    property color  placeholderColor: Style.outline
    property color  selectionHighlight: Qt.alpha(Style.primary, 0.35)
    property real   leftPad: 44
    property real   rightPad: 16

    signal queryChanged(string value)
    signal escapePressed()
    signal upPressed()
    signal downPressed()
    signal leftPressed()
    signal rightPressed()
    signal returnPressed()
    signal emptyBackspace()
    signal backspaceOnEmpty()
    signal superPressed()

    function forceActiveFocus() { appInput.forceActiveFocus() }
    function clear()            { _clearing = true; appInput.clear(); _clearing = false }
    function setText(t)         { appInput.editField.text = t; appInput.editField.cursorPosition = t.length }
    function appendText(t)      { appInput.editField.insert(appInput.editField.cursorPosition, t) }
    readonly property int length: appInput.editField ? appInput.editField.text.length : 0

    readonly property alias hasFocus: appInput.hasFocus
    property alias input: appInput.editField
    property alias passwordMode: appInput.passwordMode

    property bool _clearing: false

    Keys.onPressed: function(event) {
        // Escape primero: si trae texto asociado no debe insertarse.
        if (event.key === Qt.Key_Escape) { root.escapePressed(); event.accepted = true; return }
        if (event.text.length > 0 && !(event.modifiers & Qt.ControlModifier) && event.key !== Qt.Key_Backspace && event.key !== Qt.Key_Delete) {
            appInput.forceActiveFocus()
            appInput.editField.insert(appInput.editField.cursorPosition, event.text)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Left) { root.leftPressed(); event.accepted = true; return }
        if (event.key === Qt.Key_Right) { root.rightPressed(); event.accepted = true; return }
        if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R ||
            event.key === Qt.Key_Meta) {
            root.superPressed()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Backspace && appInput.text === "" && appInput.hasFocus) {
            root.backspaceOnEmpty()
            event.accepted = true
        }
    }
    Keys.onUpPressed:     root.upPressed()
    Keys.onDownPressed:   root.downPressed()
    Keys.onReturnPressed: root.returnPressed()

    AppTextInput {
        id: appInput
        anchors.fill: parent
        inputHeight: root.inputHeight
        inputRadius: root.inputRadius
        bgColor:  root.bgColor
        borderActive: root.borderActive
        borderIdle: root.borderIdle
        borderWidth: root.borderWidth
        borderWidthActive: root.borderWidthActive
        fontSize: root.fontSize
        fontFamily: root.fontFamily
        textColor: root.textColor
        placeholderColor: root.placeholderColor
        selectionHighlight: root.selectionHighlight
        leftPad: root.leftPad
        rightPad: root.counterText === "" ? root.rightPad : Math.max(root.rightPad, 66)
        placeholderText: root.placeholder
        text: root.text

        onTextChanged: {
            root.queryChanged(appInput.text)
            if (appInput.text === "" && !root._clearing && hasFocus)
                root.emptyBackspace()
        }
        onEscapePressed: root.escapePressed()
        onUpPressed:     root.upPressed()
        onDownPressed:   root.downPressed()
        onReturnPressed: root.returnPressed()
    }

    // Lupa M3 — overlay (no roba foco: el input sigue abajo).
    Text {
        anchors.left: parent.left; anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.passwordMode ? Icons.lock : Icons.search
        font.pixelSize: 18; font.family: Icons.font
        color: Style.on_surface_variant
    }

    // Contador integrado a la derecha (opt-in vía counterText).
    Text {
        visible: root.counterText !== ""
        anchors.right: parent.right; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 12; font.family: Config.uiFont
        color: Style.on_surface_variant
        text: root.counterText
    }
}
