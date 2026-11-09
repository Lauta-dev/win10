// logic/startmenu.js - Funciones puras del launcher.

function parseAI(arg, providers) {
    var s = (arg || "").trim()
    var sp = s.indexOf(" ")
    var head = (sp >= 0 ? s.slice(0, sp) : s).toLowerCase()
    var rest = sp >= 0 ? s.slice(sp + 1).trim() : ""
    var provs = providers || {}
    if (provs[head]) return { key: head, prompt: rest }
    return { key: "gpt", prompt: s }
}

function commandUrl(item, providers) {
    var arg = ((item && item.arg) || "").trim()
    if (!item) return ""
    if (item.cmd === "b") {
        return arg === "" ? "" : "https://duckduckgo.com/?q=" + encodeURIComponent(arg)
    }
    if (item.cmd === "ia") {
        var ai = parseAI(arg, providers)
        var p = (providers && providers[ai.key]) || {}
        return (p.url || "") + encodeURIComponent(ai.prompt)
    }
    return ""
}

function prettyPath(p, homeDir) {
    var h = (homeDir || "") + "/"
    if (h !== "/" && (p || "").indexOf(h) === 0) return "~/" + p.slice(h.length)
    return p
}

function fileIconFor(path, Icons) {
    var ext = (String(path || "").split("/").pop().split(".").pop() || "").toLowerCase()
    var code = ["js","ts","tsx","jsx","mjs","cjs","go","rs","py","sh","bash","c","h",
                "cpp","hpp","java","kt","lua","qml","css","scss","html","xml","json",
                "yaml","yml","toml","ini","conf","nix","rb","php","sql"]
    var I = Icons || {}
    if (code.indexOf(ext) >= 0) return (ext === "html" || ext === "css") ? I.fileWeb : I.fileCode
    if (ext === "md" || ext === "txt" || ext === "log") return I.fileText
    if (ext === "pdf") return I.filePdf
    if (["png","jpg","jpeg","webp","gif","svg","avif","bmp"].indexOf(ext) >= 0) return I.image
    if (["mp4","mkv","webm","mov","avi"].indexOf(ext) >= 0) return I.fileVideo
    if (["mp3","flac","ogg","opus","wav","m4a"].indexOf(ext) >= 0) return I.fileAudio
    if (["zip","tar","gz","xz","zst","7z","rar"].indexOf(ext) >= 0) return I.fileArchive
    if (["ods","xlsx","csv"].indexOf(ext) >= 0) return I.fileSheet
    if (["odp","pptx"].indexOf(ext) >= 0) return I.fileSlides
    if (["odt","docx"].indexOf(ext) >= 0) return I.fileDoc
    return I.file
}

function filterAppsByText(apps, lower) {
    var q = (lower || "").toLowerCase()
    var out = []
    var list = apps || []
    for (var i = 0; i < list.length; i++) {
        var a = list[i]
        if (!a || a.noDisplay) continue
        if (q === "" ||
            (a.name || "").toLowerCase().indexOf(q) >= 0 ||
            (a.comment || "").toLowerCase().indexOf(q) >= 0) {
            out.push(a)
        }
    }
    return out
}

function filterAppsRecentFirst(apps, recentApps, textPredicate, enrichApp) {
    var list = apps || []
    var ra = recentApps || []
    var recentSet = {}
    for (var i = 0; i < ra.length; i++) recentSet[ra[i].exec] = true

    var execIndex = {}
    for (var i = 0; i < list.length; i++) {
        var a = list[i]
        if (a && a.execString) execIndex[a.execString] = a
    }

    var matched = []
    var rest = []
    var matchedExecs = {}

    var pred = textPredicate || function() { return true }
    var enrich = enrichApp || function(x) { return x }

    for (var ri = 0; ri < ra.length; ri++) {
        var exec = ra[ri].exec
        var a = execIndex[exec]
        if (!a || a.noDisplay) continue
        if (matchedExecs[exec]) continue
        if (!pred(a)) continue
        matchedExecs[exec] = true
        matched.push(enrich(a))
    }
    for (var r2 = 0; r2 < list.length; r2++) {
        var a2 = list[r2]
        if (!a2 || a2.noDisplay) continue
        var e2 = a2.execString || ""
        if (matchedExecs[e2] || recentSet[e2]) continue
        if (!pred(a2)) continue
        rest.push(enrich(a2))
    }
    rest.sort(function(a, b) { return (a.name || "").localeCompare(b.name || "") })
    return matched.concat(rest)
}