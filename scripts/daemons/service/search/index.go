// Package search mantiene un índice en memoria del home del usuario y
// resuelve consultas por nombre para el menú de apps (">sf").
package search

import (
	"bufio"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	// Tope de entradas indexadas: acota memoria (~150 B por entrada) y el
	// tiempo del primer walk en homes gigantes.
	defaultMaxEntries = 120000

	scoreExact   = 100
	scorePrefix  = 80
	scoreName    = 60
	scoreRelPath = 30

	cacheHeader = "#qs-fileindex 1"
)

// Carpetas que nunca aportan al menú y sí cuestan tiempo de recorrido.
var prunedDirs = map[string]bool{
	".git":          true,
	"node_modules":  true,
	".cache":        true,
	"__pycache__":   true,
	".venv":         true,
	"venv":          true,
	"site-packages": true,
	"steamapps":     true,
	".rustup":       true,
	".cargo":        true,
	".gradle":       true,
	".npm":          true,
}

// Subcarpetas de ~/.local/share que solo guardan assets, stores de
// paquetes o instalaciones de juegos: miles de archivos que jamás se
// buscan desde el menú.
var prunedShare = map[string]bool{
	"icons":      true,
	"lutris":     true,
	"pnpm":       true,
	"umu":        true,
	"nvim":       true,
	"bob":        true,
	"Steam":      true,
	"containers": true,
	"flatpak":    true,
	"Trash":      true,
}

// Entry es un archivo indexado.
type Entry struct {
	Path  string `json:"path"`
	Name  string `json:"name"`
	Score int    `json:"score,omitempty"`

	lowerPath string
	lowerName string
}

// Index es el índice de archivos bajo Root.
type Index struct {
	Root       string
	MaxEntries int
	CachePath  string

	mu      sync.RWMutex
	entries []Entry
	built   time.Time

	building atomic.Bool
}

// NewIndex crea un índice vacío. cachePath puede ser "" para no persistir.
func NewIndex(root string, maxEntries int, cachePath string) *Index {
	if maxEntries <= 0 {
		maxEntries = defaultMaxEntries
	}
	return &Index{Root: root, MaxEntries: maxEntries, CachePath: cachePath}
}

// Len devuelve la cantidad de archivos indexados.
func (ix *Index) Len() int {
	ix.mu.RLock()
	defer ix.mu.RUnlock()
	return len(ix.entries)
}

// BuiltAt devuelve cuándo se construyó el índice (cero si nunca).
func (ix *Index) BuiltAt() time.Time {
	ix.mu.RLock()
	defer ix.mu.RUnlock()
	return ix.built
}

// Stale indica si el índice falta o se construyó hace más de max.
func (ix *Index) Stale(max time.Duration) bool {
	at := ix.BuiltAt()
	return at.IsZero() || time.Since(at) > max
}

// skipDir decide si una carpeta se poda (rel es relativo al root).
func skipDir(rel, name string) bool {
	if prunedDirs[name] {
		return true
	}
	rel = filepath.ToSlash(rel)
	if strings.HasPrefix(rel, ".local/share/") {
		sub := strings.SplitN(rel[len(".local/share/"):], "/", 2)[0]
		if prunedShare[sub] {
			return true
		}
	}
	return rel == ".local/share/Trash"
}

func newEntry(path, name string) Entry {
	return Entry{
		Path:      path,
		Name:      name,
		lowerPath: strings.ToLower(filepath.ToSlash(path)),
		lowerName: strings.ToLower(name),
	}
}

// topLevel devuelve los hijos directos del root, con las carpetas visibles
// primero: ahí están los archivos del usuario y no queremos que el tope se
// lo coman ~/.config y compañía.
func (ix *Index) topLevel() []string {
	des, err := os.ReadDir(ix.Root)
	if err != nil {
		return []string{ix.Root}
	}
	visible := make([]string, 0, len(des))
	hidden := make([]string, 0, len(des))
	for _, de := range des {
		path := filepath.Join(ix.Root, de.Name())
		if strings.HasPrefix(de.Name(), ".") {
			hidden = append(hidden, path)
		} else {
			visible = append(visible, path)
		}
	}
	return append(visible, hidden...)
}

// walk recorre el árbol y devuelve las entradas (sin tocar el índice).
// Aplica una cuota por carpeta de primer nivel para que ningún proyecto
// gigante (juegos, builds) deje sin indexar al resto del home.
func (ix *Index) walk() []Entry {
	tops := ix.topLevel()
	quota := ix.MaxEntries / max(len(tops), 1)
	if quota < 20000 {
		quota = 20000
	}

	entries := make([]Entry, 0, 4096)
	for _, top := range tops {
		if len(entries) >= ix.MaxEntries {
			break
		}
		rel, relErr := filepath.Rel(ix.Root, top)
		if relErr != nil {
			rel = filepath.Base(top)
		}
		if skipDir(rel, filepath.Base(top)) {
			continue
		}
		q := quota
		if q > ix.MaxEntries-len(entries) {
			q = ix.MaxEntries - len(entries)
		}
		entries = ix.walkTree(top, q, entries)
	}

	return entries
}

