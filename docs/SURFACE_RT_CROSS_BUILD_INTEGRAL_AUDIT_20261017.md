# AS2K Stable VONTAR -> Surface RT — auditoría integral previa a nuevo intento

**Fecha:** 2026-10-17. **Estado:** `NO_GO_FULL_BUILD`; **ninguna ejecución de compilación autorizada por esta auditoría**.

## Alcance inamovible

- Replicar AS2K Stable VONTAR **36996b91053969661371dc067d49026fab367a47**, donante MAME **1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b**.
- Host de compilación cruzada: T640, reutilizando toolchain ARMv7 hard-float/musl y sysroot de Alpine previamente preparados, **sin recrearlos**. Destino Surface RT/postmarketOS ARMv7. Preservar VONTAR.
- No modificar comportamiento AS2K ni ejecutar DIAG, Writer o trabajos ajenos. Frontend GTK, launcher y recursos se copian del mismo commit, sin reedición.
- Referencias: `docs/AS2K_STABLE_VONTAR_CHECKPOINT_20261015.md`, `docs/SURFACE_RT_NATIVE_HANDOFF_20261016.md`; script recuperado `googledrive:AS2K_TEMP/surface-rt/as2k_surface_rt_cross_build_t640_v6.sh` (sin tomarlo por un script validado de extremo a extremo). Reglas: `AS2K_T640_DCJOB_OPERATING_RULES_20261009.md`, `T640_ESTADO_OPERATIVO.md`, `AS2K_COMMANDER_DEVICE_BINDING_20261007.md`.

## Evidencia, no hipótesis

- V4: `FAIL SOURCES`; usaba remoto de checkout Eeepc, incompatible con ref de VONTAR. Corregido en V5 consultando repo canónico.
- V5: `FAIL CROSS_COMPILE rc=2` en `src/emu/recording.cpp` por elección del `png.h` de sysroot sobre `src/lib/util/png.h`; se corrigió el orden con `-idirafter` en V6.
- V6: `FAIL CROSS_COMPILE rc=2` en `3rdparty/bx/src/file.cpp` porque invoca `fseeko64/ftello64` en Linux, pero no están declaradas bajo los flags musl actuales. El fallo no corresponde a código AS2K funcional.
- V6 sí acredita: toolchain presente, dependencias X11/SDL2/Fontconfig con enlace trivial, revisión AS2K/MAME, gate estático, detección musl en `bx/platform.h`, prioridad del encabezado MAME `png.h`. **No acredita** compatibilidad ABI completa, build, link del binario final, paquete, instalación o funcionamiento en Surface.

## Defectos de procedimiento adicionales detectados en V6

1. **Pruebas incompletas de libc/API:** se verifica `BX_CRT_MUSL`, pero no las interfaces POSIX/glibc asumidas por `bx/file.cpp`. En musl `off_t` es siempre 64 bits; `-D_LARGEFILE64_SOURCE` expone nombres de compatibilidad mediante alias (documentación de musl). No se impondrá esta macro a ciegas: comprobar que se declara y compila enlazado con **el compilador y headers reales del destino**. Preferir flag único si la prueba pasa; fallback permitido: shim bajo `#if BX_CRT_MUSL` **sólo en copia de build** con equivalencia verificada. No editar emulador.
2. **Sysroot mezclado y sin trazabilidad suficiente:** wrapper GCC proviene de Buildroot musl y bibliotecas externas de un sysroot Alpine; `-idirafter` protege de la colisión `png.h`, pero **no demuestra** que headers libc, startup CRT, libstdc++, libgcc y librerías compartidas sean coherentes. Preflight debe registrar `-print-sysroot`, `-print-file-name=crt1.o`, `libstdc++.so`, include search order `-v -E`, flags de `pkg-config` y rutas de link; detectar contaminación x86/glibc, duplicados de headers y divergencias ABI. No reemplazar toolchain/sysroot sin evidencia.
3. **Prueba de enlace demasiado pequeña:** el smoke test usa sólo SDL/X11/Fontconfig e ignora `bx`, encabezados internos MAME, compilador de los TU complejos y contrato del link final. La fase previa necesita compilar **sólo objetos centinela** con flags derivados del makefile efectivo (no un `hello world`): `bx/src/file.cpp`, `src/emu/recording.cpp`, un módulo SDL y el TU `emumem_aspace.cpp` con workaround ya conocido. Si alguno falla, `BLOCKED` sin compilar MAME completo. No repetir compilaciones innecesarias; reutilizar objetos válidos.
4. **No se auditan todos los parámetros de make/regeneración:** registrar y validar `CROSS_BUILD`, `TARGETOS`, `PLATFORM`, `PTR64`, `ARCHITECTURE`, `OVERRIDE_*`, `PKG_CONFIG_*`, `USE_QTDEBUG=0`, flags ARM y definición `-D_LARGEFILE64_SOURCE` si procede. MAME requiere `REGENIE=1` al cambiar opciones. Verificar generados y distinguir utilidades del host x86_64 del binario destino ARM; ningún `-m32` ni headers x86.
5. **Riesgo de restauración en scripts existentes:** el `build-stable-core.sh` del commit instalado conserva `trap restore EXIT HUP INT TERM`, que puede restaurar dos veces tras señal y provocar error por temporal borrado (ya diagnosticado en el build Surface). Reutilizar **la corrección previa probada de overlay y un único `EXIT`**, con `HUP/INT/TERM` convertidos a salida, snapshots persistentes y recuperación limpia; sin nuevos árboles funcionales ni parches al baseline.
6. **Lanzamiento/reintentos:** V6 ya muestra tres fallos reales V4–V6. Faltan los gates anteriores a coste alto. Separar un job `PREFLIGHT_ONLY` (sin MAME completo, sin editar fuentes pinneadas y con resultados Drive) de otro job posterior `CROSS_BUILD` sólo si todos los gates específicos son PASS. Sin relanzamiento automático tras FAIL ni consumo repetitivo de Commander.
7. **Empaquetado e instalación NO conformes con plan:** V6 genera `install.sh` que realiza `apk add`, `cp -R` y sobrescribe `/usr/local` **sin respaldo/rollback**. El usuario exigió `surface-native-install.sh` con staging, respaldo y aprobación separada. **Prohibido ejecutar `install.sh` de V6**. Paquete debe ser sólo artefacto verificable, manifest y checksums; la instalación final seguirá el instalador controlado tras validación nativa y autorización.
8. **ABI/runtime no acreditados:** un ELF32 con intérprete `ld-musl-armhf.so.1` no prueba disponibilidad de dependencias o ABI en Surface. Exigir `readelf -h -A -l -d`, endian/ARM EABI/hardfloat, biblioteca `NEEDED`, sonames/rutas de destino y existencia de símbolos/versions; luego `-validate` real en Surface **antes** de instalación. No cruzar ROM/NVRAM privada.
9. **Versionado de scripts:** V6 solo reside como SH en Drive y en T; los commits previos de GitHub documentan el lanzamiento, pero no guardan necesariamente el contenido de SH. Para reproducibilidad, congelar versión de script y SHA256 tanto en GitHub (ruta `scripts/`) como Drive antes de cualquier job posterior; versionar reporte de auditoría junto al script validado.
10. **Estados inflados:** corregir clasificación del proyecto; fuentes y toolchain tienen PASS parcial, pero P3 es `REOPENED / NO_GO` en compatibilidad, P4 `FAIL` (no “en progreso”), P5/P6 no iniciados. Nunca interpretar `Result=success` de systemd como PASS de compilación.

