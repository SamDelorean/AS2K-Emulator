# AS2K-DIAG T640 — consolidación acumulativa, auditoría y handoff (22-oct-2026)

**Estado actual (actualización de las 12:01 de México): `CANDIDATE_STATIC_PASS_CUMULATIVE_PASSIVE_SDK_SET2_IR_RAM2_PC / MV11_CUMULATIVE_FUNCTIONAL_PASS / OTHER_FUNCTIONAL_TESTS_PENDING`.**

La etapa de las 10:36, `CANDIDATE_STATIC_PASS_IR_RAM_RAM2_PC`, es ahora un resultado histórico intermedio.

**Historial inicial del 22-oct (antes de la compilación exitosa):** `CANDIDATE_STATIC_MERGE_PREPARED / BUILD_PENDING / FUNCTIONAL_PENDING`.
La consolidación **NO está terminada**. Ningún resultado histórico PASS se revalidó ni se alteró. Alcance exclusivamente T640; Vontar y Surface RT no se tocaron.

## Referencia conservada

- Árbol MAME-DIAG: `/home/spc/Projects/alphasmart/mame-as2k`;
  rama `as2k-mame0289-dev`, HEAD `a4b99b1a700a1d70b93a798fe7833e4cae28c137`.
- Ejecutable canónico **restaurado tras cada intento bloqueado**:
  `mame-as2k/as2kdiag`, 71.533.224 bytes, SHA-256
  `861e976aa2b3c2992823fc00088e84f5d1a665e83cd94472adcfd7b38c10b39b`.
- Stable T instalada: `/usr/local/libexec/as2k/as2k-bin`,
  SHA-256 `7ba52866caf2899a9ffa309a4063a0d1530332e129b5724156ba86caa67b6557`.
  **Nunca fue sustituida ni compilada durante esta intervención.**
- Diferencia **sin conciliar** con el SHA documentado en la aceptación MV-11:
  `e0dde298b0f817d22d324c800418bb000c1e81e92c69d201eee0663f6d406220`.
  No se puede adjudicar a la versión actualmente instalada un PASS integral de MV-11 sin la reconciliación de identidad.

## Inventario real de funcionalidades e instrumentos no equivalentes

| Fuente T conservada | SHA-256 controlador (antes de fusionar) | Instrumentación diferencial |
| --- | --- | --- |
| `mame-as2k/src/mame/skeleton/alphasma.cpp` | `6b64b7c1adef4d0bc02549c68b6c2f0fe74d43d05147b075922373a6fce173ae` | Bootstrap de diagnóstico, `AS2K_PM_R4_KB_CB`, IRQ de teclado, PC conectado, impresora conectada; CPU además tiene PM-R4 IRQ |
| `worktrees/mame-as2k-ramtrace/src/mame/skeleton/alphasma.cpp` | `41a5d6963b4fe10843754bd250d44c22dc152d958b3fff11701ebb40c47548eb` | IrDA, peer de transmisión/recepción, impresión PCL/PDF, Gate1B trazas de memoria, ventanas y contadores RAM, `AS2K_POSTIR_RAM_TRACE`, teclado, callback de instrucciones |
| `mame-as3k/src/mame/skeleton/alphasma.cpp` | `e4f6c85daa2af54c97254a5dfbd38695f679852dd58423a0bef909e28379e76d` | SDK/monitor de bootstrap, Gate1A, ZPSD y Payload-1B, trazas de puertos, funciones de envío serializador y pruebas auxiliares |
| `worktrees/mame-ram2-probe` y `mame-post-ir-ram` | ver Git y auditoría local | Instrumentos RAM2/internal-RAM y post-IR alternativos; no demostrar equivalencia con RAMTRACE sin contrato de escenarios |
| `mame-pr16171-fix` | `2f2281b6300a45d7a788bcdbfe36cdd77c4ba22dca0475fafb440012d446cb9f` | Decodificación de tramas Set2, Alt-numérico y caracteres especiales PC; no integrado en la candidata inicial |

