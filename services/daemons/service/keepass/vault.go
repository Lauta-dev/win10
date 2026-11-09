package keepass

import (
	"fmt"
	"os"
	"sort"
	"strings"

	gokeepasslib "github.com/tobischo/gokeepasslib/v3"
)

// openDB lee y descifra la base con la contraseña. La llama getDB
// cuando el archivo cambió (o al unlock); lo caro es el KDF de la base
// (~2,4 s medidos), por eso el cache evita re-abrir por cada pedido.
// La base queda descifrada en RAM hasta que el proceso muere (lock
// manual o auto-bloqueo por inactividad).
func openDB(dbPath, password string) (*gokeepasslib.Database, error) {
	f, err := os.Open(dbPath)
	if err != nil {
		return nil, fmt.Errorf("no se pudo abrir la base: %v", err)
	}
	defer f.Close()
	db := gokeepasslib.NewDatabase()
	db.Credentials = gokeepasslib.NewPasswordCredentials(password)
	if err := gokeepasslib.NewDecoder(f).Decode(db); err != nil {
		return nil, mapOpenErr(err)
	}
	if err := db.UnlockProtectedEntries(); err != nil {
		return nil, fmt.Errorf("no se pudo descifrar: %v", err)
	}
	return db, nil
}

// getDB devuelve una base lista para usar, con cache: si el archivo no
// cambió desde el último pedido, reusa la descifrada; si cambió
// (Syncthing, edición externa), la re-abre y refresca. El cache viene
// sincronizado por syncCache en unlock y después de cada orden que
// guarda (el rename cambia el mtime; sin eso el próximo getDB
// re-descifraría de más).
func (d *Daemon) getDB() (*gokeepasslib.Database, error) {
	st, err := os.Stat(d.dbPath)
	if err != nil {
		return nil, fmt.Errorf("no se pudo abrir la base: %v", err)
	}
	if d.dbCache != nil && st.ModTime().Equal(d.dbCacheMod) {
		return d.dbCache, nil
	}
	db, err := openDB(d.dbPath, d.password)
	if err != nil {
		return nil, err
	}
	d.dbCache = db
	d.dbCacheMod = st.ModTime()
	return db, nil
}

// syncCache apunta el cache a la base ya descifrada/guardada y toma el
// mtime actual del archivo. Se usa tras el unlock y tras guardar.
func (d *Daemon) syncCache(db *gokeepasslib.Database) {
	if st, err := os.Stat(d.dbPath); err == nil {
		d.dbCache = db
		d.dbCacheMod = st.ModTime()
	}
}

// mapOpenErr traduce un fallo de apertura a mensaje para la UI, sin
// filtrar detalles de criptografía.
func mapOpenErr(err error) error {
	msg := err.Error()
	if strings.Contains(msg, "HMAC") || strings.Contains(msg, "checksum") ||
		strings.Contains(msg, "Wrong password") || strings.Contains(msg, "integrity check") {
		return fmt.Errorf("Contraseña incorrecta")
	}
	return fmt.Errorf("No se pudo abrir la base de datos")
}

// collectEntries recorre los grupos y arma la lista plana con rutas
// estilo "Grupo/Sub/Título" (igual que `ls -R -f` del CLI, para no
// cambiarle el formato a la UI). El grupo raíz no aparece en las rutas.
// Orden alfabético, Recycle Bin último.
func collectEntries(db *gokeepasslib.Database) []Entry {
	out := []Entry{}
	// walkGroup procesa un grupo: sus entradas van con prefix, sus
	// subgrupos cuelgan el nombre.
	var walkGroup func(g *gokeepasslib.Group, prefix string)
	walkGroup = func(g *gokeepasslib.Group, prefix string) {
		for j := range g.Entries {
			e := &g.Entries[j]
			title := e.GetTitle()
			if title == "" {
				title = "(sin título)"
			}
			path := title
			if prefix != "" {
				path = prefix + "/" + title
			}
		out = append(out, Entry{
			Path:     path,
			Title:    title,
			Group:    prefix,
			HasTotp:  e.GetContent("otp") != "",
			Username: e.GetContent("UserName"),
			URL:      e.GetContent("URL"),
		})
		}
		for i := range g.Groups {
			sub := &g.Groups[i]
			subPrefix := sub.Name
			if prefix != "" {
				subPrefix = prefix + "/" + sub.Name
			}
			walkGroup(sub, subPrefix)
		}
	}
	if db.Content != nil && db.Content.Root != nil {
		// El primer nivel es la raíz: sus entradas van sueltas y sus
		// grupos cuelgan directo, sin el nombre de la raíz.
		for i := range db.Content.Root.Groups {
			walkGroup(&db.Content.Root.Groups[i], "")
		}
	}
	sort.Slice(out, func(a, b int) bool {
		aRec := strings.HasPrefix(out[a].Path, "Recycle Bin")
		bRec := strings.HasPrefix(out[b].Path, "Recycle Bin")
		if aRec != bRec {
			return bRec
		}
		return strings.ToLower(out[a].Title) < strings.ToLower(out[b].Title)
	})
	return out
}

// findEntry ubica una entrada por su ruta exacta (la que muestra la UI).
func findEntry(db *gokeepasslib.Database, path string) *gokeepasslib.Entry {
	var found *gokeepasslib.Entry
	var walkGroup func(g *gokeepasslib.Group, prefix string)
	walkGroup = func(g *gokeepasslib.Group, prefix string) {
		for j := range g.Entries {
			if found != nil {
				return
			}
			title := g.Entries[j].GetTitle()
			if title == "" {
				title = "(sin título)"
			}
			p := title
			if prefix != "" {
				p = prefix + "/" + title
			}
			if p == path {
				found = &g.Entries[j]
				return
			}
		}
		for i := range g.Groups {
			if found != nil {
				return
			}
			sub := &g.Groups[i]
			subPrefix := sub.Name
			if prefix != "" {
				subPrefix = prefix + "/" + sub.Name
			}
			walkGroup(sub, subPrefix)
		}
	}
	if db.Content != nil && db.Content.Root != nil {
		for i := range db.Content.Root.Groups {
			if found != nil {
				break
			}
			walkGroup(&db.Content.Root.Groups[i], "")
		}
	}
	return found
}
