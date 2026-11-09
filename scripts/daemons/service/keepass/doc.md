# keepass-daemon

Puente entre la interfaz (QML) y una base KeePassXC (`.kdbx`), leída en
forma nativa con `gokeepasslib` (sin `keepassxc-cli`, sin procesos para
el trabajo de la base).

La UI le manda pedidos en JSON por stdin. La contraseña maestra viaja en
el pedido de unlock y queda solo en la RAM de este proceso; al bloquear
(o al auto-bloqueo por 15 min sin pedidos) el proceso termina y la
memoria se libera con él.

La base descifrada vive en cache en el daemon y se invalida por mtime:
si el archivo no cambió, los pedidos no pagan el KDF de descifrado
(~2,4 s); si cambió (Syncthing, edición externa), se re-abre para leer
siempre el archivo actual.

## Ciclo de vida

Al revés que el daemon de MPD (que vive lo que el menú abierto), este
vive desde el unlock hasta el lock: la UI lo levanta al desbloquear y lo
mata al bloquear. Vive varios minutos y varias aperturas del menú.

## Protocolo

```text
Pedido:   {"id": 7, "cmd": "unlock", "args": {"password": "..."}}
Respuesta: {"type": "entries", "id": 7, "ok": true, "entries": [...]}
Ack:       {"type": "ack", "id": 7, "ok": true}
Aviso:     {"type": "locked"}                              (sin id)
```

Comandos: `unlock`, `list`, `copy`, `add`, `edit`, `del`, `genpass`, `totp-new`, `totp-set`, `ping`.

- `unlock {password}`: abre la base y devuelve las entradas (rutas estilo
  `Grupo/Sub/Título`, orden alfabético, Recycle Bin último).
- `list`: re-lista con la contraseña guardada (requiere unlock). Siempre
  refleja el archivo actual: el cache se invalida por mtime, y si el
  archivo cambió se re-descifra el archivo nuevo.
- `copy {path, attr?, totp?}`: lee el campo y lo pasa a `wl-copy` por
  stdin. El secreto **nunca** sale por stdout ni va en argumentos (ni
  QML ni `ps` lo ven). `attr` es `UserName` (reintenta `Username`) o
  `Password`; `totp` copia el código actual calculado acá mismo.
- `add {title, username?, password?, url?}`: crea una entrada en el grupo
  raíz. Vacíos quedan vacíos; si `password` viene vacío genera una
  aleatoria (20 caracteres). Guarda atómico (temporal + rename) y copia
  la contraseña a `wl-copy` (la generada no tiene otra forma de
  conocerse). Responde `added` con la lista refrescada. El título no
  puede estar vacío, contener `/` ni repetirse.
- `edit {path, title, username?, password?, url?, gen?}`: actualiza la
  entrada (vacíos quedan vacíos). `password` vacío sin `gen` mantiene la
  actual; con `gen` o no vacío la cambia (y la copia a `wl-copy`).
  Responde `edited` con la lista refrescada y la ruta nueva en `label`.
- `del {path}`: elimina la entrada y responde `deleted` con la lista
  refrescada.
- `genpass {length?}`: genera una contraseña aleatoria (defecto 20, tope
  128) y la devuelve en `password` para mostrarla en el form. Es la única
  excepción al "nunca por stdout", equivalente a una tipeada: al guardar
  igual va a `wl-copy`.
- `totp-new {path}`: genera un secreto nuevo, lo guarda como URL
  `otpauth://` en el campo `otp` y copia el secreto en crudo a
  `wl-copy` para registrarlo en el servicio. Responde `totp` con la
  lista refrescada.
- `totp-set {path, secret}`: igual pero con un secreto pegado por el
  usuario (se normaliza y valida base32 con round-trip canónico).
- `ping`: no hace nada, solo reinicia el temporizador de auto-lock.

## Decisiones

- Cache de la base descifrada, invalidada por mtime (getDB/syncCache): un
  copy tras otro no repite el KDF de descifrado (~2,4 s). Costo: la base
  queda descifrada en RAM mientras viva el proceso (junto con la
  contraseña maestra); el cache siempre se compara el mtime, así que
  Syncthing se refleja en el pedido siguiente.
- TOTP calculado en casa (stdlib): la `otp` de la entrada trae URL
  `otpauth://` y el código se deriva con HMAC-SHA1/SHA256/SHA512.
- `HasTotp` es real (la entrada trae semilla), no heurística por nombre.
- `wl-copy` por stdin es la única excepción a "sin procesos": Wayland no
  expone otra API para el portapapeles. Nunca recibe secretos por argv.
- Dependencias: solo `gokeepasslib` (+ `x/crypto`, `x/sys` transitivas).

## Cómo agregar un comando

1. Sumar un `case` en `handle` (`daemon.go`).
2. Emitir el evento tipado con el ID del pedido y luego el ack.
