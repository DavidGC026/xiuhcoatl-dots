pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    property var snapshot: ({})
    property string notice: ""
    property string operation: ""
    property bool showAllPeers: false
    readonly property string script: Caching.serpantinumDir + "/scripts/desktop/devices.py"
    Keys.onEscapePressed: closeRequested()
    onVisibleChanged: if (visible) { forceActiveFocus(); refresh(); }

    function run(args, op) {
        if (probe.running) return;
        operation = op;
        probe.command = ["python3", script].concat(args);
        probe.running = true;
    }
    function refresh() { run(["status"], "status"); }

    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (result.ok && root.operation === "status") root.snapshot = result;
                    else root.notice = result.message || "No se pudo actualizar la lista.";
                } catch (e) { root.notice = "No se pudo leer la respuesta. Revisa que Python 3 esté instalado."; }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && root.notice === "") root.notice = "No se pudo consultar el servicio. Revisa su configuración.";
            if (code === 0 && root.operation === "add") Qt.callLater(root.refresh);
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
        font.family: ThemeBackend.fontFamily
        font.pixelSize: Scaler.s(13)
        padding: Scaler.s(11)
        background: Rectangle {
            radius: Scaler.s(8)
            color: button.down ? DvgEstilo.carmin : button.hovered ? ThemeBackend.surface1 : ThemeBackend.surface0
            border.color: button.activeFocus ? ThemeBackend.text : DvgEstilo.oro
            border.width: button.activeFocus ? 2 : 1
            opacity: button.enabled ? 1 : 0.45
        }
        contentItem: Text { text: button.text; color: ThemeBackend.text; font: button.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
    }

    Rectangle { anchors.fill: parent; color: "#99000000"; MouseArea { anchors.fill: parent; onClicked: root.closeRequested() } }
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - Scaler.s(40), Scaler.s(940))
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
                Layout.fillWidth: true
                Copy { text: "Mis equipos"; color: DvgEstilo.oro; font.family: DvgEstilo.tituloFont; font.pixelSize: Scaler.s(26) }
                Action { text: probe.running ? "Consultando…" : "Actualizar"; enabled: !probe.running; onClicked: root.refresh() }
                Action { text: "Cerrar"; onClicked: root.closeRequested() }
            }
            FileteHeraldico { Layout.fillWidth: true }
            Copy { visible: root.notice !== ""; text: root.notice; color: DvgEstilo.oro }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: Scaler.s(12)
                    Copy { text: "Red privada · Tailscale"; color: DvgEstilo.oro; font.pixelSize: Scaler.s(18) }
                    Copy { text: root.snapshot.tailscale ? root.snapshot.tailscale.message : "Consulta tus equipos y carpetas compartidas." }
                    Repeater {
                        model: root.snapshot.tailscale ? (root.showAllPeers ? root.snapshot.tailscale.peers : root.snapshot.tailscale.peers.slice(0, 3)) : []
                        delegate: Rectangle {
                            id: peerDelegate
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: peerRow.implicitHeight + Scaler.s(22)
                            color: ThemeBackend.surface0
                            radius: Scaler.s(8)
                            RowLayout {
                                id: peerRow
                                anchors.fill: parent
                                anchors.margins: Scaler.s(11)
                                Rectangle { implicitWidth: Scaler.s(8); implicitHeight: Scaler.s(8); radius: width / 2; color: peerDelegate.modelData.online ? ThemeBackend.green : ThemeBackend.overlay0; Accessible.name: peerDelegate.modelData.online ? "Conectado" : "Desconectado" }
                                Copy { text: peerDelegate.modelData.name + " · " + peerDelegate.modelData.os; font.bold: true }
                                Copy { Layout.fillWidth: false; text: (peerDelegate.modelData.online ? "Conectado" : "Desconectado") + "  " + peerDelegate.modelData.ips.join(" · "); color: ThemeBackend.subtext0; font.pixelSize: Scaler.s(12) }
                            }
                        }
                    }
                    Action {
                        visible: !!(root.snapshot.tailscale && root.snapshot.tailscale.peers.length > 3)
                        text: root.showAllPeers ? "Mostrar solo los primeros tres" : "Ver los " + (root.snapshot.tailscale ? root.snapshot.tailscale.peers.length : 0) + " equipos"
                        onClicked: root.showAllPeers = !root.showAllPeers
                    }
                    Copy { text: "Carpetas"; color: DvgEstilo.oro; font.pixelSize: Scaler.s(18) }
                    Copy { text: "Abre un acceso configurado o agrega la dirección real de una carpeta. Los permisos y la conexión los gestiona Archivos."; color: ThemeBackend.subtext0 }
                    Repeater {
                        model: root.snapshot.accesses || []
                        delegate: RowLayout {
                            id: accessDelegate
                            required property var modelData
                            Layout.fillWidth: true
                            Copy { text: accessDelegate.modelData.label + "\n" + accessDelegate.modelData.uri + " · " + accessDelegate.modelData.source }
                            Action { text: "Abrir"; enabled: !probe.running; onClicked: root.run(["open", accessDelegate.modelData.id], "open") }
                        }
                    }
                    Copy { visible: !(root.snapshot.accesses || []).length; text: "Aún no tienes accesos. Agrega uno abajo; también se leen tus marcadores de red de Archivos." }
                    RowLayout {
                        Layout.fillWidth: true
                        TextField { id: folderName; Layout.preferredWidth: Scaler.s(150); placeholderText: "Nombre"; color: ThemeBackend.text; palette.placeholderText: ThemeBackend.subtext0; background: Rectangle { color: ThemeBackend.surface0; radius: 6; border.color: folderName.activeFocus ? DvgEstilo.oro : ThemeBackend.surface1 } }
                        TextField { id: folderUri; Layout.fillWidth: true; placeholderText: "smb://equipo/carpeta o sftp://equipo/ruta"; color: ThemeBackend.text; palette.placeholderText: ThemeBackend.subtext0; selectByMouse: true; background: Rectangle { color: ThemeBackend.surface0; radius: 6; border.color: folderUri.activeFocus ? DvgEstilo.oro : ThemeBackend.surface1 } }
                        Action { text: "Guardar"; enabled: !probe.running && folderName.text.trim() !== "" && folderUri.text.trim() !== ""; onClicked: root.run(["add", folderName.text.trim(), folderUri.text.trim()], "add") }
                    }
                    Copy { visible: (root.snapshot.warnings || []).length > 0; text: (root.snapshot.warnings || []).join("\n"); color: DvgEstilo.oro }
                    FileteHeraldico { Layout.fillWidth: true }
                    Copy { text: "Sincronización · Syncthing"; color: DvgEstilo.oro; font.pixelSize: Scaler.s(18) }
                    Copy { text: root.snapshot.syncthing ? root.snapshot.syncthing.message : ""; color: ThemeBackend.subtext0 }
                    Repeater {
                        model: root.snapshot.syncthing ? root.snapshot.syncthing.folders : []
                        delegate: Rectangle {
                            id: folderDelegate
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: folderColumn.implicitHeight + Scaler.s(24)
                            color: ThemeBackend.surface0
                            radius: Scaler.s(8)
                            ColumnLayout {
                                id: folderColumn
                                anchors.fill: parent
                                anchors.margins: Scaler.s(12)
                                Copy { text: folderDelegate.modelData.label; font.bold: true }
                                Copy { text: folderDelegate.modelData.path; color: ThemeBackend.subtext0; font.pixelSize: Scaler.s(12) }
                                Copy { text: folderDelegate.modelData.available ? ((folderDelegate.modelData.paused ? "En pausa" : ({idle: "Al día", syncing: "Sincronizando", scanning: "Revisando archivos", error: "Con errores"}[folderDelegate.modelData.state] || folderDelegate.modelData.state)) + " · " + folderDelegate.modelData.needFiles + " archivos pendientes · " + folderDelegate.modelData.errors + " errores" + (folderDelegate.modelData.localChanges ? " · " + folderDelegate.modelData.localChanges + " cambios locales sin enviar" : "")) : folderDelegate.modelData.message; color: folderDelegate.modelData.errors ? ThemeBackend.red : ThemeBackend.text }
                                Copy { visible: folderDelegate.modelData.files.length > 0; text: folderDelegate.modelData.files.join("\n"); font.pixelSize: Scaler.s(12) }
                            }
                        }
                    }
                    Action { visible: !!(root.snapshot.syncthing && root.snapshot.syncthing.web); text: "Abrir Syncthing local"; onClicked: Quickshell.execDetached(["xdg-open", root.snapshot.syncthing.web]) }
                }
            }
        }
    }
}
