# theming

Sistema de temas de la shell en Go: un binario por comando, lógica
compartida en `internal/`. Sin bash, sin python, sin jq/perl.

Viven en `scripts/` ya compilados (igual que `wp-helper`):

| Binario | Hace |
| --- | --- |
| `scripts/gtk-apply` | Tema GTK + iconos: gsettings, `settings.ini` (gtk3/gtk4), `gtkrc-2.0`, `accent-color`, mousepad y el icono de labwc (`rc.xml` `<theme><icon>` + reconfigure) |
| `scripts/shell-theme` | Preset de `data/shell-themes.json` a shell + GTK + labwc + alacritty |
| `scripts/matugen-apply` | Colores desde wallpaper vía `matugen` + post-hooks GTK |

## Contratos CLI (los consume QML)

```text
gtk-apply [--gtk <tema>|auto] [--icons <tema>|auto] --mode <dark|light> [--print]
shell-theme <id> --mode <dark|light> [--print]
matugen-apply <wallpaper> --type <scheme> --mode <dark|light>
```

`--print` muestra sin escribir. Los tres primeros imprimen el marcador
`__GTK_THEME__=<tema>` que la UI parsea de stdout.

## Layout

```text
scripts/theming/
├── cmd/gtk-apply/      # main: flags, orquesta internal/gtk
├── cmd/shell-theme/    # main: preset -> md3 + GTK + labwc + terminal
├── cmd/matugen-apply/  # main: matugen + publicación md3 + hooks
└── internal/
    ├── gtk/            # resolve de variantes, gsettings, ini, gtkrc, accent
    ├── labwc/          # icono de decoraciones en rc.xml + reconfigure
    ├── md3/            # catálogo, build md3 dual, renders alacritty/themerc
    ├── args/           # argv con orden libre (--clave valor, --flag, posicional)
    └── run/            # ejecuta procesos externos
```

## Compilar

```sh
go build -o ../../bin/gtk-apply ./cmd/gtk-apply
go build -o ../../bin/shell-theme ./cmd/shell-theme
go build -o ../../bin/matugen-apply ./cmd/matugen-apply
go test ./...
```
