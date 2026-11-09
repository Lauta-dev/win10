package mpd

import (
	"fmt"
	"strings"
)

// Comandos de búsqueda permitidos (evita inyectar sintaxis MPD).
var searchTags = map[string]bool{
	"Artist": true, "Album": true, "Title": true, "File": true,
	"Genre": true, "Date": true, "AlbumArtist": true,
}

// handle atiende un pedido y emite su respuesta tipada más el ack.
// Para agregar un comando: sumar un case que use d.exec y emita el
// evento con el ID del pedido.
func (d *Daemon) handle(req Request) {
	ok := func() {
		d.emit(Event{Type: "ack", ID: req.ID, OK: true})
	}
	fail := func(typ string, err error) {
		d.emit(Event{Type: typ, ID: req.ID, OK: false, Error: err.Error()})
		d.emit(Event{Type: "ack", ID: req.ID, OK: false})
	}

	switch req.Cmd {
	case "ping":
		ok()

	case "raw":
		// Passthrough de texto MPD (una línea o varias).
		line := strArg(req.Args, "line")
		if line == "" {
			fail("raw", fmt.Errorf("line vacía"))
			return
		}
		lines, ack, err := d.exec(line)
		rev := Event{Type: "raw", ID: req.ID, Lines: lines, OK: err == nil}
		if err != nil {
			if strings.HasPrefix(ack, "ACK ") {
				rev.Ack = ack
			} else {
				rev.Error = err.Error()
			}
		}
		d.emit(rev)
		ok()

	case "resync", "status":
		d.refreshStatus()
		d.refreshSong()
		d.refreshQueue()
		d.refreshPlaylists()
		ok()

	case "currentsong":
		d.refreshSong()
		ok()

	case "queue":
		lines, _, err := d.exec("playlistinfo")
		if err != nil {
			fail("queue", err)
			return
		}
		ver := 0
		if sl, _, err := d.exec("status"); err == nil {
			if v, ok := toMap(sl)["playlist"]; ok {
				ver = parseInt(v, 0)
			}
		}
		d.emit(Event{Type: "queue", ID: req.ID, OK: true, Queue: parseSongs(lines), Version: ver})
		ok()

	case "playlists":
		lines, _, err := d.exec("listplaylists")
		if err != nil {
			fail("playlists", err)
			return
		}
		names := []string{}
		for _, l := range lines {
			if k, v, ok := cut(l); ok && k == "playlist" && v != "" {
				names = append(names, v)
			}
		}
		d.emit(Event{Type: "playlists", ID: req.ID, OK: true, Names: names})
		ok()

	case "search":
		tag := strArg(req.Args, "tag")
		q := strArg(req.Args, "value")
		limit := intArg(req.Args, "limit", 200)
		if !searchTags[tag] {
			fail("search", fmt.Errorf("tag inválido: %q", tag))
			return
		}
		if strings.TrimSpace(q) == "" {
			fail("search", fmt.Errorf("búsqueda vacía"))
			return
		}
		lines, _, err := d.exec("search " + tag + " " + Quote(q))
		if err != nil {
			fail("search", err)
			return
		}
		items := parseSongs(lines)
		if limit > 0 && len(items) > limit {
			items = items[:limit]
		}
		d.emit(Event{Type: "search", ID: req.ID, OK: true, Items: items})
		ok()

	case "artists":
		lines, _, err := d.exec("list Artist")
		if err != nil {
			fail("artists", err)
			return
		}
		d.emit(Event{Type: "artists", ID: req.ID, OK: true, Names: prefixed(lines, "Artist:")})
		ok()

	case "albums":
		lines, _, err := d.exec("list Album")
		if err != nil {
			fail("albums", err)
			return
		}
		d.emit(Event{Type: "albums", ID: req.ID, OK: true, Names: prefixed(lines, "Album:")})
		ok()

	case "recent":
		// Lo último sumado a la biblioteca, por Last-Modified
		// descendente. Va por el socket como todo lo demás. Cada
		// ítem trae su portada cacheada ("" si no tiene).
		limit := intArg(req.Args, "limit", 5)
		lines, _, err := d.exec("listallinfo")
		if err != nil {
			fail("recent", err)
			return
		}
		items := parseRecent(lines, limit)
		md := d.dirMusica()
		for i := range items {
			items[i].Art = resolveArt(md, items[i].File)
		}
		d.emit(Event{Type: "recent", ID: req.ID, OK: true, Items: items})
		ok()

	case "enter":
		// Entrada al modo música: faltantes + recientes en UN solo
		// escaneo (reemplaza syncdb+recent secuenciales desde la UI).
		// `recent:false` solo sincroniza sin escanear de más.
		limit := intArg(req.Args, "limit", 5)
		added, items, err := d.syncAndRecent(limit, boolArg(req.Args, "recent", true))
		if err != nil {
			fail("enter", err)
			return
		}
		ev := Event{Type: "enter", ID: req.ID, OK: true, Added: added}
		if items != nil {
			ev.Items = items
		}
		d.emit(ev)
		ok()

	case "art":
		// Portada de un archivo puntual (relativo a music_directory).
		// Responde ok:true con art:"" si no tiene; el arte sale
		// cacheado de ~/.cache/qs-mpd-art.
		f := strArg(req.Args, "file")
		if badFile(f) {
			fail("art", fmt.Errorf("file inválido"))
			return
		}
		d.emit(Event{Type: "art", ID: req.ID, OK: true, Art: resolveArt(d.dirMusica(), f)})
		ok()

	case "add":
		f := strArg(req.Args, "file")
		if badFile(f) {
			fail("add", fmt.Errorf("file inválido"))
			return
		}
		if _, _, err := d.exec("add " + Quote(f)); err != nil {
			fail("add", err)
			return
		}
		d.emit(Event{Type: "add", ID: req.ID, OK: true})
		ok()

	case "addplay":
		// Agrega y reproduce lo agregado (no la posición actual).
		f := strArg(req.Args, "file")
		if badFile(f) {
			fail("addplay", fmt.Errorf("file inválido"))
			return
		}
		lines, _, err := d.exec("addid " + Quote(f))
		if err != nil {
			fail("addplay", err)
			return
		}
		id := -1
		for _, l := range lines {
			if k, v, ok := cut(l); ok && k == "Id" {
				id = parseInt(v, -1)
			}
		}
		if id < 0 {
			fail("addplay", fmt.Errorf("el servidor no devolvió Id"))
			return
		}
		if _, _, err := d.exec(fmt.Sprintf("playid %d", id)); err != nil {
			fail("addplay", err)
			return
		}
		d.emit(Event{Type: "addplay", ID: req.ID, OK: true})
		ok()

	case "playplaylist":
		// Reemplaza la cola por la playlist guardada y reproduce.
		name := strArg(req.Args, "name")
		if name == "" {
			fail("playplaylist", fmt.Errorf("name vacío"))
			return
		}
		if _, _, err := d.exec("clear\nload " + Quote(name) + "\nplay"); err != nil {
			fail("playplaylist", err)
			return
		}
		d.emit(Event{Type: "playplaylist", ID: req.ID, OK: true})
		ok()

	case "delplaylist":
		name := strArg(req.Args, "name")
		if name == "" {
			fail("delplaylist", fmt.Errorf("name vacío"))
			return
		}
		if _, _, err := d.exec("rm " + Quote(name)); err != nil {
			fail("delplaylist", err)
			return
		}
		d.emit(Event{Type: "delplaylist", ID: req.ID, OK: true})
		ok()

	case "saveplaylist":
		name := strArg(req.Args, "name")
		if name == "" {
			fail("saveplaylist", fmt.Errorf("name vacío"))
			return
		}
		// save falla si ya existe: se borra primero sin importar
		// si había algo o no, y después se guarda.
		_, _, _ = d.exec("rm " + Quote(name))
		if _, _, err := d.exec("save " + Quote(name)); err != nil {
			fail("saveplaylist", err)
			return
		}
		d.emit(Event{Type: "saveplaylist", ID: req.ID, OK: true})
		ok()

	case "toggle":
		d.mu.Lock()
		playing, state := d.playing, d.state
		d.mu.Unlock()
		var cmd string
		if playing {
			cmd = "pause 1"
		} else if state == "pause" {
			cmd = "pause 0"
		} else {
			cmd = "play"
		}
		if _, _, err := d.exec(cmd); err != nil {
			fail("toggle", err)
			return
		}
		d.emit(Event{Type: "toggle", ID: req.ID, OK: true})
		ok()

	case "syncdb":
		// Seguro de faltantes: si la base trae más que la cola, suma la
		// diferencia. La UI lo pide al entrar al modo música; el daemon
		// también lo dispara solo ante cambios en la base.
		added, err := d.syncMissing()
		if err != nil {
			fail("syncdb", err)
			return
		}
		d.emit(Event{Type: "syncdb", ID: req.ID, OK: true, Added: added})
		ok()

	default:
		fail(req.Cmd, fmt.Errorf("comando desconocido: %s", req.Cmd))
	}
}

func badFile(f string) bool {
	return f == "" || strings.ContainsAny(f, "\n\r")
}

// prefixed junta los valores de las líneas que empiezan con prefix.
func prefixed(lines []string, prefix string) []string {
	out := []string{}
	for _, l := range lines {
		if strings.HasPrefix(l, prefix) {
			if v := strings.TrimSpace(strings.TrimPrefix(l, prefix)); v != "" {
				out = append(out, v)
			}
		}
	}
	return out
}
