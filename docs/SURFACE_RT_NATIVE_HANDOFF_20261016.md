# HANDOFF — AS2K Stable en Surface RT — 2026-10-16

## Objetivo
Replicar en Surface RT la instalación **AS2K Stable** funcional de VONTAR. **Compilación nativa en Surface**, nunca cruzada en T640. Conservar interfaz GTK, lanzador y núcleo MAME. La instalación se hará sólo después de confirmar build PASS y nueva autorización.

## Directrices universales
STATIC_FIRST y manuales primero; cero experimentación exploratoria; conservar ROM, DictROM, NVRAM y archivos del usuario; mínimo de llamadas Commander (operaciones agrupadas en SH desatendidos, resultados PASS/FAIL/BLOCKED); sin polling reiterado; permisos sudo -n ya verificados; no modificar kernel, DTB, particiones ni Wi-Fi; no reinstalar paquetes existentes; no tocar DIAG. Preparación, fuentes, compilación e instalación son etapas separadas. J=1 por RAM Surface, no J=3 de VONTAR.

## Hardware y entorno verificados
Commander Surface deviceId `ae7a284a-68e1-49fc-bbd3-537674bc6a17`, nombre `surf`. postmarketOS v26.06, ARMv7l, 1.9 GiB RAM y 2.9 GiB zram, eMMC interno ext4 28.6 GiB (~18 GiB disponibles tras build parcial), sin USB montado. Entorno GCC/G++/make/git/Python/GTK3/SDL2/Fontconfig/X11 PASS sin instalar paquetes nuevos.

## Referencias inmutables
GitHub repo privado `SamDelorean/AS2K-Emulator`, rama de documentación/scripts `feature/stable-payload-auto-boot-b3-20261015`.
AS2K Stable código **instalado en VONTAR** pin `36996b91053969661371dc067d49026fab367a47`.
MAME donor pin `1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b` de `SamDelorean/mame-as3k`.
No aplicar observaciones posteriores de menú/NVRAM a esta réplica; están registradas en `docs/AS2K_STABLE_VONTAR_CHECKPOINT_20261015.md`.

## Rutas en Surface
Raíz `/home/user/Projects/alphasmart/as2k-surf-native`.
Scripts:
- `scripts/surface-native-prepare.sh`
- `scripts/surface-native-fetch-sources.sh`
- `scripts/surface-native-build.sh` (versión corregida desplegada)
- `scripts/surface-native-run-after-sources.sh`
- `scripts/surface-native-install.sh` (NO EJECUTADO)
Fuentes en `sources/AS2K-Emulator` y `sources/mame-as3k`.
Estados `status/environment.status`, `status/sources.status`, `status/native-build-run.status`, `status/build.status`, `status/install.status`.
Logs `logs/native-build-runner.log`, `logs/native-build.log`.
Overlay de compilación `build-overlay/`, temporales persistentes `tmp/`.

## Estado al cierre de esta conversación
- `environment.status = PASS STEP=READY`.
- `sources.status = PASS SOURCES_PINNED`; ambos hashes Git confirmados.
- Primera compilación nativa interrumpida por TERM en `luaengine.cpp`; no hubo ELF ni instalación. Causa del TERM **no determinada**. Árboles Git inspeccionados limpios, sin reinicio ni OOM demostrado. El constructor original ejecutaba doble restauración por `trap restore EXIT HUP INT TERM`, con error de temporal ya borrado.
- Se corrigió **el flujo de construcción**, no el emulador, en commit `4d3a711cd6c3be4e2763e5b0ce6a200a6687f4d0`: overlay separado, snapshots en eMMC, `trap restore EXIT` único, preservación de objetos previos, J=1.
- Script corregido desplegado en Surface, SHA256 `4c992f45d9567ed9a22532347bc0f7b891c5bac7fd6cef90ff612b616626756a`.
- Lock antiguo archivado y **nueva compilación desatendida lanzada mediante setsid, PID inicial 5998**. **NO SE HA COMPROBADO RESULTADO FINAL**. No afirmar éxito.
- Último documento de seguimiento: `docs/SURFACE_RT_NATIVE_BUILD_PREPARATION_20261015.md`, commit `5abb99249e5c4457a8fcc3a9a8eb5c43e99d1824`.
- No hay AS2K instalado en Surface; VONTAR permanece intacta.

