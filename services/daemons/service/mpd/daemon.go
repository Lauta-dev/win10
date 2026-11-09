package mpd

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
	"sync"
	"time"
)

// Daemon traduce pedidos JSON a comandos MPD y reenvía los cambios del
// servidor como eventos. Guarda apenas lo necesario: la conexión de
// comandos y si está sonando (para resolver "toggle").
type Daemon struct {
	network, addr string
	musicDir      string // descubierto perezoso si viene vacío
	musicProbed  bool

	mu      sync.Mutex
	cmd     *Conn
	ready   bool
	playing bool
	state   string

	// syncMu serializa las sincronizaciones (pedido de la UI y disparo
	// automático por idle corren en hilos distintos): el cálculo de
	// faltantes y su agregado son una sola sección crítica, así dos
	// corridas no pueden agregar lo mismo dos veces.
	syncMu sync.Mutex

	connEmitted bool
	connState   bool

	outMu sync.Mutex
	enc   *json.Encoder
}

func NewDaemon(network, addr, musicDir string) *Daemon {
	d := &Daemon{network: network, addr: addr, musicDir: musicDir, enc: json.NewEncoder(os.Stdout)}
	d.enc.SetEscapeHTML(false)
	return d
}

// dirMusica devuelve el music_directory, descubriéndolo una sola vez si
// no vino por flag/env (ver art.go).
func (d *Daemon) dirMusica() string {
	d.mu.Lock()
	defer d.mu.Unlock()
	if !d.musicProbed {
		d.musicProbed = true
		if d.musicDir == "" {
			d.musicDir = findMusicDir("")
		}
	}
	return d.musicDir
}

// emit escribe un evento por stdout. Las listas nil salen como [] porque
// la UI usa .length sin chequear null.
func (d *Daemon) emit(ev Event) {
	if ev.Queue == nil {
		ev.Queue = []Song{}
	}
	if ev.Names == nil {
		ev.Names = []string{}
	}
	if ev.Items == nil {
		ev.Items = []Song{}
	}
	if ev.Lines == nil {
		ev.Lines = []string{}
	}
	d.outMu.Lock()
	defer d.outMu.Unlock()
	_ = d.enc.Encode(ev)
}

// setConn avisa si hay servidor solo cuando cambia (evita spam).
func (d *Daemon) setConn(up bool) {
	d.mu.Lock()
	if d.connEmitted && d.connState == up {
		d.mu.Unlock()
		return
	}
	d.connEmitted = true
	d.connState = up
	d.mu.Unlock()
	d.emit(Event{Type: "conn", Connected: up})
}

func (d *Daemon) dialCmd() error {
	m, err := Dial(d.network, d.addr, dialTimeout)
	if err != nil {
		return err
	}
	d.mu.Lock()
	if d.cmd != nil {
		d.cmd.Close()
	}
	d.cmd = m
	d.ready = true
	d.mu.Unlock()
	d.setConn(true)
	return nil
}

func (d *Daemon) ensureCmd() error {
	d.mu.Lock()
	ok := d.ready && d.cmd != nil
	d.mu.Unlock()
	if ok {
		return nil
	}
	return d.dialCmd()
}

func (d *Daemon) dropCmd() {
	d.mu.Lock()
	d.ready = false
	if d.cmd != nil {
		d.cmd.Close()
		d.cmd = nil
	}
	d.mu.Unlock()
}

// exec ejecuta un comando en la conexión compartida. Si se rompió, la
// marca para rediscar y avisa a la UI una sola vez.
func (d *Daemon) exec(cmd string) (lines []string, ack string, err error) {
	if err := d.ensureCmd(); err != nil {
		return nil, "", err
	}
	d.mu.Lock()
	c := d.cmd
	d.mu.Unlock()
	lines, ack, err = c.Exec(cmd, cmdTimeout)
	if err != nil {
		d.dropCmd()
		d.setConn(false)
		return lines, ack, err
	}
	return lines, "", nil
}

// refreshStatus pregunta el estado y lo empuja. La posición arranca en
// -1 (sin tema) para no confundirla con la posición 0.
func (d *Daemon) refreshStatus() {
	lines, _, err := d.exec("status")
	if err != nil {
		return
	}
	m := toMap(lines)
	ev := Event{Type: "status"}
	ev.State = m["state"]
	if ev.State == "" {
		ev.State = "stop"
	}
	ev.Playing = ev.State == "play"
	ev.Volume = parseInt(m["volume"], -1)
	ev.Repeat = m["repeat"] == "1"
	ev.Random = m["random"] == "1"
	ev.Single = m["single"] == "1" || m["single"] == "oneshot"
	ev.Consume = m["consume"] == "1"
	ev.Pos = -1
	if v, ok := m["song"]; ok {
		ev.Pos = parseInt(v, -1)
	}
	if v, ok := m["songid"]; ok {
		ev.SongID = parseInt(v, 0)
	}
	ev.Playlist = parseInt(m["playlist"], 0)
	if v, ok := m["elapsed"]; ok {
		ev.Elapsed = parseFloat(v, 0)
	} else if v, ok := m["time"]; ok {
		if p := strings.SplitN(v, ":", 2); len(p) >= 1 {
			ev.Elapsed = parseFloat(p[0], 0)
		}
	}
	if v, ok := m["duration"]; ok {
		ev.Duration = parseFloat(v, 0)
	} else if v, ok := m["time"]; ok {
		if p := strings.SplitN(v, ":", 2); len(p) == 2 {
			ev.Duration = parseFloat(p[1], 0)
		}
	}
	d.mu.Lock()
	d.playing = ev.Playing
	d.state = ev.State
	d.mu.Unlock()
	d.emit(ev)
	d.setConn(true)
}

