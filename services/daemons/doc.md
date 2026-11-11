# daemons

Un solo binario Go con los daemons de la shell. Cada servicio mantiene su
protocolo NDJSON por stdin/stdout; solo cambia el arranque.

```sh
daemons <mpd|bright|search> [flags...] | daemons version
# QML: [bin/daemon, "mpd", "run"]
#      [bin/daemon, "bright", "run"]
#      [bin/daemon, "search", "run"]
```

- `service/mpd/` — puente QML ↔ servidor MPD (pedidos JSON → comandos
  MPD; eventos del servidor → empujones JSON). Protocolo en
  `service/mpd/doc.md` (sin cambios).
- `service/bright/` — puente QML ↔ backlight (lectura sysfs +
  escritura vía `brightnessctl`); vigila cambios externos. Protocolo en
  `service/bright/doc.md`.
- `service/search/` — índice en memoria de `$HOME` para el menú de apps
  (`>sf`): se arma en la primera consulta y responde por nombre. Protocolo
  en `service/search/doc.md`.

Sin dependencias externas: solo stdlib.
