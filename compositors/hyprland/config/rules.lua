-- Reglas de ventana de Xiuhcóatl.

-- Dialogos de archivo (GTK/portal) flotando y centrados.
hl.window_rule({
  name = "dialogos-archivo",
  match = { title = "^(Abrir|Guardar|Seleccionar|Open|Save|Select).*(archivo|carpeta|File|Folder|Files).*$" },
  float = true,
  center = true,
  size = "60% 65%",
})
hl.window_rule({
  name = "portal-selector-archivos",
  match = { class = "^(xdg-desktop-portal-gtk|org.freedesktop.impl.portal.desktop.kde)$" },
  float = true,
  center = true,
  size = "60% 65%",
})

-- Picture-in-Picture de los navegadores: flotante, fijo en todos los
-- espacios y en la esquina inferior derecha.
hl.window_rule({
  name = "picture-in-picture",
  match = { title = "^(Picture.in.[Pp]icture|Imagen en imagen)$" },
  float = true,
  pin = true,
  keep_aspect_ratio = true,
  size = "480 270",
  move = "monitor_w-500 monitor_h-300",
})

-- Utilidades pequenas: flotantes y centradas.
hl.window_rule({
  name = "utilidades-flotantes",
  match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol|com.github.wwmm.easyeffects|blueman-manager|nm-connection-editor|org.gnome.Calculator|hyprland-share-picker)$" },
  float = true,
  center = true,
  size = "55% 60%",
})

-- Scratchpad: si abres una terminal ahi, que flote grande y centrada.
hl.window_rule({
  name = "scratchpad-flotante",
  match = { workspace = "special:scratch" },
  float = true,
  center = true,
  size = "85% 85%",
})