## Siguiente paso exacto (sin curva de aprendizaje)
**UNA consulta consolidada Commander** a Surface, en modo lectura, que reporte:
1. `cat status/native-build-run.status status/build.status` (si existen);
2. `tail -n 40 logs/native-build-runner.log` y `tail -n 60 logs/native-build.log`;
3. `ps` del PID en `status/native-build-runner.pid` y procesos make/g++;
4. existencia, `file`, SHA256 del `sources/AS2K-Emulator/out/as2k-bin`;
5. `git status --short` de ambos árboles, espacio y RAM.
Si RUNNING: dejar trabajar, sin polling. Si FAIL/BLOCKED: análisis estático de causa, plan de corrección y autorización; no reintentar ciegamente. Si ambos estados PASS y ELF ARMv7 válido: reportar y solicitar autorización antes de ejecutar `surface-native-install.sh`. No instalar ni modificar ROM/NVRAM por cuenta propia.

## Documentación adicional
`docs/AS2K_STABLE_VONTAR_CHECKPOINT_20261015.md` — baseline VONTAR y observaciones pendientes de menús, flags PC/IR, NVRAM, Acerca de.
`docs/SURFACE_RT_NATIVE_BUILD_PREPARATION_20261015.md` — historial completo, scripts, fallas y relanzamiento.

**Este archivo es el punto de reanudación canónico.**

## Actualización 2026-10-16 19:32 — OOM confirmado y compilación aislada

**Diagnóstico definitivo** obtenido con 2 consultas de solo lectura: `journalctl -k` reporta a las **2026-10-16 10:50:24 -06:00** `Out of memory: Killed process 28051 (cc1plus)`, `anon-rss:475220kB`; `systemd` reporta `desktop-commander.service: Failed with result 'oom-kill'` y reinicio. Los fallos de `luaengine.cpp` se deben a OOM del sistema y muerte del servicio de Commander, **no** a un error sintáctico de MAME. La Surface tenía ~170 MiB de memoria disponible con Firefox consumiendo varios cientos de MiB.

**Solución aplicada sin cambiar fuentes ni SO persistente:** se añadieron los scripts `scripts/surface-native-oom-recovery-launch.sh` y `scripts/surface-native-systemd-build.sh` al repositorio; se desplegaron en Surface y pasaron `sh -n`. Se creó swap **temporal** de 4 GiB en `/home/user/Projects/alphasmart/as2k-surf-native/tmp/build-extra.swap`, activada con prioridad -1, además de zram; no se agregó a fstab. Se archivaron locks activos obsoletos, tras confirmar ausencia de compiladores activos y limpieza Git. Se lanzó compilación mediante `systemd-run --system --no-block --collect`, ejecutada como `user` en la unidad independiente `as2k-surface-native-20261016.service`, fuera del cgroup de Commander.

**Verificación de ejecución REAL:** `systemctl show` = `ActiveState=active`, `MainPID=23040`, `ControlGroup=/system.slice/as2k-surface-native-20261016.service`; `ps` mostró PID `23217` ejecutando `make -j1 SUBTARGET=as2k SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 USE_QTDEBUG=0`; validación estática UI e instalación PASS y parche HC11 PASS. `status/systemd-build.status = RUNNING STEP=NATIVE_BUILD`, `status/native-build-run.status = RUNNING STEP=NATIVE_COMPILE`. **Todavía no hay binario ni resultado PASS final.** No instalar.

**Consulta futura ÚNICA:** `systemctl show as2k-surface-native-20261016.service -p ActiveState -p Result -p MainPID -p ControlGroup`; `cat status/{systemd-build,native-build-run,build}.status`; `tail logs/native-build.log`; `file` y `sha256sum` de `sources/AS2K-Emulator/out/as2k-bin`; `grep build-extra.swap /proc/swaps`; `journalctl -u as2k-surface-native-20261016.service` si falla. Si PASS, validar ELF ARM y `-validate` ya efectuado por constructor, **solicitar autorización para instalar**. Tras finalizar y estabilizar memoria, desactivar y borrar **solo** el swap temporal si `swapoff` resulta seguro (no forzar durante compilación ni bajo presión de RAM). No hacer polling por Commander ni repetir la compilación sin evidencia.

