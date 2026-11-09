// Menú de atajos de Xiuhcóatl (Super + F1).
// Lee los atajos en vivo de `hyprctl binds -j` (solo los que tienen
// descripción "Categoría: texto" en ~/.config/hypr/config/keybinds.lua) y
// toma los colores del tema activo del shell.
// Se abre y cierra con `xiuhcoatl-atajos`. Esc o clic fuera cierra.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // Paleta: la del tema activo, con DVG Carmín y Oro de respaldo.
    property var pal: ({
        base: "#171310", mantle: "#151210", crust: "#100D0A",
        surface0: "#2A2220", surface1: "#3A2F2A", surface2: "#4A3E37",
        text: "#F2DFC0", subtext0: "#C4B8A6", subtext1: "#E2D8C6",
        mauve: "#E2A72E"
    })
    property string fontFamily: "Adwaita Mono"

    readonly property var categoryOrder: ["Ventanas", "Espacios", "Apps", "Shell", "Captura", "Multimedia", "Sistema"]
    property var groups: []
    property string query: ""

    FileView {
        id: colorsFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/serpantinum/qs_matugen_colors.json"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        try {
            const c = JSON.parse(colorsFile.text());
            const merged = Object.assign({}, root.pal);
            for (const k in merged) if (c[k]) merged[k] = c[k];
            root.pal = merged;
        } catch (e) {}
    }

    Process {
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.groups = root.buildGroups(JSON.parse(this.text))
        }
    }

    // modmask de Hyprland: SHIFT 1, CTRL 4, ALT 8, SUPER 64.
    function modsText(mask) {
        const out = [];
        if (mask & 64) out.push("Super");
        if (mask & 4) out.push("Ctrl");
        if (mask & 8) out.push("Alt");
        if (mask & 1) out.push("Shift");
        return out;
    }

    function keyText(key) {
        const names = {
            "RETURN": "Enter", "SPACE": "Espacio", "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
            "mouse:272": "Clic izq.", "mouse:273": "Clic der.", "Print": "ImpPt",
            "XF86AudioPlay": "Play", "XF86AudioPause": "Pausa", "XF86AudioPrev": "Anterior", "XF86AudioNext": "Siguiente",
            "XF86AudioMute": "Silencio", "XF86AudioMicMute": "Mic", "XF86AudioLowerVolume": "Vol −",
            "XF86AudioRaiseVolume": "Vol +", "XF86MonBrightnessDown": "Brillo −", "XF86MonBrightnessUp": "Brillo +",
            "XF86PowerOff": "Encendido", "apostrophe": "'", "questiondown": "¿"
        };
        return names[key] || (key.length === 1 ? key.toUpperCase() : key);
    }

    function buildGroups(binds) {
        const byCat = {};
        const byDesc = {};
        for (const b of binds) {
            if (!b.description) continue;
            const sep = b.description.indexOf(": ");
            const cat = sep > 0 ? b.description.slice(0, sep) : "Otros";
            const label = sep > 0 ? b.description.slice(sep + 2) : b.description;
            const combo = root.modsText(b.modmask).concat([root.keyText(b.key)]);
            // El mismo texto con varias teclas (p. ej. SUPER+Q y ALT+F4) va en una sola fila.
            const id = cat + "|" + label;
            if (byDesc[id]) {
                byDesc[id].combos.push(combo);
                continue;
            }
            byDesc[id] = { label: label, combos: [combo] };
            (byCat[cat] = byCat[cat] || []).push(byDesc[id]);
        }
        const cats = Object.keys(byCat).sort((a, b) => {
            const ia = root.categoryOrder.indexOf(a), ib = root.categoryOrder.indexOf(b);
            return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
        });
        return cats.map(c => ({ name: c, rows: byCat[c] }));
    }

    function matches(row, q) {
        if (!q) return true;
        q = q.toLowerCase();
        if (row.label.toLowerCase().indexOf(q) >= 0) return true;
        return row.combos.some(c => c.join(" + ").toLowerCase().indexOf(q) >= 0);
    }

    // Reparte los grupos en `count` columnas, cada uno en la más corta
    // (altura aproximada = filas + encabezado), respetando el orden.
    function distribute(list, count) {
        const cols = [];
        const heights = [];
        for (let i = 0; i < count; i++) { cols.push([]); heights.push(0); }
        for (const g of list) {
            let best = 0;
            for (let i = 1; i < count; i++) if (heights[i] < heights[best]) best = i;
            cols[best].push(g);
            heights[best] += g.rows.length + 2;
        }
        return cols;
    }

    readonly property var visibleGroups: groups
        .map(g => ({ name: g.name, rows: g.rows.filter(r => matches(r, query)) }))
        .filter(g => g.rows.length > 0)

    PanelWindow {
        id: win
        anchors { top: true; bottom: true; left: true; right: true }
        color: Qt.rgba(0, 0, 0, 0.45)
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "xiuhcoatl-atajos"

        // Clic fuera de la tarjeta: cerrar.
        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 96, 1800)
            height: Math.min(parent.height - 140, header.height + flow.implicitHeight + 72)
            radius: 18
            color: root.pal.base
            border.color: root.pal.surface1
            border.width: 1

            opacity: 0
            scale: 0.97
            Component.onCompleted: { opacity = 1; scale = 1; }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

            MouseArea { anchors.fill: parent }  // no cerrar al hacer clic dentro

            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 28 }
                height: 44

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "Atajos de teclado"
                    color: root.pal.text
                    font { family: root.fontFamily; pixelSize: 22; weight: Font.DemiBold }
                }

                Rectangle {
                    id: searchBox
                    anchors { right: hint.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    width: 320; height: 40; radius: 10
                    color: root.pal.surface0
                    border.color: search.activeFocus ? root.pal.mauve : "transparent"
                    border.width: 1

                    Text {
                        id: searchIcon
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "󰍉"
                        color: root.pal.subtext0
                        font { family: "Iosevka Nerd Font"; pixelSize: 16 }
                    }
                    TextInput {
                        id: search
                        anchors { left: searchIcon.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        focus: true
                        color: root.pal.text
                        selectionColor: root.pal.mauve
                        font { family: root.fontFamily; pixelSize: 14 }
                        clip: true
                        onTextChanged: root.query = text
                        Keys.onEscapePressed: text.length > 0 ? text = "" : Qt.quit()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text.length === 0
                            text: "Buscar atajo o tecla…"
                            color: root.pal.subtext1
                            font: search.font
                        }
                    }
                }

                Text {
                    id: hint
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "Esc para cerrar"
                    color: root.pal.subtext1
                    font { family: root.fontFamily; pixelSize: 12 }
                }
            }

            Flickable {
                anchors { top: header.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 28; rightMargin: 28; bottomMargin: 24 }
                contentHeight: flow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: flow
                    width: parent.width
                    spacing: 16
                    readonly property int columns: width > 1500 ? 4 : (width > 1100 ? 3 : (width > 700 ? 2 : 1))
                    readonly property real colWidth: (width - spacing * (columns - 1)) / columns
                    readonly property var columnsData: root.distribute(root.visibleGroups, columns)

                    // Mosaico: cada grupo va a la columna más corta.
                    Row {
                        spacing: flow.spacing

                        Repeater {
                            model: flow.columnsData

                            delegate: Column {
                                id: column
                                required property var modelData
                                width: flow.colWidth
                                spacing: flow.spacing

                                Repeater {
                                    model: column.modelData

                                delegate: Rectangle {
                                    id: groupCard
                                    required property var modelData
                                    width: flow.colWidth
                                    height: groupCol.implicitHeight + 28
                                    radius: 14
                                    color: root.pal.mantle

                                    Column {
                                        id: groupCol
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                                        spacing: 6

                                        Text {
                                            text: groupCard.modelData.name.toUpperCase()
                                            color: root.pal.mauve
                                            font { family: root.fontFamily; pixelSize: 12; weight: Font.Bold; letterSpacing: 1.2 }
                                            bottomPadding: 4
                                        }

                                        Repeater {
                                            model: groupCard.modelData.rows

                                            delegate: Item {
                                                id: row
                                                required property var modelData
                                                width: groupCol.width
                                                height: Math.max(label.implicitHeight, keys.implicitHeight) + 6

                                                Text {
                                                    id: label
                                                    anchors { left: parent.left; right: keys.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                                    text: row.modelData.label
                                                    color: root.pal.text
                                                    elide: Text.ElideRight
                                                    font { family: root.fontFamily; pixelSize: 13 }
                                                }

                                                Column {
                                                    id: keys
                                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                                    spacing: 3

                                                    Repeater {
                                                        model: row.modelData.combos

                                                        delegate: Row {
                                                            id: combo
                                                            required property var modelData
                                                            anchors.right: parent.right
                                                            spacing: 3

                                                            Repeater {
                                                                model: combo.modelData

                                                                delegate: Rectangle {
                                                                    required property string modelData
                                                                    width: Math.max(24, cap.implicitWidth + 12)
                                                                    height: 22
                                                                    radius: 6
                                                                    color: root.pal.surface1
                                                                    border.color: root.pal.surface2
                                                                    border.width: 1

                                                                    Text {
                                                                        id: cap
                                                                        anchors.centerIn: parent
                                                                        text: parent.modelData
                                                                        color: root.pal.text
                                                                        font { family: root.fontFamily; pixelSize: 11; weight: Font.DemiBold }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.visibleGroups.length === 0 && root.groups.length > 0
                        width: flow.width
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: 40
                        text: "Ningún atajo coincide con «" + root.query + "»"
                        color: root.pal.subtext0
                        font { family: root.fontFamily; pixelSize: 14 }
                    }
                }
            }
        }
    }
}
