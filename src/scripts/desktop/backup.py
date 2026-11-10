#!/usr/bin/env python3
"""Respaldos de escritorio: ZIP con un JSON validado, sin extracción de rutas."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import socket
import stat
import sys
import tempfile
import zipfile

MAX_SIZE = 8 * 1024 * 1024
BAR = set("position width height opacity style time autohide autohideTimeout modules menuItems".split())
BAR.update("menuStyle workspacesStyle timeStyle visBarCount visContinuous visAlignment sysmonStyle wifiStyle btStyle batStyle kbStyle volStyle mediaHideWhenIdle batShowIcon batShowPercent btShowIcon btShowName centerByEdges distinctPills groupColors hideEmptyWorkspaces hideBarInRedactor kbShowIcon mediaInfoMode mediaShowControls mediaShowIcon mediaWidth sysmonStats timeShowDate volShowIcon volShowPercent wifiShowIcon wifiShowName workspaceCount workspaces fontFamily fontSize fontWeight".split())
BAR.update("bat bt kb sysmon wifi vol vis sysmonShowCpu sysmonShowDisk sysmonShowRam sysmonShowTemp menuShowCaffeine menuShowLauncher menuShowNightLight menuShowSettings visBars visStyle".split())
DOCK = set("enabled position onTop elementSize floating background exclusive autohide smartAutohide autohideTimeout editing apps overrideBoundsCorrection enableScrolling visibleElements scrollingElements maxVisibleElements maxElements hoverScale cascadeScale focusRunning showRunningIndicators showRunningApps runningScope".split())
THEME = {"fontFamily", "borderRadius", "activePreset", "matugen", "colors"}
THEME.update({"elementOpacity", "blurBackground", "blurStyle"})
COLORS = set("base mantle crust text subtext0 subtext1 surface0 surface1 surface2 overlay0 overlay1 overlay2 blue sapphire peach green red mauve pink yellow maroon teal".split())
WIDGET = set("type variant x y width height opacity rotation id stretchWidth stretchHeight imagePath wType wVariant wX wY wWidth wHeight wOpacity wRotation wId wImagePath".split())
WIDGET.update("w h path wStretchWidth wStretchHeight offsetX offsetY anchor anchors anchorH anchorX horizontalAnchor hAnchor anchorHorizontal anchorV anchorY verticalAnchor vAnchor anchorVertical".split())
# Geometría y apariencia; se excluyen payloads arbitrarios, comandos y claves de servicios.
WIDGET_STYLE = set("fontSize fontFamily color backgroundColor textColor accentColor showSeconds showDate format borderRadius borderWidth backgroundOpacity title label unit location face variant".split())
WIDGET_STYLE.update("sineWave lineThickness lyricsLines lyricsAlignment showNoLyrics continuous textContent".split())
SECRET = re.compile(r"(?i)(-----BEGIN .*PRIVATE KEY|(?:password|passwd|api[_-]?key|access[_-]?token|secret)\s*[=:]\s*['\"]?[^\s'\",}]+)")


def encode(data):
    return json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2).encode() + b"\n"


def safe_path(path):
    path = Path(path).absolute()
    for parent in (path, *path.parents):
        if parent.is_symlink():
            raise ValueError("No se permiten enlaces simbólicos en las rutas del respaldo.")
    return path


def read_regular(path):
    safe_path(path)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as f:
        info = os.fstat(f.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_SIZE:
            raise ValueError("Archivo no regular o demasiado grande.")
        return f.read(MAX_SIZE + 1)


def scalar_tree(value, depth=0):
    if depth > 12:
        raise ValueError("Estructura demasiado profunda.")
    if isinstance(value, dict):
        if len(value) > 200:
            raise ValueError("Demasiados campos.")
        if any(re.search(r"(?i)(password|passwd|secret|token|api.?key|command|^cmd$|^exec$|script)", str(k)) for k in value):
            raise ValueError("El respaldo no admite claves de servicios ni comandos fuera de los atajos.")
        return {str(k): scalar_tree(v, depth + 1) for k, v in value.items()}
    if isinstance(value, list):
        if len(value) > 500:
            raise ValueError("Demasiados elementos.")
        return [scalar_tree(v, depth + 1) for v in value]
    if isinstance(value, str):
        if len(value) > 8192 or SECRET.search(value):
            raise ValueError("Un campo contiene una credencial o un texto demasiado largo.")
    elif isinstance(value, float) and not math.isfinite(value):
        raise ValueError("Un número del respaldo no es finito.")
    elif value is not None and not isinstance(value, (bool, int, float)):
        raise ValueError("Tipo de dato no permitido.")
    return value


def colors(data):
    if not isinstance(data, dict) or set(data) - COLORS or any(not isinstance(v, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", v) for v in data.values()):
        raise ValueError("La paleta contiene campos o colores no válidos.")
    return data


def settings(data, strict=True):
    groups = {"bar": BAR, "dock": DOCK, "theme": THEME}
    flat = {k for k in data if isinstance(k, str) and "." in k and k.split(".", 1)[0] in groups and k.split(".", 1)[1] in groups[k.split(".", 1)[0]]} if isinstance(data, dict) else set()
    if not isinstance(data, dict) or (strict and set(data) - set(groups) - flat):
        raise ValueError("El respaldo solo puede incluir barra, dock y tema.")
    out = {}
    for group, allowed in (("bar", BAR), ("dock", DOCK), ("theme", THEME)):
        if group not in data:
            continue
        value = data[group]
        if not isinstance(value, dict) or (strict and set(value) - allowed):
            raise ValueError("Ajustes de escritorio no reconocidos.")
        out[group] = scalar_tree({k: v for k, v in value.items() if k in allowed})
    if "colors" in out.get("theme", {}):
        colors(out["theme"]["colors"])
    for item in out.get("dock", {}).get("apps", []):
        if not isinstance(item, dict) or set(item) - {"name", "comment", "desktop_id", "icon"}:
            raise ValueError("Las apps del dock deben ser accesos de escritorio sin comandos incrustados.")
        if "desktop_id" in item and (not isinstance(item["desktop_id"], str) or not re.fullmatch(r"[A-Za-z0-9_.-]{1,250}", item["desktop_id"])):
            raise ValueError("Identificador de aplicación del dock no válido.")
    if "time" in out.get("bar", {}) and (not isinstance(out["bar"]["time"], dict) or set(out["bar"]["time"]) - {"format"}):
        raise ValueError("Formato del reloj no válido.")
    if "modules" in out.get("bar", {}) and (not isinstance(out["bar"]["modules"], dict) or set(out["bar"]["modules"]) - {"left", "center", "right"}):
        raise ValueError("Módulos de barra no válidos.")
    def identifiers(value):
        if isinstance(value, list):
            return all(identifiers(v) for v in value)
        return isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,100}", value)
    if any(not identifiers(value) for value in out.get("bar", {}).get("modules", {}).values()):
        raise ValueError("Los módulos solo pueden contener identificadores, sin instrucciones.")
    if "menuItems" in out.get("bar", {}) and not identifiers(out["bar"]["menuItems"]):
        raise ValueError("El menú solo puede contener identificadores, sin instrucciones.")
    for key in flat:
        group, field = key.split(".", 1)
        out[key] = settings({group: {field: data[key]}})[group][field]
    return out


def widget_layout(data, strict=True):
    if not isinstance(data, list) or len(data) > 200:
        raise ValueError("Distribución de widgets no válida.")
    result = []
    for row in data:
        if not isinstance(row, dict) or (strict and set(row) - WIDGET - WIDGET_STYLE):
            raise ValueError("El widget contiene campos no permitidos.")
        result.append(scalar_tree({k: v for k, v in row.items() if k in WIDGET | WIDGET_STYLE}))
    return result


def monitor_name(name):
    if not isinstance(name, str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,160}", name):
        raise ValueError("Nombre de monitor no válido.")
    return name


class Desktop:
    def __init__(self, home=None, state=None, settings_path=None):
        self.home = Path(home or Path.home())
        self.state = Path(state or os.environ.get("QS_STATE_DIR") or self.home / ".local/state/serpantinum")
        self.settings_path = Path(settings_path or os.environ.get("QS_SETTINGS") or self.home / ".config/serpantinum/settings.json")
        self.history = self.state / "desktop-backups"

    def collect(self):
        result = {"format": "xiuhcoatl-desktop", "version": 1, "created": datetime.now(timezone.utc).isoformat(), "host": socket.gethostname(), "settings": {}, "widgets": {}, "colors": {}}
        if self.settings_path.exists():
            result["settings"] = settings(json.loads(read_regular(self.settings_path)), strict=False)
        widgets = self.state / "widgets"
        safe_path(widgets)
        if widgets.exists():
            for path in sorted(widgets.glob("*/layout.json"))[:32]:
                result["widgets"][monitor_name(path.parent.name)] = widget_layout(json.loads(read_regular(path)), strict=False)
        for name in ("qs_colors.json", "qs_matugen_colors.json"):
            path = self.state / name
            if path.exists():
                raw = json.loads(read_regular(path))
                # Los colores de matugen incluyen metadatos, nunca se respaldan.
                result["colors"][name] = colors({k: v for k, v in raw.items() if k in COLORS})
        shortcut = self.home / ".config/hypr/config/keybinds.lua"
        if shortcut.exists():
            text = read_regular(shortcut).decode("utf-8")
            if SECRET.search(text):
                raise ValueError("Los atajos contienen una posible credencial. Retírala antes de exportar.")
            result["shortcuts"] = text
        validate(result)
        return result

    def export(self, path, allow_empty=False):
        data = self.collect()
        if not allow_empty and not (data["settings"] or data["widgets"] or data["colors"] or data.get("shortcuts")):
            raise ValueError("Todavía no hay configuración de escritorio que guardar.")
        path = safe_path(Path(path).expanduser())
        if path.exists():
            raise ValueError("Ese archivo ya existe. Elige otro nombre para conservarlo.")
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, name = tempfile.mkstemp(dir=path.parent, prefix=".xiuhcoatl-")
        try:
            os.close(fd)
            with zipfile.ZipFile(name, "w", zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("desktop.json", encode(data))
            # Crear sin sobrescribir un archivo que aparezca mientras se exporta.
            os.link(name, path)
        finally:
            Path(name).unlink(missing_ok=True)
        return {"ok": True, "message": "Escritorio guardado.", "path": str(path)}

    def restore(self, path, digest, trust_shortcuts=False, mappings=None):
        raw, data = load_archive(path)
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError("El archivo cambió desde la vista previa. Revísalo otra vez.")
        if data.get("shortcuts") and not trust_shortcuts:
            raise ValueError("Los atajos pueden ejecutar aplicaciones. Confirma que confías en su origen.")
        mappings = mappings or {}
        if set(mappings) - set(data["widgets"]):
            raise ValueError("El monitor de origen no existe en el respaldo.")
        destinations = [monitor_name(mappings.get(k, k)) for k in data["widgets"]]
        if len(set(destinations)) != len(destinations):
            raise ValueError("Cada distribución debe tener un monitor de destino distinto.")
        targets = {}
        if data["settings"]:
            current = json.loads(read_regular(self.settings_path)) if self.settings_path.exists() else {}
            if not isinstance(current, dict):
                raise ValueError("Los ajustes actuales no son válidos; no se modificaron.")
            for group, value in data["settings"].items():
                if "." in group:
                    current[group] = value
                    continue
                existing = current.get(group) or {}
                current[group] = {**existing, **value}
            targets[self.settings_path] = encode(current)
        for name, value in data["widgets"].items():
            targets[self.state / "widgets" / monitor_name(mappings.get(name, name)) / "layout.json"] = encode(value)
        for name, value in data["colors"].items():
            targets[self.state / name] = encode(value)
        if "shortcuts" in data:
            targets[self.home / ".config/hypr/config/keybinds.lua"] = data["shortcuts"].encode()
        originals = {}
        for target in targets:
            safe_path(target)
            originals[target] = (read_regular(target), stat.S_IMODE(target.stat().st_mode)) if target.exists() else None
        safe_path(self.history)
        self.history.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        previous = self.history / ("antes-de-restaurar-" + stamp + ".xiuhcoatl.zip")
        self.export(previous, allow_empty=True)  # También permite trasladar a un escritorio nuevo.
        written = []
        try:
            for target, content in targets.items():
                atomic_write(target, content, originals[target][1] if originals[target] else 0o600)
                written.append(target)
        except Exception:
            failed = []
            for target in reversed(written):
                try:
                    original = originals[target]
                    if original is None:
                        target.unlink(missing_ok=True)
                    else:
                        atomic_write(target, *original)
                except Exception:
                    failed.append(str(target))
            if failed:
                raise ValueError("Restauración interrumpida. Conserva el respaldo previo en " + str(previous) + "; revisa permisos para recuperar: " + ", ".join(failed))
            raise ValueError("La restauración falló; se recuperaron los archivos originales. Respaldo previo: " + str(previous))
        return {"ok": True, "message": "Escritorio recuperado. Reinicia Xiuhcóatl para cargar widgets y colores; recarga Hyprland para aplicar atajos.", "previous": str(previous), "files": len(targets)}


def atomic_write(path, content, mode=0o600):
    safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=".xiuhcoatl-")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def validate(data):
    allowed = {"format", "version", "created", "host", "settings", "widgets", "colors", "shortcuts"}
    if not isinstance(data, dict) or set(data) - allowed or data.get("format") != "xiuhcoatl-desktop" or data.get("version") != 1:
        raise ValueError("El archivo no es un respaldo compatible de Xiuhcóatl.")
    if not all(k in data for k in ("settings", "widgets", "colors")):
        raise ValueError("El respaldo está incompleto.")
    settings(data["settings"])
    if not isinstance(data["widgets"], dict) or len(data["widgets"]) > 32:
        raise ValueError("Lista de monitores no válida.")
    for name, layout in data["widgets"].items():
        monitor_name(name)
        widget_layout(layout)
    if not isinstance(data["colors"], dict) or set(data["colors"]) - {"qs_colors.json", "qs_matugen_colors.json"}:
        raise ValueError("Archivo de colores no permitido.")
    for value in data["colors"].values():
        colors(value)
    if "shortcuts" in data and (not isinstance(data["shortcuts"], str) or len(data["shortcuts"]) > 1_000_000 or SECRET.search(data["shortcuts"])):
        raise ValueError("Atajos no válidos o con posibles credenciales.")
    scalar_tree({k: data[k] for k in ("host", "created") if k in data})


def load_archive(path):
    raw = read_regular(Path(path).expanduser())
    if len(raw) > MAX_SIZE:
        raise ValueError("El respaldo excede 8 MiB.")
    import io
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        info = archive.infolist()
        if len(info) != 1 or info[0].filename != "desktop.json" or info[0].file_size > MAX_SIZE or info[0].flag_bits & 1 or stat.S_IFMT(info[0].external_attr >> 16) not in {0, stat.S_IFREG}:
            raise ValueError("El archivo debe contener únicamente desktop.json regular, sin enlaces ni rutas externas.")
        data = json.loads(archive.read(info[0]))
    validate(data)
    return raw, data


def preview(path):
    raw, data = load_archive(path)
    return {"ok": True, "digest": hashlib.sha256(raw).hexdigest(), "host": data.get("host", ""), "created": data.get("created", ""), "groups": list(data["settings"]), "monitors": list(data["widgets"]), "widgetCount": sum(len(v) for v in data["widgets"].values()), "colorFiles": list(data["colors"]), "shortcuts": "shortcuts" in data, "shortcutPreview": data.get("shortcuts", ""), "message": "Revisa el origen y los atajos antes de recuperar. Los programas y las imágenes no se incluyen; las rutas pueden necesitar ajustes en otro equipo."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    exp = sub.add_parser("export")
    exp.add_argument("path", nargs="?")
    pre = sub.add_parser("preview")
    pre.add_argument("path")
    res = sub.add_parser("restore")
    res.add_argument("path")
    res.add_argument("--digest", required=True)
    res.add_argument("--trust-shortcuts", action="store_true")
    res.add_argument("--map", action="append", default=[], metavar="ORIGEN=DESTINO")
    args = parser.parse_args()
    try:
        desktop = Desktop()
        if args.action == "preview":
            result = preview(args.path)
        elif args.action == "export":
            path = args.path or desktop.history / ("escritorio-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".xiuhcoatl.zip")
            result = desktop.export(path)
        else:
            result = desktop.restore(args.path, args.digest, args.trust_shortcuts, dict(pair.split("=", 1) for pair in args.map))
        print(json.dumps(result, ensure_ascii=False))
    except Exception as error:
        print(json.dumps({"ok": False, "message": str(error) if isinstance(error, ValueError) else "No se pudo leer o guardar el respaldo. Revisa el formato y los permisos."}, ensure_ascii=False))
        sys.exit(1)


if __name__ == "__main__":
    main()
