package mpd

import (
	"strconv"
	"strings"
)

// Request es un pedido de la UI (una línea JSON por stdin).
type Request struct {
	ID   int            `json:"id"`
	Cmd  string         `json:"cmd"`
	Args map[string]any `json:"args"`
}

// Song es un tema con justo los campos que la UI muestra.
type Song struct {
	File     string  `json:"file"`
	Title    string  `json:"title"`
	Artist   string  `json:"artist"`
	Album    string  `json:"album"`
	Duration float64 `json:"duration"`
	Pos      int     `json:"pos"`
	ID       int     `json:"id"`
	Art      string  `json:"art,omitempty"`
}

// Event es todo lo que sale por stdout: respuestas (con ID), acks (con ID)
// y empujones del servidor (sin ID).
//
// OJO: Playlist, Pos y Version van siempre, incluso en 0. La UI distingue
// "ausente" de 0, y omitir el 0 la dejaba con la posición anterior
// (el primer tema de la cola nunca se enfocaba).
type Event struct {
	Type string `json:"type"`
	ID   int    `json:"id,omitempty"`

	Connected bool `json:"connected,omitempty"`

	State   string  `json:"state,omitempty"`
	Playing bool    `json:"playing,omitempty"`
	Volume  int     `json:"volume,omitempty"`
	Repeat  bool    `json:"repeat,omitempty"`
	Random  bool    `json:"random,omitempty"`
	Single  bool    `json:"single,omitempty"`
	Consume bool    `json:"consume,omitempty"`
	Elapsed float64 `json:"elapsed,omitempty"`

	Duration float64 `json:"duration,omitempty"`
	Playlist int     `json:"playlist"`
	Pos      int     `json:"playlistPos"`
	SongID   int     `json:"songId,omitempty"`

	Song *Song `json:"song,omitempty"`

	Queue   []Song `json:"queue"`
	Version int    `json:"version"`

	Names []string `json:"names"`
	Items []Song   `json:"items"`

	Art string `json:"art,omitempty"`

	Added int `json:"added,omitempty"`

	OK    bool     `json:"ok"`
	Lines []string `json:"lines"`
	Error string   `json:"error,omitempty"`
	Ack   string   `json:"ack,omitempty"`
}

func strArg(args map[string]any, key string) string {
	if args == nil {
		return ""
	}
	s, _ := args[key].(string)
	return s
}

func intArg(args map[string]any, key string, def int) int {
	if args == nil {
		return def
	}
	switch v := args[key].(type) {
	case float64:
		return int(v)
	case int:
		return v
	case string:
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
			return n
		}
	}
	return def
}

func boolArg(args map[string]any, key string, def bool) bool {
	if args == nil {
		return def
	}
	if v, ok := args[key].(bool); ok {
		return v
	}
	return def
}
