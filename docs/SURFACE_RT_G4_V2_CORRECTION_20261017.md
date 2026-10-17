# G4 v2 — corrección determinista de identificación de receta SDL

**Fecha:** 2026-10-17; sin autorización G5 ni instalación.

Resultado real anterior G4: `STATUS=BLOCKED STEP=G4_GENERATED_RECIPES RC=1`. El `make -n` de `bx_file` y `recording` localizó correctamente las recetas; para `sdlmain`, el script supuso un nombre de objeto `obj/Release/src/osd/sdl/sdlmain.o` que **no es un objetivo directo** de `osd_sdl.make`. No se ejecutó ningún compilador centinela ni un build completo.

La referencia MAME fijada `scripts/src/osd/sdl.lua` incluye expresamente `src/osd/sdl/sdlmain.cpp` en el proyecto `osd_sdl`. El nuevo procedimiento usa la receta puntual cuando existe; si el único fallo es `No rule to make target`, extrae **sin ejecutar** las recetas del proyecto `osd_sdl.make` completo, filtra la línea del compilador para esa fuente y exige exactamente **una** coincidencia ARM. Las compilaciones reales siguen siendo exclusivamente cuatro llamadas directas a compiladores cruzados, objetos aislados en staging. Se rechazan flags de dependencia de forma compactada para evitar escrituras fuera del staging. Cualquier incertidumbre termina `BLOCKED`, nunca ejecuta `make` de compilación.

Nuevo SH independiente `surface_rt_cross_g4_sentinels_v2_20261017.sh`, SHA-256 `3746d995d196241b771f77a2510d9e600ea9e623c4922fa4d1f32bed2e53cd20`; `bash -n` y los dos bloques Python `compile()` PASS. No borra ni reemplaza el archivo G4 anterior, su resultado, objetos previos ni worktrees. Log/status nuevo bajo `AS2K_TEMP/surface-rt/results/vontar-36996b9/preflight-g4-v2`. `G5=NOT_AUTHORIZED`, P4/P5/P6 no se reanudan.
