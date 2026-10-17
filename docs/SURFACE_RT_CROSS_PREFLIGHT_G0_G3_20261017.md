# AS2K Stable VONTAR -> Surface RT — incremento P3/G0–G3 (2026-10-17)

## Regla de continuidad

Estado: **PREPARADO / NO EJECUTADO EN T640**. `NO_GO_FULL_BUILD`. Este incremento no ejecuta compilaciones MAME, no toca VONTAR/Surface y no modifica las fuentes de los repositorios aprobados.

Documento rector: `docs/SURFACE_RT_CROSS_BUILD_INTEGRAL_AUDIT_20261017.md`. Esta especificación prevalece sobre cualquier frase anterior que sugiera reintentar V4–V6, ejecutar la compilación completa o instalar el tar.gz generado por V6.

## Artefacto reproducible

- SH: `scripts/surface-rt-cross-preflight-g0-g3-20261017.sh` en `SamDelorean/AS2K-Emulator`.
- Copia transportable: `googledrive:AS2K_TEMP/surface-rt/surface_rt_cross_preflight_g0_g3_20261017.sh`.
- SHA-256: `6a78cf6a620844f6fd0e0ecbbd878791f18c251cd029d9f6cd6a1479e76276d3`.
- Validación realizada **fuera de T**: `bash -n`: PASS. Su semántica de ejecución sobre el toolchain real permanece **PENDING**.
- Requiere que el script histórico V6 siga intacto, SHA-256 `0adc04f13d9bed7a0c1dd3070dda065723045baabc63afd8f669d107d1430805`.
- Entradas canónicas ya existentes en T: `/home/spc/Projects/alphasmart/as2k-surface-cross/`, checkouts aislados de AS2K (`36996b91053969661371dc067d49026fab367a47`) y MAME (`1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`); Buildroot ARMv7 musl y Alpine sysroot sin reinstalaciones.

## Qué verifica (ninguna recompilación completa)

| Gate | Actividad acotada | Criterio de cierre |
|---|---|---|
| G0 | Verifica SHA exactos de los **checkouts aislados**, ausencia de modificaciones rastreadas, y checksum de V6. No fetch/reset/checkout/clean. | PASS sólo con baseline idéntico. |
| G1 | Verifica cross-toolchain, CRT/libstdc++, sysroot, pkg-config ARMv7; compila y **enlaza** dos ejecutables de prueba ELF ARM32, uno con bibliotecas SDL2/SDL2_ttf/X11/Xinerama/Fontconfig; inspecciona `readelf` (ARM EABI/VFP/musl, `NEEDED`, versiones GLIBC). No los ejecuta en T. | PASS sólo con ABI hard-float y enlace sin símbolos GLIBC. |
| G2 | Compila/enlaza sobre el compilador ARM real `fseeko64`, `ftello64` y `sizeof(off_t)==8` con `_LARGEFILE64_SOURCE`. Comprueba `png.h` propio de MAME y `BX_CRT_MUSL` sobre **una copia** de `platform.h` sin modificar el donante. | PASS sólo si libc/API y encabezados son correctos. |
| G3 | Comprueba `CROSS_BUILD=1`, `OVERRIDE_CXX` y `REGENIE=1` del makefile/builder congelados; genera **sin ejecutar** una copia segura del builder en staging con snapshot persistente, `trap restore EXIT` único, señales separadas y eliminación de `./as2k -validate` en host. Verifica que ya existen `Makefile`, `emu.make` y `bx.make` generados del intento anterior. | PASS sólo con script sintácticamente correcto y proyectos existentes. |
| G4 | **NO se ejecuta en este incremento.** Compilación de objetos centinela con los flags reales, en una intervención posterior autorizada: `bx/src/file.cpp`, `emu/recording.cpp`, SDL y `emumem_aspace.cpp`. | PENDING, no confundir con PASS de G0–G3. |

## Límites/advertencias de la auditoría

1. Un PASS de G0–G3 NO prueba el conjunto completo de MAME, ni autoriza G5. Tras superar G0–G3, hay que verificar los makefiles/flags efectivos en G4 y compilar **sólo** objetos centinela; no iniciar el target completo.
2. `_LARGEFILE64_SOURCE` es una **hipótesis comprobable**, no una corrección global autorizada hasta obtener evidencia G2 y luego G4.
3. **Revisión pendiente para G4/G5**: el builder original borra artefactos derivados Qt; el overlay corregido elimina la restauración doble, pero no debe emplearse en una compilación completa sin verificar también las opciones efectivas de GENie, rutas del frontend y paquetes. Reutilizar configuración/objetos válidos sin `make clean`.
4. **G6** debe generar paquete sin instalador destructivo. **G7** debe validar ELF con `-validate` sobre la Surface real antes de instalar con `surface-native-install.sh` adaptado a artefacto cruzado, staging, backup y rollback. Nunca usar `install.sh` de V6.
5. No copiar ROM/DictROM ni NVRAM privadas. El único objetivo es trasladar el producto funcional congelado.

## Evidencias previstas al ejecutarse (NO existen todavía como PASS)

`googledrive:AS2K_TEMP/surface-rt/results/vontar-36996b9/preflight-g0-g3/`:

- `preflight-g0-g3-20261017.status` con `STATUS=PASS`, `GATES=G0_G1_G2_G3`, `G4=NOT_EXECUTED`, `G5=NOT_AUTHORIZED`, o `STATUS=BLOCKED` y causa.
- `preflight-g0-g3-20261017.log`, con trazas deterministas de gates. La evidencia detallada adicional queda en staging T, sin borrar fuentes.

## Commander y autorización

**0 llamadas Commander consumidas en preparación.** No se lanzó ninguna unidad ni trabajo; no se ejecutó el script en T640. Para la futura ejecución es obligatoria autorización separada. T640 canónica: `deviceId=dee0b4b6-578a-41a5-88de-73dbeb808983`; como máximo **3 llamadas por intervención autorizada**, incluido start/read, nunca polling. Transporte por Drive y resultado por Drive. `dcjob v1.1` sólo si inbox se reconcilia y contiene exactamente un job; alternativa systemd existente debe validarse con el patrón documentado, sin nuevos launchers. Sudo `-n` reconocido; no prechecks de privilegio ni `pwd/ls/find` sobre la T.

## Posición del plan

P1 PASS; P2 recuperado, compatibilidad aún pendiente; P3 G0–G3 **READY_TO_DISPATCH pero NO PASS**, G4 PENDING; P4 FAIL histórico/no relanzado; P5/P6 sin iniciar. Mantener `NO_GO_FULL_BUILD`.
