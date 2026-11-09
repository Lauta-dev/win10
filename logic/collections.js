// logic/collections.js - Filtrado, deduplicacion y ordenamiento.

function dedupeByKey(arr, keyFn) {
    var seen = {}
    var out = []
    for (var i = 0; i < arr.length; i++) {
        var k = keyFn(arr[i])
        if (seen[k]) continue
        seen[k] = true
        out.push(arr[i])
    }
    return out
}

function sortByField(arr, field, locale) {
    var out = arr.slice()
    out.sort(function(a, b) {
        return String(a && a[field] || "").localeCompare(String(b && b[field] || ""))
    })
    return out
}

function filterByFields(arr, predicate) {
    var out = []
    for (var i = 0; i < arr.length; i++) {
        if (predicate(arr[i])) out.push(arr[i])
    }
    return out
}