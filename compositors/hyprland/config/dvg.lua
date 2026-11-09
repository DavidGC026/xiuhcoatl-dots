-- DVG OS: ajustes de Xiuhcóatl que dependen del sistema instalado.
--
-- Todo va envuelto en pcall: si el Lua de Hyprland no trae io/os, la sesión
-- arranca igual con el resto de la configuración.

-- Fondos de DVG en el selector. La carpeta es del usuario: lo que copie ahí
-- también aparece.
pcall(function()
  hl.env("WALLPAPER_DIR", os.getenv("HOME") .. "/.local/share/dvg-os/fondos")
end)

-- El teclado que se eligió al instalar: Calamares lo deja en la config de X11,
-- que Hyprland no lee.
pcall(function()
  local archivo = io.open("/etc/X11/xorg.conf.d/00-keyboard.conf", "r")
  if not archivo then return end
  local texto = archivo:read("*a")
  archivo:close()
  local distribucion = texto:match('"XkbLayout"%s+"([^"]+)"')
  local variante = texto:match('"XkbVariant"%s+"([^"]*)"')
  if distribucion then
    hl.config({
      input = {
        kb_layout = distribucion,
        kb_variant = variante or "",
        kb_options = "grp:alt_shift_toggle",
        accel_profile = "flat",
        touchpad = { natural_scroll = true, disable_while_typing = false },
      },
    })
  end
end)

-- Carpetas del usuario en su idioma (~/Imágenes, ~/Vídeos): el shell guarda las
-- grabaciones en $XDG_VIDEOS_DIR y sin la variable usaría ~/Videos. En el
-- primer inicio el archivo puede no existir todavía; desde el segundo ya sale.
pcall(function()
  local home = os.getenv("HOME")
  local archivo = io.open(home .. "/.config/user-dirs.dirs", "r")
  if not archivo then return end
  for linea in archivo:lines() do
    local nombre, valor = linea:match('^(XDG_%u+_DIR)="(.*)"$')
    if (nombre == "XDG_PICTURES_DIR" or nombre == "XDG_VIDEOS_DIR") and valor then
      hl.env(nombre, (valor:gsub("^%$HOME", home)))
    end
  end
  archivo:close()
end)

-- Primer inicio: fondo, tema, idioma, carpeta de capturas y preset de DVG.
hl.on("hyprland.start", function()
  hl.exec_cmd("xiuhcoatl-primer-inicio")
end)
