package mpd

// Arte incrustado para la tira de recientes: extrae la portada del tag
// (mp3/flac/ogg-opus/m4a) y la cachea en ~/.cache/qs-mpd-art.
// Sin dependencias: parsing manual de ID3v2 APIC, FLAC/Vorbis PICTURE y
// MP4 covr. Si no hay arte (o falla algo) devuelve "" y la UI usa el
// glifo; nunca es error fatal.

import (
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// cacheDir devuelve $XDG_CACHE_HOME/win10/mpd-art.
func cacheDir() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return ""
		}
		base = filepath.Join(home, ".cache")
	}
	dir := filepath.Join(base, "win10", "mpd-art")
	_ = os.MkdirAll(dir, 0o755)
	return dir
}

// findMusicDir resuelve el music_directory: flag/env, mpd.conf del
// usuario, /etc/mpd.conf, y ~/Music como último recurso.
func findMusicDir(flagDir string) string {
	if flagDir != "" {
		return flagDir
	}
	if env := os.Getenv("MPD_MUSIC_DIR"); env != "" {
		return env
	}
	home, _ := os.UserHomeDir()
	candidates := []string{}
	if home != "" {
		candidates = append(candidates, filepath.Join(home, ".config", "mpd", "mpd.conf"))
	}
	candidates = append(candidates, "/etc/mpd.conf")
	for _, conf := range candidates {
		if dir := grepMusicDir(conf, home); dir != "" {
			return dir
		}
	}
	if home != "" {
		return filepath.Join(home, "Music")
	}
	return ""
}

// grepMusicDir busca music_directory "..." sin parsear todo el conf.
func grepMusicDir(path, home string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		rest, ok := strings.CutPrefix(line, "music_directory")
		if !ok {
			continue
		}
		rest = strings.TrimSpace(rest)
		rest = strings.Trim(rest, `"`)
		rest = strings.Trim(rest, `'`)
		if rest == "" {
			continue
		}
		if strings.HasPrefix(rest, "~/") && home != "" {
			rest = filepath.Join(home, rest[2:])
		} else if strings.HasPrefix(rest, "$HOME") && home != "" {
			rest = home + rest[len("$HOME"):]
		}
		return rest
	}
	return ""
}

func artExt(mime string, data []byte) string {
	m := strings.ToLower(mime)
	switch {
	case strings.Contains(m, "png") || (len(data) > 3 && data[0] == 0x89 && data[1] == 0x50):
		return ".png"
	default:
		return ".jpg"
	}
}

// --- ID3v2 (mp3): frame APIC (v2.3+) o PIC (v2.2) ---

func id3TagRange(data []byte) []byte {
	if len(data) < 10 || string(data[:3]) != "ID3" {
		return nil
	}
	size := int(data[6]&0x7f)<<21 | int(data[7]&0x7f)<<14 | int(data[8]&0x7f)<<7 | int(data[9]&0x7f)
	if 10+size > len(data) {
		return nil
	}
	tag := data[10 : 10+size]
	// Unsynchronisation global: FF 00 → FF.
	if data[5]&0x80 != 0 {
		out := make([]byte, 0, len(tag))
		for i := 0; i < len(tag); i++ {
			out = append(out, tag[i])
			if tag[i] == 0xFF && i+1 < len(tag) && tag[i+1] == 0x00 {
				i++
			}
		}
		tag = out
	}
	// Extended header: se salta.
	if data[5]&0x40 != 0 && len(tag) >= 4 {
		var ext int
		if data[3] >= 4 {
			ext = int(binary.BigEndian.Uint32(tag[:4]))
		} else {
			ext = int(tag[0]&0x7f)<<21 | int(tag[1]&0x7f)<<14 | int(tag[2]&0x7f)<<7 | int(tag[3]&0x7f)
		}
		if ext+4 <= len(tag) {
			tag = tag[ext+4:]
		}
	}
	return tag
}

func nullTerm(data []byte, enc byte, from int) int {
	if enc == 1 { // UTF-16: terminador doble
		for i := from; i+1 < len(data); i += 2 {
			if data[i] == 0 && data[i+1] == 0 {
				return i + 2
			}
		}
		return len(data)
	}
	for i := from; i < len(data); i++ {
		if data[i] == 0 {
			return i + 1
		}
	}
	return len(data)
}