func (d *Daemon) refreshSong() {
	lines, _, err := d.exec("currentsong")
	if err != nil {
		return
	}
	songs := parseSongs(lines)
	ev := Event{Type: "song"}
	if len(songs) > 0 {
		s := songs[0]
		ev.Song = &s
	}
	d.emit(ev)
}

// refreshQueue pide la cola completa siempre. En socket local es rápida
// y así no existe lógica de deltas que mantener.
func (d *Daemon) refreshQueue() {
	lines, _, err := d.exec("playlistinfo")
	if err != nil {
		return
	}
	ver := 0
	if sl, _, err := d.exec("status"); err == nil {
		if v, ok := toMap(sl)["playlist"]; ok {
			ver = parseInt(v, 0)
		}
	}
	d.emit(Event{Type: "queue", Queue: parseSongs(lines), Version: ver})
}

func (d *Daemon) refreshPlaylists() {
	lines, _, err := d.exec("listplaylists")
	if err != nil {
		return
	}
	names := []string{}
	for _, l := range lines {
		if k, v, ok := cut(l); ok && k == "playlist" && v != "" {
			names = append(names, v)
		}
	}
	d.emit(Event{Type: "playlists", Names: names})
}

// syncCap limita cuántos temas agrega una corrida. Con una biblioteca
// normal nunca se alcanza; está para que un reescaneo gigante no
// reescriba la cola de golpe. El resto entra en el próximo disparo.
const syncCap = 500

// syncAndRecent combina el seguro de faltantes con los últimos agregados
// en UN solo listallinfo (antes eran dos escaneos: listall + listallinfo).
// Reglas heredadas de syncMissing (no tocar sin motivo):
//   - Solo suma por diferencia exacta de nombres: un archivo no puede
//     entrar dos veces por construcción.
//   - Nunca borra, nunca reordena, nunca toca lo que ya está.
//   - Si la cola está vacía y la base llena, la rellena entera: es la
//     forma de recuperar la cola si el servidor la perdió.
// Si los conteos coinciden y no se piden recientes, no escanea nada.
func (d *Daemon) syncAndRecent(limit int, wantRecent bool) (added int, recent []Song, err error) {
	d.syncMu.Lock()
	defer d.syncMu.Unlock()

	sl, _, err := d.exec("stats")
	if err != nil {
		return 0, nil, err
	}
	total := -1
	for _, l := range sl {
		if k, v, ok := cut(l); ok && k == "songs" {
			total = parseInt(v, -1)
			break
		}
	}
	if total < 0 {
		return 0, nil, fmt.Errorf("stats sin conteo de temas")
	}
	pl, _, err := d.exec("playlistinfo")
	if err != nil {
		return 0, nil, err
	}
	inQueue := map[string]bool{}
	for _, l := range pl {
		if k, v, ok := cut(l); ok && k == "file" && v != "" {
			inQueue[v] = true
		}
	}
	// Paso barato primero: conteos iguales y sin recientes = nada que hacer.
	if total == len(inQueue) && !wantRecent {
		return 0, nil, nil
	}
	al, _, err := d.exec("listallinfo")
	if err != nil {
		return 0, nil, err
	}
	entries := parseLibrary(al)
	var missing []string
	for _, e := range entries {
		if e.file == "" || inQueue[e.file] {
			continue
		}
		inQueue[e.file] = true // por si la base lista un archivo dos veces
		missing = append(missing, e.file)
	}
	if wantRecent {
		recent = topRecent(entries, limit)
		md := d.dirMusica()
		for i := range recent {
			recent[i].Art = resolveArt(md, recent[i].File)
		}
	}
	if len(missing) == 0 {
		return 0, recent, nil
	}
	sortStrings(missing)
	if len(missing) > syncCap {
		missing = missing[:syncCap]
	}
	// Un solo bloque: o entran todos o el servidor corta en el primero
	// que falle, sin dejar la conexión con respuestas a medio leer.
	var sb strings.Builder
	sb.WriteString("command_list_ok_begin\n")
	for _, f := range missing {
		sb.WriteString("add " + Quote(f) + "\n")
	}
	sb.WriteString("command_list_end")
	if _, _, err := d.exec(sb.String()); err != nil {
		return 0, recent, err
	}
	return len(missing), recent, nil
}

