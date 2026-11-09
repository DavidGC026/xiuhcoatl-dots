local mainMod = _G.mainMod or "SUPER"
local terminal = _G.terminal or "kitty"

-- Descripción "Categoría: texto" para el menú de atajos (Super + F1), que la
-- lee de `hyprctl binds -j`. Los atajos sin descripción no salen en el menú.
local function d(description, opts)
  opts = opts or {}
  opts.description = description
  return opts
end

-- Si el scratchpad está abierto, la app nueva caería dentro de él (flotante y
-- al 85 %): primero se oculta para que abra en el espacio normal.
local function launch(cmd)
  return function()
    local special = hl.get_active_special_workspace and hl.get_active_special_workspace()
    if special then
      local name = special.name:gsub("^special:", "")
      hl.dispatch(hl.dsp.workspace.toggle_special(name))
    end
    hl.dispatch(hl.dsp.exec_cmd(cmd))
  end
end

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), d("Ventanas: Arrastrar ventana con el mouse", { mouse = true }))
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), d("Ventanas: Redimensionar con el mouse", { mouse = true }))

hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), d("Ventanas: Achicar a lo ancho", { repeating = true }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), d("Ventanas: Agrandar a lo ancho", { repeating = true }))
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), d("Ventanas: Achicar a lo alto", { repeating = true }))
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), d("Ventanas: Agrandar a lo alto", { repeating = true }))

hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.move({ direction = "l" }), d("Ventanas: Mover a la izquierda"))
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.move({ direction = "r" }), d("Ventanas: Mover a la derecha"))
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.move({ direction = "u" }), d("Ventanas: Mover arriba"))
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.move({ direction = "d" }), d("Ventanas: Mover abajo"))

hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }), d("Ventanas: Enfocar a la izquierda"))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }), d("Ventanas: Enfocar a la derecha"))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }), d("Ventanas: Enfocar arriba"))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }), d("Ventanas: Enfocar abajo"))

hl.bind(mainMod .. " + Q", hl.dsp.window.close(), d("Ventanas: Cerrar ventana"))
hl.bind("ALT + F4", hl.dsp.window.close(), d("Ventanas: Cerrar ventana"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }), d("Ventanas: Alternar flotante / mosaico"))
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), d("Ventanas: Maximizar"))
hl.bind(mainMod .. " + ALT + RETURN", hl.dsp.window.fullscreen({ mode = "maximized" }), d("Ventanas: Maximizar"))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.window.fullscreen(), d("Ventanas: Pantalla completa"))
hl.bind(mainMod .. " + ALT + P", hl.dsp.window.pseudo(), d("Ventanas: Pseudo-mosaico"))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), d("Ventanas: Girar la división"))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("serpantinum brightness lower"), d("Sistema: Bajar brillo", { locked = true }))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("serpantinum brightness raise"), d("Sistema: Subir brillo", { locked = true }))
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("serpantinum lock"), d("Sistema: Bloquear sesión", { locked = true }))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("serpantinum lock"), d("Sistema: Bloquear sesión", { repeating = true, locked = true }))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("serpantinum set notifications dnd toggle"), d("Sistema: No molestar"))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("dvg-pantallas"), d("Sistema: Pantallas en red"))

hl.bind("Print", hl.dsp.exec_cmd("serpantinum screenshot"), d("Captura: Captura de región", { locked = true }))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --edit"), d("Captura: Región y editar", { locked = true }))
hl.bind("SUPER + Print", hl.dsp.exec_cmd("serpantinum screenshot --full"), d("Captura: Pantalla completa", { locked = true }))
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --full --edit"), d("Captura: Pantalla completa y editar", { locked = true }))
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd("xiuhcoatl-grabar pantalla"), d("Captura: Grabar pantalla (iniciar / detener)"))
hl.bind(mainMod .. " + ALT + SHIFT + R", hl.dsp.exec_cmd("xiuhcoatl-grabar region"), d("Captura: Grabar región (iniciar / detener)"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("xiuhcoatl-color"), d("Captura: Selector de color (copia el hex)"))

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("playerctl play-pause"), d("Multimedia: Reproducir / pausar", { locked = true }))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), d("Multimedia: Pista anterior", { locked = true }))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), d("Multimedia: Pista siguiente", { locked = true }))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("serpantinum volume mic-toggle"), d("Multimedia: Silenciar micrófono", { locked = true }))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("serpantinum volume mute-toggle"), d("Multimedia: Silenciar audio", { locked = true }))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("serpantinum volume lower"), d("Multimedia: Bajar volumen", { repeating = true, locked = true }))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("serpantinum volume raise"), d("Multimedia: Subir volumen", { repeating = true, locked = true }))

