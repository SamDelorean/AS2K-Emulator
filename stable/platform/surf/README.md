# AS2K Stable en Surface RT — integración ARMv7/musl

**Frontend actualizado (22-oct-2026):** el instalador copia los
archivos `as2k_ui.py` y `as2k_session.py` del checkout actual de
`stable/`, ejecuta la regresión automática `tests/test_view_scale.py`
antes de instalar y comprueba sus bytes después. Esto evita reinstalar
el defecto del menú Ver (100/150/200). Es una mejora del paquete fuente:
**describe la salvaguarda del instalador, sin implicar por sí misma una reinstalación**.

**Hotfix ejecutado en Surf el 22-oct-2026:** se sustituyeron solamente los dos
Python del frontend, previamente comprobados contra el baseline anterior,
con respaldo y coincidencia de hashes finales. Resultado
`AS2K_STABLE_VIEW_100_150_200_HEADLESS_PASS` y
`SURF_SCALE_HOTFIX_INSTALLED_PASS`. Sin recompilación del núcleo ni reinicio
forzado. Sigue pendiente la prueba visual al cerrar y reabrir GTK.
[Evidencia detallada](../../docs/SURF_VIEW_SCALE_FIX_20261022.md).

## Procedimiento realmente recuperado

La Surface RT ya dispone de un árbol MAME preparado en
`~/Projects/alphasmart/as2k-surf-native/`.
Se revisaron directamente los scripts existentes y los estados
`native-musl-v2-20261017.status=PASS`, `build.status=PASS`.
La construcción correcta fue **nativa en Surf**, `-j1`, y recuperó
una adaptación temporal del componente `bx` que corrige
el reconocimiento de la libc musl, los alias de `fseeko64/ftello64`
y `sys/prctl.h`.

Fuentes originales fijadas:
`AS2K-Emulator@36996b91053969661371dc067d49026fab367a47`;
`mame-as3k@1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`.
Utiliza `MAKEFLAGS=ARCHITECTURE=`, `PLATFORM=arm`,
`NOASM=1`, `FORCE_DRC_C_BACKEND=1`, `NOWERROR=1`,
`OPTIMIZE=1` y `make -j1` para reducir presión de memoria.
No limpiar objetos ni reinstalar paquetes sin diagnóstico.

## Scripts archivados aquí

- `surface-native-prepare.sh`: prepara herramientas; puede
  instalar dependencias si faltan. No ejecutarlo por costumbre.
- `surface-native-fetch-sources.sh`: recupera fuentes fijadas,
  solo si faltan y el usuario autoriza.
- `surface-native-build.sh`: constructor original del
  árbol nativo antes de la corrección musl.
- `surface-native-musl-v2-20261017.sh`: **generador de una
  recuperación de una sola vez** (incluye precondiciones de FAIL previo).
  Pasó y quedó respaldado: no es un comando de compilación repetible
  sobre el estado ya aprobado. Nunca volver a lanzarlo a ciegas.
- `surface-native-run-after-sources.sh`: orquestación histórica.
- `surface-native-install.sh`: instalación desde ELF ARMv7
  **ya validado**, staging y rollback. Esta versión publicada
  copia expresamente `as2k_session.py`, `as2k_ui.py`,
  PCL/PDF, atajos y lanzador de la misma fuente Vontar aprobada.

## Verificaciones obligatorias antes de instalar

Comprobar que ninguna compilación sigue activa, árbol MAME y repositorio
original limpios y de revisión correcta, espacio y RAM suficientes,
`status/build.status = PASS STEP=READY`, ELF32 ARM
`readelf -h` / `-validate`, configuración actual intacta y que
los respaldos puedan restaurar cada destino.

Desde un checkout de la rama de publicación y después de obtener
autorización para modificar una instalación existente:

```sh
sh stable/platform/surf/surface-native-install.sh
```

La orden **instala**, no es una instrucción de revisión ni una
recomendación de repetirla en una Surf que ya funciona. Contiene
rollback de los archivos de /usr/local; evita escribir
ROM/NVRAM y no cambia kernel, Wi-Fi o particiones.

## Límite de evidencia

La construcción musl v2 y el ejecutable de la Surface tienen
evidencia PASS. El ajuste de este lanzamiento para instalar
el gestor GTK completo se publicó inicialmente **sin nueva prueba
interactiva sobre Surf**. Después se instaló únicamente el hotfix de escala
sobre los dos Python del frontend, con PASS estático y de instalación;
queda por validar su efecto visual en sesión GTK nueva. No atribuirse aprobación funcional
de DictROM/PC/Send/impresión a este cambio de instalador.
