// CpKeepassAddForm.qml — Form de alta y edición de entradas KeePass.
// Crear: campos title/user/pass/url + sección TOTP (pegar secreto o
// generar al guardar). Editar (isEdit): precarga title/user/url, la
// contraseña vacía mantiene la actual. Vacío es vacío, sin comodines.
import QtQuick
import QtQuick.Layouts
import "../../state"
import ".."

Item {
    id: root

    property bool isEdit: false
    property string origPath: ""

    signal saved(var form)
    signal cancelled()

    // Abre el form para crear: precarga el título, limpia el resto y
    // enfoca el primer campo vacío.
    function open(title) {
        isEdit = false
        origPath = ""
        errorText.text = ""
        titleInput.text = title || ""
        userInput.clear()
        passInput.clear()
        urlInput.clear()
        totpInput.clear()
        totpGen = false
        passVisible = false
        if ((title || "") !== "") userInput.forceActiveFocus()
        else titleInput.forceActiveFocus()
    }

    // Abre el form para editar: precarga todo salvo la contraseña.
    function openForEdit(entry) {
        isEdit = true
        origPath = entry.path || ""
        errorText.text = ""
        titleInput.text = entry.title || ""
        userInput.text = entry.username || ""
        passInput.clear()
        urlInput.text = entry.url || ""
        totpInput.clear()
        totpGen = false
        passVisible = false
        userInput.forceActiveFocus()
    }

    function clearSecrets() {
        passInput.clear()
        totpInput.clear()
    }

    property bool totpGen: false
    property bool passVisible: false

    // Guardando = daemon trabajando (argon2 + wl-copy tarda segundos).
    // Mientras tanto se bloquean los botones y el Guardar lo muestra.
    readonly property bool saving: KeePassState.loading

    function tryCancel() {
        if (!saving) root.cancelled()
    }

    // Genera una clave nueva en el daemon (crypto/rand, nunca
    // Math.random) y la deja en el input. Cada click, una nueva.
    function genPassword() {
        if (root.saving) return
        KeePassState.genPassword(function(pw) {
            passInput.text = pw
            passInput.forceActiveFocus()
        })
    }

    function doSave() {
        if (root.saving) return
        var t = (titleInput.text || "").trim()
        if (t === "") {
            errorText.text = "El título es obligatorio"
            titleInput.forceActiveFocus()
            return
        }
        errorText.text = ""
        var totpMode = "none"
        var secret = ""
        if (!isEdit) {
            if (totpGen) totpMode = "generate"
            else if ((totpInput.text || "").trim() !== "") {
                totpMode = "paste"
                secret = (totpInput.text || "").trim()
            }
        }
        root.saved({
            isEdit: isEdit,
            origPath: origPath,
            title: t,
            username: userInput.text || "",
            password: passInput.text || "",
            url: urlInput.text || "",
            totpMode: totpMode,
            totpSecret: secret
        })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ── Campos principales ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: "Título *"; font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont; color: Style.on_surface_variant }
            AppTextInput {
                id: titleInput
                Layout.fillWidth: true
                placeholderText: "Nombre de la entrada"
                KeyNavigation.tab: userInput.editField
                onAccepted: userInput.forceActiveFocus()
                onEscapePressed: root.tryCancel()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: "Usuario"; font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont; color: Style.on_surface_variant }
            AppTextInput {
                id: userInput
                Layout.fillWidth: true
                placeholderText: "usuario"
                KeyNavigation.tab: passInput.editField
                onAccepted: passInput.forceActiveFocus()
                onEscapePressed: root.tryCancel()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: root.isEdit ? "Contraseña  (vacía = mantener)" : "Contraseña  (vacía = generar)"; font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont; color: Style.on_surface_variant }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                AppTextInput {
                    id: passInput
                    Layout.fillWidth: true
                    placeholderText: "contraseña"
                    passwordMode: !root.passVisible
                    KeyNavigation.tab: urlInput.editField
                    onAccepted: urlInput.forceActiveFocus()
                    onEscapePressed: root.tryCancel()
                }
                PillButton {
                    size: 32; iconSize: 15
                    icon: root.passVisible ? Icons.eyeClose : Icons.eyeOpen
                    customRadius: 8
                    onClicked: root.passVisible = !root.passVisible
                }
                PillButton {
                    size: 32; iconSize: 15
                    icon: Icons.dice
                    customRadius: 8
                    onClicked: root.genPassword()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: "URL"; font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont; color: Style.on_surface_variant }
            AppTextInput {
                id: urlInput
                Layout.fillWidth: true
                placeholderText: "https://…"
                KeyNavigation.tab: root.isEdit ? titleInput.editField : totpInput.editField
                onAccepted: totpInput.forceActiveFocus()
                onEscapePressed: root.tryCancel()
            }
        }

        // ── TOTP (solo al crear; en edición se maneja desde el detalle) ──
        ColumnLayout {
            visible: !root.isEdit
            Layout.fillWidth: true
            spacing: 2
            Text { text: "TOTP  (pegar secreto o generar)"; font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont; color: Style.on_surface_variant }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                AppTextInput {
                    id: totpInput
                    Layout.fillWidth: true
                    placeholderText: root.totpGen ? "se generará al guardar" : "secreto base32"
                    enabled: !root.totpGen
                    opacity: root.totpGen ? 0.5 : 1.0
                    onAccepted: root.doSave()
                    onEscapePressed: root.tryCancel()
                    onTextChanged: if (text !== "") root.totpGen = false
                }
                PillButton {
                    size: 32; iconSize: 15
                    icon: Icons.refresh
                    active: root.totpGen
                    customRadius: 8
                    onClicked: {
                        root.totpGen = !root.totpGen
                        if (root.totpGen) totpInput.clear()
                    }
                }
            }
        }

        Text {
            id: errorText
            Layout.fillWidth: true
            visible: text !== ""
            font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
            color: Style.error
        }

        Item { Layout.fillHeight: true }

        // ── Acciones ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Item { Layout.fillWidth: true }
            PillButton {
                label: "Cancelar"
                icon: Icons.close
                iconSize: 14
                minWidth: 136
                interactive: !root.saving
                opacity: root.saving ? 0.4 : 1.0
                onClicked: root.tryCancel()
            }
            PillButton {
                label: root.saving ? "Guardando" : "Guardar"
                icon: root.saving ? Icons.refresh : Icons.check
                iconSize: 14
                minWidth: 136
                interactive: !root.saving
                opacity: 1.0
                onClicked: root.doSave()
            }
        }
    }
}