-- Apps: navegador predeterminado, carpeta personal con el gestor predeterminado
-- (Tanatl en DVG OS) y terminal.
hl.bind(mainMod .. " + F", launch([[sh -c 'gtk-launch "$(xdg-settings get default-web-browser)"']]), d("Apps: Navegador"))
hl.bind(mainMod .. " + E", launch("dvg-archivos"), d("Apps: Archivos"))
hl.bind(mainMod .. " + RETURN", launch(terminal), d("Apps: Terminal"))
hl.bind(mainMod .. " + T", launch(terminal), d("Apps: Terminal"))

hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("serpantinum reload"), d("Shell: Recargar Xiuhcóatl"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"), d("Shell: Historial del portapapeles"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("serpantinum msg toggle launcher"), d("Shell: Lanzador de apps"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("serpantinum msg toggle music"), d("Shell: Panel de música"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("serpantinum msg toggle system"), d("Shell: Panel del sistema"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("serpantinum msg toggle wallpaper"), d("Shell: Fondos de pantalla"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("serpantinum msg toggle calendar"), d("Shell: Calendario"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("serpantinum msg toggle network"), d("Shell: Red"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("serpantinum msg toggle volume"), d("Shell: Volumen"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("serpantinum msg toggle settings"), d("Shell: Ajustes de Xiuhcóatl"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("serpantinum msg bar autohide"), d("Shell: Ocultar la barra automáticamente"))
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("xiuhcoatl-atajos"), d("Shell: Menú de atajos"))

-- Fila numérica: 1…0 y, con teclado latinoamericano, las dos teclas contiguas
-- (' y ¿). En el menú solo se describe el 1 para no repetir 24 líneas.
local wsKeys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "apostrophe", "questiondown" }
for i, key in ipairs(wsKeys) do
  local ws = tostring(i)
  local goOpts = i == 1 and d("Espacios: Ir al espacio 1–12 (1…0, ' y ¿)") or nil
  local moveOpts = i == 1 and d("Espacios: Mover ventana al espacio 1–12") or nil
  hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws), goOpts)
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws .. " move"), moveOpts)
end

-- Scratchpad: espacio especial que aparece encima del actual.
hl.bind(mainMod .. " + Z", hl.dsp.workspace.toggle_special("scratch"), d("Espacios: Mostrar / ocultar scratchpad"))
-- Alterna la ventana enfocada entre el scratchpad y el espacio actual. Las
-- reglas de tamaño y centrado solo aplican al abrir una ventana; como aquí se
-- mueve una ya abierta, se flota, redimensiona y centra a mano.
hl.bind(mainMod .. " + SHIFT + Z", function()
  local win = hl.get_active_window()
  if not win then return end
  local mon = win.monitor or hl.get_monitor_at_cursor()

  if win.workspace and win.workspace.name == "special:scratch" then
    local ws = mon and mon.active_workspace or hl.get_active_workspace()
    if not ws then return end
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws.id), window = win }))
    if win.floating then
      hl.dispatch(hl.dsp.window.float({ action = "toggle", window = win }))
    end
    return
  end

  hl.dispatch(hl.dsp.window.move({ workspace = "special:scratch", window = win }))
  if not win.floating then
    hl.dispatch(hl.dsp.window.float({ action = "toggle", window = win }))
  end
  if mon then
    local w = math.floor(mon.width / mon.scale * 0.85)
    local h = math.floor(mon.height / mon.scale * 0.85)
    hl.dispatch(hl.dsp.window.resize({ x = w, y = h, relative = false, window = win }))
  end
  hl.dispatch(hl.dsp.window.center({ window = win }))
end, d("Espacios: Meter / sacar ventana del scratchpad"))
