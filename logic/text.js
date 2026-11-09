// logic/text.js - Funciones puras de texto y matching.

function trimLower(s) {
    return (s || "").trim().toLowerCase()
}

function fuzzyScore(query, target) {
    if (query === "") return 0
    var qi = 0, score = 0, prevMatch = false
    var t = target || ""
    for (var ti = 0; ti < t.length && qi < query.length; ti++) {
        if (t[ti] === query[qi]) {
            score += prevMatch ? 10 : 1
            if (ti === 0) score += 5
            prevMatch = true; qi++
        } else {
            prevMatch = false
        }
    }
    return qi === query.length ? score : 0
}

function subFor(text, searchPrefix) {
    var t = trimLower(text)
    var px = searchPrefix || ""
    if (t.startsWith(px + "playlist")) return "playlist"
    if (t.startsWith(px + "artist"))   return "artist"
    if (t.startsWith(px + "album"))    return "album"
    if (t.startsWith(px + "pldel"))     return "pldel"
    return ""
}

function resolveSub(text, searchPrefix, subModes) {
    var t = trimLower(text)
    var px = searchPrefix || ""
    if (!t.startsWith(px) || t === px) return ""
    var prefix = t.slice(px.length).trim()
    if (prefix === "") return ""
    var modes = subModes || []
    var best = "", bestScore = 0
    for (var i = 0; i < modes.length; i++) {
        var s = fuzzyScore(prefix, modes[i])
        if (s > bestScore) { bestScore = s; best = modes[i] }
    }
    return best
}

function prettyPath(p, homeDir) {
    var h = (homeDir || "") + "/"
    if (h !== "/" && p.indexOf(h) === 0) return "~/" + p.slice(h.length)
    return p
}