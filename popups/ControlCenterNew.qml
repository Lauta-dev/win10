// ControlCenterNew.qml — Panel de control con datos reales.
// Vista del panel "controlcenter" en PanelPopupHost (posición right).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Networking
import "../state"
import "../components"
import "../components/pomodoro"

Item {
    id: root
    // ── API de PanelPopupHost ──
    // El shell ya no da el tamaño: la vista mide lo que informa al host.
    width: viewWidth
    height: viewHeight
    readonly property real viewWidth: 420
    readonly property real viewHeight: root.visualHeight
    readonly property real viewX: 0
    readonly property bool viewExclusiveFocus: (root._expandedSsid || "") !== ""
    readonly property bool viewOpen: TaskbarState.panel === "controlcenter"

    readonly property bool _wifiEnabled: WifiState.wifiEnabled

    // ── Tiles M3 solo-ícono: 0 wifi, 1 dark, 2 night,
    readonly property bool _wifiScanning: WifiState.scanning
    readonly property var _connectedNet: {
        var nets = WifiState.networks
        for (var i = 0; i < nets.length; i++) {
            if (nets[i] && nets[i].connected) return nets[i]
        }
        return null
    }
    readonly property string _connectedName: _connectedNet ? _connectedNet.name : ""
    readonly property bool _wifiConnected: _wifiEnabled && _connectedName !== ""

    // Redes ordenadas: conocidas primero (para las secciones del ListView).
    // Key por nombres: señales/connected/known no regeneran el cache (los
    // delegates leen el objeto vivo). El swap del modelo lo hace la lista
    // (wifiListComp) para preservar el scroll al aparecer/desaparecer redes.
    // ── Tiles M3 solo-ícono: 0 wifi, 1 pantalla (menú de layouts),
    // 2 dark/night. Las funciones se re-evalúan solas (QML rastrea las
    // deps usadas adentro).
    function _tileOn(k) {
        if (k === 0) return _wifiEnabled
        if (k === 3) return KcdState.connected
        if (k === 4) return PomodoroState.isRunning
        if (k === 5) return root._calOpen
        return root._layVisible
    }
    function _tileIcon(k) {
        if (k === 0) return _wifiConnected ? Icons.wifi : Icons.wifiOff
        if (k === 3) return KcdState.connected ? Icons.cellphone : Icons.cellphoneOff
        if (k === 4) return PomodoroState.isRunning ? Icons.musicPause : Icons.musicPlay
        if (k === 5) return Icons.calendar
        return Icons.display
    }
    function _tileLabel(k) {
        if (k === 0) return root._wifiConnected ? root._connectedName : "WiFi"
        if (k === 3) return KcdState.connected ? KcdState.device.name : "Sin dispositivo"
        if (k === 4) {
            if (PomodoroState.timerState === "idle") return "Pomodoro"
            var t = PomodoroState.timeRemaining
            var m = Math.floor(t / 60), s = t % 60
            return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        }
        if (k === 5) return "Cal"
        return MonitorState.activeLayout === "dual" ? "Dual"
             : MonitorState.activeLayout === "monitor" ? "Monitor" : "Netbook"
    }
    function _tileRun(k, mouse) {
        if (k === 4) {
            // Abre/cierra el submenú del pomodoro (exclusivo con calendario).
            root._pomoOpen = !root._pomoOpen
            if (root._pomoOpen) root._calOpen = false
            return
        }
        if (k === 5) {
            // Abre/cierra el submenú del calendario (exclusivo con pomodoro).
            root._calOpen = !root._calOpen
            if (root._calOpen) root._pomoOpen = false
            return
        }
        if (k === 3) {
            // Abre/cierra la ficha del dispositivo (batería, id, tipo).
            root._devOpen = !root._devOpen
            return
        }
        if (k === 0) {
            if (mouse && mouse.button === Qt.RightButton) WifiState.setWifiEnabled(!_wifiEnabled)
            else {
                root._wifiListOpen = !root._wifiListOpen
                if (root._wifiListOpen) {
                    root._refreshNets(true)
                    if (WifiState.wifiEnabled && !WifiState.scanning) WifiState.triggerScan()
                } else {
                    WifiState.stopScan()
                }
            }
        }
    }

    // Tile de pantalla (3): menú flotante de layouts. Posiciona con el
    // tamaño implícito del DropdownMenu y hace flip vertical si no entra arriba.
    function _toggleLayoutMenu(tile) {
        if (_layVisible) { _layVisible = false; return }
        var w = layMenu.width
        var h = layMenu.height
        var pos = tile.mapToItem(wrapper, 0, 0)
        _layX = Math.max(8, Math.min(pos.x + tile.width / 2 - w / 2, wrapper.width - w - 8))
        var layY = pos.y - h - 8
        if (layY < 8) {
            var spaceBelow = wrapper.height - 8 - (pos.y + tile.height)
            if (spaceBelow >= h) {
                layY = pos.y + tile.height + 8
            } else {
                layY = Math.max(8, pos.y - h - 8)
            }
        }
        _layY = layY
        _layVisible = true
    }

    property var _netsLatest: []
    property string _netsKey: ""
    // El swap del modelo lo hace la lista (preserva scroll); root publica.
    property int _netsRev: 0
    function _refreshNets(force) {
        var nets = WifiState.networks.slice()
        nets.sort(function(a, b) {
            return ((b && b.known) ? 1 : 0) - ((a && a.known) ? 1 : 0)
        })
        var key = ""
        for (var i = 0; i < nets.length; i++) {
            key += (nets[i] ? nets[i].name : "-") + "|"
        }
        if (force || key !== _netsKey) {
            _netsKey = key
            _netsLatest = nets
            _netsRev++
        }
    }

    // Context menu state
    property bool _ctxVisible: false
    property string _ctxSsid: ""
    property real _ctxX: 0
    property real _ctxY: 0
    property bool _ctxConnected: false
    property bool _ctxKnown: false

    // Menú de layouts de pantalla (tile laptop)
    property bool _layVisible: false
    property real _layX: 0
    property real _layY: 0

    // Lista WiFi expandida debajo del tile (acordeón)
    property bool _wifiListOpen: false
    // Ficha del dispositivo Android expandida bajo el tile (acordeón)
    property bool _devOpen: false
    // Submenús pomodoro/calendario: acordeones full-width bajo la fila de
    // tiles, exclusivos entre sí (abrir uno cierra el otro).
    property bool _pomoOpen: false
    property bool _calOpen: false
    // Glifo de batería por nivel (con bolt si está cargando).
    readonly property string _devBattIcon: {
        if (!KcdState.connected) return ""
        if (KcdState.charging) return Icons.batteryCharging
        if (KcdState.battery >= 60) return Icons.batteryHigh
        if (KcdState.battery >= 30) return Icons.batteryMedium
        return Icons.batteryLow
    }

    // Submenú inline de contraseña estilo KDE (ssid expandido)
    property string _expandedSsid: ""
    // Borradores de contraseña por ssid (sobreviven a reescaneos que recrean delegates)
    property var _pwdDrafts: ({})

    // "Hoy" del calendario se recalcula solo al abrir el panel (no con un
    // timer): si la shell lleva días corriendo, al abrirlo ya está al día.
    onViewOpenChanged: { if (viewOpen) { MonitorState.refresh(); BrightState.sync(); KcdState.start() } else { _ctxVisible = false; _layVisible = false; _wifiListOpen = false; _devOpen = false; _pomoOpen = false; _calOpen = false; _expandedSsid = ""; _pwdDrafts = {}; WifiState.inlineSsid = ""; WifiState.stopScan(); KcdState.stop() } }

    Connections {
        target: WifiState
        function onNetworksChanged() { root._refreshNets() }
    }

    Component.onCompleted: Qt.callLater(function() { root._refreshNets() })

    // Superficie fija en el shell (surfaceHeight = _maxH): el compositor no
    // redimensiona la ventana por frame. El alto del contenido es la suma
    // de sus partes (sin animación): piso = vista colapsada exacta.
    readonly property real _maxH: Screen.height - Config.taskbarHeight - 20
    readonly property real visualHeight: Math.min(ccFlickable.contentHeight + 2, _maxH)
    // Alto fijo para las listas de sub-vistas (wifi/batería): ventana más
    // alta al abrir un tile. Fijo (no sigue al alto animado) para evitar
    // loops de binding con la altura animada.
    readonly property real subViewListH: Math.min(480, _maxH - 240)

    // Contenido (el shell aporta superficie + máscara + wipe + shape).
    Item {
        id: wrapper
        anchors.fill: parent

                Flickable {
                    id: ccFlickable
                    anchors.fill: parent
                    anchors.margins: 1
                    contentWidth: width
                    contentHeight: mainCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height && !root._wifiListOpen

                Column {
                    id: mainCol
                    width: parent.width
                        spacing: 16
                        topPadding: 16
                        bottomPadding: 16
 

                    // ── TILES ESTILO QUICK SETTINGS (ANDROID) ──────────────
                    // wifi, dark, night, pantalla.
                    // Grilla de 2 columnas: píldora con ícono a la izquierda
                    // y label al lado. ON = primary_container + ícono en
                    // círculo primary; OFF = surface_container_high.
                    GridLayout {
                        id: tilesGrid
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            // 0 wifi, 1 pantalla (layouts), 2 dark/night,
                            // 3 dispositivo Android (kcd), 4 pomodoro,
                            // 5 calendario, 6 submenú pomo/cal (fila full-width).
                            model: 7
                            delegate: Item {
                                id: m3tile
                                readonly property int kind: index
                                readonly property bool m3on: root._tileOn(kind)
                                property real wifiListAnimH: 0
                                property real devAnimH: 0
                                property real subAnimH: 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: kind === 6 ? subAnimH : 64 + wifiListAnimH + devAnimH
                                Layout.columnSpan: kind === 0 || kind === 3 || kind === 6 ? 2 : 1

                                NumberAnimation {
                                    id: wifiListAnim
                                    target: m3tile
                                    property: "wifiListAnimH"
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }

                                    Connections {
                                    target: root
                                    function on_WifiListOpenChanged() {
                                        wifiListAnim.from = wifiListAnimH
                                        wifiListAnim.to = kind === 0 && root._wifiListOpen ? Math.min(300, root.subViewListH) : 0
                                        wifiListAnim.start()
                                    }
                                }

                                NumberAnimation {
                                    id: devAnim
                                    target: m3tile
                                    property: "devAnimH"
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }

                                Connections {
                                    target: root
                                    function on_DevOpenChanged() {
                                        devAnim.from = devAnimH
                                        devAnim.to = kind === 3 && root._devOpen ? 104 : 0
                                        devAnim.start()
                                    }
                                }

                                NumberAnimation {
                                    id: subAnim
                                    target: m3tile
                                    property: "subAnimH"
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }

                                // Fila del submenú (kind 6): la altura depende
                                // del exclusivo activo (240 pomo / 300 cal).
                                // Guard por kind: los demás tiles ignoran.
                                Connections {
                                    target: root
                                    function on_PomoOpenChanged() {
                                        if (kind !== 6) return
                                        subAnim.from = subAnimH
                                        subAnim.to = root._pomoOpen ? 240 : (root._calOpen ? 300 : 0)
                                        subAnim.start()
                                    }
                                    function on_CalOpenChanged() {
                                        if (kind !== 6) return
                                        subAnim.from = subAnimH
                                        subAnim.to = root._calOpen ? 300 : (root._pomoOpen ? 240 : 0)
                                        subAnim.start()
                                    }
                                }

                                Component.onCompleted: {
                                    wifiListAnimH = kind === 0 && root._wifiListOpen ? Math.min(300, root.subViewListH) : 0
                                    devAnimH = kind === 3 && root._devOpen ? 104 : 0
                                    subAnimH = kind === 6 ? (root._pomoOpen ? 240 : root._calOpen ? 300 : 0) : 0
                                }

                                Column {
                                    anchors.fill: parent
                                    spacing: 0

                                    // Tile actual (altura fija 64). En la fila
                                    // submenú (kind 6) se omite por completo:
                                    // el Column salta los hijos invisibles.
                                    Item {
                                        id: tileContent
                                        visible: kind !== 6
                                        width: parent.width
                                        height: 64

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Style.container_radius
                                            color: kind === 2 ? Style.surface_container_low
                                                : m3tile.m3on ? Style.primary_container : Style.surface_container_low
                                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: parent.radius
                                                color: Style.interactive_bg
                                                opacity: tileMouse.containsMouse ? 1.0 : 0.0
                                                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                            }

                                            Row {
                                                visible: kind !== 2
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 16
                                                spacing: 12

                                                Item {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 40; height: 40

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: Style.container_radius
                                                        color: Style.primary
                                                        opacity: m3tile.m3on ? 1.0 : 0.0
                                                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: root._tileIcon(m3tile.kind)
                                                        font.pixelSize: Config.fontSizeIconLg
                                                        font.family: Icons.font
                                                        color: m3tile.m3on ? Style.on_primary : Style.on_surface_variant
                                                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 52 - (kind === 3 ? 104 : 0)
                                                    text: root._tileLabel(m3tile.kind)
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    font.pixelSize: Config.fontSizeBodySm
                                                    font.weight: m3tile.m3on ? Config.fontWeightMedium : Config.fontWeightNormal
                                                    font.family: Config.uiFont
                                                    color: m3tile.m3on ? Style.on_primary_container : Style.on_surface_variant
                                                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                                }

                                                // Batería del dispositivo (sólo kind 3), en vivo vía kcd.
                                                Item {
                                                    visible: kind === 3
                                                    width: kind === 3 ? 92 : 0
                                                    height: parent.height

                                                    Row {
                                                        anchors.centerIn: parent
                                                        spacing: 4
                                                        visible: KcdState.connected

                                                        Text {
                                                            text: root._devBattIcon
                                                            font.pixelSize: Config.fontSizeIcon
                                                            font.family: Icons.font
                                                            color: m3tile.m3on ? Style.on_primary_container : Style.on_surface_variant
                                                        }
                                                        Text {
                                                            text: KcdState.battery >= 0 ? KcdState.battery + "%" : "—"
                                                            font.pixelSize: Config.fontSizeBodySm
                                                            font.weight: Config.fontWeightMedium
                                                            font.family: Config.uiFont
                                                            color: m3tile.m3on ? Style.on_primary_container : Style.on_surface_variant
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: kind === 2
                                                anchors.fill: parent
                                                radius: Style.container_radius
                                                color: Style.surface_container_low
                                                clip: true

                                                Row {
                                                    anchors.fill: parent
                                                    spacing: 2

                                                    Item {
                                                        width: (parent.width - 2) / 2
                                                        height: parent.height

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: TaskbarState.darkMode ? Style.primary_container : Style.surface_container_high
                                                            topLeftRadius: Style.container_radius
                                                            topRightRadius: 0
                                                            bottomLeftRadius: Style.container_radius
                                                            bottomRightRadius: 0
                                                        }
                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: Style.interactive_bg
                                                            opacity: leftCircle.containsMouse ? 1.0 : 0.0
                                                            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                                            topLeftRadius: Style.container_radius
                                                            topRightRadius: 0
                                                            bottomLeftRadius: Style.container_radius
                                                            bottomRightRadius: 0
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.darkMode
                                                            font.pixelSize: Config.fontSizeIconLg
                                                            font.family: Icons.font
                                                            color: TaskbarState.darkMode ? Style.on_primary_container : Style.on_surface
                                                        }

                                                        Mouse {
                                                            id: leftCircle
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            acceptedButtons: Qt.LeftButton
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: TaskbarState.applyDarkMode(!TaskbarState.darkMode)
                                                        }
                                                    }

                                                    Item {
                                                        width: (parent.width - 2) / 2
                                                        height: parent.height

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: TaskbarState.nightMode ? Style.primary_container : Style.surface_container_high
                                                            topLeftRadius: 0
                                                            topRightRadius: Style.container_radius
                                                            bottomLeftRadius: 0
                                                            bottomRightRadius: Style.container_radius
                                                        }
                                                        Rectangle {
                                                            anchors.fill: parent
                                                            color: Style.interactive_bg
                                                            opacity: rightCircle.containsMouse ? 1.0 : 0.0
                                                            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                                            topLeftRadius: 0
                                                            topRightRadius: Style.container_radius
                                                            bottomLeftRadius: 0
                                                            bottomRightRadius: Style.container_radius
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: Icons.nightLightOff
                                                            font.pixelSize: Config.fontSizeIconLg
                                                            font.family: Icons.font
                                                            color: TaskbarState.nightMode ? Style.on_primary_container : Style.on_surface
                                                        }

                                                        Mouse {
                                                            id: rightCircle
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            acceptedButtons: Qt.LeftButton
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: { TaskbarState.nightMode = !TaskbarState.nightMode; TaskbarState.applyNightMode() }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Mouse {
                                            id: tileMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: kind !== 2
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: (mouse) => {
                                                if (kind === 1) root._toggleLayoutMenu(m3tile)
                                                else root._tileRun(kind, mouse)
                                            }
                                        }

                                        // Zona del ícono (sólo tile pomodoro,
                                        // kind 4): pausa/reanuda sin abrir la
                                        // vista. Encima de tileMouse para
                                        // quedarse el click.
                                        Mouse {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: 52
                                            enabled: kind === 4
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (PomodoroState.isRunning) PomodoroState.pause()
                                                else PomodoroState.start()
                                            }
                                        }
                                    }

                                    // Lista WiFi debajo del tile (sólo kind 0, acordeón)
                                    Item {
                                        id: wifiListArea
                                        width: parent.width
                                        height: wifiListAnimH
                                        clip: true

                                        Loader {
                                            anchors.fill: parent
                                            active: root._wifiListOpen || wifiListAnimH > 0
                                            sourceComponent: WifiState.wifiEnabled ? wifiListComp : wifiEmptyOffComp
                                        }
                                    }

                                    // Ficha del dispositivo Android debajo del tile
                                    // (sólo kind 3, acordeón).
                                    Item {
                                        id: devArea
                                        width: parent.width
                                        height: devAnimH
                                        clip: true

                                        Loader {
                                            anchors.fill: parent
                                            active: root._devOpen || devAnimH > 0
                                            sourceComponent: KcdState.connected ? devCardComp : devEmptyComp
                                        }
                                    }

                                    // Submenú pomodoro/calendario (kind 6):
                                    // fila full-width del grid.
                                    // Vistas exclusivas superpuestas,
                                    // pre-creadas al abrir el CC (anti-lag).
                                    Item {
                                        id: subArea
                                        width: parent.width
                                        height: subAnimH
                                        clip: true
                                        visible: kind === 6
                                            && (root._pomoOpen || root._calOpen || subAnimH > 0)

                                        Item {
                                            anchors.fill: parent
                                            visible: root._pomoOpen

                                            Loader {
                                                anchors.fill: parent
                                                asynchronous: true
                                                active: root.viewOpen
                                                visible: status === Loader.Ready
                                                sourceComponent: pomoComp
                                            }
                                        }

                                        Item {
                                            anchors.fill: parent
                                            visible: root._calOpen

                                            Loader {
                                                anchors.fill: parent
                                                asynchronous: true
                                                active: root.viewOpen
                                                visible: status === Loader.Ready
                                                sourceComponent: calComp
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── BRILLO ──────────────────────────────────────────
                    Rectangle {
                        id: brightBox
                        width: parent.width - 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 56
                        radius: 12
                        color: Style.surface_container_low

                        ValueSlider {
                            anchors.fill: parent
                            anchors.margins: 4
                            value: BrightState.brightness
                            iconChar: Icons.brightness
                            showIconToggle: false
                            showLabel: true
                            labelText: BrightState.brightness + "%"
                            onChangeRequested: (newValue) => BrightState.setBrightness(newValue)
                        }
                    }


                }

            }

        // Cierra los menús al clickear afuera (solo cuando hay uno abierto)
        Mouse {
            anchors.fill: parent
            z: 500
            visible: root._ctxVisible || root._layVisible
            cursorShape: Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: { root._ctxVisible = false; root._layVisible = false }
        }

        // ── Context Menu (inside wrapper so Region mask includes it) ─────
        // Menú contextual WiFi sobre DropdownMenu: items según estado
        // (conectar/desconectar; olvidar solo en conocidas no conectadas).
        // Sin onDismissed: el click en la superficie no cierra (paridad).
        DropdownMenu {
            id: ctxMenu
            x: root._ctxX
            y: root._ctxY
            width: 180
            itemHeight: 32
            iconPixelSize: Config.fontSizeBodySm
            open: root._ctxVisible
            items: {
                var list = [{ id: "toggle",
                              label: root._ctxConnected ? "Desconectar" : "Conectar",
                              icon: root._ctxConnected ? Icons.wifiOff : Icons.wifi }]
                if (root._ctxKnown && !root._ctxConnected)
                    list.push({ id: "forget", label: "Olvidar", icon: Icons.trash, danger: true })
                return list
            }
            onPicked: (id) => {
                if (id === "toggle") {
                    if (root._ctxConnected) WifiState.disconnect(root._ctxSsid)
                    else WifiState.connectTo(root._ctxSsid, "")
                } else if (id === "forget") {
                    WifiState.forget(root._ctxSsid)
                }
                root._ctxVisible = false
            }
        }

        // ── Menú de layouts de pantalla (tile laptop) ────────────────────
        DropdownMenu {
            id: layMenu
            x: root._layX
            y: root._layY
            open: root._layVisible
            selectedId: MonitorState.activeLayout
            items: [
                { id: "netbook", label: "Netbook", icon: Icons.display },
                { id: "dual", label: "Dual", icon: Icons.displayDual },
                { id: "monitor", label: "Monitor", icon: Icons.displayMonitor }
            ]
            onPicked: (id) => {
                MonitorState.layoutSwitchProc.apply(id)
                root._layVisible = false
            }
            onDismissed: root._layVisible = false
        }
    }

    Component {
        id: wifiListComp
        // Alto = ventana visible (el Loader sigue al acordeón animado): si
        // quedara en subViewListH el viewport es más alto que la ventana y
        // el fin de la lista queda inalcanzable tras el clip.
        Rectangle {
            id: listCard
            height: parent.height
            radius: 12
            color: Style.surface_container_low

            // Swap del modelo con preservación de scroll: el reset del
            // ListView tira contentY a 0; se re-aplica el valor previo.
            // Sin property _dirty: el handler escribe _appliedRev, que es
            // dependencia del binding → QML lo detecta como loop. La
            // conexión es explícita a _netsRev (ajeno a lo que se escribe).
            property var _model
            property int _appliedRev: -1
            function _applyRev() {
                if (_appliedRev === root._netsRev) return
                _appliedRev = root._netsRev
                if (!wifiList) return
                var y = wifiList.contentY
                _model = root._netsLatest
                wifiList.contentY = y
            }
            Component.onCompleted: _applyRev()
            Connections {
                target: root
                function on_NetsRevChanged() { listCard._applyRev() }
            }

                ListView {
                    id: wifiList
                    anchors.fill: parent
                    anchors.margins: 8
                    // Margen de contenido arriba/abajo (no pega contra los
                    // bordes redondeados al scrollear) y sin rebote al final.
                    topMargin: 8
                    bottomMargin: 8
                    boundsBehavior: Flickable.StopAtBounds
                    model: listCard._model
                    clip: true
                    spacing: 2

                section.property: "known"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    width: wifiList.width
                    height: 30

                    SectionLabel {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: section === "true" ? "CONOCIDAS" : "DESCONOCIDAS"
                    }
                }

                delegate: Item {
                    id: netDelegate
                    required property var modelData
                    required property int index
                    width: wifiList.width
                    height: 44 + subMenu.height

                    readonly property bool _expanded: root._expandedSsid !== "" && modelData && root._expandedSsid === modelData.name && !modelData.connected
                    readonly property bool _hasError: modelData && WifiState.errorSsid === modelData.name && WifiState.errorMsg !== ""
                    readonly property bool _busy: modelData && modelData.stateChanging && !_showError
                    // Error efectivo: del estado o por timeout (excluye conectada)
                    readonly property bool _showError: modelData && !modelData.connected && (_hasError || _timedOut)
                    readonly property string _errorText: _hasError ? WifiState.errorMsg : "Tiempo de conexión agotado. Inténtalo de nuevo."
                    property bool _timedOut: false
                    property double _attemptAt: 0

                    // Timeout: si NM no resuelve el intento, cancela y muestra error
                    Timer {
                        interval: 1000
                        repeat: true
                        running: netDelegate._busy && root.viewOpen
                        onTriggered: {
                            if (netDelegate._attemptAt > 0 && Date.now() - netDelegate._attemptAt > 25000) {
                                netDelegate._attemptAt = 0
                                netDelegate._timedOut = true
                                if (netDelegate.modelData) netDelegate.modelData.disconnect()
                            }
                        }
                    }

                    property bool ph: false

                    function _submit() {
                        if (!modelData || pwdField.text.length === 0) return
                        var pwd = pwdField.text
                        pwdField.text = ""
                        delete root._pwdDrafts[modelData.name]
                        WifiState.inlineSsid = modelData.name
                        _timedOut = false
                        _attemptAt = Date.now()
                        WifiState.connectTo(modelData.name, pwd)
                    }

                    // BG que engloba fila + submenú (overlays independientes, Bug 1/2)
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Style.surface_container_high
                        opacity: !netDelegate._showError && !(modelData && modelData.connected) && !netDelegate._expanded ? 1.0 : 0.0
                        
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Style.secondary_container
                        opacity: !netDelegate._showError && (modelData && modelData.connected) ? 1.0 : 0.0
                        
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Style.surface_container_highest
                        opacity: !netDelegate._showError && !(modelData && modelData.connected) && netDelegate._expanded ? 1.0 : 0.0
                        
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Style.error_container
                        opacity: netDelegate._showError ? 1.0 : 0.0
                        
                    }

                    Column {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                    // Fila principal
                    Item {
                        width: parent.width; height: 44
                    Mouse {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: netDelegate.ph = true
                        onExited:  netDelegate.ph = false
                        onClicked: (mouse) => {
                            if (!modelData) return
                            root._ctxVisible = false
                            if (mouse.button === Qt.RightButton) {
                                var pos = netDelegate.mapToItem(wrapper, mouse.x, mouse.y)
                                root._ctxSsid = modelData.name
                                root._ctxConnected = modelData.connected
                                root._ctxKnown = modelData.known
                                var w = ctxMenu.width
                                var h = ctxMenu.height
                                root._ctxX = (pos.x + w > wrapper.width) ? pos.x - w : pos.x
                                root._ctxY = (pos.y + h > wrapper.height) ? pos.y - h : pos.y
                                root._ctxVisible = true
                                } else {
                                    if (modelData.connected) {
                                        netDelegate._attemptAt = 0
                                        netDelegate._timedOut = false
                                        WifiState.disconnect(modelData.name)
                                    } else if (modelData.security !== 0 && !modelData.known) {
                                    root._expandedSsid = (root._expandedSsid === modelData.name) ? "" : modelData.name
                                    if (root._expandedSsid === modelData.name)
                                        Qt.callLater(function() { pwdField.forceActiveFocus() })
                                    } else {
                                        netDelegate._timedOut = false
                                        netDelegate._attemptAt = Date.now()
                                        WifiState.connectTo(modelData.name, "")
                                    }
                            }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Style.interactive_bg
                        opacity: netDelegate.ph && !(modelData && modelData.connected) && !netDelegate._expanded && !netDelegate._showError ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                        
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24

                            Text {
                                anchors.centerIn: parent
                                text: Icons.wifi
                                font.pixelSize: Config.fontSizeIconLg
                                font.family: Icons.font
                                color: netDelegate._showError ? Style.on_error_container
                                    : (modelData && modelData.connected) ? Style.on_secondary_container : Style.on_surface
                                visible: !netDelegate._busy
                            }

                            // Spinner orbitando mientras conecta/reconecta
                            Item {
                                anchors.centerIn: parent
                                width: 20; height: 20
                                visible: netDelegate._busy

                                Rectangle {
                                    width: 5; height: 5; radius: 2.5
                                    color: Style.tertiary
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData ? modelData.name : ""
                            font.pixelSize: Config.fontSizeBody
                            font.family: Config.uiFont
                            font.weight: (modelData && modelData.connected) ? Config.fontWeightMedium : Config.fontWeightNormal
                            color: netDelegate._showError ? Style.on_error_container
                                : (modelData && modelData.connected) ? Style.on_secondary_container : Style.on_surface
                            elide: Text.ElideRight
                            width: parent.width - 160
                        }

                        Item { width: parent.width - 160; height: 1 }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.check
                            font.pixelSize: Config.fontSizeIcon
                            font.family: Icons.font
                            color: Style.on_secondary_container
                            visible: modelData && modelData.connected
                        }
                    }
                    }

                    // Submenú inline estilo KDE: contraseña + conectar + error
                    Item {
                        id: subMenu
                        width: parent.width
                        height: netDelegate._expanded ? (netDelegate._showError ? 72 : 48) : 0
                        clip: true
                        visible: height > 0
                        // Expandir/colapsar (conectar, error) sin salto: el
                        // delegate crece 44 + height por frame.
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        

                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            anchors.topMargin: 4; anchors.bottomMargin: 8
                            spacing: 6

                            Row {
                                width: parent.width; height: 36; spacing: 8

                                AppTextInput {
                                    id: pwdField
                                    width: parent.width - 104
                                    inputHeight: 36
                                    inputRadius: 8
                                    fontSize: Config.fontSizeBody
                                    placeholderText: "Contraseña"
                                    placeholderColor: Style.on_surface_variant
                                    passwordMode: true

                                    editField.focus: netDelegate._expanded
                                    Component.onCompleted: text = root._pwdDrafts[modelData.name] || ""
                                    onTextChanged: root._pwdDrafts[modelData.name] = text
                                    onAccepted: netDelegate._submit()
                                    onEscapePressed: root._expandedSsid = ""
                                }

                                PillButton {
                                    width: 96
                                    label: "Conectar"
                                    active: pwdField.text.length > 0
                                    interactive: pwdField.text.length > 0
                                    onClicked: netDelegate._submit()
                                }
                            }

                            Text {
                                width: parent.width
                                text: netDelegate._errorText
                                font.pixelSize: Config.fontSizeCaption
                                font.family: Config.uiFont
                                color: Style.on_error_container
                                elide: Text.ElideRight
                                visible: netDelegate._showError
                            }
                        }
                    }
                    }
                }
            }
        }
    }

    Component {
        id: wifiEmptyOffComp
        Rectangle {
            height: parent.height
            radius: 12
            color: Style.surface_container_low

            EmptyState {
                anchors.centerIn: parent
                width: parent.width - 32
                icon: Icons.wifiOff
                title: "WiFi apagado"
                subtitle: "Activalo para ver las redes disponibles"
            }
        }
    }

    Component {
        id: devCardComp
        // Ficha del dispositivo Android (kcd, en vivo).
        Rectangle {
            id: devCard
            height: parent.height
            radius: 12
            color: Style.surface_container_low
            clip: true

            readonly property var d: KcdState.device

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 14
                anchors.topMargin: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Tipo"
                        font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                        color: Style.on_surface_variant
                    }
                    Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
                    Text {
                        text: devCard.d ? devCard.d.type : "—"
                        font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                        color: Style.on_surface
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "ID"
                        font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                        color: Style.on_surface_variant
                    }
                    Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
                    Text {
                        Layout.preferredWidth: 240
                        text: devCard.d ? devCard.d.id : "—"
                        font.pixelSize: Config.fontSizeCaption; font.family: Config.ibmPlexMono
                        color: Style.on_surface
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Batería"
                        font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                        color: Style.on_surface_variant
                    }
                    Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
                    Text {
                        text: devCard.d
                            ? ((devCard.d.charge >= 0 ? devCard.d.charge + "%" : "—")
                               + (devCard.d.charging ? " · cargando" : ""))
                            : "—"
                        font.pixelSize: Config.fontSizeLabelSm; font.weight: Config.fontWeightMedium
                        font.family: Config.uiFont
                        color: Style.on_surface
                    }
                }
            }
        }
    }

    Component {
        id: devEmptyComp
        Rectangle {
            height: parent.height
            radius: 12
            color: Style.surface_container_low

            EmptyState {
                anchors.centerIn: parent
                width: parent.width - 32
                icon: Icons.cellphone
                title: "Sin dispositivo"
                subtitle: "El Android no está conectado (kcd)"
            }
        }
    }

    Component {
        id: pomoComp
        // Submenú pomodoro (acordeón bajo la fila de tiles).
        Rectangle {
            height: parent.height
            radius: 12
            color: Style.surface_container_low
            clip: true

            Flickable {
                id: pomoFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: Math.max(height, pomoPanel.implicitHeight)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height && !root._wifiListOpen

                PomodoroPanel {
                    id: pomoPanel
                    width: pomoFlick.width
                    height: Math.max(pomoFlick.height, implicitHeight)
                    active: root.viewOpen && root._pomoOpen
                }
            }
        }
    }

    Component {
        id: calComp
        // Submenú calendario (acordeón bajo la fila de tiles).
        // "Hoy" se refresca al abrir el CC: el Loader se pre-crea entonces
        // (y se destruye al cerrar el CC), como hacía la card vieja.
        Rectangle {
            height: parent.height
            radius: 12
            color: Style.surface_container_low
            clip: true

            Component.onCompleted: calRoot.refreshToday()

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                QtObject {
                    id: calRoot
                    property var refDate: new Date()
                    property int year:  refDate.getFullYear()
                    property int month: refDate.getMonth()
                    // _rev fuerza a recalcular "today" cuando el
                    // panel se abre (ver refreshToday()).
                    property int _rev: 0
                    property var today: { _rev; return new Date() }

                    function refreshToday() { _rev++ }

                    function prevMonth() {
                        var d = new Date(refDate); d.setDate(1); d.setMonth(d.getMonth() - 1); refDate = d
                    }
                    function nextMonth() {
                        var d = new Date(refDate); d.setDate(1); d.setMonth(d.getMonth() + 1); refDate = d
                    }
                }

                // Titular M3 Expressive + navegación
                Item {
                    width: parent.width
                    height: 40

                    RowLayout {
                        anchors.fill: parent
                        spacing: 4

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0
                            Text {
                                text: {
                                    var m = ["Enero","Febrero","Marzo","Abril","Mayo","Junio",
                                             "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]
                                    return m[calRoot.month]
                                }
                                font.pixelSize: Config.fontSizeTitle
                                font.weight: Config.fontWeightBold
                                font.family: Config.uiFont
                                color: Style.on_surface
                            }
                            Text {
                                text: calRoot.year
                                font.pixelSize: Config.fontSizeCaption
                                font.family: Config.uiFont
                                color: Style.on_surface_variant
                            }
                        }

                        // Pill "Hoy" — visible fuera del mes actual
                        Item {
                            Layout.preferredWidth: 58
                            Layout.preferredHeight: 30
                            visible: calRoot.month !== calRoot.today.getMonth()
                                || calRoot.year !== calRoot.today.getFullYear()
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Style.secondary_container
                                opacity: calTitleH.hovered ? 1.0 : 0.75
                                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Hoy"
                                    font.pixelSize: Config.fontSizeLabelSm
                                    font.weight: Config.fontWeightMedium
                                    font.family: Config.uiFont
                                    color: Style.on_secondary_container
                                }
                            }
                            HoverHandler { id: calTitleH }
                            TapHandler { onTapped: { calRoot.refDate = new Date(); calRoot.today = new Date() } }
                        }

                        Rectangle {
                            Layout.preferredWidth: 32; Layout.preferredHeight: 32
                            radius: 8
                            color: "transparent"
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: Style.surface_container_highest
                                opacity: calPrevH.hovered ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            }
                            Text {
                                anchors.centerIn: parent
                                text: Icons.calendarPrev
                                font.pixelSize: Config.fontSizeBody; font.family: Icons.font
                                color: Style.on_surface_variant
                            }
                            HoverHandler { id: calPrevH }
                            TapHandler   { onTapped: calRoot.prevMonth() }
                        }

                        Rectangle {
                            Layout.preferredWidth: 32; Layout.preferredHeight: 32
                            radius: 8
                            color: "transparent"
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: Style.surface_container_highest
                                opacity: calNextH.hovered ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            }
                            Text {
                                anchors.centerIn: parent
                                text: Icons.chevronRight
                                font.pixelSize: Config.fontSizeBody; font.family: Icons.font
                                color: Style.on_surface_variant
                            }
                            HoverHandler { id: calNextH }
                            TapHandler   { onTapped: calRoot.nextMonth() }
                        }
                    }
                }

                // Cabecera días — inicial simple M3
                Row {
                    width: parent.width
                    Repeater {
                        model: ["L","M","M","J","V","S","D"]
                        Text {
                            text: modelData
                            width: Math.floor(parent.width / 7)
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Config.fontSizeCaption
                            font.weight: Config.fontWeightMedium
                            font.family: Config.uiFont
                            color: index >= 5 ? Style.primary : Style.on_surface_variant
                        }
                    }
                }

                // Grilla días
                Grid {
                    id: calGrid
                    width: parent.width
                    columns: 7

                    property int offset: {
                        var d = new Date(calRoot.year, calRoot.month, 1).getDay()
                        return (d + 6) % 7
                    }
                    property int daysInMonth: new Date(calRoot.year, calRoot.month + 1, 0).getDate()
                    property int daysInPrevMonth: new Date(calRoot.year, calRoot.month, 0).getDate()
                    readonly property real cellW: Math.floor(width / 7)

                    Repeater {
                        model: 42
                        delegate: Item {
                            id: cell
                            width: calGrid.cellW; height: 32

                            // Mes relativo: -1 = mes anterior, 0 = actual, 1 = siguiente
                            readonly property int rel: index < calGrid.offset ? -1
                                : index < calGrid.offset + calGrid.daysInMonth ? 0 : 1
                            readonly property int day: rel === 0
                                ? index - calGrid.offset + 1
                                : rel === -1
                                ? calGrid.daysInPrevMonth - (calGrid.offset - 1 - index)
                                : index - (calGrid.offset + calGrid.daysInMonth) + 1
                            readonly property bool weekend: (index % 7) >= 5
                            readonly property bool isToday: rel === 0
                                && day           === calRoot.today.getDate()
                                && calRoot.month === calRoot.today.getMonth()
                                && calRoot.year  === calRoot.today.getFullYear()

                            // Día de otro mes: sin bg (se ve el fondo de la tarjeta)
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 6
                                color: Style.surface_container
                                visible: false
                                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            }

                            // Día del mes: bg elevado sutil (sin animación:
                            // al cambiar de mes el fade delato las celdas)
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 6
                                color: Style.surface_container_highest
                                opacity: cell.rel === 0 && !cell.isToday ? 0.35 : 0.0
                            }

                            // Hoy — bg de toda la celda con padding chico
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 6
                                color: Style.primary
                                opacity: cell.isToday ? 1.0 : 0.0
                            }

                            // Hover (nunca tapa al "hoy")
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 6
                                color: Style.surface_container_highest
                                opacity: cellH.hovered && !cell.isToday && cell.rel === 0 ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: cell.day
                                color: cell.isToday    ? Style.on_primary
                                     : cell.rel !== 0  ? Style.on_surface_variant
                                     : cell.weekend    ? Style.primary
                                     : Style.on_surface
                                opacity: cell.rel === 0 ? 1.0 : 0.55
                                font.pixelSize: Config.fontSizeLabel
                                font.weight: cell.isToday ? Config.fontWeightBold : Font.Normal
                                font.family: Config.uiFont
                            }

                            HoverHandler { id: cellH }
                        }
                    }
                }
            }
        }
    }

}
