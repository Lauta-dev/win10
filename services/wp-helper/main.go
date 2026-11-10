// wp-helper — binario Go para wallpapers: scan + compresión de previews WebP.
// Uso:
//   wp-helper load <dir> -> recorre <dir> (orden alfabético) y emite una línea
//      NDJSON por imagen: {"src": <abs fuente>, "thumb": <abs preview WebP>}.
//      Las previews se guardan en ~/.cache/win10/wp-preview con el hash FNV-1a
//      de la ruta en el nombre, para que imágenes homónimas de carpetas
//      distintas no se pisen.
// Reglas de la compresión:
//   - Preview vigente (mtime >= fuente) -> se emite directo, sin ffmpeg.
//   - Nueva o desactualizada -> se comprime y luego se emite.
//   - Se escribe a un temporario .tmp.webp y se renombra al final: un proceso
//     cortado nunca deja una preview parcial que valide mtime.
//   - Una imagen rota no corta el lote (log a stderr, se omite).
// Compilar: cd services/wp-helper && go build -o ../../bin/wp-helper .
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"hash/fnv"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

// Extensiones de imagen consideradas.
var imageExts = []string{".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"}

func isImageFile(path string) bool {
	lower := strings.ToLower(path)
	for _, ext := range imageExts {
		if strings.HasSuffix(lower, ext) {
			return true
		}
	}
	return false
}

// thumbCacheDir siempre devuelve ~/.cache/win10/wp-preview (ruta fija).
func thumbCacheDir() string {
	home := os.Getenv("HOME")
	if home == "" {
		home = "/root"
	}
	return home + "/.cache/win10/wp-preview"
}

// thumbName define el nombre de preview para una fuente: incorpora el hash
// FNV-1a de la ruta completa para evitar colisiones entre imágenes con el
// mismo nombre en carpetas distintas.
func thumbName(src string) string {
	h := fnv.New32a()
	h.Write([]byte(src))
	return fmt.Sprintf("thumb_%08x_%s.webp", h.Sum32(), filepath.Base(src))
}

// preview es una línea del resultado: imagen fuente + preview comprimida.
type preview struct {
	Src   string `json:"src"`
	Thumb string `json:"thumb"`
}

// thumb convierte una imagen a WebP con ffmpeg (o copia si no hay ffmpeg).
// Escribe a un temporario y renombra al destino.
func thumb(path string, outPath string) error {
	tmpPath := outPath + ".tmp.webp"
	ffpath, err := exec.LookPath("ffmpeg")
	if err != nil {
		// Sin ffmpeg: copiar la imagen tal cual.
		in, err := os.Open(path)
		if err != nil {
			return err
		}
		defer in.Close()
		out, err := os.Create(tmpPath)
		if err != nil {
			return err
		}
		_, err = io.Copy(out, in)
		out.Close()
		if err != nil {
			return err
		}
		return os.Rename(tmpPath, outPath)
	}
	cmd := exec.Command(ffpath,
		"-i", path,
		"-c:v", "libwebp",
		"-q:v", "40",
		tmpPath,
	)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("ffmpeg falló: %v, stderr: %s", err, stderr.String())
	}
	return os.Rename(tmpPath, outPath)
}

// scanDir recorre un directorio y devuelve los archivos de imagen ordenados
// alfabéticamente por nombre (case-insensitive).
func scanDir(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool {
		return strings.ToLower(entries[i].Name()) < strings.ToLower(entries[j].Name())
	})
	var files []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		path := filepath.Join(dir, entry.Name())
		if isImageFile(path) {
			files = append(files, path)
		}
	}
	return files, nil
}

// loadDir recorre <dir> y emite el lote de previews en NDJSON, en orden.
// Va en streaming: cada imagen se emite apenas queda lista.
func loadDir(dir string) error {
	if st, err := os.Stat(dir); err != nil || !st.IsDir() {
		return fmt.Errorf("no es un directorio: %s", dir)
	}
	files, err := scanDir(dir)
	if err != nil {
		return err
	}
	cacheDir := thumbCacheDir()
	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		return err
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	for _, in := range files {
		outPath := filepath.Join(cacheDir, thumbName(in))
		// Short-circuit: preview vigente en disco -> emitir sin convertir.
		if outStat, err1 := os.Stat(outPath); err1 == nil {
			if inStat, err2 := os.Stat(in); err2 == nil && !outStat.ModTime().Before(inStat.ModTime()) {
				enc.Encode(preview{Src: in, Thumb: outPath})
				continue
			}
		}
		if err := thumb(in, outPath); err != nil {
			fmt.Fprintf(os.Stderr, "error con %s: %v\n", in, err)
			continue
		}
		enc.Encode(preview{Src: in, Thumb: outPath})
	}
	return nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "error: falta el comando\n")
		os.Exit(1)
	}
	switch os.Args[1] {
	case "load":
		if len(os.Args) < 3 {
			fmt.Fprintf(os.Stderr, "error: se requiere un directorio para load\n")
			os.Exit(1)
		}
		if err := loadDir(os.Args[2]); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "comando desconocido: %s\n", os.Args[1])
		os.Exit(1)
	}
}
