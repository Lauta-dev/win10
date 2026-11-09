# qsipc

Llama a un `IpcHandler` de la shell sin spawnear `qs`: habla el protocolo
IPC de quickshell directo sobre el unix socket de la instancia. Evita el
bootstrap Qt (~40ms) que paga `qs -p … ipc call` en cada keypress.

```sh
qsipc [--config DIR] [--pid PID] [--socket PATH] [--no-fallback] <target> <function> [args...]
# ej: qsipc command-palette toggle
```

Descubre el socket en `$XDG_RUNTIME_DIR/quickshell/by-pid/<pid>/ipc.sock`
(una sola instancia viva → directo; varias → la que corra `--config`,
default `~/.config/labwc/b`). Si el socket falla, cae a
`qs -p <config> ipc call …` salvo `--no-fallback`.

Protocolo espejado de `quickshell/src/io/ipccomm.cpp`: mantener en sync
con `qs --version`. Sin dependencias: solo stdlib.