## Procedimiento obligatorio antes de reanudar

- **G0 — Congelación:** hashes de SH, AS2K, MAME; no cambios en VONTAR/Surface ni en fuentes de referencia. Compatibilidad en overlay reversible. Si difieren, `BLOCKED`.
- **G1 — Toolchain/sysroot** (sólo verificación): arquitectura, GCC/ld, ABI hard-float, orden real de include y rutas CRT/libstdc++/musl; si se mezclan bibliotecas incompatibles, `BLOCKED`.
- **G2 — API libc y terceros:** compilar/enlazar con cross GCC una matriz breve de headers y firmas de `fseeko64/ftello64`, `off_t=64`, `bx/platform.h`, PNG de MAME y SDL/X11; comprobar todos los outputs, no ejecutar ARM en T. `BLOCKED` ante divergencias.
- **G3 — Configuración MAME:** verificar `make` efectivo y `REGENIE`, comandos de host/target, toolchain wrappers, SDL/X11 y la restauración segura antes de gastar horas. Examinar dependencias al menos de TU representativos. No cambiar build dir ni hacer `make clean`.
- **G4 — Centinelas de compilación** (trabajo acotado, no build completo): generar y compilar únicamente los objetos faltantes/conocidos para `bx`, `recording`, SDL y el caso GCC ICE mediante los flags reales. `BLOCKED` si cualquiera falla. No afirmar certeza sobre todos los TU no compilados.
- **G5 — AUTORIZACIÓN DE NUEVA COMPILACIÓN COMPLETA:** únicamente si G0–G4 PASS. Un único job desatendido separado con logs/status independientes a Drive. Revisar failure logs sin nuevos Commander; no reintentos a ciegas.
- **G6 — Paquete no instalador:** tras ELF/link PASS, inspección binaria, dependencias/runtime y archivo manifest/sha256. No introducir `apk add` en el paquete ni sustituir instalador con rollback.
- **G7 — Surface:** validar `-validate` y bibliotecas con la máquina real; sólo instalar después de permiso expreso y usando staging/backups/rollback. VONTAR intacta.

## Política Commander aplicada

T canónica `dee0b4b6-578a-41a5-88de-73dbeb808983`. **Máximo 3 llamadas por intervención previamente autorizada**; permiso de llamadas mayores sólo explícito para esa intervención. No gastar ninguna en esta auditoría. Scripts completos y validados sintácticamente primero; Drive `AS2K_TEMP/COMMANDER_PIPELINE` como transporte ordinario con exactamente **un job** al lanzar `dcjob v1.1`, sin manipular trabajos de otras colas; cuando se requiera unidad systemd independiente, utilizar sólo procedimiento ya comprobado y autorizado. Evidencias y resultados por Drive, no polling. Sudo `-n` canónico; no revalidar superusuario/rutas/hostname online sin fallo real.

## Decisión actual

`NO_GO_FULL_BUILD`. No se despacha V7. Se autorizan **solo preparación y revisión estática/Drive/GitHub** de un plan de preflight antes de otra intervención T. No prometer “cero errores”: los gates reducen fallos previsibles y aíslan los restantes, no prueban éxito completo hasta que exista un ELF y validación nativa.
