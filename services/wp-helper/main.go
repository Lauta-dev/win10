// wp-helper — binario Go para escanear wallpapers y generar miniaturas.
// Uso:
//   wp-helper scan <dir>       -> imprime un array JSON de rutas absolutas a imágenes en <dir>.
//   wp-helper thumb <path>     -> escribe una miniatura del wallpaper <path> en stdout (ruta absoluta).
//   wp-helper thumb-batch ...  -> convierte múltiples imágenes a WebP usando un archivo temporal reutilizable.
// Las miniaturas generadas se guardan SIEMPRE en ~/.cache/win10/wp-preview/.
// No se usa XDG_CACHE_HOME ni ningún otro directorio.
// El archivo temporal de lote (/tmp/wp-helper-thumbbatch.txt) permanece en /tmp, sin eliminarse durante la ejecución.
// Compilar: go build -o ../bin/wp-helper .
package main

import (
    "bufio"
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
)

// Extensiones de imagen consideradas.
var imageExts = []string{".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"}

func isImageFile(path string) bool {
    for _, ext := range imageExts {
        if strings.HasSuffix(strings.ToLower(path), ext) {
            return true
        }
    }
    return false
}

// thumbCacheDir siempre devuelve ~/.cache/win10/wp-preview (ruta fija, sin excepciones).
// Esta es la ruta exacta donde se guardan las miniaturas.
func thumbCacheDir() string {
    home := os.Getenv("HOME")
    if home == "" {
        home = "/root"
    }
    // Ruta fija y definitiva: ~/.cache/win10/wp-preview
    return home + "/.cache/win10/wp-preview"
}

// thumb convierte una imagen a WebP usando ffmpeg o copia simple.
func thumb(path string, outPath string) error {
    // Intentar usar ffmpeg para convertir a WebP.
    ffpath, err := exec.LookPath("ffmpeg")
    if err != nil {
        // Sin ffmpeg: simplemente copiar.
        in, err := os.Open(path)
        if err != nil {
            return err
        }
        defer in.Close()
        out, err := os.Create(outPath)
        if err != nil {
            return err
        }
        defer out.Close()
        _, err = io.Copy(out, in)
        return err
    }
    cmd := exec.Command(ffpath,
        "-i", path,
        "-c:v", "libwebp",
        "-q:v", "40",
        outPath,
    )
    var stderr bytes.Buffer
    cmd.Stderr = &stderr
    if err := cmd.Run(); err != nil {
        return fmt.Errorf("ffmpeg falló: %v, stderr: %s", err, stderr.String())
    }
    return nil
}

// scanDir recorre un directorio y devuelve los archivos de imagen.
func scanDir(dir string) ([]string, error) {
    var files []string
    entries, err := os.ReadDir(dir)
    if err != nil {
        return nil, err
    }
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

// thumbBatch convierte múltiples imágenes a WebP usando un archivo temporal reutilizable en el caché.
func thumbBatch(inputs []string) error {
    // Determinar el directorio de caché (siempre ~/.cache/win10/wp-preview).
    cacheDir := thumbCacheDir()
    // Asegurar que el directorio exista.
    if err := os.MkdirAll(cacheDir, 0755); err != nil {
        return err
    }
    // Crear un archivo temporal único para este lote dentro del caché.
    batchFile, err := os.CreateTemp(cacheDir, "batch-*.txt")
    if err != nil {
        return err
    }
    defer batchFile.Close()
    // Escribir cada input en una línea.
    writer := bufio.NewWriter(batchFile)
    for _, in := range inputs {
        if _, err := writer.WriteString(in + "\n"); err != nil {
            return err
        }
    }
    // Flush del writer para asegurar que se escriben los datos.
    if err := writer.Flush(); err != nil {
        return err
    }
    // Mover el puntero al inicio para que ffmpeg lo lea.
    if _, err := batchFile.Seek(0, 0); err != nil {
        return err
    }
    // Ejecutar ffmpeg con el archivo de lista.
    ffpath, err := exec.LookPath("ffmpeg")
    if err != nil {
        // fallback: procesar cada entrada por separado usando el mismo caché.
        for _, in := range inputs {
            if !isImageFile(in) {
                return fmt.Errorf("archivo no es una imagen: %s", in)
            }
            base := filepath.Base(in)
            thumbName := "thumb_" + base
            outPath := filepath.Join(cacheDir, thumbName)
            if err := thumb(in, outPath); err != nil {
                return err
            }
            fmt.Println(outPath)
        }
        return nil
    }
    // Ejecutar ffmpeg -i @<archivo>.
    cmd := exec.Command(ffpath,
        "-i", "@"+batchFile.Name(),
        "-c:v", "libwebp",
        "-q:v", "60",
    )
    var stdout bytes.Buffer
    cmd.Stdout = &stdout
    var stderr bytes.Buffer
    cmd.Stderr = &stderr
    if err := cmd.Run(); err != nil {
        return fmt.Errorf("ffmpeg batch falló: %v, stderr: %s", err, stderr.String())
    }
    // Imprimir cada ruta de salida (la ruta completa en el caché).
    for _, in := range inputs {
        base := filepath.Base(in)
        thumbName := "thumb_" + base
        thumbPath := filepath.Join(cacheDir, thumbName)
        fmt.Println(thumbPath)
    }
    return nil
}

func main() {
    command := os.Args[1]

    switch command {
    case "scan":
        if len(os.Args) < 3 {
            fmt.Fprintf(os.Stderr, "error: se requiere directorio para escanear\n")
            os.Exit(1)
        }
        files, err := scanDir(os.Args[2])
        if err != nil {
            fmt.Fprintf(os.Stderr, "error al escanear: %v\n", err)
            os.Exit(1)
        }
        enc := json.NewEncoder(os.Stdout)
        enc.SetEscapeHTML(false)
        if err := enc.Encode(files); err != nil {
            fmt.Fprintf(os.Stderr, "error al imprimir JSON: %v\n", err)
            os.Exit(1)
        }
    case "thumb":
        if len(os.Args) < 3 {
            fmt.Fprintf(os.Stderr, "error: se requiere path de imagen para thumb\n")
            os.Exit(1)
        }
        imgPath := os.Args[2]
        if !isImageFile(imgPath) {
            fmt.Fprintf(os.Stderr, "error: archivo no es una imagen: %s\n", imgPath)
            os.Exit(1)
        }
        cacheDir := thumbCacheDir()
        if err := os.MkdirAll(cacheDir, 0755); err != nil {
            fmt.Fprintf(os.Stderr, "error al crear directorio de caché: %v\n", err)
            os.Exit(1)
        }
        base := filepath.Base(imgPath)
        thumbName := "thumb_" + base
        outPath := filepath.Join(cacheDir, thumbName)
        if err := thumb(imgPath, outPath); err != nil {
            fmt.Fprintf(os.Stderr, "error al crear miniatura: %v\n", err)
            os.Exit(1)
        }
        fmt.Println(outPath)
    case "thumb-batch":
        // Recopilar todos los paths de entrada (todo lo que sea -- o posición).
        var inputs []string
        for _, arg := range os.Args[2:] {
            if arg == "--" { break }
            inputs = append(inputs, arg)
        }
        if len(inputs) == 0 {
            fmt.Fprintf(os.Stderr, "error: no se proporcionaron entradas\n")
            os.Exit(1)
        }
        if err := thumbBatch(inputs); err != nil {
            fmt.Fprintf(os.Stderr, "error en thumb-batch: %v\n", err)
            os.Exit(1)
        }
    default:
        fmt.Fprintf(os.Stderr, "comando desconocido: %s\n", command)
        os.Exit(1)
    }
}
