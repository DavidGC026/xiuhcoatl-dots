import json
import os
import re
import subprocess
import sys
import time
import urllib.request

# Xiuhcóatl se actualiza desde el repositorio de DVG OS (servidor principal y
# espejo), no desde GitHub: la versión publicada sale de novedades.json.
PACKAGE = "xiuhcoatl"
ORIGINS = ("https://dvgos.dvguzman.com", "https://espejo-dvgos.dvguzman.com")
DEFAULT_VER = "1.0.0"

state_dir = os.path.expanduser("~/.local/state/serpantinum")
if "--state-dir" in sys.argv:
    try:
        idx = sys.argv.index("--state-dir")
        if idx + 1 < len(sys.argv):
            state_dir = sys.argv[idx + 1]
    except Exception:
        pass

package_managed = os.path.isfile(os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))),
    "package-managed",
))

state_file = os.path.join(state_dir, "version")
last_check_file = os.path.join(state_dir, "last_check")
notified_file = os.path.join(state_dir, "last_notified")

if "--save-notified" in sys.argv:
    try:
        idx = sys.argv.index("--save-notified")
        if idx + 1 < len(sys.argv):
            ver_to_save = sys.argv[idx + 1]
            os.makedirs(state_dir, exist_ok=True)
            with open(notified_file, "w") as f:
                f.write(ver_to_save)
    except Exception:
        pass
    sys.exit(0)

if "--delay" in sys.argv:
    if os.path.isfile(last_check_file):
        try:
            with open(last_check_file, "r") as f:
                last_ts = float(f.read().strip())
            elapsed = time.time() - last_ts
            remaining = int(max(0, 3600 - elapsed) * 1000)
            print(remaining)
            sys.exit(0)
        except Exception:
            pass
    print(0)
    sys.exit(0)

def get_package_ver():
    """Versión instalada con pacman (x.y.z-pkgrel), o vacío si no es un paquete."""
    try:
        res = subprocess.run(["pacman", "-Q", PACKAGE], capture_output=True, text=True, timeout=10)
        if res.returncode == 0:
            return res.stdout.split()[1]
    except Exception:
        pass
    return ""

def get_local_ver():
    if package_managed:
        ver = get_package_ver()
        if ver:
            return ver
    if os.path.isfile(state_file):
        try:
            with open(state_file, "r") as f:
                for line in f:
                    if line.startswith("SERPANTINUM_VERSION="):
                        v = line.split("=", 1)[1].strip().strip('"').strip("'")
                        if v:
                            return v
        except Exception:
            pass
    return DEFAULT_VER

def get_last_notified():
    if os.path.isfile(notified_file):
        try:
            with open(notified_file, "r") as f:
                return f.read().strip()
        except Exception:
            pass
    return ""

def parse_v(v):
    nums = re.findall(r"\d+", v)
    return [int(x) for x in nums] if nums else [0]

try:
    os.makedirs(state_dir, exist_ok=True)
    with open(last_check_file, "w") as f:
        f.write(str(time.time()))
except Exception:
    pass

def get_published():
    """(versión, notas, origen) publicados en el repositorio de DVG OS."""
    for origin in ORIGINS:
        try:
            req = urllib.request.Request(origin + "/novedades.json",
                                         headers={"User-Agent": "xiuhcoatl-updater"})
            with urllib.request.urlopen(req, timeout=5) as res:
                data = json.loads(res.read(1048576).decode("utf-8"))
            release = (data.get("packages") or {}).get(PACKAGE) or {}
            version = str(release.get("version") or "").strip()
            if version:
                notes = [str(n)[:500] for n in (release.get("notes") or [])[:10]]
                return version, notes, origin
        except Exception:
            continue
    return "", [], ""

local_ver = get_local_ver()
remote_ver, notes, origin = get_published()
if not remote_ver:
    remote_ver = local_ver

has_update = parse_v(remote_ver) > parse_v(local_ver)

print(json.dumps({
    "local": local_ver,
    "remote": remote_ver,
    "has_update": has_update,
    "notes": notes if has_update else [],
    "origin": origin,
    "package_managed": package_managed,
    "last_notified": get_last_notified()
}, ensure_ascii=False))
