#!/usr/bin/env python3
"""Exercise actual supervisor/lease processes without inhibiting the host."""

import importlib.util
import json
import os
from pathlib import Path
import select
import signal
import shutil
import subprocess
import sys
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "src/scripts/desktop_modes.py"
SPEC = importlib.util.spec_from_file_location("desktop_modes", SCRIPT)
MODES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODES)


class InhibitorLifecycle(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.fake = self.directory / "systemd-inhibit"
        self.fake.write_text(
            f"#!{sys.executable}\nimport os,sys\n"
            "from pathlib import Path\n"
            "Path(os.environ['MODE_TEST_PID']).write_text(str(os.getpid()))\n"
            "args=sys.argv[sys.argv.index('--')+1:]\n"
            "os.execv(args[0],args)\n"
        )
        self.fake.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.directory}:{os.environ['PATH']}",
                        MODE_TEST_PID=str(self.directory / "lease-pid"))
        self.processes = []

    def tearDown(self):
        for process in self.processes:
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=4)
            for pipe in (process.stdin, process.stdout, process.stderr):
                if pipe and not pipe.closed:
                    pipe.close()
        self.temp.cleanup()

    def start(self):
        process = subprocess.Popen([sys.executable, str(SCRIPT), "inhibit"],
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=self.env)
        self.processes.append(process)
        return process

    def read_result(self, process):
        self.assertTrue(select.select([process.stdout], [], [], 4)[0], "helper did not respond")
        return json.loads(process.stdout.readline())

    def wait_released(self, pid):
        deadline = time.monotonic() + 4
        while MODES.alive(pid) and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertFalse(MODES.alive(pid), "lease outlived its owner")

    def test_closing_shell_pipe_releases_lease(self):
        process = self.start()
        self.assertEqual(self.read_result(process), {"ready": True})
        pid = int((self.directory / "lease-pid").read_text())
        process.stdin.close()
        self.assertEqual(process.wait(timeout=4), 0)
        self.wait_released(pid)

    def test_mode_off_sigterm_releases_lease(self):
        process = self.start()
        self.assertEqual(self.read_result(process), {"ready": True})
        pid = int((self.directory / "lease-pid").read_text())
        process.terminate()
        self.assertEqual(process.wait(timeout=4), 0)
        self.wait_released(pid)

    def test_supervisor_crash_cannot_leave_lease(self):
        process = self.start()
        self.assertEqual(self.read_result(process), {"ready": True})
        pid = int((self.directory / "lease-pid").read_text())
        process.send_signal(signal.SIGKILL)
        process.wait(timeout=4)
        self.wait_released(pid)

    def test_failure_is_reported_without_claiming_protection(self):
        self.fake.write_text(f"#!{sys.executable}\nimport sys\nsys.stderr.write('Access denied\\n')\nsys.exit(1)\n")
        process = self.start()
        result = self.read_result(process)
        self.assertEqual(result, {"error": "Access denied"})
        self.assertEqual(process.wait(timeout=4), 1)

    def test_repeated_sessions_release_independently(self):
        for _ in range(3):
            process = self.start()
            self.assertEqual(self.read_result(process), {"ready": True})
            pid = int((self.directory / "lease-pid").read_text())
            process.stdin.close()
            process.wait(timeout=4)
            self.wait_released(pid)


