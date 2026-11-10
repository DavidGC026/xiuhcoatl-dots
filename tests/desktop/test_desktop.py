"""Pruebas aisladas: no leen ni modifican el escritorio de quien las ejecuta."""
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "src/scripts/desktop" / (name + ".py"))
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


backup, devices = module("backup"), module("devices")


class Backups(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.desktop = backup.Desktop(self.home, self.home / "state", self.home / "config/settings.json")
        self.desktop.settings_path.parent.mkdir()
        self.desktop.settings_path.write_text(json.dumps({"bar": {"height": 40, "wifiStyle": "pill", "wifiShowName": False}, "dock": {"apps": [{"desktop_id": "kitty", "name": "Terminal"}]}, "theme": {"blurBackground": False, "elementOpacity": 80, "colors": {"maroon": "#A61B24"}}, "general": {"apiKey": "EXCLUDED"}, "notifications": {"dnd": True}}))
        self.widgets = self.desktop.state / "widgets/eDP-1/layout.json"
        self.widgets.parent.mkdir(parents=True)
        self.widgets.write_text(json.dumps([{"type": "time", "wX": 10, "wVariant": "round", "showSeconds": True, "offsetX": 4, "sineWave": False, "apiKey": "EXCLUDED"}]))
        self.archive = self.home / "desktop.zip"

    def tearDown(self):
        self.tmp.cleanup()

    def make(self):
        self.desktop.export(self.archive)
        return backup.preview(self.archive)["digest"]

    def test_export_allowlist_and_restore_preserves_other_settings(self):
        digest = self.make()
        _, data = backup.load_archive(self.archive)
        self.assertNotIn(b"EXCLUDED", backup.encode(data))
        self.assertEqual(data["settings"]["bar"]["wifiStyle"], "pill")
        self.assertFalse(data["settings"]["theme"]["blurBackground"])
        self.assertEqual(data["widgets"]["eDP-1"][0]["offsetX"], 4)
        current = json.loads(self.desktop.settings_path.read_text())
        current["bar"]["height"] = 99
        self.desktop.settings_path.write_text(json.dumps(current))
        result = self.desktop.restore(self.archive, digest)
        restored = json.loads(self.desktop.settings_path.read_text())
        self.assertEqual(restored["bar"]["height"], 40)
        self.assertTrue(restored["notifications"]["dnd"])
        self.assertTrue(Path(result["previous"]).is_file())

    def test_transfer_to_empty_desktop_with_monitor_mapping(self):
        digest = self.make()
        other = backup.Desktop(self.home / "new", self.home / "new/state", self.home / "new/config/settings.json")
        result = other.restore(self.archive, digest, mappings={"eDP-1": "HDMI-A-1"})
        self.assertTrue((other.state / "widgets/HDMI-A-1/layout.json").is_file())
        self.assertTrue(Path(result["previous"]).is_file())

    def test_failed_write_rolls_back_exact_bytes(self):
        digest = self.make()
        self.desktop.settings_path.write_text('{"bar":{"height":123},"general":{"retained":true}}')
        original = self.desktop.settings_path.read_bytes()
        real = backup.atomic_write
        calls = []
        def fail_second(path, content, mode=0o600):
            calls.append(path)
            if len(calls) == 2:
                raise OSError("disco")
            return real(path, content, mode)
        with patch.object(backup, "atomic_write", fail_second), self.assertRaisesRegex(ValueError, "archivos originales"):
            self.desktop.restore(self.archive, digest)
        self.assertEqual(self.desktop.settings_path.read_bytes(), original)
        self.assertEqual(len(list(self.desktop.history.glob("*.zip"))), 1)

    def test_changed_archive_cannot_use_previous_preview(self):
        digest = self.make()
        self.archive.write_bytes(self.archive.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "cambió"):
            self.desktop.restore(self.archive, digest)

    def test_rejects_paths_symlinks_duplicate_entries_and_oversize(self):
        payload = backup.encode(self.desktop.collect())
        for entry in ("../settings.json", "/etc/passwd", "desktop.json/../oops"):
            archive = self.home / "bad.zip"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr(entry, payload)
            with self.assertRaises(ValueError):
                backup.preview(archive)
        info = zipfile.ZipInfo("desktop.json")
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(archive, "w") as z:
            z.writestr(info, payload)
        with self.assertRaises(ValueError):
            backup.preview(archive)
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("desktop.json", b" " * (backup.MAX_SIZE + 1))
        with self.assertRaises(ValueError):
            backup.preview(archive)

    def test_symlink_destination_and_source_rejected(self):
        digest = self.make()
        original = self.desktop.settings_path.read_bytes()
        target = self.home / "external"
        target.write_bytes(original)
        self.desktop.settings_path.unlink()
        self.desktop.settings_path.symlink_to(target)
        with self.assertRaisesRegex(ValueError, "simbólicos"):
            self.desktop.restore(self.archive, digest)
        self.assertEqual(target.read_bytes(), original)

    def test_requires_shortcut_trust_and_rejects_credentials(self):
        shortcut = self.home / ".config/hypr/config/keybinds.lua"
        shortcut.parent.mkdir(parents=True)
        shortcut.write_text('hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))')
        digest = self.make()
        with self.assertRaisesRegex(ValueError, "origen"):
            self.desktop.restore(self.archive, digest)
        self.desktop.restore(self.archive, digest, trust_shortcuts=True)
        shortcut.write_text('local api_key="do-not-export"')
        with self.assertRaisesRegex(ValueError, "credencial"):
            self.desktop.collect()

    def test_bad_payload_rejected(self):
        data = self.desktop.collect()
        data["widgets"] = {"../escape": []}
        with self.assertRaises(ValueError):
            backup.validate(data)

    def test_rejects_embedded_commands_and_secret_fields(self):
        for value in ({"bar": {"modules": {"left": [{"cmd": "sh -c bad"}]}}}, {"bar": {"menuItems": [{"command": "bad"}]}}, {"dock": {"apps": [{"desktop_id": "kitty;sh -c bad"}]}}, {"bar": {"wifi": {"api_key": "private"}}}):
            with self.assertRaises(ValueError):
                backup.settings(value)
        data = self.desktop.collect()
        data["settings"]["general"] = {"token": "hidden"}
        with self.assertRaises(ValueError):
            backup.validate(data)

    def test_does_not_overwrite_export(self):
        self.make()
        original = self.archive.read_bytes()
        with self.assertRaises(ValueError):
            self.desktop.export(self.archive)
        self.assertEqual(original, self.archive.read_bytes())


class Devices(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.env = patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.home / ".config"), "XDG_STATE_HOME": str(self.home / ".local/state"), "XDG_DATA_HOME": str(self.home / ".local/share")})
        self.env.start()

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def test_explicit_accesses_and_bookmarks_no_invented_shares(self):
        devices.save_access("NAS", "smb://nas/Documentos", home=self.home)
        path = self.home / ".config/gtk-3.0/bookmarks"
        path.parent.mkdir(parents=True)
        path.write_text("sftp://server/home/david Servidor\nsmb://user:secret@server/private Ignorar\n")
        rows, warnings = devices.configured(self.home)
        self.assertEqual({r["uri"] for r in rows}, {"smb://nas/Documentos", "sftp://server/home/david"})
        self.assertFalse(warnings)
        for uri in ("javascript:alert(1)", "smb://user:secret@host/share", "--help", "file://remote/etc", "sftp://host/path?token=secret"):
            with self.assertRaises(ValueError):
                devices.valid_uri(uri)

    def test_optional_tailscale_and_timeout(self):
        with patch.object(devices.shutil, "which", return_value=None):
            self.assertFalse(devices.tailscale()["available"])
        with patch.object(devices.shutil, "which", return_value="/fake"), patch.object(devices.subprocess, "run", side_effect=subprocess.TimeoutExpired("tailscale", 4)):
            self.assertFalse(devices.tailscale()["available"])

    def test_parses_real_tailscale_status(self):
        payload = {"BackendState": "Running", "Self": {"HostName": "local"}, "Peer": {"one": {"HostName": "completa", "Online": True, "TailscaleIPs": ["100.1.2.3"]}}}
        with patch.object(devices.shutil, "which", return_value="/fake"), patch.object(devices.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, json.dumps(payload))):
            self.assertEqual(devices.tailscale()["peers"][0]["name"], "completa")

    def test_syncthing_key_never_in_output_and_remote_gui_rejected(self):
        path = self.home / ".local/state/syncthing/config.xml"
        path.parent.mkdir(parents=True)
        path.write_text('<configuration><gui><address>127.0.0.1:8384</address><apikey>PRIVATE-KEY</apikey></gui><folder id="notes" label="Notas" path="/notes"/></configuration>')
        def fake_open(req, timeout):
            self.assertEqual(req.headers["X-api-key"], "PRIVATE-KEY")
            response = {"needFiles": 2, "state": "syncing", "pullErrors": 0} if "/db/status" in req.full_url else {"progress": [{"name": "a.md"}], "queued": [{"name": "b.md"}], "rest": []}
            return io.BytesIO(json.dumps(response).encode())
        class Opener:
            open = staticmethod(fake_open)
        with patch.object(devices, "build_opener", return_value=Opener()):
            result = devices.syncthing(self.home)
        self.assertTrue(result["available"])
        self.assertEqual(result["folders"][0]["files"], ["a.md", "b.md"])
        self.assertNotIn("PRIVATE-KEY", json.dumps(result))
        path.write_text(path.read_text().replace("127.0.0.1", "100.2.3.4"))
        self.assertFalse(devices.syncthing(self.home)["available"])

    def test_open_uses_argv_not_shell(self):
        row = devices.access("Safe", "sftp://host/path$(touch%20bad)", "Configured")
        with patch.object(devices, "status", return_value={"accesses": [row]}), patch.object(devices.subprocess, "Popen") as popen:
            devices.open_access(row["id"], self.home)
            self.assertEqual(popen.call_args.args[0], ["xdg-open", row["uri"]])
            self.assertNotIn("shell", popen.call_args.kwargs)


if __name__ == "__main__":
    unittest.main()
