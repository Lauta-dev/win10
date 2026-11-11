pragma Singleton
import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
    id: wifiState

    // ── Estado de errores ───────────────────────────────────────────────────
    property string errorSsid: ""
    property string errorMsg: ""
    // SSID cuya contraseña se pide inline (submenú en el ítem, estilo KDE)
    property string inlineSsid: ""
    property bool   scanning: false

    // ── WiFi on/off ─────────────────────────────────────────────────────────
    property bool wifiEnabled: Networking.wifiEnabled

    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = enabled
    }

    Connections {
        target: Networking
        function onWifiEnabledChanged() {
            wifiState.wifiEnabled = Networking.wifiEnabled
        }
    }

    // ── Dispositivo WiFi nativo ─────────────────────────────────────────────
    readonly property var _wifiDevice: {
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i]
        }
        return null
    }

    // ── Redes crudas (WifiNetwork objects) ──────────────────────────────────
    readonly property var networks: _wifiDevice ? _wifiDevice.networks.values : []

    // ── Tracking de señales por red ─────────────────────────────────────────
    property var _trackedNets: []

    function _trackNet(net) {
        if (!net || _trackedNets.indexOf(net) >= 0) return
        _trackedNets.push(net)
        net.connectionFailed.connect(function(reason) {
            _onConnectionFailed(net, reason)
        })
        net.connectedChanged.connect(function() {
            _onConnectedChanged(net)
        })
    }

    function _onConnectionFailed(net, reason) {
        var ssid = net.name
        if (reason === 1 && inlineSsid !== ssid) {
            // Nadie la atiende inline: exponer error sin olvidar
            // (puede ser un perfil conocido con clave cambiada)
            errorSsid = ssid
            errorMsg = _reasonToMsg(reason)
        } else if (reason === 1) {
            // Se envió contraseña inline y falló → incorrecta
            errorSsid = ssid
            errorMsg = "Contraseña incorrecta"
            net.forget()
        } else {
            errorSsid = ssid
            errorMsg = _reasonToMsg(reason)
            net.forget()
        }
    }

    function _onConnectedChanged(net) {
        if (!net.connected) return
        if (inlineSsid === net.name) {
            inlineSsid = ""
        }
    }

    // ── Conectar señales al device ──────────────────────────────────────────
    // onNetworkAdded no existe en el device, se usa onNetworksChanged arriba

    Component.onCompleted: Qt.callLater(function() {
        _trackAllNets()
    })

    on_WifiDeviceChanged: {
        if (_wifiDevice) {
            _trackAllNets()
        }
    }

    onNetworksChanged: _trackAllNets()

    function _trackAllNets() {
        var nets = networks
        for (var i = 0; i < nets.length; i++) {
            if (nets[i]) _trackNet(nets[i])
        }
    }

    // ── Trigger scan ────────────────────────────────────────────────────────
    // El scanner vive mientras la lista de redes esté abierta: con el scanner
    // apagado NM deja de reportar APs y Quickshell los poda de `networks`
    // (la lista queda solo con las conectadas/conocidas). Se apaga al cerrar
    // la lista o el panel (ControlCenterNew) o al desactivar WiFi.
    Connections {
        target: Networking
        function onWifiEnabledChanged() {
            if (!Networking.wifiEnabled) wifiState.stopScan()
        }
    }

    function triggerScan() {
        if (_wifiDevice) {
            scanning = true
            _wifiDevice.scannerEnabled = true
        }
    }

    function stopScan() {
        scanning = false
        if (_wifiDevice) _wifiDevice.scannerEnabled = false
    }

    // ── Acciones ────────────────────────────────────────────────────────────
    function connectTo(ssid, pwd) {
        var net = _findNetwork(ssid)
        if (!net) return
        errorSsid = ""
        errorMsg = ""
        if (pwd !== "") {
            net.connectWithPsk(pwd)
        } else {
            net.connect()
        }
    }

    function disconnect(ssid) {
        var net = _findNetwork(ssid)
        if (net && net.connected) net.disconnect()
    }

    function forget(ssid) {
        var net = _findNetwork(ssid)
        if (net) net.forget()
    }

    function _findNetwork(ssid) {
        for (var i = 0; i < networks.length; i++) {
            if (networks[i] && networks[i].name === ssid) return networks[i]
        }
        return null
    }

    function _reasonToMsg(reason) {
        if (reason === 0) return "Error desconocido"
        if (reason === 1) return "Se requiere contraseña"
        if (reason === 2) return "Wi-Fi desconectado"
        if (reason === 3) return "Error de autenticación"
        if (reason === 4) return "Tiempo de autenticación agotado"
        if (reason === 5) return "Red no encontrada"
        return "Error de conexión"
    }
}
