// Command matugen-apply genera colores desde el wallpaper con matugen,
// publica el md3 para Quickshell y delega GTK a gtk-apply.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"theming/internal/args"
	"theming/internal/gtk"
	"theming/internal/labwc"
	"theming/internal/md3"
)

func main() {
	parsed := args.Parse(os.Args[1:])
	schemeType := parsed.Opt("type", "scheme-tonal-spot")
	mode := parsed.Opt("mode", gtk.ModeDark)

	home, err := os.UserHomeDir()
	if err != nil {
		fatal(err)
	}
	exe, err := os.Executable()
	if err != nil {
		fatal(err)
	}

	wallpaper := ""
	if len(parsed.Pos) > 0 {
		wallpaper = parsed.Pos[0]
	}
	if wallpaper == "" || !isFile(wallpaper) {
		fmt.Fprintf(os.Stderr, "Error: wallpaper no encontrado: '%s'\n", wallpaper)
		os.Exit(1)
	}
	if _, err := exec.LookPath("matugen"); err != nil {
		fmt.Fprintln(os.Stderr, "Error: matugen no está instalado.")
		os.Exit(1)
	}

	fmt.Printf("▶ Matugen: %s (%s)\n", mode, schemeType)

	matugen := exec.Command("matugen", "image",
		"--source-color-index", "1",
		"--mode", mode,
		"--type", schemeType,
		wallpaper)
	matugen.Stdout = os.Stdout
	matugen.Stderr = os.Stderr
	if err := matugen.Run(); err != nil {
		fmt.Println("⚠ matugen falló")
	}

	// Publicar md3 para Quickshell.
	configDir, _ := os.UserConfigDir()
	win10Dir := filepath.Join(configDir, "win10")	if err := os.MkdirAll(win10Dir, 0755); err != nil {
		fatal(err)
	}
	src := filepath.Join(win10Dir, "theme-md3.json")
	if raw, err := os.ReadFile(src); err == nil {
		if err := md3.AtomicWrite(filepath.Join(win10Dir, "theme-active.json"), raw); err != nil {
			fatal(err)
		}
	}

	// adw-gtk3 publica dos variantes: adw-gtk3 (light) y adw-gtk3-dark.
	// "adw-gtk3-light" NO existe: setearlo deja a GTK sin tema.
	gtkName := gtk.FallbackLight
	if mode == gtk.ModeDark {
		gtkName = gtk.FallbackDark
	}
	fmt.Printf("%s%s\n", gtk.Marker, gtkName)

	gtkBin := filepath.Join(filepath.Dir(exe), "gtk-apply")
	hook := exec.Command(gtkBin, "--gtk", gtkName, "--icons", "auto", "--mode", mode)
	hook.Stdout = os.Stdout
	_ = hook.Run()
	_ = labwc.Reload()

	fmt.Printf("✓ Listo (%s)\n", mode)
}

func isFile(path string) bool {
	st, err := os.Stat(path)
	return err == nil && !st.IsDir()
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
