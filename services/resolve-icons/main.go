// resolve-icons — genera { appId: absoluteIconPath } desde el icon theme.
// Uso: resolve-icons [--theme NombreTema]
// Sin --theme usa gsettings (o Papirus como fallback).
// Solo stdlib.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

var (
	reVendorPrefix = regexp.MustCompile(`^(re|io|org|com|net|app|dev)\.`)
	reDoubleSuffix = regexp.MustCompile(`\.\w+\.\w+$`)
	reDashSuffix   = regexp.MustCompile(`(-\d+|-browser|-desktop)$`)
)

func getSystemTheme() string {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "gsettings", "get", "org.gnome.desktop.interface", "icon-theme")
	var buf bytes.Buffer
	cmd.Stdout = &buf
	if err := cmd.Run(); err != nil {
		return "Papirus"
	}
	t := strings.TrimSpace(buf.String())
	t = strings.Trim(t, "'\"")
	if t == "" {
		return "Papirus"
	}
	return t
}

func homeDir() string {
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	return "/root"
}

func main() {
	primary := ""
	args := os.Args[1:]
	for i, a := range args {
		if a == "--theme" && i+1 < len(args) {
			primary = args[i+1]
		}
	}
	if primary == "" {
		primary = getSystemTheme()
	}
	if primary == "" {
		primary = "Papirus"
	}

	iconThemes := []string{}
	seen := map[string]bool{}
	for _, t := range []string{primary, "hicolor", "Adwaita"} {
		if t == "" || seen[t] {
			continue
		}
		seen[t] = true
		iconThemes = append(iconThemes, t)
	}

	home := homeDir()
	iconBases := []string{
		"/usr/share/icons",
		filepath.Join(home, ".local/share/icons"),
		"/usr/local/share/icons",
	}
	sizes := []string{"48x48", "64x64", "32x32", "scalable", "24x24", "22x22", "16x16"}
	cats := []string{"apps", "applications"}
	exs := map[string]bool{".svg": true, ".png": true, ".xpm": true}

	iconIndex := map[string]string{}
	addDir := func(d string) {
		entries, err := os.ReadDir(d)
		if err != nil {
			return
		}
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			name := e.Name()
			ext := strings.ToLower(filepath.Ext(name))
			if !exs[ext] {
				continue
			}
			key := strings.ToLower(strings.TrimSuffix(name, filepath.Ext(name)))
			if _, ok := iconIndex[key]; !ok {
				iconIndex[key] = filepath.Join(d, name)
			}
		}
	}

	// Dos layouts de tema, en este orden de preferencia:
	//   estándar     <tema>/<tamaño>/<categoría>   (Papirus, Adwaita, …)
	//   apps-first   <tema>/<categoría>/<tamaño>   (WhiteSur, Fluent, …)
	// El recorrido es tema→base→layout para que el tema primario gane
	// siempre sobre hicolor/Adwaita, sea cual sea su layout.
	appSizes := []string{"48", "64", "32", "scalable", "24", "22", "16", "symbolic"}
	for _, theme := range iconThemes {
		for _, base := range iconBases {
			for _, size := range sizes {
				for _, cat := range cats {
					addDir(filepath.Join(base, theme, size, cat))
				}
			}
			for _, cat := range cats {
				for _, size := range appSizes {
					addDir(filepath.Join(base, theme, cat, size))
				}
				addDir(filepath.Join(base, theme, cat))
			}
		}
	}
	}

	findIcon := func(name string) string {
	if name == "" {
		return ""
	}
	if strings.HasPrefix(name, "/") {
		if st, err := os.Stat(name); err == nil && !st.IsDir() {
			return name
		}
		return ""
	}
	return iconIndex[strings.ToLower(name)]
	}

	variants := func(appID, iconName string) []string {
		set := map[string]bool{}
		add := func(s string) {
			if s != "" {
				set[s] = true
			}
		}
		add(appID)
		add(strings.ToLower(appID))
		for _, seg := range strings.Split(appID, ".") {
			add(seg)
			add(strings.ToLower(seg))
		}
		clean := strings.ToLower(appID)
		clean = reVendorPrefix.ReplaceAllString(clean, "")
		clean = reDoubleSuffix.ReplaceAllString(clean, "")
		clean = reDashSuffix.ReplaceAllString(clean, "")
		add(clean)
		add(strings.ReplaceAll(clean, ".", "-"))
		add(strings.ReplaceAll(strings.ReplaceAll(clean, "-", ""), "_", ""))
		if iconName != "" {
			add(iconName)
			add(strings.ToLower(iconName))
		}
		out := make([]string, 0, len(set))
		for k := range set {
			out = append(out, k)
		}
		sort.Strings(out)
		return out
	}

	desktopDirs := []string{
		"/usr/share/applications",
		"/usr/local/share/applications",
		filepath.Join(home, ".local/share/applications"),
		"/var/lib/flatpak/exports/share/applications",
		filepath.Join(home, ".local/share/flatpak/exports/share/applications"),
	}

	result := map[string]string{}
	for _, ddir := range desktopDirs {
		st, err := os.Stat(ddir)
		if err != nil || !st.IsDir() {
			continue
		}
		_ = filepath.WalkDir(ddir, func(path string, d os.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return nil
			}
			if !strings.HasSuffix(strings.ToLower(d.Name()), ".desktop") {
				return nil
			}
			appID := strings.TrimSuffix(d.Name(), filepath.Ext(d.Name()))
			iconName := ""
			data, err := os.ReadFile(path)
			if err != nil {
				return nil
			}
			inMain := false
			for _, line := range strings.Split(string(data), "\n") {
				line = strings.TrimSpace(strings.TrimSuffix(line, "\r"))
				if line == "[Desktop Entry]" {
					inMain = true
					continue
				}
				if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
					inMain = false
					continue
				}
					if inMain && strings.HasPrefix(line, "Icon=") {
						iconName = strings.TrimSpace(strings.TrimPrefix(line, "Icon="))
						break
					}
				}
				resolved := findIcon(iconName)
				if resolved == "" {
					resolved = findIcon(appID)
				}
				if resolved == "" {
					return nil
				}
				for _, key := range variants(appID, iconName) {
					if key != "" {
						if _, ok := result[key]; !ok {
							iconIndex[key] = resolved
						}
					}
				}
			}
			return nil
		})
	}
	}

	enc, _ := json.Marshal(result)
	fmt.Println(string(enc))
}