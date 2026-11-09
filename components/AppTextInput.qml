import QtQuick
import "../state"

Rectangle {
    id: root

    property alias  text: input.text
    property string placeholderText: ""
    property int    inputHeight: 32
    property real   inputRadius: Style.radius_md
    property color  bgColor: Style.surface_container_low
    property color  borderIdle: Style.outline_variant
    property color  borderActive: Qt.alpha(Style.primary, 0.45)
    property real   borderWidth: 0
    property real   borderWidthActive: 0
    property int    borderAnimMs: 120

    property real   fontSize: Config.fontSizeBodySm
    property string fontFamily: Config.uiFont
    property color  textColor: Style.on_surface
    property color  placeholderColor: Style.outline
    property color  selectionHighlight: Qt.alpha(Style.primary, 0.35)
    property real   leftPad: 10
    property real   rightPad: 10
    property bool   passwordMode: false

    property alias  echoMode: input.echoMode
    property alias  editField: input
    readonly property bool hasFocus: input.activeFocus

    signal accepted()
    signal escapePressed()
    signal upPressed()
    signal downPressed()
    signal returnPressed()

    function forceActiveFocus() { input.forceActiveFocus() }
    function clear() { input.text = "" }

    implicitHeight: inputHeight
    height: inputHeight
    radius: inputRadius
    color: bgColor
    border.color: input.activeFocus ? borderActive : borderIdle
    border.width: input.activeFocus ? borderWidthActive : borderWidth

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.leftPad
        anchors.rightMargin: root.rightPad
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        color: root.textColor
        selectionColor: root.selectionHighlight
        echoMode: root.passwordMode ? TextInput.Password : TextInput.Normal
        passwordCharacter: Icons.passwordBullet
        passwordMaskDelay: 600
        clip: true

        onTextChanged: root.textChanged()
        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escapePressed()
        Keys.onUpPressed:     root.upPressed()
        Keys.onDownPressed:   root.downPressed()
        Keys.onReturnPressed: root.returnPressed()
        Keys.onEnterPressed:  root.returnPressed()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholderText
            font: parent.font
            color: root.placeholderColor
            visible: parent.text === ""
        }
    }
}
