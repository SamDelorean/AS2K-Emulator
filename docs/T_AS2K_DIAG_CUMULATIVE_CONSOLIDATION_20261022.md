# AS2K-DIAG T640 — consolidación acumulativa, auditoría y handoff (22-oct-2026)

**Estado real: `CANDIDATE_STATIC_MERGE_PREPARED / BUILD_PENDING / FUNCTIONAL_PENDING`.**
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
