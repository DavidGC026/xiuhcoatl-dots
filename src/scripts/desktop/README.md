# Equipos y respaldo del escritorio

Ambos comandos solo necesitan Python 3 (biblioteca estándar). Responden un objeto JSON por stdout, con `ok` y un mensaje en español cuando corresponde. No requieren instalar Tailscale o Syncthing para abrir los paneles.

## Mis equipos

`python3 devices.py status` consulta `tailscale status --json` (4 s), la configuración local de Syncthing y su API REST en localhost (1.5 s por petición, cuatro carpetas simultáneas, máximo 16 carpetas). No se buscan ni inventan recursos compartidos de cada peer. El estado incluye equipos conectados y desconectados, IP, carpetas de Syncthing, archivos pendientes **por recibir en este equipo**, errores y hasta 20 nombres por carpeta. Actualizar es una acción explícita; no hay sondeo continuo de archivos.

La clave de Syncthing se lee de su XML solo en memoria, nunca sale por JSON, argumentos de procesos ni mensajes de error. Se bloquean interfaces remotas, proxies y redirecciones HTTP. HTTPS usa la validación normal del certificado; si el certificado local no es de confianza, el panel explica cómo revisar el servicio. Se leen las ubicaciones modernas de estado y las anteriores de configuración/datos respetando XDG.

Los accesos de carpetas proceden de Syncthing local, marcadores de red GTK 3/4 y el archivo `$XDG_CONFIG_HOME/xiuhcoatl/equipos.json` (`~/.config/xiuhcoatl/equipos.json` por defecto):

```json
[
  {"label": "Documentos del servidor", "uri": "sftp://mi-equipo/ruta/real", "peer": "mi-equipo"}
]
```

El panel permite agregar un acceso y abre únicamente IDs de accesos existentes. También se puede usar `python3 devices.py add NOMBRE URI [--peer EQUIPO]`. Protocolos: `smb`, `sftp`, `dav`, `davs`, `file`; sin contraseñas en URL, parámetros ni fragmentos. Las credenciales y permisos los gestiona el explorador. Los procesos reciben listas de argumentos, sin intérprete de shell.

## Guardar y recuperar

```sh
xiuhcoatl-escritorio export /ruta/escritorio.xiuhcoatl.zip
xiuhcoatl-escritorio preview /ruta/escritorio.xiuhcoatl.zip
xiuhcoatl-escritorio restore /ruta/escritorio.xiuhcoatl.zip --digest SHA256_DE_LA_VISTA_PREVIA
```

Si hay atajos, recuperar requiere además `--trust-shortcuts`. Para trasladar widgets a otro monitor: `--map eDP-1=HDMI-A-1` (repetible). La interfaz permite revisar los atajos, confirmar su origen y remapear una distribución; la CLI admite varios remapeos.

Sin ruta, exportar guarda en `~/.local/state/serpantinum/desktop-backups/` (respeta `QS_STATE_DIR`). Nunca sobrescribe un archivo existente.

El ZIP v1 contiene **solo `desktop.json`**, con `format: xiuhcoatl-desktop`, versión, fecha, host y estas listas positivas:

- `settings`: barra, dock y tema (incluye estilos de indicadores, tipografía, transparencia, blur, colores y aliases planos reconocidos). Se lee el archivo de Config (`QS_SETTINGS` o `~/.config/serpantinum/settings.json`). Al importar conserva otras secciones y campos ajenos.
- `widgets`: distribuciones `widgets/<monitor>/layout.json`, geometría, tipo, variante, anclajes y apariencia reconocida en el registro de widgets. No incluye datos privados de las aplicaciones, notas guardadas aparte ni propiedades de extensiones desconocidas.
- `colors`: `qs_colors.json` y `qs_matugen_colors.json`, solo nombres y valores hexadecimales de la paleta.
- `shortcuts`: `~/.config/hypr/config/keybinds.lua`, opcional. Puede ejecutar programas al pulsar teclas; se muestra íntegro y exige confirmar el origen antes de restaurarlo. Se rechazan indicadores de credenciales y llaves privadas.

No incluye SSH, Syncthing, cuentas, claves de servicios, historial, fondos, binarios ni otros archivos de Hyprland. Las apps del dock son IDs de entradas de escritorio, sin comandos incrustados. Menús/módulos solo aceptan identificadores; campos de comandos y credenciales están bloqueados. Imágenes y programas se conservan como referencias y deberán existir en el equipo destino.

La lectura rechaza rutas adicionales, entradas duplicadas, enlaces simbólicos/archivos especiales, ZIP cifrado y contenido mayor de 8 MiB. No se extrae el ZIP al disco. Las rutas locales se derivan del esquema, no del archivo, y no admiten symlinks. El SHA-256 liga la restauración a la vista previa del mismo archivo.

Antes de escribir, se valida el respaldo, cada destino y se guarda automáticamente una copia del escritorio anterior. Cada escritura usa un archivo temporal y reemplazo atómico; ante fallo se revierten en orden inverso los archivos ya cambiados, conservando bytes y permisos originales. Un escritorio nuevo permite snapshot vacío. Si el disco o los permisos impiden también revertir, el error identifica los archivos y la copia de recuperación. No sustituye una copia de seguridad del disco ni garantiza una transacción entre archivos ante un corte de energía. La restauración no reinicia procesos: el mensaje pide reiniciar Xiuhcóatl y recargar Hyprland.

## Verificación

`python3 -m unittest discover -s tests/desktop -v` usa únicamente directorios temporales y mocks de servicios. No modifica configuraciones del usuario.
