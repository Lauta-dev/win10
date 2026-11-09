// Command daemons unifica los daemons Go en un solo binario.
// Cada servicio mantiene su protocolo NDJSON por stdin/stdout; solo
// cambia el arranque: `daemons <servicio> [flags...]`.
//
// Uso: daemons <mpd|keepass|bright|search> [flags...] | daemons version
// QML: [scripts/daemon, "mpd", "run"], [scripts/daemon, "keepass", "--db", path],
//      [scripts/daemon, "bright", "run"], [scripts/daemon, "search", "run"]
package main

import (
	"fmt"
	"os"

	"daemons/service/bright"
	"daemons/service/keepass"
	"daemons/service/mpd"
	"daemons/service/search"
)

func usage() {
	fmt.Fprintln(os.Stderr, "uso: daemons <mpd|keepass|bright|search> [flags...] | daemons version")
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	svc, rest := os.Args[1], os.Args[2:]
	var code int
	switch svc {
	case "mpd":
		code = mpd.Main(rest)
	case "keepass":
		code = keepass.Main(rest)
	case "bright":
		code = bright.Main(rest)
	case "search":
		code = search.Main(rest)
	case "version":
		fmt.Println("daemons 1.0.0")
		return
	default:
		usage()
		code = 2
	}
	os.Exit(code)
}
