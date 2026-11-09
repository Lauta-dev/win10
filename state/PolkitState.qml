pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property bool isActive: agent.isActive
    readonly property var flow: agent.flow

    function submit(value) {
        if (flow) flow.submit(value)
    }

    function cancel() {
        if (flow) flow.cancelAuthenticationRequest()
    }
}
