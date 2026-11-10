#!/usr/bin/env python3
"""Equipos reales y accesos elegidos por el usuario; nunca deduce recursos SMB."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit, urlencode
from urllib.request import Request, build_opener, ProxyHandler, HTTPRedirectHandler
import xml.etree.ElementTree as ET


def roots(home=None):
    home = Path(home or Path.home())
    return home, Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")), Path(os.environ.get("XDG_STATE_HOME", home / ".local/state"))


def valid_uri(uri):
    """No claves, opciones de programa, ni protocolos que ejecuten código."""
    p = urlsplit(uri)
    if p.scheme not in {"smb", "sftp", "file", "dav", "davs"} or p.password or p.query or p.fragment:
        raise ValueError("Usa una dirección smb://, sftp://, dav(s):// o file:// sin contraseña ni parámetros.")
    if any(ord(c) < 32 for c in uri) or (p.scheme == "file" and p.netloc not in {"", "localhost"}):
        raise ValueError("Dirección de carpeta no válida.")
    if p.scheme != "file" and not p.hostname:
        raise ValueError("Falta el nombre del equipo en la dirección.")
    if p.scheme == "file" and not p.path.startswith("/"):
        raise ValueError("La carpeta local debe tener una ruta absoluta.")
    return uri


def access(label, uri, source, peer=""):
    valid_uri(uri)
    return {"id": hashlib.sha256(uri.encode()).hexdigest()[:24], "label": str(label or uri)[:160], "uri": uri, "source": source, "peer": str(peer)[:160]}


def configured(home=None):
    _, config, _ = roots(home)
    result, warnings = [], []
    path = config / "xiuhcoatl/equipos.json"
    if path.exists():
        try:
            data = json.loads(path.read_text())
            for row in data[:100]:
                result.append(access(row.get("label"), row["uri"], "Configurado", row.get("peer", "")))
        except (OSError, ValueError, TypeError, KeyError, AttributeError):
            warnings.append("Revisa ~/.config/xiuhcoatl/equipos.json: no se pudieron leer todos los accesos.")
    for bookmark in (config / "gtk-3.0/bookmarks", config / "gtk-4.0/bookmarks"):
        try:
            for line in bookmark.read_text().splitlines()[:200]:
                uri, _, label = line.partition(" ")
                try:
                    if urlsplit(uri).scheme != "file":
                        result.append(access(label, uri, "Marcador de Archivos"))
                except ValueError:
                    pass
        except OSError:
            pass
    return list({r["id"]: r for r in result}.values()), warnings


def save_access(label, uri, peer="", home=None):
    row = access(label, uri, "Configurado", peer)
    _, config, _ = roots(home)
    path = config / "xiuhcoatl/equipos.json"
    data = json.loads(path.read_text()) if path.exists() else []
    if not isinstance(data, list):
        raise ValueError("El archivo de accesos debe contener una lista.")
    data = [r for r in data if r.get("uri") != uri]
    if len(data) >= 100:
        raise ValueError("El límite es de 100 accesos.")
    data.append({k: row[k] for k in ("label", "uri", "peer")})
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as f:
        name = f.name
        json.dump(data, f, ensure_ascii=False, indent=2)
    try:
        os.chmod(name, 0o600)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)
    return {"ok": True, "message": "Acceso guardado."}


def tailscale():
    if not shutil.which("tailscale"):
        return {"available": False, "message": "Tailscale no está instalado. Instálalo y conecta este equipo para ver tus computadoras.", "peers": []}
    try:
        p = subprocess.run(["tailscale", "status", "--json"], capture_output=True, text=True, timeout=4, check=True)
        data = json.loads(p.stdout)
        peers = [{"id": v.get("ID", k), "name": v.get("HostName") or v.get("DNSName", "").rstrip("."), "dns": v.get("DNSName", "").rstrip("."), "online": bool(v.get("Online")), "os": v.get("OS", ""), "ips": v.get("TailscaleIPs", []), "lastSeen": v.get("LastSeen", "")} for k, v in (data.get("Peer") or {}).items()]
        peers.sort(key=lambda r: (not r["online"], r["name"].lower()))
        state = data.get("BackendState", "")
        return {"available": state == "Running", "message": "Conectado a tu red privada." if state == "Running" else "Tailscale no está conectado. Abre Tailscale e inicia sesión.", "peers": peers, "self": (data.get("Self") or {}).get("HostName", "")}
    except (OSError, subprocess.SubprocessError, ValueError, AttributeError):
        return {"available": False, "message": "Tailscale no responde. Revisa que tailscaled esté activo y que tengas acceso.", "peers": []}


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def syncthing_config(home=None):
    home, config, state = roots(home)
    data = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    for path in (state / "syncthing/config.xml", config / "syncthing/config.xml", data / "syncthing/config.xml"):
        if not path.is_file() or path.stat().st_size > 4_000_000:
            continue
        tree = ET.fromstring(path.read_bytes())
        gui = tree.find("gui")
        if gui is None or gui.get("enabled", "true") == "false":
            continue
        address = gui.findtext("address", "127.0.0.1:8384")
        parsed = urlsplit("http://" + address)
        host = parsed.hostname or ""
        # Nunca se transmite la API key a una interfaz remota ni a un redirect.
        if host in {"0.0.0.0", "::"}:
            host = "127.0.0.1"
        if host != "localhost" and not ipaddress.ip_address(host).is_loopback:
            raise ValueError("La interfaz de Syncthing debe estar disponible en localhost.")
        host = "[" + host + "]" if ":" in host else host
        scheme = "https" if gui.get("tls", "false") == "true" else "http"
        return f"{scheme}://{host}:{parsed.port or 8384}", gui.findtext("apikey", ""), tree.findall("folder")
    return None


def syncthing(home=None):
    try:
        config = syncthing_config(home)
        if not config:
            return {"available": False, "message": "No se encontró Syncthing local. Configúralo y activa su interfaz web para consultar pendientes.", "folders": []}
        base, key, folders = config
        if not key:
            raise ValueError("Falta la clave de la interfaz local de Syncthing.")
        opener = build_opener(ProxyHandler({}), NoRedirect())

        def get(endpoint, folder):
            req = Request(base + "/rest/" + endpoint + "?" + urlencode({"folder": folder, "page": 1, "perpage": 20}), headers={"X-API-Key": key})
            with opener.open(req, timeout=1.5) as response:
                return json.loads(response.read(2_000_001))

        def folder_status(folder):
            name = folder.get("label") or folder.get("id", "Carpeta")
            path = Path(folder.get("path", "")).expanduser()
            item = {"id": folder.get("id"), "label": name, "path": str(path), "paused": folder.get("paused", "false") == "true", "files": [], "available": False}
            try:
                status = get("db/status", item["id"])
                item.update({"available": True, "state": status.get("state", "unknown"), "needFiles": status.get("needFiles", 0), "needBytes": status.get("needBytes", 0), "errors": status.get("pullErrors", 0), "localChanges": status.get("receiveOnlyTotalItems", 0)})
                if item["needFiles"]:
                    need = get("db/need", item["id"])
                    item["files"] = [f.get("name", "") for section in ("progress", "queued", "rest") for f in need.get(section, [])][:20]
            except Exception:
                item["message"] = "No se pudieron consultar los pendientes. Revisa Syncthing local."
            return item

        with ThreadPoolExecutor(max_workers=4) as pool:
            rows = list(pool.map(folder_status, folders[:16]))
        return {"available": any(r["available"] for r in rows) or not folders, "message": "Pendientes por recibir en este equipo; hasta 20 nombres por carpeta." + (" Se muestran las primeras 16 carpetas." if len(folders) > 16 else ""), "web": base, "folders": rows}
    except Exception:
        # Errores de XML/HTTP pueden contener credenciales: nunca se serializan.
        return {"available": False, "message": "No se pudo consultar Syncthing local. Revisa su servicio, su interfaz en localhost y el certificado si usas HTTPS.", "folders": []}


def status(home=None):
    with ThreadPoolExecutor(max_workers=2) as pool:
        ts = pool.submit(tailscale)
        st = pool.submit(syncthing, home)
        accesses, warnings = configured(home)
        sync = st.result()
        for folder in sync["folders"]:
            path = Path(folder["path"])
            if path.is_absolute() and path.is_dir():
                accesses.append(access(folder["label"], path.as_uri(), "Syncthing local"))
        return {"ok": True, "tailscale": ts.result(), "syncthing": sync, "accesses": list({r["id"]: r for r in accesses}.values()), "warnings": warnings}


def open_access(identifier, home=None):
    rows = status(home)["accesses"]
    row = next((r for r in rows if r["id"] == identifier), None)
    if not row:
        raise ValueError("El acceso ya no está configurado. Actualiza la lista.")
    subprocess.Popen(["xdg-open", valid_uri(row["uri"])], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return {"ok": True, "message": "Carpeta enviada al gestor de archivos."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("status")
    op = sub.add_parser("open")
    op.add_argument("id")
    add = sub.add_parser("add")
    add.add_argument("label")
    add.add_argument("uri")
    add.add_argument("--peer", default="")
    args = parser.parse_args()
    try:
        out = status() if args.action == "status" else open_access(args.id) if args.action == "open" else save_access(args.label, args.uri, args.peer)
        print(json.dumps(out, ensure_ascii=False))
    except Exception as error:
        print(json.dumps({"ok": False, "message": str(error) if isinstance(error, ValueError) else "No se pudo completar la acción. Revisa los permisos y la configuración."}, ensure_ascii=False))
        sys.exit(1)


if __name__ == "__main__":
    main()
