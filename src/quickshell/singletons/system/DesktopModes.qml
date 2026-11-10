pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../"

Item {
    id: root

    // Presentation deliberately does not survive shell restart. DND, caffeine,
    // idle timers and wallpaper choices retain their original stored values.
    property bool presentationActive: false
    readonly property bool notificationsSuppressed: presentationActive
    readonly property bool idleInhibited: presentationActive
    readonly property bool configuredDnd: Config.getSetting("notifications.dnd", false) === true
    readonly property bool effectiveDnd: configuredDnd || presentationActive

    readonly property bool lightweightManual: Config.getSetting("desktopModes.lightweight", false) === true
    readonly property bool autoOnBattery: Config.getSetting("desktopModes.autoOnBattery", false) === true
    readonly property bool onBattery: SysData.onBattery
    readonly property bool batteryTriggered: autoOnBattery && onBattery
    readonly property bool lightweightActive: lightweightManual || batteryTriggered
    readonly property bool wallpaperPaused: lightweightActive
    readonly property string lightweightReason: lightweightManual ? "Activado manualmente"
        : batteryTriggered ? "Activo por batería" : "Desactivado"

    property bool sleepInhibited: false
    property string inhibitorError: ""
    readonly property string helperPath: Caching.serpantinumDir + "/scripts/desktop_modes.py"

    function animationDuration(normalDuration: int): int {
        return root.lightweightActive ? 0 : normalDuration;
    }

    function setPresentation(enabled: bool): void { root.presentationActive = enabled; }
    function togglePresentation(): void { setPresentation(!root.presentationActive); }
    function setLightweight(enabled: bool): void { Config.setSetting("desktopModes.lightweight", enabled); }
    function toggleLightweight(): void { setLightweight(!root.lightweightManual); }
    function setAutoOnBattery(enabled: bool): void { Config.setSetting("desktopModes.autoOnBattery", enabled); }

    function startInhibitor(): void {
        root.inhibitorError = "";
        root.sleepInhibited = false;
        if (!root.presentationActive) return;
        if (!Caching.serpantinumDir) {
            root.inhibitorError = "No se encontró el componente de suspensión. Reinicia Xiuhcóatl.";
            return;
        }
        inhibitorProcess.stdinEnabled = true;
        inhibitorProcess.running = true;
    }

    function retryInhibitor(): void {
        inhibitorProcess.running = false;
        retryTimer.restart();
    }

    onPresentationActiveChanged: {
        if (root.presentationActive) root.startInhibitor();
        else {
            retryTimer.stop();
            // EOF permits an orderly release before QProcess terminates it.
            inhibitorProcess.stdinEnabled = false;
            inhibitorProcess.running = false;
            root.sleepInhibited = false;
            root.inhibitorError = "";
        }
    }

    Timer { id: retryTimer; interval: 150; onTriggered: root.startInhibitor() }

    Process {
        id: inhibitorProcess
        // QProcess can otherwise transfer a running process across a reload.
        // A new shell always begins without a presentation lease.
        running: false
        command: ["python3", root.helperPath, "inhibit"]
        stdinEnabled: true
        onStarted: inhibitorProcess.stdinEnabled = true
        stdout: SplitParser {
            onRead: line => {
                try {
                    let result = JSON.parse(line);
                    if (result.ready && root.presentationActive) root.sleepInhibited = true;
                    if (result.error && root.presentationActive) root.inhibitorError = String(result.error);
                } catch (e) {}
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.sleepInhibited = false;
            if (root.presentationActive && !retryTimer.running && root.inhibitorError === "")
                root.inhibitorError = "No se pudo bloquear la suspensión. Reintenta la protección.";
        }
    }

    // Independent from the user's caffeine timer and automatically destroyed on
    // reload/crash. One mapped surface per output also works with multi-monitor
    // compositor policies that only honor inhibitors on visible outputs.
    Variants {
        model: root.presentationActive ? Quickshell.screens : []
        delegate: PanelWindow {
            id: inhibitWindow
            required property var modelData
            screen: modelData
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            focusable: false
            anchors { top: true; left: true }
            WlrLayershell.namespace: "xiuhcoatl-presentation-inhibitor"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            IdleInhibitor { window: inhibitWindow; enabled: root.presentationActive }
        }
    }

    IpcHandler {
        target: "desktopModes"
        function togglePresentation(): void { root.togglePresentation(); }
        function setPresentation(enabled: bool): void { root.setPresentation(enabled); }
        function toggleLightweight(): void { root.toggleLightweight(); }
        function setLightweight(enabled: bool): void { root.setLightweight(enabled); }
        function setAutoOnBattery(enabled: bool): void { root.setAutoOnBattery(enabled); }
        function status(): string {
            return JSON.stringify({presentation: root.presentationActive, sleepInhibited: root.sleepInhibited,
                inhibitorError: root.inhibitorError, dnd: root.effectiveDnd,
                lightweightManual: root.lightweightManual, autoOnBattery: root.autoOnBattery,
                onBattery: root.onBattery, lightweightActive: root.lightweightActive});
        }
    }
}