## Reactivación de compilación cruzada T640 — 2026-10-17

Se recuperaron desde Google Drive el trabajo previo real `AS2K_TEMP/surface-rt/as2k_surface_rt_cross_build_t640_v3.sh` (SHA256 `3f707e5b6534c551674371511e9e1f86aa8059e8457360ef2fe98736798d7274`) y las reglas `AS2K_T640_DCJOB_OPERATING_RULES_20261009.md`, `T640_ESTADO_OPERATIVO.md`, `AS2K_COMMANDER_DEVICE_BINDING_20261007.md`.

**Ruta activa:** compilación cruzada **T640 x86_64 -> Surface ARMv7/musl**, reutilizando toolchain `/home/spc/Projects/alphasmart/as2k-surface-cross/armv7-eabihf--musl--stable-2025.08-1` y sysroot `alpine-armv7-sysroot`, no recompilación en Surface. El V3 anterior contenía la revisión obsoleta `790e0ab...`; el script V4 ahora usa exactamente AS2K VONTAR `36996b91053969661371dc067d49026fab367a47` y MAME donor `1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`. V4 adapta solamente detección de musl de `bx` en la copia de trabajo, desactiva reintento especulativo GCC `-O0`, evita sobrescribir paquetes y conserva GUI, instalador y lógica AS2K. No hay cambios de instalación VONTAR/Surface, firmware/ROM/NVRAM.

**Ejecución:** T canónica `dee0b4b6-578a-41a5-88de-73dbeb808983`. V4 guardado en `/home/spc/Projects/alphasmart/as2k-surface-cross/as2k_surface_rt_cross_build_t640_v4.sh`, SHA256 comprobado `1c185aa65177d19505f23184b9c398202f75be60fac41f61d57dc0b81c200d29`. El V3 original se conservó como `as2k_surface_rt_cross_build_t640_v3.saved.sh` y pasó verificación de hash. `bash -n` de V4 y de `run-as2k-vontar-surface-v4.sh`: PASS. Primer despacho `systemd-run --user` no ejecutó la compilación por falta de variables DBUS/XDG en sesión Commander. Se corrigió **solo despacho** mediante `sudo -n systemd-run --system -p User=spc`. Servicio independiente `as2k-vontar-surface-v4.service` confirmado `ActiveState=active`, `MainPID=225848`, `ControlGroup=/system.slice/as2k-vontar-surface-v4.service`. **Ejecución desatendida lanzada, resultado funcional de compilación TODAVÍA NO verificado.** No afirmar PASS ni paquete creado sin evidencia.

**Consulta exclusiva de resultado por Drive (sin Commander):**
- `AS2K_TEMP/surface-rt/results/vontar-36996b9/vontar-36996b9-cross-build-v4.status`
- `AS2K_TEMP/surface-rt/results/vontar-36996b9/vontar-36996b9-cross-build-v4.log`
- Solo si PASS: `AS2K_TEMP/surface-rt/packages/as2k-stable_vontar-36996b9_surface-rt_armv7-musl.tar.gz` y su `.sha256`, con `rclone check` en script.

**Commander consumido:** exactamente **3 llamadas** en la intervención (lanzamiento, lectura necesaria de resultado, reparación determinista de servicio), límite 3 agotado. No hacer más llamadas en este incremento. Ante FAIL, análisis estático del log exportado a Drive antes de decidir un nuevo incremento. No instalar Surface hasta paquete ARMv7-musl PASS y verificación nativa `-validate`.

## V5 — recuperación del commit VONTAR y reanudación cruzada (2026-10-17)

**Causa exacta del FAIL V4:** `SOURCES RC=1` por `fatal: no se pudo encontrar ref remota feature/stable-payload-auto-boot-b3-20261015`. La lógica heredada consultaba el `origin` del antiguo checkout Eeepc, que NO era la fuente canónica de la revisión Stable. GitHub confirmó separadamente la existencia de la rama `feature/stable-payload-auto-boot-b3-20261015` y del commit aprobado `36996b91053969661371dc067d49026fab367a47` en `SamDelorean/AS2K-Emulator`.

