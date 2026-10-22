# T640 — auditoría y limpieza de instancias AS2K (22 de octubre de 2026)

**Alcance expresamente autorizado: ÚNICAMENTE la T canónica
`spc-HP-t640-Thin-Client`.** No se accedió ni modificó Vontar, Surface RT,
sus instalaciones, fuentes o datos.

## Política de productos

Los dos productos operativos AS2K para T son:

1. **AS2K-STABLE**: `/usr/local/libexec/as2k/as2k-bin`
   SHA-256 `7ba52866caf2899a9ffa309a4063a0d1530332e129b5724156ba86caa67b6557`.
   Lanzador `/usr/local/bin/as2k`. La instalación se mantuvo
   idéntica durante esta auditoría.
2. **AS2K-DIAG**: `/home/spc/Projects/alphasmart/mame-as2k/as2kdiag`
   SHA-256 **observado el 22-oct**:
   `861e976aa2b3c2992823fc00088e84f5d1a665e83cd94472adcfd7b38c10b39b`,
   tamaño 71.533.224 bytes, MAME `-validate` exit 0 y `-listfull`
   registra `asma2k` (y también `asmapro` en el mismo ejecutable).
   Árbol Git donante: `mame-as2k`, HEAD
   `a4b99b1a700a1d70b93a798fe7833e4cae28c137`,
   con modificaciones locales que **NO se descartaron**.

Los binarios de compilación y ejecutables que residan en otros
proyectos o sean outputs intermedios **no** se consideran nuevas
instalaciones autorizadas de AS2K, y no se promoverán a producto.
No crear árboles DIAG para cada incremento futuro.

## Discrepancia relevante — NO cerrar como último DIAG verificado