@unittest.skipUnless(shutil.which("qs") and os.environ.get("WAYLAND_DISPLAY"), "Quickshell Wayland session required")
class ModeTransitions(unittest.TestCase):
    def test_shell_reload_releases_transient_presentation(self):
        with tempfile.TemporaryDirectory(prefix="xiuhcoatl-modes-reload-") as temporary:
            root = Path(temporary)
            (root / "singletons/system").mkdir(parents=True)
            (root / "scripts").mkdir()
            shutil.copy(SCRIPT.parents[1] / "quickshell/singletons/system/DesktopModes.qml", root / "singletons/system")
            (root / "qmldir").write_text(
                "singleton DesktopModes 1.0 singletons/system/DesktopModes.qml\n"
                "singleton Config 1.0 Config.qml\nsingleton SysData 1.0 SysData.qml\n"
                "singleton Caching 1.0 Caching.qml\n")
            (root / "Config.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject {function getSetting(k,v){return v;} function setSetting(k,v){}}')
            (root / "SysData.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject {property bool onBattery:false}')
            (root / "Caching.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject {property string serpantinumDir:' + json.dumps(str(root)) + '}')
            marker = root / "helper-pid"
            (root / "scripts/desktop_modes.py").write_text(
                'import sys,os\nfrom pathlib import Path\nPath(' + repr(str(marker)) + ').write_text(str(os.getpid()))\n'
                'print(\'{"ready": true}\',flush=True)\nfor line in sys.stdin: pass\n')
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "."
ShellRoot { readonly property bool mode:DesktopModes.presentationActive
IpcHandler {target:"lifecycle";function reload():void{Quickshell.reload(true);}} }''')
            process = subprocess.Popen(["qs", "--no-color", "-p", str(root / "shell.qml")],
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                       env=dict(os.environ, QT_QPA_PLATFORM="wayland"))

            def call(target, function, *args):
                return subprocess.run(["qs", "ipc", "--pid", str(process.pid), "call", target, function, *args],
                                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=2)

            def status_until(predicate):
                deadline = time.monotonic() + 8
                while time.monotonic() < deadline:
                    result = call("desktopModes", "status")
                    try:
                        status = json.loads(result.stdout)
                        if predicate(status):
                            return status
                    except json.JSONDecodeError:
                        pass
                    time.sleep(0.1)
                self.fail("Quickshell did not reach the expected mode state")

            try:
                status_until(lambda status: not status["presentation"])
                self.assertEqual(call("desktopModes", "setPresentation", "true").returncode, 0)
                status_until(lambda status: status["sleepInhibited"])
                pid = int(marker.read_text())
                self.assertEqual(call("lifecycle", "reload").returncode, 0)
                status_until(lambda status: not status["presentation"] and not status["sleepInhibited"])
                self.assertFalse(MODES.alive(pid), "inhibitor survived shell reload")
            finally:
                process.terminate()
                try:
                    process.wait(timeout=4)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=2)
                process.stdout.close()

    def test_real_qml_policy_with_isolated_preferences(self):
        """Load the unmodified singleton/UI; all settings and helpers are local fakes."""
        with tempfile.TemporaryDirectory(prefix="xiuhcoatl-modes-") as temporary:
            root = Path(temporary)
            qml = SCRIPT.parents[1] / "quickshell"
            (root / "singletons/system").mkdir(parents=True)
            (root / "modos").mkdir()
            (root / "scripts").mkdir()
            shutil.copy(qml / "singletons/system/DesktopModes.qml", root / "singletons/system")
            for name in ("ModosPanel.qml", "ModeButton.qml", "qmldir"):
                shutil.copy(qml / "modos" / name, root / "modos")
            (root / "scripts/desktop_modes.py").write_text(
                'import sys\nprint(\'{"ready": true}\', flush=True)\nfor line in sys.stdin: pass\n')
            (root / "qmldir").write_text(
                "singleton DesktopModes 1.0 singletons/system/DesktopModes.qml\n"
                "singleton Config 1.0 Config.qml\nsingleton SysData 1.0 SysData.qml\n"
                "singleton Caching 1.0 Caching.qml\nsingleton Scaler 1.0 Scaler.qml\n"
                "singleton ThemeBackend 1.0 ThemeBackend.qml\nsingleton DvgEstilo 1.0 DvgEstilo.qml\n")
            (root / "Config.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property var rawSettings: ({notifications:{dnd:false}, idle:{manualInhibit:true}, theme:{elementOpacity:48}})
    property int writes: 0
    function getSetting(key,fallback) {
        let value=rawSettings;
        for (let part of key.split(".")) { if (value[part] === undefined) return fallback; value=value[part]; }
        return value;
    }
    function setSetting(key,value) {
        let next=JSON.parse(JSON.stringify(rawSettings)); let parts=key.split(".");
        if (!next[parts[0]]) next[parts[0]]={};
        next[parts[0]][parts[1]]=value; rawSettings=next; writes++;
    }
}''')
            (root / "SysData.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool onBattery: false }')
            (root / "Caching.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { property string serpantinumDir: ' + json.dumps(str(root)) + ' }')
            (root / "Scaler.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { function s(n) {return n;} }')
            (root / "ThemeBackend.qml").write_text('''pragma Singleton
import QtQuick
QtObject { property int borderRadius:8; property string fontFamily:"sans-serif"
property color text:"#eee5d5"; property color subtext0:"#c7b7a2"; property color subtext1:"#e1d2ba"
property color base:"#241b1b"; property color mantle:"#1b1515"; property color surface0:"#3a2929"
property color surface1:"#503434"; property color surface2:"#685050"; property color red:"#ff7777" }''')
            (root / "DvgEstilo.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { property color carmin:"#a61b24"; property color oro:"#e2a72e"; property string tituloFont:"serif" }')
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import "."
import "modos"
ShellRoot {
    id: test
    property int stage:0
    property string failure:""
    function check(ok,message) { if(!ok) { failure+=message+"; "; console.error("ASSERT",message); } }
    PanelWindow { visible:false; ModosPanel {width:620;height:650} }
    Timer {
        interval:200; running:true; repeat:true
        onTriggered: {
            if(test.stage===0) {
                test.check(!DesktopModes.lightweightActive,"normal startup");
                DesktopModes.setAutoOnBattery(true);
                test.check(!DesktopModes.lightweightActive,"auto configured while AC");
                SysData.onBattery=true;
                test.check(DesktopModes.lightweightActive && DesktopModes.batteryTriggered,"battery activates");
                test.check(DesktopModes.animationDuration(300)===0 && DesktopModes.wallpaperPaused,"effective visual reduction");
                DesktopModes.setLightweight(true); SysData.onBattery=false;
                test.check(DesktopModes.lightweightActive && !DesktopModes.batteryTriggered,"manual survives AC");
                DesktopModes.setLightweight(false);
                test.check(!DesktopModes.lightweightActive && DesktopModes.animationDuration(300)===300,"manual restores");
                DesktopModes.setAutoOnBattery(false); SysData.onBattery=true;
                test.check(!DesktopModes.lightweightActive,"auto disabled on battery");
                DesktopModes.setPresentation(true);
                test.check(DesktopModes.notificationsSuppressed && DesktopModes.effectiveDnd && DesktopModes.idleInhibited,"presentation effective overrides");
            } else if(test.stage===1) {
                test.check(DesktopModes.sleepInhibited,"confirmed inhibitor handshake");
                DesktopModes.setPresentation(false);
                test.check(!DesktopModes.sleepInhibited && !DesktopModes.effectiveDnd,"restore previous DND off");
                test.check(Config.writes===4,"presentation never writes settings");
                test.check(Config.rawSettings.idle.manualInhibit===true && Config.rawSettings.theme.elementOpacity===48,"preferences unchanged");
                Config.setSetting("notifications.dnd",true);
                DesktopModes.setPresentation(true);
            } else if(test.stage===2) {
                test.check(DesktopModes.sleepInhibited,"inhibitor restarts with stdin pipe");
                DesktopModes.setPresentation(false);
                test.check(DesktopModes.effectiveDnd && Config.rawSettings.notifications.dnd,"restore previous DND on");
                console.log(test.failure==="" ? "MODE_TRANSITIONS_OK" : "MODE_TRANSITIONS_FAILED "+test.failure);
                Qt.quit();
            }
            test.stage++;
        }
    }
}''')
            result = subprocess.run(["qs", "--no-color", "-p", str(root / "shell.qml")],
                                    env=dict(os.environ, QT_QPA_PLATFORM="wayland"),
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=12)
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("MODE_TRANSITIONS_OK", result.stdout)
            self.assertNotIn("TypeError", result.stdout)
            self.assertNotIn("ReferenceError", result.stdout)


if __name__ == "__main__":
    unittest.main()