**No confundir suma de fuentes con suma funcional**: varios árboles modifican
simultáneamente `in_pa_callback`, `out_pd_callback`, `machine_reset`,
`machine_start`, entradas `PC_CONNECTED`, IRQ y callbacks HC11; la unión
textual puede duplicar hooks o alterar el firmware visible. La instrumentación
Gate1A/ZPSD no se reactiva automáticamente: los controladores de la dirección
actual del proyecto señalan Gate1A como inactivo, salvo autorización de
reapertura explícita. Integración futura debe mantener los observadores
selectivos por escenario y no imponer nuevos comportamientos en boot normal.

## Trabajo efectuado y reproducible

1. Se comprobaron los árboles/SHAs y las modificaciones locales
   preexistentes; no se hizo `git reset`, `clean` ni borrado de fuentes.
2. Se creó una **candidata de combinación puramente estática** dentro de
   `/tmp/as2k-merge-static-B1hSE79L/integrated/`, **NO una segunda
   compilación MAME ni instalación**. Combina instrumentación del
   `mame-as2k-ramtrace` con PC/impresora/PM-R4 del canónico.
3. Fusionador de 3 vías contra MAME HEAD fijado `1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`:
   6 conflictos en driver; 2 en `mc68hc11.cpp`; 2 en `mc68hc11.h`.
   Se identificaron y resolvieron estáticamente las colisiones de
   inicializadores, miembros, puertos, IRQ, callbacks y CPU.
4. Se conservaron las funciones `diag_pc_*`, la ruta combinada
   `asma2k_port_a_r()` y los eventos IR/RAM. El `m_maincpu->set_as2k_gate1a_probe`
   de la candidata quedó deshabilitado por defecto para no reactivar la
   fase histórica.
5. Primer intento de compilación: **no iniciado** por error antiguo de
   `AGENTS.md` de fin de archivo al ejecutar `git diff --check` global.
   Script aplicó restauración automática; se restringió la comprobación
   a los 3 archivos funcionales.
6. Compilación incremental real posterior **falló** (`make exit 2`):
   faltaban `fileio.h`/`emuopts.h` y había doble implementación
   `asma2k_state::machine_reset()`. El script restauró automáticamente
   fuentes y ejecutable originales.
7. Se corrigieron esos problemas **solo en la candidata temporal**:
   cabeceras agregadas y cuerpos de reset conservados bajo una única
   función; **no se validaron dinámicamente**. En el siguiente intento
   `git diff --check` detectó whitespace en la línea 2113 del
   controlador candidato y detuvo el build antes de iniciar `make`.
   La restauración se comprobó nuevamente.
8. Bajo ninguna circunstancia se declaró BUILD PASS o FULL REGRESSION
   para esta candidata. No se tocaron Vontar ni Surf.

### Rutas de auditoría local (T)

- `/home/spc/.local/share/alphasmart/audits/as2k/diag-cumulative-20261022/`
  contiene `originals.json`, respaldos locales de **tres fuentes
  y ejecutable anterior**, `build.log`, `build.status` y errores.
  Son respaldos para **rollback**, no nuevos entornos DIAG autorizados.
- Candidata sin compilar: `/tmp/as2k-merge-static-B1hSE79L/integrated/`,
  archivos `alphasma.cpp`, `mc68hc11.cpp`, `mc68hc11.h`.
  **Temporal; puede desaparecer tras reinicio**. La fuente de verdad
  continúa siendo el checkout canónico, y este documento registra
  cómo se creó y por qué no está aceptada.

## Continuidad técnica y límite de la tarea

