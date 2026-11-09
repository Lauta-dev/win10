import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../state"
import "../../components"

// SettingsTabMonitors — Material You: canvas tonal + cards + filter chips
Item {
    id: root
    anchors.fill: parent
    property var root   // reference to SettingsPopup PanelWindow

    readonly property int activeCount: {
        var n = 0
        var ms = root.root ? root.root.monitors : []
        for (var i = 0; i < ms.length; i++) if (ms[i].enabled && ms[i].current_mode) n++
        return n
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ── Canvas de layout ──────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 178
            radius: 12
            color: Style.surface_container_high

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36
                                                radius: 8
                        color: Style.primary_container
                        Text {
                            anchors.centerIn: parent
                            text: Icons.display
                            font.pixelSize: 18; font.family: Icons.font
                            color: Style.on_primary_container
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: "Organizar pantallas"
                            font.pixelSize: Config.fontSizeBody; font.weight: Config.fontWeightBold
                            font.family: Config.uiFont; color: Style.on_surface
                        }
                        Text {
                            text: "Arrastrá para reposicionar"
                            font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                            color: Style.on_surface_variant
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: countTxt.implicitWidth + 20
                        Layout.preferredHeight: 26
                        radius: 8
                        color: Style.secondary_container
                        Text {
                            id: countTxt
                            anchors.centerIn: parent
                            text: root.activeCount + (root.activeCount === 1 ? " activa" : " activas")
                            font.pixelSize: Config.fontSizeCaption; font.weight: Config.fontWeightMedium
                            font.family: Config.uiFont; color: Style.on_secondary_container
                        }
                    }
                }

                Item {
                    id: mc
                    Layout.fillWidth: true; Layout.fillHeight: true

                    property var b: {
                        var mx = 1920, my = 1080
                        var ms = root.root ? root.root.monitors : []
                        for (var i = 0; i < ms.length; i++) {
                            var m = ms[i]
                            if (!m.enabled || !m.current_mode) continue
                            var ex = (m.position ? m.position.x : 0) + m.current_mode.width
                            var ey = (m.position ? m.position.y : 0) + m.current_mode.height
                            if (ex > mx) mx = ex
                            if (ey > my) my = ey
                        }
                        return { w: mx, h: my }
                    }
                    property real sf: Math.min(width / Math.max(b.w, 1), height / Math.max(b.h, 1)) * 0.88

                    function snapVal(v) { return Math.round(v / 8) * 8 }

                    Repeater {
                        model: root.root ? root.root.monitors : []
                        delegate: Item {
                            id: monItem
                            required property var modelData
                            required property int index

                            visible: modelData.enabled && modelData.current_mode

                            property real  dragX:     (modelData.position ? modelData.position.x : 0) * mc.sf
                            property real  dragY:     (modelData.position ? modelData.position.y : 0) * mc.sf
                            property bool  isDragging: false

                            Binding on dragX {
                                when: !monItem.isDragging
                                value: (monItem.modelData.position ? monItem.modelData.position.x : 0) * mc.sf
                            }
                            Binding on dragY {
                                when: !monItem.isDragging
                                value: (monItem.modelData.position ? monItem.modelData.position.y : 0) * mc.sf
                            }

                            x: dragX
                            y: dragY
                            width:  (modelData.current_mode ? modelData.current_mode.width  : 1920) * mc.sf
                            height: (modelData.current_mode ? modelData.current_mode.height : 1080) * mc.sf

                            z: isDragging ? 10 : 1

                            Rectangle {
                                anchors.fill: parent; anchors.margins: 2; radius: 8
                                color: Style.primary_container
                                opacity: monItem.isDragging ? 1.0 : 0.85
                                border.color: Style.primary
                                border.width: monItem.isDragging ? 2 : 1

                                Column {
                                    anchors.centerIn: parent; spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: monItem.modelData.name
                                        font.pixelSize: Config.fontSizeLabelSm; font.weight: Config.fontWeightBold
                                        font.family: Config.uiFont; color: Style.on_primary_container
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: monItem.modelData.current_mode !== null
                                        text: monItem.modelData.current_mode
                                              ? (monItem.modelData.current_mode.width + "×" + monItem.modelData.current_mode.height)
                                              : ""
                                        font.pixelSize: Config.fontSizeCaption; font.family: Config.uiFont
                                        color: Style.on_primary_container; opacity: 0.75
                                    }
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: monItem.isDragging
                                            width: coordTxt.implicitWidth + 12; height: 18; radius: 6
                                        color: Style.secondary_container
                                        Text {
                                            id: coordTxt
                                            anchors.centerIn: parent
                                            text: mc.snapVal(monItem.dragX / mc.sf) + "," + mc.snapVal(monItem.dragY / mc.sf)
                                            font.pixelSize: Config.fontSizeBadge; font.family: Config.uiFont
                                            color: Style.on_secondary_container
                                        }
                                    }
                                }
                            }

                            Mouse {
                                anchors.fill: parent
                                cursorShape:  Qt.SizeAllCursor
                                drag.target:  monItem
                                drag.axis:    Drag.XAndYAxis
                                drag.minimumX: 0
                                drag.maximumX: mc.width  - monItem.width
                                drag.minimumY: 0
                                drag.maximumY: mc.height - monItem.height

                                onPressed: {
                                    monItem.isDragging  = true
                                    MonitorState.randrProc._dragging = true
                                }

                                onReleased: {
                                    monItem.isDragging  = false
                                    MonitorState.randrProc._dragging = false

                                    var bestX = monItem.x
                                    var bestY = monItem.y
                                    var dxMin = Infinity
                                    var dyMin = Infinity

                                    var siblings = mc.children
                                    for (var s = 0; s < siblings.length; s++) {
                                        var sib = siblings[s]
                                        if (sib === monItem || !sib.visible || !sib.modelData) continue
                                        var sL = sib.x
                                        var sR = sib.x + sib.width
                                        var sT = sib.y
                                        var sB = sib.y + sib.height

                                        var d = Math.abs(monItem.x - sR)
                                        if (d < dxMin) { dxMin = d; bestX = sR }
                                        d = Math.abs((monItem.x + monItem.width) - sL)
                                        if (d < dxMin) { dxMin = d; bestX = sL - monItem.width }
                                        d = Math.abs(monItem.x - sL)
                                        if (d < dxMin) { dxMin = d; bestX = sL }

                                        d = Math.abs(monItem.y - sB)
                                        if (d < dyMin) { dyMin = d; bestY = sB }
                                        d = Math.abs((monItem.y + monItem.height) - sT)
                                        if (d < dyMin) { dyMin = d; bestY = sT - monItem.height }
                                        d = Math.abs(monItem.y - sT)
                                        if (d < dyMin) { dyMin = d; bestY = sT }
                                    }

                                    bestX = Math.max(0, Math.min(bestX, mc.width  - monItem.width))
                                    bestY = Math.max(0, Math.min(bestY, mc.height - monItem.height))

                                    monItem.dragX = bestX
                                    monItem.dragY = bestY

                                    var realX = mc.snapVal(bestX / mc.sf)
                                    var realY = mc.snapVal(bestY / mc.sf)

                                    var origX = monItem.modelData.position ? monItem.modelData.position.x : 0
                                    var origY = monItem.modelData.position ? monItem.modelData.position.y : 0
                                    if (realX !== origX || realY !== origY) {
                                        MonitorState.randrProc.setPos(monItem.modelData.name, realX, realY)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Modo espejo / extendido ───────────────────────────
        Rectangle {
            id: mirrorRow
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            radius: 12
            color: Style.surface_container_high

            readonly property bool isMirror: {
                var ms = root.root ? root.root.monitors : []
                var active = ms.filter(function(m) { return m.enabled && m.current_mode })
                if (active.length < 2) return false
                for (var i = 0; i < active.length; i++) {
                    var p = active[i].position
                    if (!p || p.x !== 0 || p.y !== 0) return false
                }
                return true
            }
            property bool mirrorApplying: false

            Connections {
                target: MonitorState.shellCmd
                function onRunningChanged() {
                    if (!MonitorState.shellCmd.running)
                        mirrorRow.mirrorApplying = false
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    radius: 10
                    color: Style.secondary_container
                    Text {
                        anchors.centerIn: parent
                        text: mirrorRow.isMirror ? Icons.mirror : Icons.monitor
                        font.pixelSize: 17; font.family: Icons.font
                        color: Style.on_secondary_container
                    }
                }
                Column {
                    Layout.fillWidth: true; spacing: 1
                    Text {
                        text: mirrorRow.isMirror ? "Modo espejo" : "Modo extendido"
                        font.pixelSize: Config.fontSizeBody; font.family: Config.uiFont
                        font.weight: Config.fontWeightBold; color: Style.on_surface
                    }
                    Text {
                        text: mirrorRow.isMirror
                              ? "Todas muestran lo mismo"
                              : "Cada pantalla es independiente"
                        font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                        color: Style.on_surface_variant
                    }
                }

                Text {
                    visible: mirrorRow.mirrorApplying
                    text: Icons.refreshAlt
                    font.pixelSize: Config.fontSizeBodySm; font.family: Icons.font
                    color: Style.primary
                }

                // Segmented M3
                Rectangle {
                    Layout.preferredWidth: segRow.implicitWidth + 8
                    Layout.preferredHeight: 38
                    radius: 12
                    color: Style.surface_container_lowest
                    border.color: Style.outline_variant; border.width: 1
                    Row {
                        id: segRow
                        anchors.centerIn: parent
                        spacing: 2
                        Repeater {
                            model: [
                                { label: "Espejo",    icon: Icons.mirror,  mirror: true  },
                                { label: "Extendido", icon: Icons.monitor, mirror: false },
                            ]
                            delegate: Item {
                                id: segItem
                                required property var modelData
                                readonly property bool sel: mirrorRow.isMirror === modelData.mirror
                                width: segLbl.implicitWidth + 28; height: 30

                                Rectangle {
                                    anchors.fill: parent; radius: 8
                                    color: Style.secondary_container
                                    opacity: segItem.sel ? 1.0 : 0.0
                                }
                                Rectangle {
                                    anchors.fill: parent; radius: 8
                                    color: Style.surface_container_highest
                                    opacity: segH.hovered && !segItem.sel ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                }
                                Row {
                                    id: segLbl
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: Config.fontSizeLabel; font.family: Icons.font
                                        color: segItem.sel ? Style.on_secondary_container : Style.on_surface_variant
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData.label
                                        font.pixelSize: Config.fontSizeLabel; font.family: Config.uiFont
                                        font.weight: segItem.sel ? Config.fontWeightBold : Config.fontWeightMedium
                                        color: segItem.sel ? Style.on_secondary_container : Style.on_surface
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                HoverHandler { id: segH }
                                TapHandler {
                                    enabled: !mirrorRow.mirrorApplying && !segItem.sel
                                    onTapped: {
                                        mirrorRow.mirrorApplying = true
                                        var ms = root.root ? root.root.monitors : []
                                        var active = ms.filter(function(m) { return m.enabled && m.current_mode })
                                        if (active.length < 2) { mirrorRow.mirrorApplying = false; return }

                                        MonitorState.mirrorCmd._cmd = MonitorState.buildMirrorCmd(active, modelData.mirror)
                                        MonitorState.mirrorCmd.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Lista de monitores ──────────────────────────────────
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true
            contentHeight: mCol.implicitHeight; clip: true
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            Column {
                id: mCol; width: parent.width; spacing: 10

                Repeater {
                    model: root.root ? root.root.monitors : []
                    delegate: Rectangle {
                        id: mRow
                        required property var modelData
                        required property int index

                        property string pendingMode: ""
                        property bool   applying:   false

                        function modeKey(m) { return m.width + "x" + m.height }
                        function isCurrent(m) {
                            if (pendingMode !== "") return modeKey(m) === pendingMode
                            return m.current
                        }

                        width: parent.width - 4
                        height: mContent.implicitHeight + 20
                        radius: 12
                        color: Style.surface_container_high
                        border.color: modelData.enabled ? Style.primary : Style.outline_variant
                        border.width: modelData.enabled ? 1 : 1

                        Column {
                            id: mContent
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                            spacing: 10
                            RowLayout {
                                width: parent.width; spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                                    color: modelData.enabled ? Style.tertiary : Style.outline
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Column {
                                    Layout.fillWidth: true; spacing: 1
                                    Row {
                                        spacing: 8
                                        Text {
                                            text: modelData.name
                                            font.pixelSize: Config.fontSizeBody; font.weight: Config.fontWeightBold
                                            font.family: Config.uiFont; color: Style.on_surface
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Rectangle {
                                            visible: modelData.enabled &&
                                                     modelData.position !== null &&
                                                     modelData.position.x === 0 &&
                                                     modelData.position.y === 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: badgeText.implicitWidth + 12; height: 18; radius: 6
                                            color: Style.primary
                                            Text {
                                                id: badgeText
                                                anchors.centerIn: parent
                                                text: "PRIMARIA"
                                                font.pixelSize: Config.fontSizeBadge; font.weight: Config.fontWeightBold
                                                font.family: Config.uiFont; color: Style.on_primary
                                                font.letterSpacing: 0.5
                                            }
                                        }
                                    }
                                    Text {
                                        text: modelData.description || ""
                                        font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                                        color: Style.on_surface_variant; elide: Text.ElideRight; width: parent.width
                                    }
                                }

                                PillButton {
                                    visible: modelData.enabled &&
                                             !(modelData.position !== null &&
                                               modelData.position.x === 0 &&
                                               modelData.position.y === 0)
                                    icon: Icons.star
                                    label: "Primaria"
                                    onClicked: {
                                        var ms = root.root ? root.root.monitors : []
                                        MonitorState.primaryCmd._cmd = MonitorState.buildPrimaryCmd(ms, mRow.modelData.name)
                                        MonitorState.primaryCmd.running = true
                                    }
                                }

                                Text {
                                    visible: mRow.applying
                                    text: Icons.refreshAlt
                                    font.pixelSize: Config.fontSizeBodySm; font.family: Icons.font
                                    color: Style.primary
                                }

                                // Switch M3
                                Rectangle {
                                    Layout.preferredWidth: 48; Layout.preferredHeight: 26; radius: 13
                                    color: modelData.enabled ? Style.primary : Style.surface_container_highest
                                    border.color: modelData.enabled ? "transparent" : Style.outline; border.width: 1
                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: modelData.enabled ? parent.width - 22 : 4
                                        color: modelData.enabled ? Style.on_primary : Style.outline
                                    }
                                    Mouse { anchors.fill: parent; onClicked: MonitorState.randrProc.toggleOutput(modelData.name, !modelData.enabled) }
                                }
                            }

                            // primaryCmd vive en MonitorState (shellCmd).
                            Column {
                                visible: modelData.enabled; width: parent.width; spacing: 8
                                RowLayout {
                                    width: parent.width; spacing: 6
                                    Text { text: "Posición"; font.pixelSize: Config.fontSizeLabel; font.family: Config.uiFont; color: Style.on_surface_variant; Layout.preferredWidth: 56 }
                                    Text { text: "X"; font.pixelSize: Config.fontSizeLabel; font.family: Config.uiFont; color: Style.on_surface_variant }
                                    AppTextInput {
                                        id: posXInput
                                        width: 64
                                        inputHeight: 30
                                        inputRadius: 8
                                        fontSize: Config.fontSizeBodySm
                                        leftPad: 8
                                        rightPad: 8
                                        text: modelData.position ? String(modelData.position.x) : "0"
                                        onReturnPressed: MonitorState.randrProc.setPos(mRow.modelData.name, parseInt(posXInput.text) || 0, parseInt(posYInput.text) || 0)
                                    }
                                    Text { text: "Y"; font.pixelSize: Config.fontSizeLabel; font.family: Config.uiFont; color: Style.on_surface_variant }
                                    AppTextInput {
                                        id: posYInput
                                        width: 64
                                        inputHeight: 30
                                        inputRadius: 8
                                        fontSize: Config.fontSizeBodySm
                                        leftPad: 8
                                        rightPad: 8
                                        text: modelData.position ? String(modelData.position.y) : "0"
                                        onReturnPressed: MonitorState.randrProc.setPos(mRow.modelData.name, parseInt(posXInput.text) || 0, parseInt(posYInput.text) || 0)
                                    }
                                    PillButton {
                                        label: "Aplicar"
                                        onClicked: MonitorState.randrProc.setPos(mRow.modelData.name, parseInt(posXInput.text) || 0, parseInt(posYInput.text) || 0)
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                // ── Chips de resolución M3 ────────
                                Flow {
                                    width: parent.width; spacing: 6

                                    Repeater {
                                        model: {
                                            if (!modelData.modes) return []
                                            var seen = {}
                                            var result = []
                                            for (var i = 0; i < modelData.modes.length; i++) {
                                                var m = modelData.modes[i]
                                                var key = m.width + "x" + m.height
                                                if (seen[key]) {
                                                    if (m.current)   seen[key].current   = true
                                                    if (m.preferred) seen[key].preferred = true
                                                    continue
                                                }
                                                var entry = { width: m.width, height: m.height, key: key, current: m.current, preferred: m.preferred }
                                                seen[key] = entry
                                                result.push(entry)
                                            }
                                            return result
                                        }

                                        delegate: Item {
                                            id: resChip
                                            required property var modelData
                                            required property int index

                                            readonly property bool active:    modelData.current
                                            readonly property bool isPending: mRow.pendingMode === modelData.key

                                            width: resLbl.implicitWidth + 28; height: 32

                                            Rectangle {
                                                anchors.fill: parent; radius: 10
                                                color: Style.secondary_container
                                                opacity: (resChip.active || resChip.isPending) ? 1.0 : 0.0
                                            }
                                            Rectangle {
                                                anchors.fill: parent; radius: 10
                                                color: Style.surface_container_highest
                                                opacity: (resChip.active || resChip.isPending) ? 0.0 : (resMA.hovered ? 1.0 : 0.55)
                                                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                            }
                                            Rectangle {
                                                anchors.fill: parent; radius: 10
                                                color: "transparent"
                                                border.color: (resChip.active || resChip.isPending) ? Style.primary : Style.outline_variant
                                                border.width: (resChip.active || resChip.isPending) ? 1 : 1
                                            }

                                            Rectangle {
                                                visible: resChip.isPending && mRow.applying
                                                anchors.right: parent.right; anchors.top: parent.top
                                                anchors.rightMargin: 6; anchors.topMargin: 6
                                                width: 6; height: 6; radius: 3
                                                color: Style.primary
                                            }

                                            Row {
                                                id: resLbl
                                                anchors.centerIn: parent
                                                spacing: 4
                                                Text {
                                                    visible: resChip.active
                                                    text: Icons.check
                                                    font.pixelSize: Config.fontSizeCaption; font.family: Icons.font
                                                    color: Style.on_secondary_container
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Text {
                                                    text: modelData.width + "×" + modelData.height +
                                                          (modelData.preferred && !resChip.active ? " ★" : "")
                                                    font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                                                    font.weight: resChip.active ? Config.fontWeightBold : Config.fontWeightMedium
                                                    color: (resChip.active || resChip.isPending) ? Style.on_secondary_container : Style.on_surface
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            HoverHandler { id: resMA }
                                            TapHandler {
                                                onTapped: {
                                                    if (mRow.applying) return
                                                    mRow.pendingMode = resChip.modelData.key
                                                    mRow.applying    = true
                                                    MonitorState.randrProc.setMode(
                                                        mRow.modelData.name,
                                                        resChip.modelData.width + "x" + resChip.modelData.height
                                                    )
                                                    var conn = function() {
                                                        if (!MonitorState.randrProc.running) {
                                                            mRow.applying = false
                                                            MonitorState.randrProc.runningChanged.disconnect(conn)
                                                        }
                                                    }
                                                    MonitorState.randrProc.runningChanged.connect(conn)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    width: parent.width - 4
                    Item { Layout.fillWidth: true }
                    PillButton {
                        icon: Icons.refresh
                        label: "Actualizar"
                        onClicked: MonitorState.monitorsProc.load()
                    }
                }
                Item { width: 1; height: 4 }
            }
        }
    }
}
