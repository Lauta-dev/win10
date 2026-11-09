package bright

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

// Event es todo lo que sale por stdout: respuestas (con ID), acks (con
// ID) y empujones del watcher (sin ID).
type Event struct {
	Type string `json:"type"`
	ID   int    `json:"id,omitempty"`

	OK    bool   `json:"ok"`
	Value int    `json:"value,omitempty"`
	Min   int    `json:"min,omitempty"`
	Max   int    `json:"max,omitempty"`
	Error string `json:"error,omitempty"`
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