Antes de un nuevo intento, depurar sólo el whitespace de la
candidata, ejecutar `git diff --check --` acotado, compilar
incrementalmente en el **mismo** MAME-DIAG y verificar
`as2kdiag -validate`, `-listfull`, símbolos y trazas compiladas.
Mantener rollback automático y SHA exacto del Stable. No crear otra
instancia MAME para pruebas. A continuación, conciliar conflictos
periféricos con mame-as3k/ZPSD/SDK y RAM2 bajo activación por escenario;
solo después de validación estática autorizar una campaña dirigida DIAG
que pruebe conservación de MV-11 y los bloques reintroducidos. No
repetir los históricos PASS si no se modificó su cobertura.

**Dictamen hoy: integración acumulativa INCOMPLETA.** Existe progreso
estático reproducible y fuente/evidencia preservadas, pero el
ejecutable operativo es todavía el original de SHA `861e976...`.

## Continuación en T — integración compilada (22-oct-2026, 10:36 México)

**Resultado medido:** `CANDIDATE_STATIC_PASS_IR_RAM_RAM2_PC`, MAME `-validate` exit **0** (verificación independiente posterior), `git diff --check` de las tres fuentes modificadas **0**, proceso de compilación `make -j3 ... SUBTARGET=as2kdiag ...` **exit 0**, y ejecutable enlazado exitosamente. **No atribuir PASS funcional a este incremento.**

- **Único ejecutable AS2K-DIAG vigente en la T:** `/home/spc/Projects/alphasmart/mame-as2k/as2kdiag`, SHA-256 `82e61bfb86ceff7da89250bff8e77c1c65e4b1ce2d1ef2a4c3a87a91f34e67a8`. Un único archivo `as2kdiag` localizado en los árboles inspeccionados después de la compilación. MAME `-listfull` comprende `asma2k` y `asmapro`; esto NO significa dos emuladores DIAG ejecutables.
- **AS2K Stable T protegido:** `/usr/local/libexec/as2k/as2k-bin` SHA-256 `7ba52866caf2899a9ffa309a4063a0d1530332e129b5724156ba86caa67b6557`, igual antes y después; **Vontar/Surf sin intervención**.
- **Fuentes efectivamente instaladas en único árbol DIAG:** `src/mame/skeleton/alphasma.cpp`, `src/devices/cpu/mc68hc11/mc68hc11.cpp`, `mc68hc11.h` bajo `mame-as2k`; sin nuevo checkout ni nueva copia MAME. No se hizo reset/stash/clean, ni se editó `AGENTS.md` o el Stable.
- **Instrumentación fusionada y compilada:** PM-R4 observación de teclado e IRQ HC11, transiciones de conexión PC/impresora, IrDA lógico/peer, impresión conectada y captura/submit PCL/PDF, Gate1B memoria/punteros, acceso RAM posterior a infrarrojos y **sondas RAM2 independientes**.
- **Corrección de integración de entrada:** el puerto legado `PC_CONNECTED` con Pause/Break pertenece al selector de accesorios y ya **no** se interpreta simultáneamente como la entrada física de cable. El lector `m_diag_pc` ahora usa `PORT_START("DIAG_PC_ATTACHED")`; `diag_pc_port_a_r` conserva el dato de `asma2k_port_a_r` por defecto y solamente aplica niveles PA0/PA2 de PC/impresora cuando existe una **entrada de diagnóstico externa** explícita. Se conservan los marcadores `AS2K_DIAG_PC_HOST_EDGE_WAKE_IRQ` y `AS2K_DIAG_PRINTER_HOST_EDGE_WAKE_IRQ`.
- **RAM2:** recuperada `ram2_internal_access` con marcador `AS2K_RAM2_ACCESS`; lector/escritor `0x0040..0x00ff` instalados **solo** bajo `AS2K_RAM2_PROBE` distinto de `0`; emite `AS2K_RAM2_PROBE_ACTIVE` y no se activa en arranque normal. Coexiste con `AS2K_POSTIR_RAM_TRACE` sin ponerlo en marcha por defecto.
- **Gate1A:** código legado de diagnóstico no reactivado; `set_as2k_gate1a_probe(false)` durante configuración de la máquina por la política vigente.
- **Compile blocker recuperado:** la primera mezcla tenía cabeceras incompletas y dos `machine_reset`, que se resolvieron; un intento posterior se detuvo por espacios finales. Se corrigió solo la candidata. Nuevas compilaciones `build-20261022-b2.log` y `build-ram2-pc.log` acabaron enlazando `as2kdiag` sin errores.
- **Instrumentación aún no fusionada y que no debe marcarse completa:** banco experimental SDK/ZPSD/Payload1/Generator `mame-as3k`; experimento `mame-pr16171-fix` de PC teclado Set2/Alt numérico; diferencias particulares `mame-post-ir-ram`. Las instalaciones históricas Gate 1A directas no están autorizadas a reactivarse. Verificar contratos y resolver callbacks por escenario antes de incorporarlas.
- **Identidad MV-11 sigue abierta:** SHA aprobado anteriormente `e0dde298...`, el binario anterior al incremento tenía SHA `861e976...`, la candidata ahora SHA `82e61b...`. No se adjudica automáticamente ninguno de los antiguos PASS funcionales al nuevo compilado. Se preservan las evidencias anteriores; no reejecutar campañas ya aprobadas indiscriminadamente.
- **Evidencia T en carpeta privada preexistente:** `~/.local/share/alphasmart/audits/as2k/diag-cumulative-20261022/` con `build-20261022-b2.log`, `build-ram2-pc.log`, `validate.log`, `validate-independent.log`, `listfull.txt`, `binary-strings.txt` y `build.status`, respaldos de rollback de fuentes/ejecutable. Estos no son entornos MAME adicionales y son transitorios hasta aceptación final. No almacenar firmware privado en Git.

