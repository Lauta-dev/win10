# QuickShell v0.3.0 — Quickshell.Io

`import Quickshell.Io`

---

## Process

Child process.

### Properties
- `command: list<string>` — Command to execute. Each argument is a separate string.
- `running: bool` — Currently running. Setting true starts, false sends SIGTERM.
- `processId: variant` (readonly) — PID or null if not running.
- `stdout: DataStreamParser` — Parser for stdout.
- `stderr: DataStreamParser` — Parser for stderr.
- `stdinEnabled: bool` — If stdin is enabled (default false).
- `environment: object` — Environment variables as JS object.
- `clearEnvironment: bool` — Clear env before applying vars.
- `workingDirectory: string` — Working directory of the process.

### Functions
- `exec(context)` — Launch process with given arguments, stopping any running process.
- `startDetached()` — Launch detached from Quickshell (not tracked).
- `write(data)` — Write to stdin.
- `signal(signal)` — Send signal to process.

### Signals
- `started()`
- `exited(exitCode, exitStatus)`

---

## StdioCollector (extends DataStreamParser)

Collects all process output into a buffer.

### Properties
- `text: string` (readonly) — Buffer as text.
- `data: ArrayBuffer` (readonly) — Buffer as ArrayBuffer.
- `waitForEnd: bool` — If true, text/data won't update until stream ends (default true).

### Signals
- `streamFinished()`

---

## SplitParser (extends DataStreamParser)

DataStreamParser for delimited data streams. `read()` emitted once per delimited chunk.

### Properties
- `splitMarker: string` — The delimiter (default "\n").

---

## DataStream (uncreatable)

Data source that can be streamed into a parser.

### Properties
- `parser: DataStreamParser` — Parser to stream data into. If null, no data will be read.

---

## DataStreamParser (uncreatable)

Parser for streamed input data.

### Signals
- `read(data)` — Emitted when data is read. `data: string`.

---

## FileView

Reader for small to medium files.

### Properties
- `path: string` — Path to the file, or empty string to unload.
- `loaded: bool` (readonly) — If a file is currently loaded.
- `adapter: FileViewAdapter` (default) — Adapter to expose file content (e.g. JsonAdapter).
- `preload: bool` — Load file in background immediately when set (default true).
- `atomicWrites: bool` — Perform writes atomically (default true).
- `watchChanges: bool` — Emit fileChanged() when content changes on disk.
- `blockWrites: bool` — If true, setText/setData block UI thread until write succeeds.
- `blockLoading: bool` — If text()/data() should block until file is loaded.
- `blockAllReads: bool` — Block all operations while file loads.
- `printErrors: bool` — Print read/write errors to logs (default true).

### Functions
- `text(): string` — Returns file data as text.
- `data(): ArrayBuffer` — Returns file data as ArrayBuffer.
- `setText(text)` — Set file content as text.
- `setData(data)` — Set file content as ArrayBuffer.
- `reload()` — Unload and reload the file.
- `writeAdapter()` — Write adapter content to file.
- `waitForJob(): bool` — Block until current load completes.

### Signals
- `loaded()` — File loaded successfully.
- `saved()` — File saved successfully.
- `loadFailed(error)` — File failed to load.
- `saveFailed(error)` — File failed to save.
- `fileChanged()` — File changed on disk.
- `adapterUpdated()` — Adapter data changed.

---

## FileViewAdapter (uncreatable)

Base class for FileView adapters.

### Signals
- `adapterUpdated()` — Fired when adapter data changes.

---

## JsonAdapter (extends FileViewAdapter)

Exposes a JSON file as QML properties that can be read and written.

### Supported property types
- Primitives (int, bool, string, real)
- Sub-object adapters (JsonObject)
- JSON objects and arrays, as a var type
- Lists of any of the above (list<string>, etc.)

When properties change from QML, `FileView.adapterUpdated()` is emitted. Use `FileView.writeAdapter()` to save.

### Example
```qml
FileView {
  path: "/path/to/file"
  watchChanges: true
  onFileChanged: reload()
  onAdapterUpdated: writeAdapter()
  JsonAdapter {
    property string myString: "default"
    property list<string> myList: ["a", "b"]
    property JsonObject sub: JsonObject {
      property string key: "value"
    }
    property var inlineJson: { "a": "b" }
  }
}
```

---

## JsonObject

Sub-object adapter for JsonAdapter. Used for nested JSON objects.

---

## FileViewError (enum)
- `Success` — No error occurred.
- `FileNotFound` — File does not exist.
- `NotAFile` — Path exists but is not a file.
- `PermissionDenied` — Permission denied.
- `Unknown` — Unknown error occurred.

---

## Socket (extends DataStream)

Unix socket listener.

### Properties
- `path: string` — Path to connect to when connected is set to true.
- `connected: bool` — If socket is currently connected.

### Functions
- `write(data)` — Write data to socket. Does nothing if not connected.
- `flush()` — Flush queued writes.

### Signals
- `error(error)` — Socket error encountered.

---

## SocketServer (extends Reloadable)

Unix socket server.

### Properties
- `path: string` — Path to create socket server at.
- `active: bool` — If socket server is active. Setting false destroys all connections.
- `handler: Component` — Connection handler component. Must create a Socket.

### Example
```qml
SocketServer {
  active: true
  path: "/path/to/socket.sock"
  handler: Socket {
    onConnectedChanged: console.log(connected ? "connected!" : "dropped!")
    parser: SplitParser {
      onRead: message => console.log(`read: ${message}`)
    }
  }
}
```

---

## IpcHandler

Handler for IPC message calls. Registered into a per-instance map by its unique target. Accessible via `qs ipc`.

### Properties
- `target: string` — The target this handler is accessible from. Required and must be unique.
- `enabled: bool` — If handler should receive calls (default true).

### Handler Functions
Callable via `qs ipc call <target> <func> [args...]` (max 10 args).

**Argument types:** string, int, bool, real, color
**Return types:** void, string, int, bool, real, color

### Signals
Observable via `qs ipc wait` (one call) and `qs ipc listen` (many calls).
