package mpd

import (
	"sort"
	"strconv"
	"strings"
	"time"
)

// parseSongs convierte una respuesta con temas (cola, tema actual,
// resultados de búsqueda) en una lista. Cada línea "file:" abre un
// registro nuevo; el resto completa el registro abierto.
func parseSongs(lines []string) []Song {
	out := []Song{}
	var cur *Song
	flush := func() {
		if cur != nil {
			out = append(out, *cur)
			cur = nil
		}
	}
	for _, l := range lines {
		k, v, ok := cut(l)
		if !ok {
			continue
		}
		switch k {
		case "file":
			flush()
			cur = &Song{File: v, Pos: -1, ID: -1}
		case "Title":
			if cur != nil {
				cur.Title = v
			}
		case "Artist":
			if cur != nil {
				cur.Artist = v
			}
		case "Album":
			if cur != nil {
				cur.Album = v
			}
		case "duration", "Time":
			if cur != nil {
				cur.Duration = parseFloat(v, 0)
			}
		case "Pos":
			if cur != nil {
				cur.Pos = parseInt(v, -1)
			}
		case "Id":
			if cur != nil {
				cur.ID = parseInt(v, -1)
			}
		}
	}
	flush()
	return out
}

// parseMtime entiende Last-Modified de listallinfo: ISO8601 (MPD
// moderno) o segundos unix (formato viejo). Sin fecha válida → 0.
func parseMtime(v string) int64 {
	v = strings.TrimSpace(v)
	if v == "" {
		return 0
	}
	if t, err := time.Parse(time.RFC3339, v); err == nil {
		return t.Unix()
	}
	if n, err := strconv.ParseInt(v, 10, 64); err == nil {
		return n
	}
	return 0
}

// libEntry es un archivo de la base con sus metadatos y mtime.
type libEntry struct {
	file  string
	song  Song
	mtime int64
}

// parseLibrary convierte un listallinfo en entradas (archivo + metadatos
// + Last-Modified). Un solo parseo sirve a faltantes y a recientes.
func parseLibrary(lines []string) []libEntry {
	var out []libEntry
	var cur *libEntry
	flush := func() {
		if cur != nil {
			out = append(out, *cur)
			cur = nil
		}
	}
	for _, l := range lines {
		k, v, ok := cut(l)
		if !ok {
			continue
		}
		switch k {
		case "file":
			flush()
			cur = &libEntry{file: v, song: Song{File: v, Pos: -1, ID: -1}}
		case "Title":
			if cur != nil {
				cur.song.Title = v
			}
		case "Artist":
			if cur != nil {
				cur.song.Artist = v
			}
		case "Album":
			if cur != nil {
				cur.song.Album = v
			}
		case "duration", "Time":
			if cur != nil {
				cur.song.Duration = parseFloat(v, 0)
			}
		case "Last-Modified":
			if cur != nil {
				cur.mtime = parseMtime(v)
			}
		}
	}
	flush()
	return out
}

// topRecent ordena entradas por mtime descendente y devuelve los N temas.
func topRecent(entries []libEntry, limit int) []Song {
	if limit <= 0 {
		limit = 5
	}
	sort.SliceStable(entries, func(a, b int) bool {
		if entries[a].mtime != entries[b].mtime {
			return entries[a].mtime > entries[b].mtime
		}
		return strings.ToLower(entries[a].file) < strings.ToLower(entries[b].file)
	})
	if len(entries) > limit {
		entries = entries[:limit]
	}
	out := make([]Song, 0, len(entries))
	for _, e := range entries {
		out = append(out, e.song)
	}
	return out
}
// parseRecent ordena la base (listallinfo) por Last-Modified descendente
// y devuelve los N temas más nuevos: mtime fresco = archivo recién sumado.
func parseRecent(lines []string, limit int) []Song {
	return topRecent(parseLibrary(lines), limit)
}
// toMap aplana una respuesta "clave: valor" (status, stats) a un mapa.
func toMap(lines []string) map[string]string {
	m := map[string]string{}
	for _, l := range lines {
		if k, v, ok := cut(l); ok {
			m[k] = v
		}
	}
	return m
}

func cut(line string) (key, val string, ok bool) {
	i := strings.Index(line, ":")
	if i < 0 {
		return "", "", false
	}
	return strings.TrimSpace(line[:i]), strings.TrimSpace(line[i+1:]), true
}

func parseInt(s string, def int) int {
	n, err := strconv.Atoi(strings.TrimSpace(s))
	if err != nil {
		return def
	}
	return n
}

func parseFloat(s string, def float64) float64 {
	n, err := strconv.ParseFloat(strings.TrimSpace(s), 64)
	if err != nil {
		return def
	}
	return n
}
