pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Hyprland
import "../"
import "OverviewModel.js" as Model

Item {
    id: root
    visible: false
    enabled: visible
    focus: true
    signal closeRequested()

    property bool subscribed: false
    property var windows: []
    property var workspaces: []
    property string workspaceFilter: ""
    property string selectedId: ""
    property string statusMessage: ""
    readonly property var matches: Model.filtered(windows, search.text, workspaceFilter)
    readonly property int selectedIndex: Model.selectedIndex(matches, selectedId)
    readonly property var selectedWindow: selectedIndex >= 0 ? (matches[selectedIndex] || null) : null
    readonly property bool hyprland: Compositor.name === "hyprland"
    readonly property int columns: Math.max(1, Math.floor(grid.width / 250))

    function refresh() {
        if (!visible) return;
        let nextWindows = Model.snapshot(WindowTracker.windows || []);
        // Preserve delegates and their live streams when metadata did not change.
        if (!Model.sameWindows(windows, nextWindows)) windows = nextWindows;
        let nextWorkspaces = Model.workspaces(hyprland ? Hyprland.workspaces.values : [], windows);
        if (!Model.sameWorkspaces(workspaces, nextWorkspaces)) workspaces = nextWorkspaces;
    }
    function updateSubscription() {
        if (visible && !subscribed) {
            WindowTracker.subscribe();
            subscribed = true;
            search.clear();
            workspaceFilter = "";
            selectedId = "";
            statusMessage = "";
            if (hyprland) { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); }
            refresh();
            Qt.callLater(function() { if (root.visible) search.forceActiveFocus(); });
        } else if (!visible && subscribed) {
            WindowTracker.unsubscribe();
            subscribed = false;
        }
    }
    function startEnter() { updateSubscription(); }
    function startExit(callback) { if (callback) callback(); }
    function selectStep(step) {
        if (!matches.length) return;
        let index = Math.max(0, Math.min(matches.length - 1, selectedIndex + step));
        selectedId = matches[index].id;
        grid.positionViewAtIndex(index, GridView.Contain);
        grid.forceActiveFocus();
    }
    function activate(win) {
        if (!win) return;
        WindowTracker.activateWindow(win);
        closeRequested();
    }
    function openWorkspace() {
        if (!hyprland || !workspaceFilter) return;
        let ws = workspaces.find(function(entry) { return entry.label === root.workspaceFilter; });
        if (!ws) return;
        let command = Model.workspaceCommand(ws, Hyprland.usingLua !== false);
        if (!command) return;
        Hyprland.dispatch(command);
        closeRequested();
    }
    function moveTo(ws) {
        if (!hyprland || !selectedWindow || !ws) return;
        if (selectedWindow.workspaceLabel === ws.label) {
            statusMessage = "La ventana ya está en el escritorio " + ws.label + ".";
            return;
        }
        let command = Model.moveCommand(selectedWindow, ws, Hyprland.usingLua !== false);
        if (!command) { statusMessage = "No se pudo identificar la ventana o el escritorio."; return; }
        Hyprland.dispatch(command);
        // Confirm from compositor state rather than claiming an IPC write succeeded.
        pendingMove.windowId = selectedWindow.id;
        pendingMove.destinationLabel = ws.label;
        pendingMove.attempts = 0;
        statusMessage = "Moviendo al escritorio " + ws.label + "…";
        pendingMove.restart();
    }
    function handleKey(event) {
        let control = Boolean(event.modifiers & Qt.ControlModifier);
        let alt = Boolean(event.modifiers & Qt.AltModifier);
        if ((control || alt) && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            let number = event.key - Qt.Key_0;
            let ws = workspaces.find(function(entry) { return entry.id === number; });
            let label = ws ? ws.label : String(number);
            if (alt) moveTo(ws);
            else workspaceFilter = workspaceFilter === label ? "" : label;
        } else if (event.key === Qt.Key_Escape) closeRequested();
        else if (event.key === Qt.Key_Down) selectStep(columns);
        else if (event.key === Qt.Key_Up) selectStep(-columns);
        else if ((event.key === Qt.Key_Right || event.key === Qt.Key_Left) && !search.activeFocus) selectStep(event.key === Qt.Key_Right ? 1 : -1);
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (search.activeFocus || grid.activeFocus || root.activeFocus)) activate(selectedWindow);
        else if (control && event.key === Qt.Key_F) search.forceActiveFocus();
        else if (!control && !alt && event.text && event.text.length > 0 && !search.activeFocus && !destination.activeFocus) { search.forceActiveFocus(); search.text += event.text; }
        else { event.accepted = false; return; }
        event.accepted = true;
    }
    Keys.onPressed: function(event) { handleKey(event); }
    onVisibleChanged: updateSubscription()
    Component.onCompleted: updateSubscription()
    Component.onDestruction: { if (subscribed) WindowTracker.unsubscribe(); }
    onMatchesChanged: {
        // Dependent bindings may still contain the previous array's index in
        // this handler. Recompute from this array before reading an element.
        let index = Model.selectedIndex(matches, selectedId);
        if (index >= 0) {
            selectedId = matches[index].id;
            grid.positionViewAtIndex(index, GridView.Contain);
        } else selectedId = "";
    }

    Connections { target: WindowTracker; function onUpdated() { root.refresh(); } }
    // WindowTracker intentionally coalesces changes. Also refresh native titles
    // and workspace objects while open (including renames and special desktops).
    Timer { interval: 750; repeat: true; running: root.visible; onTriggered: root.refresh() }
    Timer {
        id: pendingMove
        interval: 180
        repeat: true
        property string windowId: ""
        property string destinationLabel: ""
        property int attempts: 0
        onTriggered: {
            root.refresh();
            let win = root.windows.find(function(entry) { return entry.id === pendingMove.windowId; });
            if (win && win.workspaceLabel === pendingMove.destinationLabel) {
                root.statusMessage = "Ventana movida al escritorio " + pendingMove.destinationLabel + ".";
                stop();
            } else if (++attempts >= 12 || !root.visible) {
                root.statusMessage = "No se confirmó el movimiento. Revisa el escritorio de destino.";
                stop();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: ThemeBackend.base
        border { width: 1; color: Qt.alpha(DvgEstilo.oro, 0.65) }
    }
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1; leftMargin: 24; rightMargin: 24 }
        height: 3
        color: DvgEstilo.carmin
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: "Vista general"
                    color: DvgEstilo.oro
                    font { family: DvgEstilo.tituloFont; pixelSize: 26 }
                }
                Text {
                    text: root.windows.length + (root.windows.length === 1 ? " ventana abierta" : " ventanas abiertas") + " · Xiuhcóatl"
                    color: ThemeBackend.subtext0
                    font { family: ThemeBackend.fontFamily; pixelSize: 12 }
                }
            }
            ActionButton {
                text: "Abrir escritorio"
                visible: root.hyprland && root.workspaceFilter !== ""
                onClicked: root.openWorkspace()
            }
            ActionButton {
                id: closeButton
                text: "Cerrar · Esc"
                onClicked: root.closeRequested()
                Accessible.name: "Cerrar vista general"
            }
        }
        TextField {
            id: search
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            placeholderText: "Buscar por título, aplicación o escritorio…"
            color: ThemeBackend.text
            placeholderTextColor: ThemeBackend.subtext0
            font { family: ThemeBackend.fontFamily; pixelSize: 14 }
            leftPadding: 14
            selectByMouse: true
            Accessible.name: "Buscar ventanas"
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { root.handleKey(event); }
            background: Rectangle {
                radius: 10
                color: ThemeBackend.mantle
                border { width: 1; color: search.activeFocus ? DvgEstilo.oro : ThemeBackend.surface1 }
            }
        }
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            contentWidth: workspaceRow.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            Row {
                id: workspaceRow
                height: parent.height
                spacing: 8
                WorkspaceChip {
                    text: "Todos"
                    highlighted: root.workspaceFilter === ""
                    onClicked: root.workspaceFilter = ""
                }
                Repeater {
                    model: root.workspaces
                    delegate: WorkspaceChip {
                        required property var modelData
                        text: modelData.label + " · " + modelData.count
                        highlighted: root.workspaceFilter === modelData.label
                        activeWorkspace: modelData.active
                        Accessible.name: "Filtrar escritorio " + modelData.label + ", " + modelData.count + " ventanas"
                        onClicked: root.workspaceFilter = root.workspaceFilter === modelData.label ? "" : modelData.label
                    }
                }
            }
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            GridView {
                id: grid
                anchors.fill: parent
                clip: true
                model: root.matches
                cellWidth: width / root.columns
                cellHeight: Math.min(230, Math.max(170, height))
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                ScrollBar.vertical: ScrollBar {}
                delegate: WindowCard {
                    required property var modelData
                    width: grid.cellWidth - 12
                    height: grid.cellHeight - 12
                    windowInfo: modelData
                    selected: root.selectedWindow !== null && root.selectedWindow.id === modelData.id
                    capturing: root.visible && y + height >= grid.contentY && y <= grid.contentY + grid.height
                    onSelectedRequested: root.selectedId = modelData.id
                    onActivated: root.activate(modelData)
                    onMoveRequested: { destination.forceActiveFocus(); destination.popup.open(); }
                }
            }
            Column {
                anchors.centerIn: parent
                width: Math.max(100, parent.width - 24)
                visible: !root.matches.length
                spacing: 12
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.windows.length === 0 ? "Tu escritorio está despejado" : "No hay ventanas que coincidan"
                    color: DvgEstilo.oro
                    wrapMode: Text.Wrap
                    font { family: DvgEstilo.tituloFont; pixelSize: 23 }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.windows.length === 0 ? "Abre una aplicación y aparecerá aquí." : "Prueba otra búsqueda o elige Todos."
                    color: ThemeBackend.subtext0
                    wrapMode: Text.Wrap
                    font { family: ThemeBackend.fontFamily; pixelSize: 13 }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(DvgEstilo.oro, 0.25) }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: root.selectedWindow ? root.selectedWindow.title : "Selecciona una ventana"
                elide: Text.ElideRight
                color: ThemeBackend.text
                font { family: ThemeBackend.fontFamily; pixelSize: 12 }
            }
            ComboBox {
                id: destination
                Layout.preferredWidth: Math.min(220, root.width * 0.28)
                palette.button: ThemeBackend.mantle
                palette.buttonText: DvgEstilo.oro
                palette.text: ThemeBackend.text
                palette.base: ThemeBackend.mantle
                palette.highlight: DvgEstilo.carmin
                palette.highlightedText: ThemeBackend.text
                model: root.workspaces
                textRole: "label"
                enabled: root.hyprland && root.selectedWindow !== null
                Accessible.name: "Escritorio de destino"
                displayText: "Escritorio " + currentText
            }
            ActionButton {
                id: moveButton
                text: "Mover"
                enabled: destination.enabled && destination.currentIndex >= 0
                onClicked: root.moveTo(root.workspaces[destination.currentIndex])
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.statusMessage || (root.hyprland ? "Flechas: seleccionar · Enter: abrir · Ctrl+1–9: filtrar · Alt+1–9: mover" : "Flechas: seleccionar · Enter: abrir · Mover entre escritorios requiere Hyprland")
            color: root.statusMessage ? DvgEstilo.oro : ThemeBackend.subtext0
            wrapMode: Text.Wrap
            font { family: ThemeBackend.fontFamily; pixelSize: 11 }
            Accessible.role: Accessible.StaticText
        }
    }

    component ActionButton: Button {
        id: action
        leftPadding: 14; rightPadding: 14; topPadding: 10; bottomPadding: 10
        contentItem: Text {
            text: action.text
            opacity: action.enabled ? 1 : 0.45
            color: ThemeBackend.text
            font { family: ThemeBackend.fontFamily; pixelSize: 12 }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            opacity: action.enabled ? 1 : 0.45
            color: action.down ? Qt.darker(DvgEstilo.carmin, 1.2) : DvgEstilo.carmin
            border.color: action.activeFocus ? DvgEstilo.oro : Qt.alpha(DvgEstilo.oro, 0.45)
        }
    }
    component WorkspaceChip: Button {
        id: chip
        property bool activeWorkspace: false
        height: 40
        leftPadding: 14; rightPadding: 14
        contentItem: Text {
            text: chip.text
            color: chip.highlighted ? ThemeBackend.text : (chip.activeWorkspace ? DvgEstilo.oro : ThemeBackend.subtext0)
            font { family: ThemeBackend.fontFamily; pixelSize: 12; bold: chip.highlighted }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 9
            color: chip.highlighted ? DvgEstilo.carmin : ThemeBackend.mantle
            border.width: 1
            border.color: chip.highlighted || chip.activeFocus || chip.activeWorkspace ? DvgEstilo.oro : Qt.alpha(DvgEstilo.oro, 0.2)
        }
    }
}
