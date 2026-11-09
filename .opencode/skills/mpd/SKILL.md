---
name: mpd
description: Use when working with MPD (Music Player Daemon). Covers installation, configuration, protocol, database, and troubleshooting MPD setups. Control is done via Go daemon.
---

# MPD

## Qué es MPD

**Music Player Daemon (MPD)** es un servidor de música ligero con arquitectura cliente-servidor. Reproduce archivos de audio, organiza playlists y mantiene una base de datos musical, todo con mínimos recursos. Se controla por red mediante el protocolo MPD (puerto 6600 por defecto).

> Nota del proyecto: todo el control de MPD pasa por el daemon Go (`scripts/mpd-daemon`). No usar clientes CLI externos.

## Instalación

```bash
# Arch Linux
sudo pacman -S mpd

# Debian/Ubuntu
sudo apt install mpd
```

## Configuración (mpd.conf)

Ubicación: `~/.config/mpd/mpd.conf` (per-user) o `/etc/mpd.conf` (sistema).

### Opciones esenciales

```conf
# Directorio de música
music_directory    "~/Music"

# Archivos internos
playlist_directory "~/.config/mpd/playlists"
db_file            "~/.config/mpd/database"
state_file         "~/.config/mpd/state"
sticker_file       "~/.config/mpd/sticker.sql"
log_file           "~/.config/mpd/log"
pid_file           "~/.config/mpd/pid"

# Red (escucha en localhost:6600)
bind_to_address    "localhost"
port               "6600"

# Auto-actualizar base de datos al cambiar archivos
auto_update        "yes"
```

### Salidas de audio

```conf
# ALSA (por defecto)
audio_output {
    type    "alsa"
    name    "ALSA"
}

# PulseAudio
audio_output {
    type    "pulse"
    name    "PulseAudio"
}

# PipeWire
audio_output {
    type    "pipewire"
    name    "PipeWire"
}
```

## Iniciar MPD

```bash
# Manual
mpd

# systemd (usuario)
systemctl --user enable --now mpd.service

# Socket activation (inicia bajo demanda)
systemctl --user enable --now mpd.socket
```

## Variables de entorno

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `MPD_HOST` | Servidor MPD | `192.168.1.10` o `/run/user/1000/mpd/socket` |
| `MPD_PORT` | Puerto MPD | `6600` |

## Clientes populares

- **myMPD** - Cliente web moderno y mobile-friendly
- **Ario** - GUI GTK3 rica en funciones
- **ympd** - Web GUI minimalista con WebSockets

## Resolución de problemas

- **No hay audio:** Verificar que la salida de audio está configurada en mpd.conf y que ALSA/PulseAudio/PipeWire funciona (`aplay -l`, `pactl info`, `pw-cli ls Node`)
- **No conecta:** Verificar que MPD está corriendo (`systemctl --user status mpd`) y que el puerto/host coinciden
- **Base de datos vacía:** Actualizar la base de datos y verificar `music_directory` apunta al directorio correcto
- **Permisos:** MPD no debe correr como root; verificar permisos de lectura en `music_directory`
- **Archivos no reconocidos:** Verificar formatos soportados (MP3, FLAC, OGG, Opus, WAV, AAC, etc.)