**Próximo incremento inequívoco:** 1) reconciliar instrumentación SDK/ZPSD/Set2 con activación por escenario, sin perder callbacks PM-R4/IR/PC; 2) compilar incrementalmente el único `as2kdiag`; 3) validar estáticamente y pruebas dirigidas DIAG solo sobre cobertura modificada; 4) fijar SHA/producto y retirar respaldos ejecutables antiguos cuando haya aceptación. No recompilar Stable.


## Continuación 10:40–10:50 — Set 2, SDK/ZPSD pasivo y cierre de integridad

**Trabajo ejecutado solamente en T640**, en el mismo `/home/spc/Projects/alphasmart/mame-as2k`, sin nuevos árboles, instancias ni modificaciones de Stable/Vontar/Surf. Las fuentes acumuladas siguen en la rama local `as2k-mame0289-dev` sobre HEAD `a4b99b1a700a1d70b93a798fe7833e4cae28c137`; las modificaciones de código NO se han publicado como commit de esa rama y no deben confundirse con las actualizaciones de esta documentación.

### 1. PC físico y teclado Set 2 integrado

- Se reutilizaron desde `mame-pr16171-fix` las tablas Set2, secuencias E0/F0/E1, 11 bits con bit de paridad, estados de Shift/Ctrl/Alt/CapsLock, `Alt+0ddd` con perfil Windows CP1252, escritura UTF-8 y reglas de cierre de sesión.
- El observador se conecta **a los flancos físicos** PD0 ascendente / PD1 invertido, dentro de `asma2k_port_d_w`, conservando los callbacks de impresora e IrDA existentes. No finge teclas ni salta a direcciones ROM para generar caracteres.
- Está **desactivado por defecto**. Se habilita únicamente con `AS2K_DIAG_SET2_SINK` y conexión PC presente mediante `DIAG_PC_ATTACHED` o selector ya situado en modo PC. La salida se llama `as2kdiag-set2.txt`, para no sobrescribir `send.txt` histórico. Su prueba funcional real todavía está pendiente.
- Un primer intento compiló con errores por tabla CP1252 omitida e indentación; se hizo rollback. El segundo intento incluyó ambos ajustes y pasó compilación, `-validate`, lista de controladores y comprobación de marcadores. SHA de la candidata intermedia: `edbbef0c94dcf95bdfb31be50ffd4d30ba70ded993f391347f020d7d43e76f2c`.

