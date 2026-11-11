// logic/mpd.js - Parseo y filtrado puros de MPD.

function _toMap(lines) {
    var map = {}
    for (var i = 0; i < lines.length; i++) {
        var idx = (lines[i] || "").indexOf(":")
        if (idx < 0) continue
        var k = lines[i].substring(0, idx).trim()
        var v = lines[i].substring(idx + 1).trim()
        if (map[k] === undefined) map[k] = v
    }
    return map
}

function parseStatusLines(lines) {
    var map = _toMap(lines || [])
    var out = {}
    if (map["volume"] !== undefined) out.volume = parseInt(map["volume"])
    else out.volume = undefined
    out.repeat = map["repeat"] === "1"
    out.random = map["random"] === "1"
    out.single = map["single"] === "1" || map["single"] === "oneshot"
    out.consume = map["consume"] === "1"
    if (map["state"] !== undefined) out.state = map["state"]
    else out.state = undefined
    if (map["song"] !== undefined) out.playlistPos = parseInt(map["song"])
    else if (map["state"] === "stop") out.playlistPos = -1
    else out.playlistPos = undefined
    if (map["songid"] !== undefined) out.songId = parseInt(map["songid"])
    else out.songId = undefined
    if (map["playlist"] !== undefined) out.playlistVersion = parseInt(map["playlist"])
    else out.playlistVersion = undefined
    if (map["elapsed"] !== undefined) out.elapsed = parseFloat(map["elapsed"])
    else if (map["time"] !== undefined) {
        var tp = map["time"].split(":")
        if (tp.length >= 1) out.elapsed = parseFloat(tp[0])
    }
    if (map["duration"] !== undefined) out.duration = parseFloat(map["duration"])
    else if (map["time"] !== undefined) {
        var tp2 = map["time"].split(":")
        if (tp2.length === 2) out.duration = parseFloat(tp2[1])
    }
    out.updatingDb = map["updating_db"] !== undefined
    return out
}

function parseCurrentSongLines(lines) {
    if (!lines || lines.length === 0) return null
    var map = _toMap(lines)
    var title = map["Title"] || map["Name"] || ""
    var artist = map["Artist"] || map["AlbumArtist"] || ""
    var album = map["Album"] || ""
    var file = map["file"] || ""
    var dur = map["duration"] ? parseFloat(map["duration"]) : (map["Time"] ? parseInt(map["Time"]) : 0)
    var id = map["Id"] ? parseInt(map["Id"]) : -1
    var pos = map["Pos"] ? parseInt(map["Pos"]) : -1
    return {
        title: title,
        artist: artist,
        album: album,
        file: file,
        duration: dur,
        id: id,
        pos: pos,
        genre: map["Genre"] || "",
        date: map["Date"] || ""
    }
}

function filterPlaylist(playlist, query, playlistPos) {
    var q = (query || "").toLowerCase().trim()
    var result = []
    var pl = playlist || []
    for (var i = 0; i < pl.length; i++) {
        var t = pl[i]
        if (q === "" ||
            (t.title && t.title.toLowerCase().indexOf(q) >= 0) ||
            (t.artist && t.artist.toLowerCase().indexOf(q) >= 0) ||
            (t.file && t.file.toLowerCase().indexOf(q) >= 0)) {
            result.push({
                pos: t.pos,
                title: t.title || "",
                artist: t.artist || "",
                album: t.album || "",
                file: t.file || "",
                duration: t.duration || 0,
                isPlaying: t.pos === playlistPos
            })
            if (result.length >= 300) break
        }
    }
    return result
}

function roundQueueDurations(q) {
    var arr = q || []
    for (var i = 0; i < arr.length; i++) {
        if (arr[i]) arr[i].duration = Math.round(arr[i].duration || 0)
    }
    return arr
}

function transformRecentItems(items) {
    var res = []
    var arr = items || []
    for (var i = 0; i < arr.length; i++) {
        var s = arr[i]
        res.push({
            title: s.title || s.file,
            artist: s.artist || "",
            album: s.album || "",
            file: s.file,
            art: s.art || "",
            duration: Math.round(s.duration || 0)
        })
    }
    return res
}