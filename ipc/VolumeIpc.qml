import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../state"

// VolumeIpc — control de volumen por CLI/teclas.
//
//   qs ipc call vol adjust +10      # sube 10 (desmutea)
//   qs ipc call vol adjust -10      # baja 10 (entre comillas si el parser lo toma como flag)
//   qs ipc call vol toggle          # mute <-> unmute
Item {
    id: root

    function _sinkReady(): bool {
        return Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? true : false
    }

    function _apply(v): string {
        if (!root._sinkReady()) return "audio sink not ready"
        var nv = Math.max(0, Math.min(100, Math.round(v)))
        if (AudioState.muted) AudioState.audioMute()
        AudioState.audioSetVolume(nv)
        TaskbarState._showOsd("vol")
        return nv.toString()
    }

    IpcHandler {
        target: "vol"

        function adjust(delta: int): string {
            return root._apply(AudioState.volume + delta)
        }

        function toggle(): string {
            if (!root._sinkReady()) return "audio sink not ready"
            AudioState.audioMute()
            TaskbarState._showOsd("vol")
            return AudioState.muted ? "muted" : AudioState.volume.toString()
        }
    }
}
