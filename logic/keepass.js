// logic/keepass.js - Filtrado puro de KeePass.

function filterEntryList(entries, query) {
    var q = (query || "").toLowerCase().trim()
    if (q === "") return (entries || []).slice()
    var res = []
    var list = entries || []
    for (var i = 0; i < list.length; i++) {
        var e = list[i]
        var path = (e.path || "").toLowerCase()
        var title = (e.title || "").toLowerCase()
        if (path.indexOf(q) >= 0 || title.indexOf(q) >= 0) res.push(e)
    }
    return res
}

function filterActions(actions, query) {
    var dq = (query || "").toLowerCase().trim()
    var base = (actions || []).slice()
    if (dq === "") return base
    var fres = []
    for (var k = 0; k < base.length; k++) {
        if ((base[k].label || "").toLowerCase().indexOf(dq) >= 0 || String(base[k].id || "").indexOf(dq) >= 0)
            fres.push(base[k])
    }
    return fres
}

function buildDetailActions(entry, kindUser, kindPassword, kindTotp, actTotpNew, actTotpPaste, Icons) {
    var I = Icons || {}
    var acts = [
        { id: kindUser, label: "Copiar usuario", description: "UserName → portapapeles", icon: I.account },
        { id: kindPassword, label: "Copiar contraseña", description: "Password → portapapeles (10s)", icon: I.key }
    ]
    if (entry && entry.hasTotp) {
        acts.push({ id: kindTotp, label: "Copiar TOTP", description: "Código TOTP", icon: I.timer })
        acts.push({ id: actTotpNew, label: "Regenerar TOTP", description: "Nuevo secreto (invalida el anterior)", icon: I.refresh })
    } else {
        acts.push({ id: actTotpNew, label: "Generar TOTP", description: "Nuevo secreto → portapapeles", icon: I.timer })
    }
    acts.push({ id: actTotpPaste, label: "Pegar secreto TOTP", description: "Secreto base32 del servicio", icon: I.keyVariant })
    return acts
}

function placeholderFor(isUnlocked, enteringTotp, selectedPath) {
    if (!isUnlocked) return "Ingresá la contraseña…"
    if (enteringTotp) return "Secreto TOTP… (vacío = generar)"
    if (selectedPath !== "") return "Filtrar acción…"
    return "Buscar en KeePass…"
}

function visibleRows(isUnlocked, addingEntry, pendingDel, enteringTotp, selectedPath, filtered, totpRowsArr, detailActions) {
    if (!isUnlocked) return []
    if (addingEntry || pendingDel !== "") return filtered
    if (enteringTotp) return totpRowsArr
    if (selectedPath !== "") return detailActions
    return filtered
}