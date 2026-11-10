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

## Herramientas de escritorio (1.1.0)

En el lanzador o en la parte superior del panel del sistema están **Ventanas**,
**Equipos**, **Respaldo** y **Modos**. También se pueden abrir desde la terminal:

| Herramienta | Comando | Atajo en la configuración nueva |
| --- | --- | --- |
| Vista general | `xiuhcoatl vista` | Super+Tab |
| Mis equipos | `xiuhcoatl equipos` | Super+Shift+E |
| Guardar y recuperar | `xiuhcoatl respaldo` | Super+Shift+S |
| Presentación y modo ligero | `xiuhcoatl modos` | Super+Shift+P |

Las configuraciones personales de Hyprland se conservan al actualizar; los atajos
nuevos se pueden incorporar desde `compositors/hyprland/config/keybinds.lua`.
La vista general busca por título, aplicación o escritorio. Selecciona una ventana
y usa Mover para elegir destino; las miniaturas dependen del permiso y soporte de
captura del compositor. Las ventanas sin captura mantienen su tarjeta seleccionable.

El modo presentación oculta y silencia los avisos (también los críticos), guarda
su historial e impide la inactividad. Muestra si la protección de suspensión del
sistema está disponible. Al salir o reiniciar el shell se liberan los inhibidores;
No molestar y los temporizadores personales conservan su configuración anterior.
`xiuhcoatl presentacion` alterna este modo.

El modo ligero reduce las animaciones, elimina transparencias y pausa los fondos
de video. Puede activarse manualmente o automáticamente con batería. Al desactivarse
se recuperan las preferencias visuales anteriores. `xiuhcoatl ligero` lo alterna.

Mis equipos usa Tailscale y Syncthing cuando están instalados y funcionando. Los
accesos a carpetas deben existir como marcadores o configurarse en el panel;
no se adivinan rutas ni se crean recursos compartidos. Los servicios no se instalan
ni se activan automáticamente.

Los respaldos `.xiuhcoatl.zip` incluyen barra, dock, widgets, paleta, tema y atajos;
no incluyen aplicaciones ni las imágenes referenciadas. Antes de restaurar se
muestran el contenido y los atajos, se verifica que el archivo siga siendo el mismo
y se guarda una copia del escritorio actual. En otro monitor se puede adaptar la
distribución. Los atajos pueden ejecutar programas: importa solo los que reconozcas.
También está disponible `xiuhcoatl-escritorio --help`.

## Traer cambios de upstream

```sh
git fetch upstream --tags
git merge v2.x.y          # resolver conflictos y actualizar upstream-version.txt
```

## Licencia

AGPL-3.0, igual que serpantinum (`LICENSE.md`). El README original de upstream
está en `README.serpantinum.md`.
