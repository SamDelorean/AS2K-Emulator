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
