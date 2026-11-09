// Command gtk-apply resuelve y aplica el tema GTK e iconos en labwc:
// gsettings, settings.ini (gtk3/gtk4), gtkrc-2.0, accent-color y mousepad.
package main

import (
	"fmt"
	"os"
	"path/filepath"

	"theming/internal/args"
	"theming/internal/gtk"
	"theming/internal/labwc"
)

func main() {
	parsed := args.Parse(os.Args[1:])
	gtkReq, iconsReq := parsed.Opt("gtk", ""), parsed.Opt("icons", "")
	mode := parsed.Opt("mode", "")
	printOnly := parsed.Flags["print"]

	home, err := os.UserHomeDir()
	if err != nil {
		fatal(err)
	}
	exe, err := os.Executable()
	if err != nil {
		fatal(err)
	}
	dataPath := filepath.Join(filepath.Dir(exe), "..", "data", "gtk-variants.json")
	resolver := gtk.NewResolver(dataPath, home)

	curGtk := gtk.Get(gtk.IfaceSchema, gtk.KeyGtkTheme)
	curIcons := gtk.Get(gtk.IfaceSchema, gtk.KeyIconTheme)
	if gtkReq == "" {
		gtkReq = curGtk
	}
	if iconsReq == "" {
		iconsReq = curIcons
	}
	if mode == "" {
		mode = gtk.ModeLight
		if gtk.Get(gtk.IfaceSchema, gtk.KeyColorTheme) == gtk.SchemeDark {
			mode = gtk.ModeDark
		}
	}

	gtkName := resolver.Resolve("gtk", gtkReq, curGtk, mode)
	iconsName := resolver.Resolve("icons", iconsReq, curIcons, mode)

	if printOnly {
		fmt.Printf("gtk=%s\nicons=%s\nmode=%s\n", gtkName, iconsName, mode)
		return
	}

	if err := gtk.WriteSettingsINI(home, gtkName, iconsName, mode); err != nil {
		fatal(err)
	}
	if err := gtk.Set(gtk.IfaceSchema, gtk.KeyGtkTheme, gtkName); err != nil {
		fatal(err)
	}
	if err := gtk.Set(gtk.IfaceSchema, gtk.KeyIconTheme, iconsName); err != nil {
		fatal(err)
	}
	// Iconos de las decoraciones de labwc (rc.xml <theme><icon>).
	if changed, err := labwc.SetIconTheme(home, iconsName); err != nil {
		fatal(err)
	} else if changed {
		_ = labwc.Reload()
	}
	if err := gtk.ApplyColorScheme(mode); err != nil {
		fatal(err)
	}
	if accent := gtk.AccentForMode(home, mode); accent != "" {
		if err := gtk.Set(gtk.IfaceSchema, gtk.KeyAccent, accent); err != nil {
			fatal(err)
		}
	}
	if err := gtk.ApplyMousepad(mode); err != nil {
		fatal(err)
	}
	if err := gtk.WriteGtkrc(home, gtkName, iconsName); err != nil {
		fatal(err)
	}
	fmt.Printf("%s%s\n", gtk.Marker, gtkName)
}

// fatal informa por stderr y sale 1 (misma disciplina que los scripts).
func fatal(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