func apicPayload(payload []byte, v2 bool, major byte) (mime string, pic []byte) {
	if len(payload) < 4 {
		return "", nil
	}
	enc := payload[0]
	p := 1
	if v2 {
		if len(payload) < 4 {
			return "", nil
		}
		mime = string(payload[1:4])
		p = 4
	} else {
		end := nullTerm(payload, 0, 1)
		mime = string(payload[1 : end-1])
		p = end
	}
	if p >= len(payload) {
		return "", nil
	}
	p++ // tipo de imagen
	p = nullTerm(payload, enc, p)
	if p > len(payload) {
		return "", nil
	}
	// v2.4 usa tamaño synchsafe por frame: si el APIC quedó truncado
	// por eso, igual se devuelve lo que haya.
	_ = major
	return mime, payload[p:]
}

func extractMP3(data []byte) (string, []byte) {
	tag := id3TagRange(data)
	if tag == nil {
		return "", nil
	}
	major := byte(3)
	if len(data) >= 4 {
		major = data[3]
	}
	v2 := major == 2
	for len(tag) > 0 {
		var id string
		var size int
		var hdr int
		if v2 {
			if len(tag) < 6 {
				return "", nil
			}
			id = string(tag[:3])
			size = int(tag[3])<<16 | int(tag[4])<<8 | int(tag[5])
			hdr = 6
		} else {
			if len(tag) < 10 {
				return "", nil
			}
			id = string(tag[:4])
			if id[0] == 0 {
				return "", nil // padding
			}
			if major == 4 {
				size = int(tag[4]&0x7f)<<21 | int(tag[5]&0x7f)<<14 | int(tag[6]&0x7f)<<7 | int(tag[7]&0x7f)
			} else {
				size = int(binary.BigEndian.Uint32(tag[4:8]))
			}
			hdr = 10
		}
		if size <= 0 || hdr+size > len(tag) {
			break
		}
		if id == "APIC" || id == "PIC" {
			if mime, pic := apicPayload(tag[hdr:hdr+size], v2, major); len(pic) > 0 {
				return mime, pic
			}
		}
		tag = tag[hdr+size:]
	}
	return "", nil
}

// --- FLAC: bloque PICTURE (tipo 6) ---

func parseFlacPicture(block []byte) (string, []byte) {
	if len(block) < 32 {
		return "", nil
	}
	mimeLen := int(binary.BigEndian.Uint32(block[4:8]))
	p := 8
	if p+mimeLen > len(block) {
		return "", nil
	}
	mime := string(block[p : p+mimeLen])
	p += mimeLen
	if p+4 > len(block) {
		return "", nil
	}
	descLen := int(binary.BigEndian.Uint32(block[p : p+4]))
	p += 4 + descLen + 20 // descripción + w/h/profundidad/colores
	if p+4 > len(block) {
		return "", nil
	}
	dataLen := int(binary.BigEndian.Uint32(block[p : p+4]))
	p += 4
	if p+dataLen > len(block) {
		return "", nil
	}
	return mime, block[p : p+dataLen]
}

func extractFLAC(data []byte) (string, []byte) {
	if len(data) < 4 || string(data[:4]) != "fLaC" {
		return "", nil
	}
	p := 4
	for p+4 <= len(data) {
		last := data[p]&0x80 != 0
		typ := data[p] & 0x7f
		size := int(data[p+1])<<16 | int(data[p+2])<<8 | int(data[p+3])
		p += 4
		if p+size > len(data) {
			return "", nil
		}
		if typ == 6 {
			if mime, pic := parseFlacPicture(data[p : p+size]); len(pic) > 0 {
				return mime, pic
			}
		}
		p += size
		if last {
			break
		}
	}
	return "", nil
}

// --- Ogg Vorbis/Opus: comentario METADATA_BLOCK_PICTURE (base64) ---

func extractOgg(data []byte) (string, []byte) {
	// Se buscan los comentarios en los primeros 64KB: suficiente para
	// el header y evita escanear todo el stream.
	if len(data) > 64*1024 {
		data = data[:64*1024]
	}
	marker := "METADATA_BLOCK_PICTURE="
	idx := strings.Index(string(data), marker)
	if idx < 0 {
		return "", nil
	}
	rest := string(data[idx+len(marker):])
	end := strings.IndexByte(rest, ';')
	if end < 0 {
		end = len(rest)
	}
	raw, err := base64.StdEncoding.DecodeString(strings.TrimSpace(rest[:end]))
	if err != nil || len(raw) < 32 {
		return "", nil
	}
	return parseFlacPicture(raw)
}

// --- MP4/M4A: moov.udta.meta.ilst.covr.data ---

func atoms(data []byte, want string) [][]byte {
	var out [][]byte
	for len(data) >= 8 {
		size := int(binary.BigEndian.Uint32(data[:4]))
		typ := string(data[4:8])
		if size < 8 || size > len(data) {
			// Tamaño extendido (64 bits).
			if size == 1 && len(data) >= 16 {
				size = int(binary.BigEndian.Uint64(data[8:16]))
				if size < 16 || size > len(data) {
					break
				}
				if typ == want {
					out = append(out, data[16:size])
				}
				data = data[size:]
				continue
			}
			break
		}
		if typ == want {
			out = append(out, data[8:size])
		}
		data = data[size:]
	}
	return out
}

