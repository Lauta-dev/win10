# bright-daemon

Puente entre la interfaz (QML) y el backlight interno.

La UI le manda pedidos en JSON por stdin y él los traduce a
lecturas directas de sysfs + escrituras vía `brightnessctl` (el sysfs
suele ser `root:root 644`, así que la escritura directa falla sin
permiso; `brightnessctl` resuelve los permisos). Además vigila cambios
externos (teclas Fn, `brightnessctl` manual) y los empuja a la UI como
eventos JSON por stdout.

## Protocolo

Es estable: la UI depende de estas formas.

```text
Pedido:   {"id": 7, "cmd": "set", "args": {"value": 80}}
Respuesta: {"type": "bright", "id": 7, "ok": true, "value": 80, "min": 0, "max": 100}
Ack:       {"type": "ack", "id": 7, "ok": true}
Empujón:   {"type": "bright", "value": 80}   (sin id)
Listo:     {"type": "ready", "ok": true, "value": 80}
```

Los empujones (sin id) nacen del watcher por polling cada 500ms sobre
`actual_brightness` (sysfs no emite inotify confiable). La UI los aplica
directo sin pedir nada.

## Comandos

Tipados: `ping`, `get`, `set` (`args.value` 0-100), `inc` / `dec`
(`args.step`, defecto 5).

`set`/`inc`/`dec` confirman con lectura real tras escribir, porque
`brightnessctl` redondea por pasos del hardware.

## Ciclo de vida

Un solo proceso OS que vive lo que el shell: nace
con la barra vía `BrightConnection.ensureStarted()` y no muere hasta que
el shell muera. Si muere inesperado, QML lo reintenta (tope 5).

Sin backlight (desktop sin panel) sale con código 2 para que QML
deshabilite el slider en vez de reintentar en loop.

## Cómo agregar un comando nuevo

1. Sumar un `case` en `daemon.go` (usar `d.bl.set` / `d.current`).
2. Emitir el evento tipado con el ID del pedido y luego el ack.
3. Si necesita argumentos nuevos, leerlos con `strArg` / `intArg`.

## Decisiones que conviene no revertir sin motivo

- La lectura es sysfs directo (sin forks); solo la escritura usa
  `brightnessctl` (sin `sh -c`, argv directo).
- Los pedidos se atienden de a uno en orden (`main.go`).
- El watcher es polling 500ms sin forks: sysfs+inotify no es confiable.
