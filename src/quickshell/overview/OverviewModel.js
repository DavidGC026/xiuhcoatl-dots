.pragma library

// Pure helpers shared by the overview and its offline regression checks.
function snapshot(windows) {
    return windows.map(function(win) {
        let native = win.native;
        let ws = native && native.workspace ? native.workspace : null;
        return {
            id: win.id, nativeId: win.nativeId, native: native,
            title: native && native.title ? native.title : (win.title || win.appId || "Ventana sin título"),
            appId: win.appId || "Aplicación", desktopId: win.desktopId || "",
            workspaceLabel: ws ? String(ws.name || ws.id) : String(win.workspaceLabel || ""),
            workspaceId: ws ? ws.id : (win.workspace >= 0 ? win.workspace + 1 : -1),
            output: native && native.monitor ? native.monitor.name : (win.output || ""),
            focused: native ? Boolean(native.activated) : Boolean(win.focused),
            lastFocus: win.lastFocus || 0
        };
    }).sort(function(a, b) {
        if (a.focused !== b.focused) return a.focused ? -1 : 1;
        return b.lastFocus - a.lastFocus;
    });
}

function filtered(windows, query, workspace) {
    let words = String(query || "").toLocaleLowerCase().trim().split(/\s+/).filter(Boolean);
    return windows.filter(function(win) {
        if (workspace !== "" && win.workspaceLabel !== workspace) return false;
        let haystack = [win.title, win.appId, win.workspaceLabel, win.output].join(" ").toLocaleLowerCase();
        return words.every(function(word) { return haystack.indexOf(word) >= 0; });
    });
}

function workspaces(nativeWorkspaces, windows) {
    let entries = Object.create(null);
    // Include empty destinations as well as named and special workspaces.
    for (let id = 1; id <= 10; id++) entries[String(id)] = { label: String(id), id: id, count: 0, active: false };
    nativeWorkspaces.forEach(function(ws) {
        let label = String(ws.name || ws.id);
        if (ws.id > 0 && label !== String(ws.id)) delete entries[String(ws.id)];
        entries[label] = { label: label, id: ws.id, count: 0, active: Boolean(ws.active) };
    });
    windows.forEach(function(win) {
        let label = win.workspaceLabel;
        if (!label) return;
        if (!entries[label]) entries[label] = { label: label, id: win.workspaceId, count: 0, active: false };
        entries[label].count++;
    });
    return Object.keys(entries).map(function(key) { return entries[key]; }).sort(function(a, b) {
        if (a.id > 0 && b.id > 0) return a.id - b.id;
        if (a.id > 0) return -1;
        if (b.id > 0) return 1;
        return a.label.localeCompare(b.label);
    });
}

function selectedIndex(windows, id) {
    let index = windows.findIndex(function(win) { return win.id === id; });
    return index < 0 && windows.length > 0 ? 0 : index;
}

// Hyprland IPC accepts dispatcher expressions, not shell commands. Quote Lua
// strings explicitly: JSON's \u escapes are not Lua string escapes.
function luaString(value) {
    return '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
        .replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t") + '"';
}

function workspaceTarget(ws) {
    if (ws.label.indexOf("special:") === 0) return ws.label;
    return ws.id > 0 ? String(ws.id) : "name:" + ws.label;
}

function moveCommand(win, ws, usingLua) {
    let address = String(win.nativeId || "").replace(/^address:/, "");
    if (address.indexOf("0x") === 0) address = address.slice(2);
    if (!/^[0-9a-f]+$/i.test(address)) return "";
    let target = workspaceTarget(ws);
    if (usingLua) return "hl.dsp.window.move({ window = " + luaString("address:0x" + address)
        + ", workspace = " + luaString(target) + ", follow = false })";
    // Legacy dispatcher separates the destination and selector with a comma.
    if (/[\r\n,;]/.test(target)) return "";
    return "movetoworkspacesilent " + target + ",address:0x" + address;
}

function sameWindows(previous, next) {
    if (previous.length !== next.length) return false;
    let keys = ["id", "nativeId", "native", "title", "appId", "desktopId", "workspaceLabel", "workspaceId", "output", "focused", "lastFocus"];
    return previous.every(function(win, index) {
        return keys.every(function(key) { return win[key] === next[index][key]; });
    });
}

function sameWorkspaces(previous, next) {
    if (previous.length !== next.length) return false;
    return previous.every(function(ws, index) {
        let other = next[index];
        return ws.label === other.label && ws.id === other.id && ws.count === other.count && ws.active === other.active;
    });
}

function workspaceCommand(ws, usingLua) {
    let target = workspaceTarget(ws);
    if (usingLua) return "hl.dsp.focus({ workspace = " + luaString(target) + " })";
    if (/[\r\n,;]/.test(target)) return "";
    return target.indexOf("special:") === 0 ? "togglespecialworkspace " + target.slice(8) : "workspace " + target;
}
