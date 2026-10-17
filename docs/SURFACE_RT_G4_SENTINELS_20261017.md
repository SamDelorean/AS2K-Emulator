# AS2K Stable VONTAR → Surface RT — G4: objetos centinela

**17 de octubre de 2026. Estado de preparación:** `READY_FOR_BOUNDED_G4`, nunca `G5_FULL_BUILD`.

## Referencias congeladas

- AS2K Stable VONTAR: `36996b91053969661371dc067d49026fab367a47`.
- MAME donante: `1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`.
- G0–G3: `STATUS=PASS` confirmado en `AS2K_TEMP/surface-rt/results/vontar-36996b9/preflight-g0-g3/`.
- Script G4 versionado: `scripts/surface-rt-cross-g4-sentinels-20261017.sh`, idéntico al SH `AS2K_TEMP/surface-rt/surface_rt_cross_g4_sentinels_20261017.sh`.
- Reutilizar T640, toolchain `as2k-surface-cross/armv7-eabihf--musl--stable-2025.08-1`, sysroot `alpine-armv7-sysroot`, work clones y makefiles ya generados; sin resets, clean ni compilación completa.

## Alcance y secuencia

1. Verificar G0–G3 PASS, SH aprobado y commits intactos; no recurrir a VONTAR ni Surface.
2. Recuperar **sin ejecutar** las recetas específicas de `bx.make`, `emu.make` y `osd_sdl.make`, con `make -n -B -f ...` orientado *solo* a objetos individuales. Se rechazan rutas o recetas inesperadas; la generación de makefiles no se repite.
3. Extraer opciones reales del compilador C++, conservarlas y producir resultados únicamente en staging privado. Se usa el wrapper cruzado ya existente, `-D_LARGEFILE64_SOURCE=1` verificado en G2 y el overlay externo `bx/platform.h` generado en G2. El workaround `emumem_aspace.cpp -O1` se aplica por el wrapper existente.
4. Compilar individualmente **solo** `3rdparty/bx/src/file.cpp`, `src/emu/recording.cpp`, `src/osd/sdl/sdlmain.cpp` y `src/emu/emumem_aspace.cpp` con un máximo de cuatro invocaciones de compilador y tiempo limitado por objeto. Confirmar objetos ELF ARM y atributo VFP hard-float. Si algo difiere, `BLOCKED` y detenerse; **nunca** ejecutar el make general.
5. Exportar status/log a Drive. Conservar outputs/dry-run y logs detallados en staging de T640, sin sobrescribir objetos derivados de compilaciones previas.

## Límites obligatorios

- G4 **no** demuestra que el enlazado completo funcione, ni que Surface pueda ejecutar MAME.
- G5 requiere autorización separada y criterios G0–G4 PASS; no despachar en cascada.
- Sin DIAG, ROM propietarias, firmware, modificación funcional, pruebas VONTAR/Surface, instalación o paquetes.
- G5 debe usar constructor de restauración segura generado por G3 (no `build-stable-core.sh` original), preservar objetos válidos y corregir el contrato de instalación: paquete no instalador, staging/verificación nativa y rollback previo a instalación.
- Commander T640 `deviceId=dee0b4b6-578a-41a5-88de-73dbeb808983` explícito; máximo 3 llamadas por intervención, incluyendo lecturas. Subir SH mediante Drive, disparar el servicio ya conocido y consultar evidencias por Drive, no hacer polling Commander.

## Evidencia esperada

`googledrive:AS2K_TEMP/surface-rt/results/vontar-36996b9/preflight-g4/preflight-g4-20261017.status` y `.log`.

El único resultado que autoriza estudiar G5 es `STATUS=PASS`, `G4=PASS`, `G5=NOT_AUTHORIZED`, con la verificación de que **exactamente cuatro** compilaciones de objetos se realizaron y aprobaron. Cualquier `BLOCKED` exige diagnóstico estático del log y no un nuevo build.
