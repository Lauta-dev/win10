# mpd-daemon

Puente entre la interfaz (QML) y el servidor de música MPD.

La UI le manda pedidos en JSON por stdin y él los traduce a comandos de
texto MPD. Además escucha cambios del servidor y los empuja a la UI como
eventos JSON por stdout.

## Protocolo

Es estable: la UI depende de estas formas.

```text
Pedido:   {"id": 7, "cmd": "queue", "args": {...}}
Respuesta: {"type": "queue", "id": 7, "ok": true, "queue": [...], ...}
Ack:       {"type": "ack", "id": 7, "ok": true}
Empujón:   {"type": "song", "song": {...}}        (sin id)
```

Los empujones (sin id) nacen de los avisos del servidor: estado, tema
actual, cola y playlists. La UI los aplica directo sin pedir nada.

## Comandos

Tipados: `ping`, `resync` (alias de `status`), `currentsong`, `queue`,
`playlists`, `search`, `artists`, `albums`, `recent`, `art`, `enter`,
`add`, `addplay`, `playplaylist`, `delplaylist`, `saveplaylist`,
`toggle`, `syncdb`.

`raw` pasa una línea tal cual al servidor y devuelve sus líneas crudas
(transporte, pausa, volumen, etc.).

`syncdb` es el seguro de faltantes: compara el conteo de la base con la
cola y suma la diferencia por nombre exacto (nunca borra, nunca duplica).
Si la cola está vacía y la base llena, la rellena: así se recupera si el
servidor la perdió. Corre cuando la UI lo pide y solo ante cambios en la
base.

`enter` es lo que pide la UI al entrar al modo música: faltantes +
recientes en UN solo `listallinfo` (con `recent:false` solo sincroniza).
El cache de arte (`~/.cache/qs-mpd-art`) se poda a 300 archivos por mtime.

Portadas: el arte del tema en reproducción sigue saliendo por MPRIS
(`MprisState.mpdArtUrl`). Además el daemon extrae el arte incrustado en
los tags (mp3/flac/ogg-opus/m4a) y lo cachea en `~/.cache/qs-mpd-art`:
`recent` trae `art` por ítem y `art` lo resuelve para un archivo
puntual (`""` si no tiene portada). El `music_directory` se descubre de
`mpd.conf` (flag `--music` o `$MPD_MUSIC_DIR` lo fuerzan).

## Cómo agregar un comando nuevo

1. Sumar un `case` en `handle.go` (usar `d.exec` para hablar con MPD).
2. Emitir el evento tipado con el ID del pedido y luego el ack.
3. Si necesita argumentos nuevos, leerlos con `strArg` / `intArg`.

## Decisiones que conviene no revertir sin motivo
- Los pedidos se atienden de a uno en orden (`main.go`). Todos los
  comandos son rápidos en socket local, así el orden se preserva solo.
- La posición 0 de la cola y la versión 0 SÍ se serializan (sin
  `omitempty`): omitirlos dejaba a la UI con datos viejos.
- La escucha de cambios usa una conexión propia, separada de la de
  comandos (`conn.go`).
- La sincronización calcula faltantes y agrega bajo un solo lock
  (`syncMu` en `daemon.go`): el pedido de la UI y el disparo automático
  corren en hilos distintos y así no duplican.