### 2. Instrumentación histórica SDK/ZPSD reincorporada sin activar programación

- Se recuperaron **11 puntos de observación** de los contratos antiguos SDK/Payload: `0x87F5`, `0x93B6`, `0xA3D6`, `0xA44B`, `0x4066`, `0x008A`, `0x00A8`, `0x00AE`, `0x00C5`, `0x00CF`, `0x008D`, registrando `AS2K_LIBSDK_PASSIVE` en el callback de instrucciones ya usado por Gate1B, sin instalar uno nuevo.
- Se incorporaron observadores de memoria **pasivos**, hasta 8 eventos por dirección/sentido, para `0x3003`, `0x3005`, `0x3007`, `0x3011` con marcador `AS2K_ZPSD_PASSIVE_MMIO`. No cambian los bytes, no inyectan valores ni simulan CPBF, VPP, PSEN o programación física. **Son direcciones observadas**, no prueba de que el ZPSD real esté modelado.
- Ambos se activan solo con `AS2K_DIAG_SDK_TRACE`. Gate 1A continúa `set_as2k_gate1a_probe(false)`. Las viejas variantes SDK/Payload, que alteraban el entorno para pruebas sintéticas, permanecen en su código fuente histórico y **no forman parte del comportamiento por defecto del nuevo DIAG**.

### 3. Verificación independiente final

- **BUILD PASS**: `make -j3 SUBTARGET=as2kdiag SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 USE_QTDEBUG=0` terminó en 0, enlazado exitoso. El núcleo `-validate` también devolvió 0 en una ejecución independiente posterior.
- **STATIC PASS**: `git diff --check` de tres fuentes 0; todos los 13 contratos estáticos verificados, incluida la presencia de una sola ruta de instruction callback, Gate1A desactivado, control de escenario en Set2/SDK/RAM2/post-IR y los dos controles de conexión separados.
- **SHA-256 único DIAG vigente**: `ab5d18fce700770a7aff2d16bd53f8bd8eb5e78241558b595031abe3a47fbd70`.
- **SHA-256 Stable sin cambios**: `7ba52866caf2899a9ffa309a4063a0d1530332e129b5724156ba86caa67b6557`.
- Un único archivo `as2kdiag` quedó localizado en los proyectos inspeccionados de T. El hecho de que `-listfull` registre `asma2k` y `asmapro` no implica otra instalación.
- **Parche reversible** completo de las tres fuentes (respecto al HEAD local, incluye modificaciones de DIAG acumuladas), guardado en T en `~/.local/share/alphasmart/audits/as2k/diag-cumulative-20261022/AS2K_DIAG_CUMULATIVE_T640_20261022.patch`. SHA-256: `e59c23a8a9603cdf8beef732dd0d5bf0c91ff61bab500c9b3f5b7b4a88f8d643`, 120,317 bytes. `git apply --reverse --check` PASS; manifiesto JSON junto al parche. Los respaldos temporales adicionales de ejecutables fueron retirados tras la compilación. No contiene ROMs ni datos privados.

### Límites que NO se pueden presentar como PASS

- Todavía **no hay una campaña de regresión funcional unificada** que demuestre todos los subsistemas nuevos en el binario SHA `ab5d18...`.
- La diferencia con el ejecutable aprobado MV-11 SHA `e0dde298...` continúa sin conciliación de procedencia. La instrumentación de teclado PM-R4 y los marcadores aparecen en la fuente/compilación, pero no sustituyen la prueba.
- Los modelos **sintéticos** heredados de ZPSD y programación/ATtiny no fueron instalados ni activados, por incompatibilidad con la ruta de trabajo vigente. Solo se integraron **observadores pasivos** compatibles.
- Una validación estática favorable no demuestra recepción real de tramas PC, impresión, negociación IrDA, accesos ZPSD ni cumplimiento del contrato de bootstrap.