**Corrección focalizada V5:** guardado en `googledrive:AS2K_TEMP/surface-rt/as2k_surface_rt_cross_build_t640_v5.sh` y T640 `/home/spc/Projects/alphasmart/as2k-surface-cross/as2k_surface_rt_cross_build_t640_v5.sh`, SHA256 `05c0650640e5c5e9b81cbbb0ce736daee34b4f99516d47355bffbc80588e5489`. Se cambió **solamente** la etapa `clone_frozen` y nombres de logs a V5: obtener rama desde `https://github.com/SamDelorean/AS2K-Emulator.git` en el checkout aislado, comprobar hash exacto antes de checkout, reconocer checkout incompleto de `git clone --no-checkout` sin borrar archivos, bloquear cualquier contenido local inesperado. No se alteraron los toolchains, sysroot, baseline VONTAR, fuentes originales, lógica AS2K ni instalación de Surface.

**Lanzamiento real:** `rclone copyto` hacia T640, `sha256sum -c` PASS, `bash -n` PASS, `sudo -n systemd-run --system --no-block -p User=spc`; unidad `as2k-vontar-surface-v5.service` confirmada `ActiveState=active`, `SubState=running`, `MainPID=226095`, `ControlGroup=/system.slice/as2k-vontar-surface-v5.service`. **No equivale a compilación PASS.** Estado fuente/compilación aún pendiente de evidencia final.

**Evidencias exclusivamente por Drive, no Commander:** `AS2K_TEMP/surface-rt/results/vontar-36996b9/vontar-36996b9-v5.status` y `vontar-36996b9-v5.log`. Solo aceptar paquete `AS2K_TEMP/surface-rt/packages/as2k-stable_vontar-36996b9_surface-rt_armv7-musl.tar.gz` y `.sha256` si el status dice `PASS` y hash verifica. La comprobación `as2k-bin -validate` debe ejecutarse **en Surface**, previo a instalación autorizada.

**Reglas Commander:** T640 canónica `dee0b4b6-578a-41a5-88de-73dbeb808983`; 2 llamadas consumidas en esta intervención (lanzamiento y lectura del proceso de lanzamiento), **sin polling**. La primera no terminó antes de devolver PID y la segunda confirmó servicio real. Restan máximo 1 llamada en la misma intervención, que no se debe usar sin necesidad; preferir Drive. Si V5 falla, analizar Drive primero; no reintentar sin una causa concreta.

## V6 — corrección de prioridad de encabezados PNG en compilación cruzada (2026-10-17)

**Resultado V5 por Drive, sin Commander:** `AS2K_TEMP/surface-rt/results/vontar-36996b9/vontar-36996b9-v5.status` contiene `STATUS=FAIL STEP=CROSS_COMPILE RC=2`. Fuente VONTAR `36996b9...` y MAME `1dc2180...` PASS, enlace dependencias ARMv7/X11/SDL PASS y `BX_MUSL_COMPAT` PASS. El log de 11,699 líneas localizó el fallo en `src/emu/recording.cpp`: `util::mng_capture_stop/start/frame` y `util::png_info` ausentes porque el header de sistema `png.h` se resolvía antes del `src/lib/util/png.h` propio de MAME. Confirmado contra headers originales pinneados: `MAME_LIB_UTIL_PNG_H` declara esos símbolos, mientras Alpine libpng declara `png_info` global.

**Corrección estrictamente limitada de transporte/flags, sin modificar emulación:** archivo V6 `googledrive:AS2K_TEMP/surface-rt/as2k_surface_rt_cross_build_t640_v6.sh` SHA256 `0adc04f13d9bed7a0c1dd3070dda065723045baabc63afd8f669d107d1430805`. Diff V5→V6: renombra log/status a V6, cambia solo las 3 invocaciones cross GCC/G++ de `-I\"$SYSROOT/usr/include\"` por `-idirafter \"$SYSROOT/usr/include\"` para preservar prioridad de los `-I` del proyecto; agrega preflight de preprocesador ARMv7 que exige guardia `MAME_LIB_UTIL_PNG_H` y aborta sin ejecutar el build si falla. No `make clean`, sin rebuild deliberado de objetos válidos, sin modificar revisión AS2K, instaladores, firmware, VONTAR o Surface. `bash -n` local PASS.

