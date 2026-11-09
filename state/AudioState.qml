import Quickshell.Services.Pipewire
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property int  volume: 50
  property bool muted: false
  property bool ready: _sinkReady

  // Bindea el sink por defecto para que node.audio.* sea válido (la doc de
  // Pipewire marca volume/muted/volumes/channels como inválidos salvo bound).
  PwObjectTracker {
    id: sinkTracker
    objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
  }

  readonly property bool _sinkReady:
    Pipewire.ready && Pipewire.defaultAudioSink
    && Pipewire.defaultAudioSink.ready && Pipewire.defaultAudioSink.audio

  // Sincroniza desde PipeWire solo cuando el sink está listo (evita 0 fantasma
  // al conectar un dispositivo nuevo). Escrituras locales son optimistas:
  // actualizan AudioState y PipeWire a la vez para evitar lag en sliders/OSD.
  Component.onCompleted: _syncFromPipewire()
  on_SinkReadyChanged: if (_sinkReady) _syncFromPipewire()

  function _syncFromPipewire() {
    var sink = Pipewire.defaultAudioSink
    if (_sinkReady && sink.audio) {
      var v = Math.round(sink.audio.volume * 100)
      if (volume !== v) volume = v
      muted = sink.audio.muted
    }
  }

  function audioMute() {
    var sink = Pipewire.defaultAudioSink
    if (_sinkReady && sink.audio) {
      var m = !sink.audio.muted
      sink.audio.muted = m
      muted = m
    }
  }
  function audioSetVolume(v) {
    var nv = Math.max(0, Math.min(100, Math.round(v)))
    var sink = Pipewire.defaultAudioSink
    if (_sinkReady && sink.audio)
      sink.audio.volume = nv / 100
    volume = nv
  }
  function audioSync() {}
}