**Estado real:** `CANDIDATE_STATIC_PASS_CUMULATIVE_PASSIVE_SDK_SET2_IR_RAM2_PC / FUNCTIONAL_PENDING`. Conservar íntegro el estado y evitar campañas PASS repetidas salvo cobertura modificada.

## Comprobación de requisitos para regresión MV-11 sobre DIAG acumulativo (22-oct-2026, ~11:00 México)

**Resultado documental MV-11 original:** se recuperó en Drive el registro de ejecución `000_as2k_probe_mv11_l3_critical_input_OBSERVER_FIX_20261020_20261021T031249Z.summary.txt` (ID `1G-X4vD0lU69EJSOSrUaL_Cw5F4PxboTN`). Reporta `STATUS=PASS`, `EXIT_CODE=0`. El documento de repin `MV11_REPIN_AS2KDIAG_20261020.md` (ID `1CO_Qh9m-yyPI3R8trcWzN73xVOolcgMU`) ancla el ejecutable histórico aprobado con SHA-256 `e0dde298b0f817d22d324c800418bb000c1e81e92c69d201eee0663f6d406220`; la evidencia de observer fix anterior (ID `1wQT3sY4WTv74WHIwWas46ZnhMSfeAO8f`) documenta la corrección del observador. No extrapolar ese PASS al nuevo binario.

**Auditoría real sobre la T:** el ejecutable DIAG acumulativo sigue exactamente en SHA-256 `ab5d18fce700770a7aff2d16bd53f8bd8eb5e78241558b595031abe3a47fbd70`. El Stable mantiene `7ba52866caf2899a9ffa309a4063a0d1530332e129b5724156ba86caa67b6557`. MAME lista para `asma2k` la ROM 3.1.4, 3.0.8, DictROM, Stage0 y KS0066; sin embargo, `as2kdiag -verifyroms asma2k` responde **`romset "asma2k" not found!`** bajo las rutas configuradas en T. En `mame-as2k/roms` solo está `dir.txt`. La exploración acotada de fuentes privadas ya conocidas no encontró un `asma2k.zip` adecuado; no se copiaron ROMs ni se creó un nuevo árbol. La presencia de una ROM KS0066 en la carpeta privada **ASPRO** no basta para ejecutar AS2K y no autoriza mezclar los productos.

**Estado de MV-11 sobre la candidata acumulativa:** `BLOCKED_ROMSET_PRECONDITION`, `MAME_FUNCTIONAL_ATTEMPTS=0`. Esta condición no invalida el PASS histórico. No modificar el pin del job MV-11 por simple sustitución de hash: su preflight e instrumentación requieren verificación de compatibilidad y el arnés del observador ya corregido. La nueva regresión solo debe cubrir los callbacks modificados y no repetir indiscriminadamente campañas anteriores.

**Ruta de desbloqueo:** reutilizar el romset privado AS2K previamente autorizado y su `rompath` original; ejecutar primero `-verifyroms` y después una única campaña dirigida sobre el mismo `as2kdiag` con NVRAM y logs separados, sin copiar ni versionar las ROM. No fabricar pruebas sintéticas de SCI o teclado. Resolver los resultados por manifest SHA, trazas reales HC11 y ausencia de errores Lua.

## Rectificación documental inmediata — ROM AS2K localizadas en PRIVATE (22-oct-2026, 11:10 México)

**La clasificación anterior `BLOCKED_ROMSET_PRECONDITION` queda RESUELTA y SUPERADA; era un error de búsqueda de ruta, NO ausencia del firmware.** La operación anterior invocó `as2kdiag -verifyroms asma2k` sin `-rompath` y solo inspeccionó `mame-as2k/roms` y algunas rutas privadas; omitió el directorio canónico `/home/spc/Projects/alphasmart/private/roms/as2k/`. El usuario indicó correctamente que las ROM estaban en `private`.