**Despacho canónico comprobado:** T640 `dee0b4b6-578a-41a5-88de-73dbeb808983`, script descargado a `/home/spc/Projects/alphasmart/as2k-surface-cross/as2k_surface_rt_cross_build_t640_v6.sh`, comprobación `sha256sum -c` PASS y `bash -n` PASS. Servicio `as2k-vontar-surface-v6.service`: `ActiveState=active`, `SubState=running`, `MainPID=230517`, `ControlGroup=/system.slice/as2k-vontar-surface-v6.service`; **despacho ejecutado correctamente, NO implica build PASS**. Evidencia final por Drive `.../results/vontar-36996b9/vontar-36996b9-v6.status` y `vontar-36996b9-v6.log`; paquete solo si PASS: `.../packages/as2k-stable_vontar-36996b9_surface-rt_armv7-musl.tar.gz` y `.sha256`.

**Commander utilizado V6:** exactamente 2 llamadas T640 (lanzamiento y lectura final de proceso de lanzamiento), máximo universal de 3 respetado, sin polling. El resultado de compilación se consultará exclusivamente por Drive. Estado plan: P1/P2/P3 PASS, P4 ejecutándose; P5/P6 NO. No instalar automáticamente en Surface.

## PRIORIDAD DE CONTINUIDAD — auditoría integral 2026-10-17

**Esta actualización prevalece** sobre instrucciones previas de reintentar tras FALLA V4/V5/V6. Documento rector: `docs/SURFACE_RT_CROSS_BUILD_INTEGRAL_AUDIT_20261017.md`. V6 terminó `STATUS=FAIL STEP=CROSS_COMPILE RC=2` por `3rdparty/bx/src/file.cpp` y símbolos `fseeko64/ftello64`. Fuente VONTAR y donor, dependencias, bx CRT y PNG pasaron; **no existen build PASS ni paquete validado**. Revisión completa encontró además mezcla potencial de sysroots, ausencia de pruebas API/objetos centinela, trampa doble en builder y empaquetado con instalador sin rollback. Estado actualizado: **P3 REOPENED/NO_GO, P4 FAIL, P5/P6 NO INICIADOS**. No lanzar V7 ni seguir probando errores aislados. Primero preparar y cerrar G0–G4 del documento de auditoría (preflight separado, sin build completo), después permiso para un único job cruzado. **Cero llamadas Commander usadas en la auditoría; herramientas remotas T no invocadas.**

## G0–G3 preflight preparado y respaldado — 2026-10-17

**NO_GO_FULL_BUILD sigue vigente.** Se preparó un preflight G0–G3, todavía **NO ejecutado en T640**. SH: `scripts/surface-rt-cross-preflight-g0-g3-20261017.sh`, SHA-256 `6a78cf6a620844f6fd0e0ecbbd878791f18c251cd029d9f6cd6a1479e76276d3`; respaldo Drive `AS2K_TEMP/surface-rt/surface_rt_cross_preflight_g0_g3_20261017.sh`. Instrucciones: `docs/SURFACE_RT_CROSS_PREFLIGHT_G0_G3_20261017.md`, con copia Drive. `bash -n` PASS local, pero **no hay PASS G0–G3 en T**. Script verifica fuentes congeladas, toolchain/sysroot musl, ARM ABI, enlaces SDL/X11, interfaces libc `_LARGEFILE64_SOURCE`/`fseeko64`/`ftello64`, encabezados bx/PNG, y prepara solo en staging un constructor con restauración una vez. G4 centinelas PENDING; G5 compilación completa NO AUTORIZADA. **Commander: 0 llamadas**. Ningún equipo modificado ni compilación iniciada. No instalar ni usar el `install.sh` de V6. Norma rector: `docs/SURFACE_RT_CROSS_BUILD_INTEGRAL_AUDIT_20261017.md`.