// walkTree agrega hasta quota archivos de top al slice.
func (ix *Index) walkTree(top string, quota int, entries []Entry) []Entry {
	added := 0
	_ = filepath.WalkDir(top, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil // sin permisos: seguir con el resto
		}
		if added >= quota || len(entries) >= ix.MaxEntries {
			return filepath.SkipAll
		}

		rel, relErr := filepath.Rel(ix.Root, path)
		if relErr != nil {
			rel = d.Name()
		}

		if d.IsDir() {
			if path != top && skipDir(rel, d.Name()) {
				return filepath.SkipDir
			}
			return nil
		}

		entries = append(entries, newEntry(path, d.Name()))
		added++
		return nil
	})
	return entries
}

// Refresh recorre el árbol, reemplaza el índice y lo guarda en disco.
// Devuelve cuántos archivos quedaron indexados.
func (ix *Index) Refresh() int {
	entries := ix.walk()

	ix.mu.Lock()
	ix.entries = entries
	ix.built = time.Now()
	ix.mu.Unlock()

	ix.Save()
	return len(entries)
}

// RefreshAsync rehace el índice en segundo plano (una sola vez a la vez).
// Mientras tanto las consultas siguen usando el índice anterior.
func (ix *Index) RefreshAsync() {
	if !ix.building.CompareAndSwap(false, true) {
		return
	}
	go func() {
		defer ix.building.Store(false)
		ix.Refresh()
	}()
}

// Snapshot devuelve una copia de las entradas actuales (para guardar).
func (ix *Index) snapshot() []Entry {
	ix.mu.RLock()
	defer ix.mu.RUnlock()
	return ix.entries
}

// Save persiste el índice en CachePath (escritura atómica).
func (ix *Index) Save() error {
	if ix.CachePath == "" {
		return nil
	}
	entries := ix.snapshot()
	built := ix.BuiltAt()

	if err := os.MkdirAll(filepath.Dir(ix.CachePath), 0o755); err != nil {
		return err
	}
	tmp := ix.CachePath + ".tmp"
	f, err := os.Create(tmp)
	if err != nil {
		return err
	}
	w := bufio.NewWriterSize(f, 256*1024)
	_, _ = w.WriteString(cacheHeader + " " + strconv.FormatInt(built.Unix(), 10) + "\n")
	for i := range entries {
		_, _ = w.WriteString(entries[i].Path)
		_ = w.WriteByte('\n')
	}
	if err := w.Flush(); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, ix.CachePath)
}

// Load lee el índice persistido. Devuelve false si no existe o no sirve.
func (ix *Index) Load() bool {
	if ix.CachePath == "" {
		return false
	}
	f, err := os.Open(ix.CachePath)
	if err != nil {
		return false
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 64*1024), 1024*1024)

	entries := make([]Entry, 0, 8192)
	var built time.Time
	first := true
	for sc.Scan() {
		line := sc.Text()
		if first {
			first = false
			parts := strings.Fields(line)
			if len(parts) != 3 || strings.Join(parts[:2], " ") != cacheHeader {
				return false
			}
			if ts, err := strconv.ParseInt(parts[2], 10, 64); err == nil {
				built = time.Unix(ts, 0)
			} else {
				return false
			}
			continue
		}
		if line == "" || !strings.HasPrefix(line, ix.Root) {
			continue
		}
		entries = append(entries, newEntry(line, filepath.Base(line)))
	}
	if err := sc.Err(); err != nil || len(entries) == 0 {
		return false
	}

	ix.mu.Lock()
	ix.entries = entries
	ix.built = built
	ix.mu.Unlock()
	return true
}

// scoreRanking puntúa una entrada contra la consulta (ya en minúsculas).
func scoreRanking(e *Entry, query string) int {
	switch {
	case e.lowerName == query:
		return scoreExact
	case strings.HasPrefix(e.lowerName, query):
		return scorePrefix
	case strings.Contains(e.lowerName, query):
		return scoreName
	case strings.Contains(e.lowerPath, query):
		return scoreRelPath
	}
	return 0
}

// Query busca archivos cuyo nombre (o ruta) contenga q. Si el índice está
// vacío lo construye en el momento. Devuelve como máximo max resultados.
func (ix *Index) Query(q string, max int) []Entry {
	query := strings.ToLower(strings.TrimSpace(q))
	if query == "" || max <= 0 {
		return nil
	}
	if ix.Len() == 0 {
		ix.Refresh()
	}

	ix.mu.RLock()
	defer ix.mu.RUnlock()

	out := make([]Entry, 0, max)
	for i := range ix.entries {
		if s := scoreRanking(&ix.entries[i], query); s > 0 {
			e := ix.entries[i]
			e.Score = s
			out = append(out, e)
		}
	}

	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Score != out[j].Score {
			return out[i].Score > out[j].Score
		}
		if len(out[i].Path) != len(out[j].Path) {
			return len(out[i].Path) < len(out[j].Path)
		}
		return out[i].Path < out[j].Path
	})

	if len(out) > max {
		out = out[:max]
	}
	return out
}
