# Surface RT — preparación de compilación nativa AS2K Stable

**Estado 2026-10-15:** preparación autorizada; compilación e instalación de AS2K como pasos **separados**. El usuario exige usar la Surface RT como host de compilación, minimizar Commander, evitar pruebas exploratorias y conservar la versión funcional de VONTAR.

## Evidencia real: Surface consultada en modo sólo lectura

- Dispositivo en Commander: `surf`; postmarketOS `v26.06`, `armv7l`, kernel `7.0.1-postmarketos-grate`.
- eMMC `/dev/mmcblk0p2` ext4, montado en `/`: 28.6 GiB, 19.4 GiB disponibles en la consulta.
- Ningún almacenamiento USB de datos montado ni visible en `lsblk`. **No formatear ni asumir una ubicación USB.**
- ~1.9 GiB RAM física, ~2.9 GiB swap zram. **Compilar con `J=1` por memoria**, no aplicar `J=3` de VONTAR a este hardware.
- Instalados y verificados: build-base, GCC/G++, make, Git, Python3, PyGObject, GTK3/dev, SDL2/dev, SDL2_ttf/dev, Fontconfig/dev, libX11-dev, libXinerama-dev, linux-headers; `sudo -n` funciona.
- Directorio de usuario `/home/user/Projects/alphasmart` existente; todavía **no hay** checkout `mame-as3k` ni `AS2K-Emulator` en las rutas buscadas.
- No cambiar kernel, DTB, bootloader, red Wi-Fi ni versión postmarketOS.

## Código de referencia (no aplicar todavía observaciones de menús)

- AS2K Stable VONTAR instalado y validado: `36996b91053969661371dc067d49026fab367a47` (núcleo y GUI).
- Donor MAME congelado de la ruta previa Surface/T640: `1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`.
- Las observaciones de UX, menús y persistencia NVRAM se documentan en `docs/AS2K_STABLE_VONTAR_CHECKPOINT_20261015.md` y permanecen pendientes. No convertirlas en cambios del port.
- No distribuir ROM stock, DictROM, NVRAM, ni imágenes bootstrap privadas con el código o binarios.

## Flujo modular (scripts reutilizables)

1. **Entorno**: `scripts/surface-native-prepare.sh`. Audita plataforma/OS; instala con `apk add` **sólo** dependencias ausentes, sin `apk upgrade` ni modificar kernel. Reutiliza el toolchain interno. Guarda estado en `$HOME/Projects/alphasmart/as2k-surf-native/status/environment.status`. No descarga fuentes, no compila, no instala AS2K.
2. **Fuentes**: `scripts/surface-native-fetch-sources.sh`. Se ejecuta únicamente después de confirmar acceso autenticado a los repositorios privados o suministrar las fuentes; intenta obtener **los commits exactos** mediante Git, con staging temporal y sin sobreescribir directorios existentes. Deja resultado `sources.status`. Si falla autenticación/revisión, marca BLOCKED en lugar de sustituir la revisión.
3. **Compilación nativa**: `scripts/surface-native-build.sh` en la propia Surface, NO T640/VONTAR. Requiere `environment.status=PASS`, fuentes correctas, 10 GiB disponibles, y ejecuta `build-stable-core.sh` con **un** proceso compilador. Fuerza `MAKEFLAGS="ARCHITECTURE="` porque el makefile donor MAME detecta erróneamente ARMv7 como `_x86`. Desactiva Qt, XInput/OpenGL y subsistemas opcionales, emplea backend DRC C, `OPTIMIZE=1`, y valida ELF ARM32 y `./as2k -validate`. Salida `AS2K-Emulator/out/as2k-bin` y `build.status`.
4. **Instalación controlada**: `scripts/surface-native-install.sh` se lanza por separado tras build PASS y autorización. Construye `/usr/local` en staging, respalda los componentes instalados y los coloca en rutas oficiales con rollback ante fallo, sin copiar/alterar `~/.config/as2k`, `~/.local/share/as2k` ni NVRAM. Verifica núcleo y sintaxis GTK sin crear `__pycache__` en el directorio root-owned.

### Cómo lanzar los scripts en Surface

Ejemplos **para una ejecución posterior expresamente autorizada**, desde una copia completa del repositorio:

```sh
sh scripts/surface-native-prepare.sh
sh scripts/surface-native-fetch-sources.sh
sh scripts/surface-native-build.sh
sh scripts/surface-native-install.sh
```

La preparación inicial puede distribuirse como un SH independiente por Commander sin requerir clonar antes repositorios privados. Los demás scripts se guardan en GitHub y pueden llevarse juntos al directorio `$HOME/Projects/alphasmart/as2k-surf-native/scripts/`. Todos dejan PASS/FAIL legible, pensando en procesos desatendidos y **consultas consolidadas** de Commander.

**Alcance inmediato:** preparar/validar dependencias y depositar los scripts. No compilar AS2K ni instalar el emulador sin autorización posterior. No repetir pruebas DIAG.

## Criterios de bloqueo y recuperación

- Ausencia de USB: usar eMMC interno; no inventar rutas `/media/usb`.
- Repositorios GitHub privados sin credenciales en Surface: no solicitar o almacenar secretos; declarar `BLOCKED_SOURCE_AUTH` y planificar transferencia privada de fuentes desde máquina autorizada.
- Falta de espacio, commit equivocado, cambios locales, fallo de `apk` o memoria: parar con estado FAIL/BLOCKED; no reintentar a ciegas.
- Si MAME presenta el ICE GCC que afectó la compilación cruzada T640, registrarlo; **no aplicar** automáticamente las soluciones `-O0`/parches a toda la compilación local.
- El actual `as2k-launcher.sh` tiene una incidencia de NVRAM al cerrar y sigue siendo parte del baseline; no corregirla indirectamente durante el port.

## Evidencia y consumos de Commander

La primera consulta consolidada real de Surface confirmó arquitectura, paquetes, RAM/zram, eMMC, ausencia de USB, estado administrativo y directorios. Fases siguientes: una llamada para instalar/verificar entorno y depositar scripts; otra consulta sólo si el job permanece RUNNING o presenta FAIL. No desperdiciar llamadas en polling repetido.
