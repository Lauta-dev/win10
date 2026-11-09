package keepass

// Request es un pedido de la UI (una línea JSON por stdin).
type Request struct {
	ID   int            `json:"id"`
	Cmd  string         `json:"cmd"`
	Args map[string]any `json:"args"`
}

// Entry es una entrada de la base con lo justo para listar, copiar y
// precargar el form de edición (UserName y URL no son secretos).
type Entry struct {
	Path     string `json:"path"`
	Title    string `json:"title"`
	Group    string `json:"group"`
	HasTotp  bool   `json:"hasTotp"`
	Username string `json:"username,omitempty"`
	URL      string `json:"url,omitempty"`
}

// Event es todo lo que sale por stdout: respuestas (con ID), acks (con
// ID) y el aviso de auto-bloqueo (sin ID). Password solo viaja en la
// respuesta de genpass (clave a mostrar en el form, equivalente a una
// tipeada); el resto de los secretos van directo a wl-copy.
type Event struct {
	Type string `json:"type"`
	ID   int    `json:"id,omitempty"`

	OK       bool    `json:"ok"`
	Entries  []Entry `json:"entries"`
	Label    string  `json:"label,omitempty"`
	Password string  `json:"password,omitempty"`
	Error    string  `json:"error,omitempty"`
}

func strArg(args map[string]any, key string) string {
	if args == nil {
		return ""
	}
	s, _ := args[key].(string)
	return s
}

func boolArg(args map[string]any, key string) bool {
	if args == nil {
		return false
	}
	b, _ := args[key].(bool)
	return b
}

func intArg(args map[string]any, key string) int {
	if args == nil {
		return 0
	}
	switch n := args[key].(type) {
	case float64:
		return int(n)
	case int:
		return n
	}
	return 0
}
