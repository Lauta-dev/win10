package search

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	defaultMaxResults = 80
	slowAfter         = 300 * time.Millisecond
	defaultRefresh    = time.Hour
)

// Request es un pedido NDJSON: {"id":1,"cmd":"query","args":{"q":"foo"}}.
type Request struct {
	ID   int            `json:"id"`
	Cmd  string         `json:"cmd"`
	Args map[string]any `json:"args"`
}

// Event es una respuesta/aviso NDJSON por stdout.
type Event struct {
	Type  string  `json:"type"`
	ID    int     `json:"id,omitempty"`
	OK    bool    `json:"ok,omitempty"`
	Error string  `json:"error,omitempty"`
	Count int     `json:"count,omitempty"`
	Items []Entry `json:"items,omitempty"`
}

func run(root string, maxEntries, maxResults int, cachePath string, refreshAfter time.Duration) int {
	ix := NewIndex(root, maxEntries, cachePath)

	// Con caché en disco el arranque es instantáneo; sin caché hay que
	// recorrer el home una vez (por eso se hace antes del "ready").
	cached := ix.Load()
	if !cached {
		ix.Refresh()
	}

	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	emit := func(ev Event) { _ = enc.Encode(ev) }

	emit(Event{Type: "ready", OK: true, Count: ix.Len()})

	// Índice viejo: se rehace en segundo plano mientras se responde con el
	// anterior (el swap es atómico).
	if cached && refreshAfter > 0 && ix.Stale(refreshAfter) {
		ix.RefreshAsync()
	}

	sc := bufio.NewScanner(os.Stdin)
	sc.Buffer(make([]byte, 64*1024), 64*1024)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}

		var req Request
		if err := json.Unmarshal([]byte(line), &req); err != nil {
			emit(Event{Type: "error", Error: "json inválido: " + err.Error()})
			continue
		}

		t0 := time.Now()
		switch req.Cmd {
		case "query":
			q, _ := req.Args["q"].(string)
			limit := maxResults
			if v, ok := req.Args["max"].(float64); ok && v > 0 {
				limit = int(v)
			}
			items := ix.Query(q, limit)
			emit(Event{Type: "results", ID: req.ID, OK: true, Count: len(items), Items: items})
		case "refresh":
			// Asíncrono y con piso de 10 min: la UI sigue consultando el
			// índice anterior mientras se rehace en segundo plano.
			if ix.Stale(10 * time.Minute) {
				ix.RefreshAsync()
			}
			emit(Event{Type: "refreshed", ID: req.ID, OK: true, Count: ix.Len()})
		case "status":
			emit(Event{Type: "status", ID: req.ID, OK: true, Count: ix.Len()})
		default:
			emit(Event{Type: "error", ID: req.ID, Error: "cmd desconocido: " + req.Cmd})
		}

		if dt := time.Since(t0); dt > slowAfter {
			fmt.Fprintf(os.Stderr, "search-daemon: %s tardó %.0fms\n", req.Cmd, float64(dt.Milliseconds()))
		}
	}
	return 0
}

// defaultCachePath devuelve $XDG_CACHE_HOME/qs-fileindex.txt.
func defaultCachePath() string {
	dir, err := os.UserCacheDir()
	if err != nil {
		return ""
	}
	return filepath.Join(dir, "qs-fileindex.txt")
}

// Main es el entry del servicio dentro del binario unificado daemons.
func Main(args []string) int {
	if len(args) >= 1 && args[0] == "version" {
		fmt.Println("search-daemon 1.1.0")
		return 0
	}

	rest := args
	if len(rest) > 0 && rest[0] == "run" {
		rest = rest[1:]
	} else if len(rest) > 0 && !strings.HasPrefix(rest[0], "-") {
		fmt.Fprintln(os.Stderr, "uso: daemons search [run] [--root DIR] [--entries N] [--max N] [--cache PATH] [--refresh-after DUR]")
		return 2
	}

	fs := flag.NewFlagSet("run", flag.ContinueOnError)
	root := fs.String("root", "", "directorio a indexar (defecto: $HOME)")
	entries := fs.Int("entries", defaultMaxEntries, "tope de archivos indexados")
	maxResults := fs.Int("max", defaultMaxResults, "máximo de resultados por consulta")
	cache := fs.String("cache", defaultCachePath(), "archivo de índice persistido (vacío = sin caché)")
	refreshAfter := fs.Duration("refresh-after", defaultRefresh, "antigüedad máxima del índice antes de rehacerlo (0 = nunca)")
	if err := fs.Parse(rest); err != nil {
		return 2
	}
	if fs.NArg() > 0 {
		fmt.Fprintln(os.Stderr, "uso: daemons search [run] [--root DIR] [--entries N] [--max N] [--cache PATH] [--refresh-after DUR]")
		return 2
	}

	base := *root
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Fprintln(os.Stderr, "search-daemon:", err)
			return 1
		}
		base = home
	}
	return run(base, *entries, *maxResults, *cache, *refreshAfter)
}
