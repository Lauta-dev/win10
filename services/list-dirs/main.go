// list-dirs — Lista subdirectorios (y archivos en modos files/images) como JSON.
// Uso: list-dirs <path> [--mode directories|files|images] [--show-hidden]
// Salida: {"path": realpath, "entries":[{name,path,isParent[,isMd|isImage]}]}
// files:  dirs + texto (sniff 512B sin NUL; isMd=true = "abrible").
// images: dirs + imágenes por extensión (isImage=true = elegible).
// Backend de components/DirBrowser.qml. Solo stdlib.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type entry struct {
	Name     string `json:"name"`
	Path     string `json:"path"`
	IsParent bool   `json:"isParent"`
	IsMd     *bool  `json:"isMd,omitempty"`
	IsImage  *bool  `json:"isImage,omitempty"`
}

var imageExts = map[string]bool{
	".png": true, ".jpg": true, ".jpeg": true, ".webp": true,
	".bmp": true, ".gif": true, ".avif": true, ".jxl": true,
	".tif": true, ".tiff": true,
}

func isImageFile(name string) bool {
	return imageExts[strings.ToLower(filepath.Ext(name))]
}

func expandUser(p string) string {
	if p == "~" || strings.HasPrefix(p, "~/") {
		home := os.Getenv("HOME")
		if home == "" {
			home = "/root"
		}
		if p == "~" {
			return home
		}
		return filepath.Join(home, strings.TrimPrefix(p, "~/"))
	}
	return os.ExpandEnv(p)
}

func boolPtr(b bool) *bool { return &b }

// isTextFile: lee 512B; sin byte NUL → texto (vacío = texto).
// Es el test "de texto" del modo files (rc.xml, .conf, scripts, etc).
func isTextFile(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	buf := make([]byte, 512)
	n, _ := f.Read(buf)
	if n == 0 {
		return true
	}
	return bytes.IndexByte(buf[:n], 0) == -1
}

func main() {
	args := os.Args[1:]
	path := ""
	mode := "directories"
	showHidden := false
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch a {
		case "--mode":
			if i+1 < len(args) {
				i++
				mode = args[i]
			}
		case "--show-hidden", "--showHidden", "-a":
			showHidden = true
		case "--hide-hidden":
			showHidden = false
			default:
				if strings.HasPrefix(a, "--mode=") {
					mode = strings.TrimPrefix(a, "--mode=")
				} else if path == "" && !strings.HasPrefix(a, "-") {
					path = a
				}
		}
	}
	if path == "" {
		path = "~"
	}
	if mode != "files" && mode != "images" {
		mode = "directories"
	}

	expanded := expandUser(path)
	realp, err := filepath.EvalSymlinks(expanded)
	if err != nil {
		realp = filepath.Clean(expanded)
	}
	// Si la ruta con ~ no existe tal cual, realpath ya la resolvió.
	st, err := os.Stat(realp)
	if err != nil || !st.IsDir() {
		out, _ := json.Marshal(map[string]any{"path": realp, "entries": []entry{}})
		fmt.Println(string(out))
		return
	}
	// Normalizar path sin trailing slash (excepto raíz)
	if len(realp) > 1 {
		realp = strings.TrimSuffix(realp, "/")
	}

	entries := []entry{}
	if realp != "/" {
		parent := filepath.Dir(realp)
		if mode == "directories" {
			entries = append(entries, entry{Name: "..", Path: parent, IsParent: true})
		} else {
			entries = append(entries, entry{Name: "..", Path: parent, IsParent: true, IsMd: boolPtr(false)})
		}
	}

	dirents, err := os.ReadDir(realp)
	if err != nil {
		out, _ := json.Marshal(map[string]any{"path": realp, "entries": entries})
		fmt.Println(string(out))
		return
	}

	type item struct {
		name  string
		path  string
		isDir bool
	}
	items := []item{}
	for _, d := range dirents {
		name := d.Name()
		if !showHidden && strings.HasPrefix(name, ".") {
			continue
		}
		full := filepath.Join(realp, name)
		// follow symlinks como Python (follow_symlinks=True)
		isDir := false
		if st, err := os.Stat(full); err == nil {
			isDir = st.IsDir()
		} else {
			isDir = d.IsDir()
		}
		items = append(items, item{name: name, path: full, isDir: isDir})
	}

	if mode == "directories" {
		sort.Slice(items, func(a, b int) bool {
			return strings.ToLower(items[a].name) < strings.ToLower(items[b].name)
		})
		for _, it := range items {
			if it.isDir {
				entries = append(entries, entry{Name: it.name, Path: it.path, IsParent: false})
			}
		}
	} else {
		sort.Slice(items, func(a, b int) bool {
			if items[a].isDir != items[b].isDir {
				return items[a].isDir && !items[b].isDir
			}
			return strings.ToLower(items[a].name) < strings.ToLower(items[b].name)
		})
		for _, it := range items {
			if it.isDir {
				entries = append(entries, entry{Name: it.name, Path: it.path, IsParent: false, IsMd: boolPtr(false)})
			} else if mode == "images" {
				if isImageFile(it.name) {
					entries = append(entries, entry{Name: it.name, Path: it.path, IsParent: false, IsImage: boolPtr(true)})
				}
			} else if isTextFile(it.path) {
				entries = append(entries, entry{Name: it.name, Path: it.path, IsParent: false, IsMd: boolPtr(true)})
			}
		}
	}
	}

	out, _ := json.Marshal(map[string]any{"path": realp, "entries": entries})
	fmt.Println(string(out))
}