El acta histórica [MV-11 repin de identidad](https://drive.google.com/file/d/1CO_Qh9m-yyPI3R8trcWzN73xVOolcgMU/view)
y la aceptación funcional MV-11 documentan un **binario aprobado distinto**:
SHA-256 `e0dde298b0f817d22d324c800418bb000c1e81e92c69d201eee0663f6d406220`.
El documento indicaba la misma ruta, tamaño y marca temporal de T,
pero el contenido actual tiene SHA `861e976...`.

No se localizó un ejecutable con SHA `e0dde298...` entre los
`as2kdiag` presentes en los proyectos inspeccionados. **La validación
actual del ejecutable (exit 0) y la presencia de la cadena
`AS2K_PM_R4_KB_CB` no demuestran equivalencia binaria** con el de MV-11.
Por tanto:

- La limpieza **sí** garantiza una sola ruta de ejecutable DIAG en los
  árboles inspeccionados.
- La identidad exacta con la **última aceptación funcional MV-11 sigue
  `UNRESOLVED`**. No afirmar `FULL_CUMULATIVE_PASS` ni
  reescribir el acta anterior.
- Proteger el ejecutable actual sin recompilar ni sustituirlo hasta
  conciliar la procedencia y los requisitos del trabajo siguiente.
  No repetir automáticamente los PASS de MV-01…MV-11.

## Eliminación realizada y evidenciada en T

Se eliminaron **solo estos 12 ficheros ejecutables** `as2kdiag`,
verificando SHA-256 antes de cada eliminación y sin borrar los
árboles de fuentes ni evidencias:

| Ruta relativa a `/home/spc/Projects/alphasmart` | SHA-256 anterior |
| --- | --- |
| `mame-as2k-stable-pr1/as2kdiag` | `a6a46a5184787c844189dc95f8ab246171109550ec5fd8889f4d5122f2bf1b88` |
| `mame-as3k/as2kdiag` | `44761693fd459f1d92544f7ad2bd1fd887e5b5a3901c47cbf1c2393175bc2119` |
| `mame-pr16171-fix/as2kdiag` | `b10c015456f2debb9b34fd5f01d09346203765238722d64de17b10f4323ee891` |
| `worktrees/mame-ram2-probe/as2kdiag` | `8fb24a1603d86d64ba39883ffd5ce432f4c75923aef6c9bf2f684f9f269530ab` |
| `worktrees/mame-as2k-ramtrace/as2kdiag` | `437be9c9fbbdd889a08bd188d0b87b03172224f66a9587a123035847c0a75d17` |
| `worktrees/mame-post-ir-ram/as2kdiag` | `a0d7a9fa7cebc56c98cb7f293c62eafb03fc6fbc805f14df7963353d8cf6a540` |
| `mame-as2k-irtrace/as2kdiag` | `40015a0bb1ca8fc8c14f2ce84744c872e2658c4711ce3e616590cc25449bc4ab` |
| `energy-r16-diag-artifacts/campaign/attempt2/as2kdiag` | `861e976aa2b3c2992823fc00088e84f5d1a665e83cd94472adcfd7b38c10b39b` |
| `energy-r16-diag-artifacts/campaign/attempt3/as2kdiag` | igual SHA que attempt2 |
| `energy-r16-diag-artifacts/campaign/attempt4/as2kdiag` | igual SHA que attempt2 |
| `energy-r16-diag-artifacts/campaign/attempt5/as2kdiag` | igual SHA que attempt2 |
| `energy-r16-diag-artifacts/campaign/attempt6/as2kdiag` | igual SHA que attempt2 |

**Resultado comprobado:** `PASS_12_DUPLICATE_DIAG_BINARIES_REMOVED`.
**Espacio lógico liberado:** 858.806.320 bytes (~819 MiB).
Manifiesto JSON privado y persistente con rutas, tamaños, mtimes, hashes
y eliminación por archivo:
`/home/spc/.local/share/alphasmart/audits/as2k/T_AS2K_DIAG_DUPLICATES_20261022T155012Z.json`.

Verificación posterior con `find` (profundidad ≤7): un solo fichero
`as2kdiag` en los proyectos de T, situado en `mame-as2k`.
Se comprobaron nuevamente los SHA de ese ejecutable y Stable.

## Árboles de desarrollo NO eliminados

Las siguientes fuentes de trabajo **contienen modificaciones
no comprometidas, resultados para terceros o dependencias activas**,
por lo que su supresión sin respaldo individual destruiría
conocimiento y violaría el criterio de esta limpieza:

- MAME `mame-as2k`: 3 modificaciones Git locales, driver de
  PC/impresora/teclado y depurador.
- `mame-as3k`: donante usado por varios proyectos, 4 cambios.
- `mame-as2k-stable-pr1`, `mame-as2k-irtrace`: 2 cambios cada uno.
- `worktrees/mame-as2k-ramtrace`, `mame-post-ir-ram`,
  `mame-ram2-probe`: cambios experimentales HC11/driver sin commit.
- Árboles EEepc, PR #16171, Writer, Energy, MAME-AS3K y
  proyectos de compilación para otras plataformas son recursos de
  investigación/compilación separados; no se borraron ni
  reclasificaron automáticamente como desechables.

En particular, **no se borraron directorios de MAME completos**.
Esta primera intervención retira solo los ejecutables antiguos
sin destruir sus fuentes y conocimiento; la decisión de archivar
o retirar cada árbol requerirá verificar sus cambios Git, estado
remoto, referencias en otros proyectos y respaldo documental.

## Reglas a partir de esta auditoría

- **AS2K-DIAG:** un ejecutable canónico incremental en T,
  con SHA fijado por prueba; no copiarlo a cada campaña.
- **AS2K Stable:** la instalación canónica de T y su frontend;
  no usarla como banco de pruebas instrumentadas.
- Mantener pruebas DIAG dentro del emulador autorizado;
  reciclar incrementos PASS sin repetir campañas.
- Fuentes MAME, scripts, contratos, registros y evidencias
  se conservan aunque se retire un ejecutable antiguo.
- Ningún cambio en Vontar o Surf.
- No confundir `mame-as2k/as2k`, `AS2K-Emulator/out/as2k-bin`
  y compilaciones EEepc almacenadas en T con otras instalaciones
  Stable: son **artefactos de compilación o destinos distintos**
  y quedaron intactos en esta intervención.
