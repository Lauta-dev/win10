// ClipFilter.qml — Filtrado estilo fzf con debounce de 120 ms.
// Recibe entries[] y searchQuery, expone results[].
//
// Uso:
//   ClipFilter {
//       id: filter
//       entries:     root.entries
//       searchQuery: root.searchQuery
//   }
//   // leer: filter.results

import QtQuick

QtObject {
    id: root

    // ── API ──────────────────────────────────────────────────────────────────
    property var    entries:     []   // array de objetos parseados por ClipEntry
    property string searchQuery: ""

    property var results: entries     // salida filtrada y ordenada

    // ── Debounce ─────────────────────────────────────────────────────────────
    property Timer _debounce: Timer {
        interval: 120
        repeat:   false
        onTriggered: root._run()
    }

    onSearchQueryChanged: _debounce.restart()
    onEntriesChanged:     _run()      // recarga sin debounce (ya llegó del proceso)

    // ── Filtrado ─────────────────────────────────────────────────────────────
    function _run() {
        var q = searchQuery.trim()
        if (q === "") {
            if (results !== entries) results = entries
            return
        }

        // Grupos OR separados por "|"
        var orGroups = q.split("|").map(function(g) {
            return g.trim().split(/\s+/).filter(function(t) { return t.length > 0 })
        })

        var out = []
        for (var i = 0; i < entries.length; i++) {
            var e    = entries[i]
            var hay  = e.raw.toLowerCase()
            var best = -1

            for (var g = 0; g < orGroups.length; g++) {
                var gScore = 0, gMatch = true
                for (var k = 0; k < orGroups[g].length; k++) {
                    var r = _matchTerm(orGroups[g][k], hay)
                    if (!r.match) { gMatch = false; break }
                    gScore += r.score
                }
                if (gMatch && gScore > best) best = gScore
            }

            if (best >= 0) out.push({ entry: e, score: best })
        }

        out.sort(function(a, b) { return b.score - a.score })
        var newResults = out.map(function(x) { return x.entry })

        if (newResults.length === root.results.length && newResults.length > 0) {
            var same = true
            for (var n = 0; n < newResults.length; n++) {
                if (newResults[n] !== root.results[n]) { same = false; break }
            }
            if (same) return
        }
        results = newResults
    }

    // ── Matching de un término individual ────────────────────────────────────
    // Soporta: fuzzy, 'exact, ^prefix, suffix$, !negate, ^exact$
    function _matchTerm(term, s) {
        if (term.length === 0) return { match: true, score: 0 }

        var negate = term[0] === "!"
        if (negate) term = term.slice(1)
        if (term.length === 0) return { match: true, score: 0 }

        var isPrefixSuffix = term[0] === "^" && term[term.length - 1] === "$"
        var isExact  = term[0] === "'"
        var isPrefix = !isPrefixSuffix && term[0] === "^"
        var isSuffix = !isPrefixSuffix && term[term.length - 1] === "$"

        if (isPrefixSuffix) term = term.slice(1, -1)
        else if (isExact)   term = term.slice(1)
        else if (isPrefix)  term = term.slice(1)
        else if (isSuffix)  term = term.slice(0, -1)

        var t       = term.toLowerCase()
        var matched = false
        var score   = 0

        if (isExact || isPrefix || isSuffix || isPrefixSuffix) {
            if (isPrefixSuffix) matched = (s === t)
            else if (isPrefix)  matched = s.startsWith(t)
            else if (isSuffix)  matched = s.endsWith(t)
            else                matched = s.includes(t)
            if (matched) score = 100 + t.length * 2
        } else {
            // Fuzzy
            var pi = 0, last = -1
            for (var j = 0; j < s.length && pi < t.length; j++) {
                if (s[j] === t[pi]) {
                    score++
                    if (last === j - 1) score += 2
                    if (j === 0 || "/_ -.".includes(s[j - 1])) score += 3
                    last = j
                    pi++
                }
            }
            matched = pi === t.length
            if (matched && s.includes(t)) score += 100
        }

        if (negate) return { match: !matched, score: matched ? 0 : 1 }
        return { match: matched, score: score }
    }
}
