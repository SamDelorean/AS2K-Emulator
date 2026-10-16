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


## Resultado real de preparación — Surface RT

- **`environment.status: PASS STEP=READY`** en `/home/user/Projects/alphasmart/as2k-surf-native/status/environment.status`.
- Registro: `/home/user/Projects/alphasmart/as2k-surf-native/logs/environment-prepare.log`, confirma `PACKAGE_REUSE_PASS: all build dependencies already installed` y `ENVIRONMENT_PASS ARMv7-native postmarketOS-v26.06`.
- Se depositaron y validaron sintácticamente los cuatro scripts en `/home/user/Projects/alphasmart/as2k-surf-native/scripts/`.
- Se comprobó que GTK3, SDL2 y SDL2_ttf, Fontconfig y X11 de desarrollo ya están instalados; **no hubo necesidad de instalar paquetes adicionales**.
- No se descargaron fuentes privadas ni se compiló o instaló AS2K.
- Una primera comprobación de versión postmarketOS falló por formato entrecomillado en `/etc/os-release`; fue corregida en GitHub (`551d200db06ca925e985c2ec2d3020c59b191278`) antes del resultado PASS. Este tipo de error debe detectarse estáticamente en futuras preparaciones.
- Pendiente: transferencia/obtención verificada de las fuentes pinneadas y posterior compilación nativa `J=1`, **sólo mediante instrucción del usuario**. No usar T640 ni cruzada.


## Continuidad — fuentes verificadas y lanzamiento de compilación

- Consulta consolidada en Surface: `status/sources.status = PASS SOURCES_PINNED`.
- AS2K exactamente `36996b91053969661371dc067d49026fab367a47`.
- MAME exactamente `1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`.
- Ambos repositorios residen únicamente en el área privada de trabajo de la Surface: `/home/user/Projects/alphasmart/as2k-surf-native/sources/`.
- Se incorporó y desplegó `scripts/surface-native-run-after-sources.sh`, sintaxis shell verificada, SHA-256 desplegado: `618f397a3d3945285bebcf4c6478547b6a6cd5de6f663790d2137ad9cb9d2a22`.
- Se lanzó desatendido como PID inicial `11076`. Si no hay errores de validación, invoca el constructor nativo `surface-native-build.sh` con `J=1`.
- Archivos para consulta posterior **agrupada** de Commander: `status/native-build-run.status`, `status/build.status`, `logs/native-build-runner.log`, `logs/native-build.log`.
- **No afirmar PASS de compilación sin comprobar `status/build.status = PASS STEP=READY` y `status/native-build-run.status = PASS NATIVE_BUILD_COMPLETE`.**
- No hay instalación automática; `surface-native-install.sh` permanece separado y sin ejecutar.
- No ejecutar consultas repetitivas de progreso. Usar una siguiente lectura consolidada de estado y errores si el usuario pide continuidad.

## Incremento de recuperación — 2026-10-16

**Primera compilación:** `sources.status=PASS SOURCES_PINNED`, `native-build-run.status=RUNNING STEP=NATIVE_COMPILE` quedó obsoleto cuando el proceso terminó por señal externa. `build.status` no apareció y no existe `out/as2k-bin`. En `logs/native-build.log` constan `luaengine.o ... Terminated` y, al salir, `cp: can't stat '/tmp/tmp.ALPPhC/alphasma.cpp'`.

**Auditoría sólo lectura:** postmarketOS llevaba más de 1 día encendido (sin reinicio durante la compilación); ambos `git status --short --untracked-files=no` estaban limpios, incluidos los cuatro archivos donor parcheados temporalmente. No hubo evidencia de errores del compilador anteriores a la terminación ni OOM visible en dmesg accesible. **No se ha determinado qué proceso emitió SIGTERM.** El error de copia se explica por el `trap restore EXIT HUP INT TERM` original, que puede ejecutar dos veces el mismo `restore` al recibir TERM y después EXIT.

**Corrección del flujo (no del emulador):** `scripts/surface-native-build.sh` en commit `4d3a711cd6c3be4e2763e5b0ce6a200a6687f4d0` construye un overlay mínimo bajo `as2k-surf-native/build-overlay`, reconstruye el mismo constructor de MAME desde las fuentes pinneadas, pero con snapshots `mktemp` en eMMC `as2k-surf-native/tmp` y un solo `trap restore EXIT` (HUP, INT, TERM emiten códigos de salida distintos). No se edita la revisión Git pinneada de AS2K; los objetos de compilación parciales ya generados en MAME se conservan para reanudar incrementalmente; `J=1`.

**Reinicio desatendido:** Se instaló el SH corregido y pasó `sh -n`; SHA-256 desplegado `4c992f45d9567ed9a22532347bc0f7b891c5bac7fd6cef90ff612b616626756a`. Tras confirmar los dos commits y ambos árboles Git limpios, se archivó el lock obsoleto del proceso detenido y se inició una nueva ejecución aislada con `setsid`, PID inicial `5998`. No se ha consultado aún el resultado final. Informe futuro en `status/native-build-run.status`, `status/build.status` y `logs/native-build.log`.

**Límite:** `PASS` de compilación sólo cuando ambos archivos de estado lo confirmen y el ELF ARMv7 exista y haya pasado `-validate`. No se instaló AS2K ni se copiaron ROM/DictROM/NVRAM. No realizar polling continuo por Commander.