// syncMissing agrega a la cola los archivos de la base que no están en
// ella. Devuelve cuántos agregó.
//
// Reglas (no tocar sin motivo):
//   - Solo suma por diferencia exacta de nombres: un archivo no puede
//     entrar dos veces por construcción.
//   - Nunca borra, nunca reordena, nunca toca lo que ya está.
//   - Si la cola está vacía y la base llena, la rellena entera: es la
//     forma de recuperar la cola si el servidor la perdió.
func (d *Daemon) syncMissing() (int, error) {
	d.syncMu.Lock()
	defer d.syncMu.Unlock()

	sl, _, err := d.exec("stats")
	if err != nil {
		return 0, err
	}
	total := -1
	for _, l := range sl {
		if k, v, ok := cut(l); ok && k == "songs" {
			total = parseInt(v, -1)
			break
		}
	}
	if total < 0 {
		return 0, fmt.Errorf("stats sin conteo de temas")
	}
	pl, _, err := d.exec("playlistinfo")
	if err != nil {
		return 0, err
	}
	inQueue := map[string]bool{}
	for _, l := range pl {
		if k, v, ok := cut(l); ok && k == "file" && v != "" {
			inQueue[v] = true
		}
	}
	// Paso barato primero: si los conteos coinciden no hay nada que
	// buscar.
	if total == len(inQueue) {
		return 0, nil
	}
	al, _, err := d.exec("listall")
	if err != nil {
		return 0, err
	}
	var missing []string
	for _, l := range al {
		if k, v, ok := cut(l); ok && k == "file" && v != "" && !inQueue[v] {
			inQueue[v] = true // por si la base lista un archivo dos veces
			missing = append(missing, v)
		}
	}
	if len(missing) == 0 {
		return 0, nil
	}
	sortStrings(missing)
	if len(missing) > syncCap {
		missing = missing[:syncCap]
	}
	// Un solo bloque: o entran todos o el servidor corta en el primero
	// que falle, sin dejar la conexión con respuestas a medio leer.
	var sb strings.Builder
	sb.WriteString("command_list_ok_begin\n")
	for _, f := range missing {
		sb.WriteString("add " + Quote(f) + "\n")
	}
	sb.WriteString("command_list_end")
	if _, _, err := d.exec(sb.String()); err != nil {
		return 0, err
	}
	return len(missing), nil
}

func sortStrings(s []string) {
	sort.Slice(s, func(a, b int) bool {
		return strings.ToLower(s[a]) < strings.ToLower(s[b])
	})
}

// onIdle traduce un aviso del servidor a los refrescos que corresponden.
// Si cambió la base de datos (temas nuevos detectados), además suma los
// faltantes a la cola: es el mismo chequeo que la UI pide al entrar.
func (d *Daemon) onIdle(changed []string) {
	status, song, queue, lists, db := false, false, false, false, false
	for _, c := range changed {
		switch c {
		case "player", "mixer", "options":
			status, song = true, true
		case "playlist":
			status, queue = true, true
		case "stored_playlist":
			lists = true
		case "database", "update":
			lists, db = true, true
		case "output":
			status = true
		}
	}
	if status {
		d.refreshStatus()
	}
	if song {
		d.refreshSong()
	}
	if queue {
		d.refreshQueue()
	}
	if lists {
		d.refreshPlaylists()
	}
	if db {
		if n, err := d.syncMissing(); err != nil {
			fmt.Fprintf(os.Stderr, "mpd: sync automático: %v\n", err)
		} else if n > 0 {
			fmt.Fprintf(os.Stderr, "mpd: sync automático: %d tema(s) nuevo(s)\n", n)
		}
	}
}

// idleLoop escucha cambios en una conexión propia: por cada aviso la
// cierra y abre otra. Si el servidor no está, espera con backoff.
func (d *Daemon) idleLoop() {
	const subs = "player playlist mixer options database stored_playlist update output"
	backoff := 300 * time.Millisecond
	for {
		m, err := Dial(d.network, d.addr, dialTimeout)
		if err != nil {
			fmt.Fprintf(os.Stderr, "mpd: sin servidor (%v), reintento\n", err)
			time.Sleep(backoff)
			backoff *= 2
			if backoff > 5*time.Second {
				backoff = 5 * time.Second
			}
			continue
		}
		backoff = 300 * time.Millisecond
		changed, err := m.WaitChange(subs)
		m.Close()
		if err != nil {
			continue
		}
		d.onIdle(changed)
	}
}

// burst puebla todo al arrancar para que la UI no espere.
func (d *Daemon) burst() {
	if err := d.dialCmd(); err != nil {
		fmt.Fprintf(os.Stderr, "mpd: sin servidor (%v)\n", err)
		d.setConn(false)
		return
	}
	d.refreshStatus()
	d.refreshSong()
	d.refreshQueue()
	d.refreshPlaylists()
}
