<div align="center">
  <img src="marca/logo-oro-256.png" alt="Xiuhcóatl" width="128" />

  # Xiuhcóatl

  El shell de escritorio de **DVG OS** sobre Hyprland.
</div>

Xiuhcóatl («serpiente de fuego» en náhuatl) es un fork de
[serpantinum](https://github.com/ilyamiro/serpantinum) de @ilyamiro, hecho con
Quickshell. Parte de serpantinum 2.5.0 (`upstream-version.txt`) y le agrega lo
propio de DVG OS:

- **Tema DVG Carmín y Oro** de fábrica, con la paleta de la marca.
- **Actualizaciones desde el repositorio de DVG OS** (dvgos.dvguzman.com y su
  espejo). En Acerca de, Actualizar abre DVG Tools y Reinstalar usa pacman. Ya no
  hay ningún `curl | eval` a GitHub.
- **«No molestar»** en el menú de la barra y con Super+Shift+N, apagado de fábrica.
- **Atajos en español** con un menú de atajos (Super+F1), grabación de pantalla,
  selector de color, scratchpad y reglas de ventanas.
- **Fondos de DVG incluidos** (escritorio, castillo y taberna) y `xiuhcoatl-fondos
  --coleccion` para bajar la colección de serpantinum desde el repo de su autor
  (~600 MB); el primer inicio lo ofrece con una notificación.
- **Integración con DVG OS**: Pantallas en red (Super+K y acciones rápidas),
  Tanatl y Temoa en el dock, fondos de DVG, teclado del instalador y primer
  inicio con el preset «DVG OS».

## Nombres internos

Para seguir trayendo arreglos de upstream, lo interno conserva el nombre de
serpantinum: el demonio `serpantinumd`, los binarios `serpantinum-core`,
`serpantinum-gamma` y `serpantinum-audio`, las rutas `~/.config/serpantinum` y
`~/.local/state/serpantinum`, y los nombres de D-Bus `org.serpantinum.*`. El
comando `xiuhcoatl` es el mismo CLI que `serpantinum`.

## Instalación

En DVG OS viene con el escritorio Hyprland (`dvg-hyprland`). El paquete
`xiuhcoatl` está en el repositorio `[dvg-os]`:

```sh
sudo pacman -S xiuhcoatl
```

## Traer cambios de upstream

```sh
git fetch upstream --tags
git merge v2.x.y          # resolver conflictos y actualizar upstream-version.txt
```

## Licencia

AGPL-3.0, igual que serpantinum (`LICENSE.md`). El README original de upstream
está en `README.serpantinum.md`.
