pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: root
    anchors.fill: parent
    visible: false
    focus: visible
    signal closeRequested()
    property var preview: null
    property string message: ""
    property string operation: ""
    property string exportedPath: ""
    readonly property string script: Caching.serpantinumDir + "/scripts/desktop/backup.py"
    Keys.onEscapePressed: closeRequested()
    onVisibleChanged: if (visible) forceActiveFocus()

    function run(args, op) {
        if (worker.running) return;
        operation = op;
        message = "";
        worker.command = ["python3", script].concat(args);
        worker.running = true;
    }
    function localPath(url) { return decodeURIComponent(url.toString().replace(/^file:\/\//, "")); }

    FileDialog {
        id: chooser
        title: "Seleccionar respaldo del escritorio"
        nameFilters: ["Respaldo de Xiuhcóatl (*.zip)"]
        onAccepted: archivePath.text = root.localPath(selectedFile)
    }
    FileDialog {
        id: saveChooser
        title: "Guardar escritorio"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "xiuhcoatl.zip"
        nameFilters: ["Respaldo de Xiuhcóatl (*.zip)"]
        onAccepted: root.run(["export", root.localPath(selectedFile)], "export")
    }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.message = result.message || "";
                    if (root.operation === "preview") root.preview = result.ok ? result : null;
                    if (root.operation === "export" && result.ok) root.exportedPath = result.path;
                    if (root.operation === "restore" && result.ok) { root.preview = null; root.message += "\nRespaldo anterior: " + result.previous; }
                } catch (e) { root.message = "No se pudo leer la respuesta. Revisa que Python 3 esté instalado."; }
            }
        }
    }
    component Copy: Text {
        color: ThemeBackend.text
        font.family: ThemeBackend.fontFamily
        font.pixelSize: Scaler.s(14)
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        Layout.fillWidth: true
    }
    component Action: Button {
        id: button
        padding: Scaler.s(11)
        font.family: ThemeBackend.fontFamily
        font.pixelSize: Scaler.s(13)
        background: Rectangle {
            radius: Scaler.s(8)
            color: button.down ? DvgEstilo.carmin : button.hovered ? ThemeBackend.surface1 : ThemeBackend.surface0
            border.color: button.activeFocus ? ThemeBackend.text : DvgEstilo.oro
            border.width: button.activeFocus ? 2 : 1
            opacity: button.enabled ? 1 : 0.45
        }
        contentItem: Text { text: button.text; font: button.font; color: ThemeBackend.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
    }
    Rectangle { anchors.fill: parent; color: "#99000000"; MouseArea { anchors.fill: parent; onClicked: root.closeRequested() } }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - Scaler.s(40), Scaler.s(900))
        height: Math.min(parent.height - Scaler.s(40), Scaler.s(800))
        color: ThemeBackend.base
        border.color: DvgEstilo.oro
        radius: Scaler.s(18)
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Scaler.s(24)
            spacing: Scaler.s(14)
            RowLayout {
                Copy { text: "Guardar y recuperar"; color: DvgEstilo.oro; font.family: DvgEstilo.tituloFont; font.pixelSize: Scaler.s(26) }
                Action { text: "Cerrar"; onClicked: root.closeRequested() }
            }
            FileteHeraldico { Layout.fillWidth: true }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: parent.width
                    spacing: Scaler.s(14)
                    Copy { text: "Tu escritorio, en un archivo"; color: DvgEstilo.oro; font.pixelSize: Scaler.s(18) }
                    Copy { text: "Guarda barra, dock, distribución de widgets, colores y atajos. Puedes volver a esta configuración o llevarla a otro equipo. Los programas, imágenes, cuentas y claves de servicios no se incluyen." }
                    RowLayout {
                        Action { text: "Guardar como…"; enabled: !worker.running; onClicked: saveChooser.open() }
                        Action { text: "Guardar copia rápida"; enabled: !worker.running; onClicked: root.run(["export"], "export") }
                        Action { text: "Mostrar archivo"; visible: root.exportedPath !== ""; onClicked: Quickshell.execDetached(["xdg-open", root.exportedPath.substring(0, root.exportedPath.lastIndexOf("/"))]) }
                    }
                    Copy { visible: root.exportedPath !== ""; text: root.exportedPath; color: ThemeBackend.subtext0; font.pixelSize: Scaler.s(12) }
                    FileteHeraldico { Layout.fillWidth: true }
                    Copy { text: "Recuperar un escritorio"; color: DvgEstilo.oro; font.pixelSize: Scaler.s(18) }
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: archivePath
                            Layout.fillWidth: true
                            placeholderText: "Ruta del archivo .xiuhcoatl.zip"
                            color: ThemeBackend.text
                            palette.placeholderText: ThemeBackend.subtext0
                            selectByMouse: true
                            onTextChanged: { root.preview = null; trusted.checked = false; monitorTarget.text = ""; }
                            background: Rectangle { color: ThemeBackend.surface0; radius: 6; border.color: archivePath.activeFocus ? DvgEstilo.oro : ThemeBackend.surface1 }
                        }
                        Action { text: "Elegir…"; enabled: !worker.running; onClicked: chooser.open() }
                        Action { text: "Revisar"; enabled: !worker.running && archivePath.text.trim() !== ""; onClicked: root.run(["preview", archivePath.text.trim()], "preview") }
                    }
                    ColumnLayout {
                        visible: root.preview !== null
                        Layout.fillWidth: true
                        Copy { text: root.preview ? "Origen: " + root.preview.host + "\nFecha: " + root.preview.created + "\nAjustes: " + root.preview.groups.join(", ") + "\nWidgets: " + root.preview.widgetCount + " · monitores: " + root.preview.monitors.join(", ") + "\nColores: " + root.preview.colorFiles.length + " archivos\nAtajos: " + (root.preview.shortcuts ? "incluidos" : "sin cambios") : "" }
                        Copy { text: "En otro equipo puedes asignar una distribución a un monitor distinto. Deja el destino vacío para conservar los nombres originales."; color: ThemeBackend.subtext0 }
                        RowLayout {
                            Layout.fillWidth: true
                            ComboBox { id: monitorSource; model: root.preview ? root.preview.monitors : []; Layout.preferredWidth: Scaler.s(180); palette.text: ThemeBackend.text; palette.buttonText: ThemeBackend.text; palette.button: ThemeBackend.surface0 }
                            TextField { id: monitorTarget; Layout.fillWidth: true; placeholderText: "Monitor destino, por ejemplo eDP-1"; color: ThemeBackend.text; palette.placeholderText: ThemeBackend.subtext0; background: Rectangle { color: ThemeBackend.surface0; radius: 6; border.color: monitorTarget.activeFocus ? DvgEstilo.oro : ThemeBackend.surface1 } }
                        }
                        Copy { visible: !!(root.preview && root.preview.shortcuts); text: "Los atajos son instrucciones que Hyprland ejecuta al pulsar teclas. Revisa su contenido y confirma que conoces su origen."; color: DvgEstilo.oro }
                        TextArea {
                            visible: !!(root.preview && root.preview.shortcuts)
                            Layout.fillWidth: true
                            Layout.preferredHeight: Scaler.s(170)
                            text: root.preview ? root.preview.shortcutPreview : ""
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            font.family: "monospace"
                            font.pixelSize: Scaler.s(11)
                            color: ThemeBackend.text
                            background: Rectangle { color: ThemeBackend.surface0; radius: 6 }
                        }
                        CheckBox { id: trusted; visible: !!(root.preview && root.preview.shortcuts); text: "Confío en el origen de estos atajos"; palette.windowText: ThemeBackend.text; palette.text: ThemeBackend.text }
                        Copy { text: "Antes de recuperar se guardará una copia del escritorio actual. Si falla una escritura, se recuperan los archivos originales." }
                        Action {
                            text: worker.running ? "Procesando…" : "Recuperar este escritorio"
                            enabled: !worker.running && root.preview !== null && (!root.preview.shortcuts || trusted.checked)
                            onClicked: {
                                let args = ["restore", archivePath.text.trim(), "--digest", root.preview.digest];
                                if (trusted.checked) args.push("--trust-shortcuts");
                                if (monitorTarget.text.trim() !== "" && monitorSource.currentText !== "") args.push("--map", monitorSource.currentText + "=" + monitorTarget.text.trim());
                                root.run(args, "restore");
                            }
                        }
                    }
                    Copy { visible: root.message !== ""; text: root.message; color: DvgEstilo.oro }
                    Copy { visible: worker.running; text: "Procesando el escritorio…" }
                }
            }
        }
    }
}