**Verificación ejecutada en la T** sobre el mismo DIAG `ab5d18fce700770a7aff2d16bd53f8bd8eb5e78241558b595031abe3a47fbd70`:

```sh
/home/spc/Projects/alphasmart/mame-as2k/as2kdiag \
 -rompath /home/spc/Projects/alphasmart/private/roms/as2k \
 -verifyroms asma2k
```

Resultado real: **exit 0**, `romset asma2k is best available`, `1 romsets found, 1 were OK`. Archivo: `private/roms/as2k/asma2k.zip` (147339 bytes, permisos privados). ZIP stock homólogo `private/roms/as2k/stock/asma2k.zip`.

Contiene y se validaron SHA-1: firmware 3.1.4 `e0b777dc68c671c31ba808e214fb9d2573b9a853`, firmware 3.0.8 `97878819188a1ec40052fbce9d5a5059728d5aec`, DictROM `033094bb850c614008b4ecc2eefbcb01b8a2bcda`, KS0066 F00 `65cf075a988cdcbb316b9afdd0529b374a1a65ec`, KS0066 F05 `0196e871584ee5d370856e7307c0f9d1466e3e51`. MAME sigue indicando `NEEDS REDUMP` para F05; eso no bloquea la verificación.

El archivo Stage0 opcional, `as2k_stage0.bin`, 27 bytes, SHA-1 `ab76eafa386311b2ab70ea644345fb15767e908f`, está en `private/roms/diagnostic/as2k/` y NO se incorporó al ZIP. La advertencia `NOT FOUND BUT OPTIONAL` es esperada con ese `-rompath`. Una ejecución de MV-11 que requiera Stage0 debe respetar sus fuentes privadas y arnés originales; no asumir que el simple `-verifyroms` prueba bootstrap funcional.

**Estado nuevo:** `ROMSET_PREFLIGHT_PASS / MV11_CUMULATIVE_FUNCTIONAL_PENDING`; intentos funcionales nuevos todavía **0**. Histórico MV-11 `STATUS=PASS` permanece válido para el binario histórico correspondiente. No se cambiaron las ROM, no se copiaron a repositorios públicos ni se tocaron Vontar, Surf o Stable. Evidencia de este preflight: `~/.local/share/alphasmart/audits/as2k/diag-cumulative-20261022/private-rom-verify.log` en T.

**Regla operativa añadida:** antes de declarar ausente una ROM AS2K, inspeccionar `/home/spc/Projects/alphasmart/private/roms/as2k/` y el subárbol `private/roms/diagnostic/as2k/` con `-rompath` explícito; no iniciar búsquedas de donantes ni reconstruir ZIP ya existente.

## MV-11 ejecutado sobre el DIAG acumulativo — PASS funcional (22-oct-2026, 12:01 México)

**Estado actual de MV-11: `PASS_HC11_RX_INJECTED_CRITICAL_MAME_KEY` para el nuevo ejecutable acumulativo.** Esta sección prevalece sobre el `MV11_CUMULATIVE_FUNCTIONAL_PENDING` de los preparativos históricos anteriores. No representa un `FULL_REGRESSION_PASS` de Set2, IR, RAM2 ni SDK/ZPSD.

