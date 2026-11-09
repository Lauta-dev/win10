# search (daemon)

Búsqueda de archivos por nombre para el menú de apps de la shell (`>sf`).
Mantiene un índice en memoria de `$HOME` y responde consultas por NDJSON
en stdin/stdout (mismo protocolo que los demás daemons).

## Arranque

```bash
scripts/daemon search run [--root DIR] [--entries N] [--max N] \
                          [--cache PATH] [--refresh-after DUR]
```

QML: `Process { command: [bin/daemon, "search", "run"] }` con
stdinEnabled: true`, arrancado bajo demanda al consultar y apagado
por inactividad.

El primer evento es siempre `{"type":"ready","ok":true,"count":N}`.

## Pedidos

```json
{"id":1,"cmd":"query","args":{"q":"nota","max":40}}
{"id":2,"cmd":"refresh"}
{"id":3,"cmd":"status"}
```

## Respuestas

```json
{"type":"results","id":1,"ok":true,"count":1,"items":[{"path":"/home/u/notas.md","name":"notas.md","score":80}]}
{"type":"refreshed","id":2,"ok":true,"count":87410}
{"type":"status","id":3,"ok":true,"count":87410}
{"type":"error","id":4,"ok":false,"error":"cmd desconocido: foo"}
```

Puntajes: `100` nombre exacto, `80` prefijo, `60` contiene en el nombre,
`30` contiene en la ruta. A igual puntaje gana la ruta más corta.

`refresh` es asíncrono (la UI sigue consultando el índice anterior) y no
hace nada si el índice tiene menos de 10 minutos.

## Índice y caché

- Se construye recorriendo `$HOME` y se guarda en
  `$XDG_CACHE_HOME/qs-fileindex.txt` (12 MB ≈ 87 000 archivos). Al
  arrancar se carga de ahí: `ready` en ~0.3 s en vez de ~4 s.
- Si el archivo tiene más de `--refresh-after` (1 h) se rehace en
  segundo plano; las consultas usan el índice anterior hasta el swap.
- Tope global `--entries` (120 000) **y** cuota por carpeta de primer
  nivel (20 000), para que `~/Games` o un proyecto con `node_modules` no
  dejen sin indexar al resto del home. Las carpetas visibles se recorren
  antes que las ocultas.
- Poda `.git`, `node_modules`, `.cache`, `__pycache__`, `.venv`, `venv`,
  `site-packages`, `steamapps`, `.rustup`, `.cargo`, `.gradle`, `.npm` y,
  dentro de `~/.local/share`: `icons`, `lutris`, `pnpm`, `umu`, `nvim`,
  `bob`, `Steam`, `containers`, `flatpak`, `Trash`.