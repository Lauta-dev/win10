// ClipEntry.qml — Parsea una línea de `cliphist list` ("<id>\t<preview>")
// en un objeto visual para el delegate. Se instancia UNA vez (en
// ClipboardState) y se llama por línea al cargar, nunca en el delegate.
//
// Retorna: { id, raw, kind, preview, isFile, isImage, label, sub, icon,
//            iconSize, iconColor } (misma forma que el delegate espera).
//
// Uso:
//   ClipEntry { id: clipEntry }
//   var obj = clipEntry.parse("6582\thttps://github.com/…")
//   if (obj) entries.push(obj)   // null si la línea no parsea
//
// El tipo se detecta por regex sobre el preview: binarios de cliphist
// ("[[ binary data … ]]"), paths locales (/… o file://…) por extensión, y
// el resto texto plano. Imágenes con path local → thumbnail directo
// (isImage + raw con el path); imágenes binarias → thumbnail vía caché
// (ClipProcesses decodifica y completa raw); URLs online → sin thumbnail,
// solo glifo.

import QtQuick
import "../../state"

QtObject {
    id: root

    // ── Metadatos visuales por categoría ─────────────────────────────────────
    readonly property var _meta: ({
        image:    { icon: Icons.clipboardItem, size: 20, color: Style.tertiary },
        pdf:      { icon: Icons.filePdf, size: 23, color: Style.error },
        archive:  { icon: Icons.fileArchive, size: 22, color: Style.secondary },
        video:    { icon: Icons.fileVideo, size: 20, color: Style.primary_container },
        audio:    { icon: Icons.fileAudio, size: 20, color: Style.tertiary_container },
        slides:   { icon: Icons.fileSlides, size: 23, color: Style.secondary_container },
        sheet:    { icon: Icons.fileSheet, size: 23, color: Style.tertiary },
        doc:      { icon: Icons.fileDoc, size: 23, color: Style.primary },
        text:     { icon: Icons.fileText, size: 22, color: Style.on_surface },
        script:   { icon: Icons.fileScript, size: 19, color: Style.tertiary },
        code:     { icon: Icons.fileCode, size: 20, color: Style.tertiary },
        web:      { icon: Icons.fileWeb, size: 19, color: Style.secondary_container },
        data:     { icon: Icons.fileData, size: 22, color: Style.secondary },
        db:       { icon: Icons.displayDual, size: 19, color: Style.primary },
        cert:     { icon: Icons.key, size: 19, color: Style.secondary },
        font:     { icon: Icons.fileFont, size: 20, color: Style.primary_container },
        iso:      { icon: Icons.fileIso, size: 21, color: Style.outline },
        email:    { icon: Icons.email, size: 20, color: Style.primary },
        subtitle: { icon: Icons.fileSubtitle, size: 20, color: Style.on_surface_variant },
        pkg:      { icon: Icons.filePkg, size: 20, color: Style.secondary_container },
        exe:      { icon: Icons.code, size: 20, color: Style.error },
        file:     { icon: Icons.fileOutline, size: 20, color: Style.outline },
    })

    // Extensión → kind (solo para previews con pinta de path).
    function _kindForExt(ext) {
        switch (ext) {
        case "png": case "jpg": case "jpeg": case "gif": case "webp":
        case "svg": case "bmp": case "ico": case "avif": case "heic":
            return "image"
        case "pdf": return "pdf"
        case "zip": case "tar": case "gz": case "tgz": case "rar":
        case "7z": case "xz": case "bz2":
            return "archive"
        case "mp4": case "mkv": case "webm": case "avi": case "mov":
            return "video"
        case "mp3": case "ogg": case "flac": case "wav": case "opus":
        case "m4a":
            return "audio"
        case "ppt": case "pptx": case "odp": return "slides"
        case "xls": case "xlsx": case "csv": case "ods": return "sheet"
        case "doc": case "docx": case "odt": case "rtf": return "doc"
        case "sh": case "py": case "pl": case "rb": return "script"
        case "js": case "ts": case "go": case "rs": case "c": case "h":
        case "cpp": case "java": case "lua": case "qml":
            return "code"
        case "html": case "htm": case "css": return "web"
        case "json": case "xml": case "yaml": case "yml": case "toml":
            return "data"
        case "db": case "sqlite": case "sqlite3": return "db"
        case "pem": case "crt": case "key": case "pub": return "cert"
        case "ttf": case "otf": case "woff": case "woff2": return "font"
        case "iso": case "img": return "iso"
        case "eml": case "mbox": return "email"
        case "srt": case "vtt": case "ass": return "subtitle"
        case "deb": case "rpm": case "pkg": case "apk": return "pkg"
        case "exe": case "msi": case "bin": case "run": case "AppImage":
            return "exe"
        case "txt": case "md": case "log": return "text"
        default: return "file"
        }
    }

    // ── parse(line) → objeto de entrada o null ──────────────────────────
    function parse(line) {
        var s = String(line)
        var tab = s.indexOf("\t")
        if (tab <= 0) return null
        var id = parseInt(s.slice(0, tab), 10)
        if (isNaN(id)) return null
        var preview = s.slice(tab + 1)
        if (preview === "") return null

        var kind = "text"
        var isImage = false
        var raw = preview
        var label = preview.replace(/\n/g, " ")
        var sub = ""

        if (preview.startsWith("[[ binary data")) {
            // Binario de cliphist: sin bytes en QML, solo badge.
            // Formatos: "image/png" o suelto ("[[ binary data 20 KiB png … ]]").
            var mt = preview.match(/([a-z]+\/[a-z0-9\-\+\.]+)/)
            var fmt = preview.split(" ")[5] || ""
            var imgFmt = /^(png|jpe?g|gif|webp|bmp|svg|ico|avif|heic)$/i.test(fmt)
            kind = ((mt && mt[1].startsWith("image/")) || imgFmt) ? "image" : "file"
            isImage = kind === "image"
            raw = ""
            // Las imágenes binarias se materializan a caché (ClipProcesses)
            // para mostrar thumbnail; el delegate usa raw cuando llega.
        } else {
            var path = preview
            if (path.startsWith("file://")) path = path.slice(7)
            // Path local de una línea sin espacios raros → archivo.
            // Solo absolutos (o ~/): URLs online (https://…) quedan texto.
            if ((path.startsWith("/") || path.startsWith("~/")) && !/\s/.test(path)) {
                var parts = path.split("/")
                var name = parts[parts.length - 1] || path
                var dot = name.lastIndexOf(".")
                kind = dot > 0 ? _kindForExt(name.slice(dot + 1).toLowerCase()) : "file"
                label = name
                sub = path
                if (kind === "image") {
                    // Thumbnail local: el delegate carga file:// + raw.
                    // Si el archivo ya no existe, Image falla y muestra "?".
                    isImage = true
                    raw = path.startsWith("~/")
                        ? StandardPaths.writableLocation(StandardPaths.HomeLocation) + path.slice(1)
                        : path
                }
            }
        }

        var m = _meta[kind] || _meta["file"]
        return {
            id:        id,
            raw:       raw,
            kind:      kind,
            preview:   "",
            isFile:    kind !== "text",
            isImage:   isImage,
            label:     label,
            sub:       sub,
            icon:      m.icon,
            iconSize:  m.size,
            iconColor: m.color,
        }
    }
}