- **Equipo:** T640 `spc-HP-t640-Thin-Client`, único `mame-as2k/as2kdiag`, SHA-256 `ab5d18fce700770a7aff2d16bd53f8bd8eb5e78241558b595031abe3a47fbd70`.
- **Stable protegido:** `/usr/local/libexec/as2k/as2k-bin`, SHA-256 `7ba52866caf2899a9ffa309a4063a0d1530332e129b5724156ba86caa67b6557`, idéntico tras la ejecución.
- **Arnés histórico original recuperado:** `000_as2k_probe_mv11_l3_critical_input_OBSERVER_FIX_20261020.job.sh`, SHA-256 `79ac390860dba469c1d4bb9f13b1c2cbc00b439bce9e06e013190b0c0e8347a5`. Archivo original localizado en el archivo privado `googledrive:AS2K_TEMP/COMMANDER_PIPELINE/archive` y en el trabajo canónico `~/.local/share/dcjob/work/000_as2k_probe_mv11_l3_critical_input_OBSERVER_FIX_20261020_20261021T031249Z/task.job.sh`.
- **Reproducción controlada:** se sustituyó **exactamente una ocurrencia** del pin SHA-256 histórico `e0dde298...` por `ab5d18...`, sin cambiar comandos MAME, arnés Lua, monitor de 172 bytes, overlay de 78 bytes, verificador ni condiciones de prueba. Job nuevo `000_as2k_probe_mv11_l3_critical_input_OBSERVER_FIX_CUMULATIVE_20261022.job.sh`, SHA-256 `eb266a9445aec5014dde1924c98b462b19db2c3287a6e07318522c31211f49fc`; `bash -n` aprobado.
- **Única ejecución autorizada:** `dcjob run-once` en T, `2026-10-22T18:01:34Z` (12:01 México), `STATUS=PASS`, `EXIT_CODE=0`, **`MAME_ATTEMPTS=1`**, `mame_rc=0`.
- **Evidencia técnica:** RX 80 bytes, TX 11 bytes, overlay original verificado, BDS `A5015020000407D7` (estado `$20`); matriz inicial `$FF`, flanco nativo `AS2K_PM_R4_KB_CB mask=80 old=1 new=0` observado una vez; lectura HC11 `MV11_MATRIX_TRANSITION A=7F SP=00FC`, retorno de filas `$FF`, restauración de PORTA, pila `$00FF`, READY PC `$0098`, sin errores de arnés.
- **Límites explícitos del arnés:** `RX_HARNESS=DEBUGGER_AT_RX_ENTRY`; `SCI_RX_NATIVE=NOT_TESTED`, `EXTERNAL_BUS_ELECTRICAL=NOT_TESTED`, `BOOTSTRAP_DOWNLOAD_NATIVE=NOT_TESTED`. La prueba ejercita transición **real en el puerto MAME** y lectura HC11, no teclado físico.
- **Fuentes ROM:** privadas en `/home/spc/Projects/alphasmart/private/roms/as2k/`; el job original construye un romroot transitorio en `/dev/shm`, separado de NVRAM/cfg/state/inputs. No se publicaron ni modificaron ROM/NVRAM.
- **Paquete canónico de evidencia:** `000_as2k_probe_mv11_l3_critical_input_OBSERVER_FIX_CUMULATIVE_20261022_20261022T180134Z.result.tar.gz`, SHA-256 `848fd17d97792c5e59de5642d53a0874c09d7d3d87f0da283581671e5131ae70`; comprobada coincidencia entre paquete local y sidecar en el `outbox` privado de Drive. Incluye `result/summary.txt`, `check.txt`, `error.log`, `input_trace.txt`, `fixture.json`, `mv11.mame` y overlay capturado. El job quedó archivado por `dcjob`.
- **Carpeta local de resultados:** `~/.local/share/dcjob/work/000_as2k_probe_mv11_l3_critical_input_OBSERVER_FIX_CUMULATIVE_20261022_20261022T180134Z/`.

**Dictamen específico:** `MV11_CUMULATIVE_FUNCTIONAL_PASS`. La discrepancia histórica entre el SHA `e0dde298...` y el DIAG posterior queda **resuelta para la cobertura funcional MV-11** porque el nuevo SHA fue sometido al mismo arnés aceptado y pasó; ambos binarios siguen siendo distintos, no se afirma identidad binaria. Conservar intactos los PASS históricos y continuar mediante pruebas nuevas **solamente de los instrumentos acumulados que carecen de evidencia dirigida**. No reinstalar Stable ni generar árboles separados.
