// logic/time.js - Formato de tiempo y utilidades numericas.

function fmtTime(secs) {
    var s = Math.max(0, Math.floor(secs || 0))
    var m = Math.floor(s / 60)
    var ss = s % 60
    return m + ":" + (ss < 10 ? "0" : "") + ss
}

function clamp(v, min, max) {
    return Math.max(min, Math.min(max, v))
}