func extractMP4(data []byte) (string, []byte) {
	for _, moov := range atoms(data, "moov") {
		for _, udta := range atoms(moov, "udta") {
			for _, meta := range atoms(udta, "meta") {
				if len(meta) < 4 {
					continue
				}
				for _, ilst := range atoms(meta[4:], "ilst") {
					for _, covr := range atoms(ilst, "covr") {
						for _, d := range atoms(covr, "data") {
							if len(d) < 8 {
								continue
							}
							kind := binary.BigEndian.Uint32(d[4:8])
							var mime string
							switch kind {
							case 14:
								mime = "image/png"
							case 27:
								mime = "image/bmp"
							default: // 13 = jpeg y resto
								mime = "image/jpeg"
							}
							if len(d) > 8 {
								return mime, d[8:]
							}
						}
					}
				}
			}
		}
	}
	return "", nil
}

// extractArt lee el archivo y devuelve mime + bytes de la portada.
func extractArt(path string) (string, []byte) {
	// Solo se lee el primer MB: los tags viven al inicio (salvo MP4,
	// que a veces trae moov al final — se lee entero si es chico).
	info, err := os.Stat(path)
	if err != nil {
		return "", nil
	}
	lower := strings.ToLower(path)
	isMP4 := strings.HasSuffix(lower, ".m4a") || strings.HasSuffix(lower, ".mp4") || strings.HasSuffix(lower, ".m4b")
	var data []byte
	if isMP4 && info.Size() <= 32*1024*1024 {
		data, err = os.ReadFile(path)
	} else {
		f, err2 := os.Open(path)
		if err2 != nil {
			return "", nil
		}
		defer f.Close()
		buf := make([]byte, 1024*1024)
		n, _ := f.Read(buf)
		data = buf[:n]
		err = nil
	}
	if err != nil || len(data) < 16 {
		return "", nil
	}
	if isMP4 {
		return extractMP4(data)
	}
	if len(data) >= 4 && string(data[:4]) == "fLaC" {
		return extractFLAC(data)
	}
	if len(data) >= 4 && string(data[:4]) == "OggS" {
		if mime, pic := extractOgg(data); len(pic) > 0 {
			return mime, pic
		}
	}
	if mime, pic := extractMP3(data); len(pic) > 0 {
		return mime, pic
	}
	return "", nil
}

// pruneArtCache borra los más viejos si el cache pasa el tope.
func pruneArtCache(dir string) {
	const maxFiles = 300
	list, err := os.ReadDir(dir)
	if err != nil || len(list) <= maxFiles {
		return
	}
	type sized struct {
		name string
		mtime int64
	}
	var files []sized
	for _, e := range list {
		if e.IsDir() {
			continue
		}
		if info, err := e.Info(); err == nil {
			files = append(files, sized{e.Name(), info.ModTime().Unix()})
		}
	}
	if len(files) <= maxFiles {
		return
	}
	sort.Slice(files, func(a, b int) bool { return files[a].mtime < files[b].mtime })
	for _, f := range files[:len(files)-maxFiles] {
		_ = os.Remove(filepath.Join(dir, f.name))
	}
}
// resolveArt devuelve el path cacheado de la portada de un archivo de la
// biblioteca (relativo a musicDir) o "" si no hay. La clave incluye el
// mtime: si el archivo cambia, se re-extrae.
func resolveArt(musicDir, file string) string {
	if musicDir == "" || file == "" || strings.ContainsAny(file, "\n\r") {
		return ""
	}
	abs := filepath.Join(musicDir, filepath.FromSlash(file))
	info, err := os.Stat(abs)
	if err != nil {
		return ""
	}
	dir := cacheDir()
	if dir == "" {
		return ""
	}
	sum := sha1.Sum([]byte(abs + "|" + fmt.Sprint(info.ModTime().Unix())))
	key := fmt.Sprintf("%x", sum)
	// Cache hit con cualquier extensión conocida.
	for _, ext := range []string{".jpg", ".png"} {
		if p := filepath.Join(dir, key+ext); fileExists(p) {
			return p
		}
	}
	mime, pic := extractArt(abs)
	if len(pic) == 0 {
		return ""
	}
	out := filepath.Join(dir, key+artExt(mime, pic))
	if err := os.WriteFile(out, pic, 0o644); err != nil {
		return ""
	}
	pruneArtCache(dir)
	return out
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}
