# Norma de publicación estable — emuladores AlphaSmart

**Política rectora de estructura de producto** establecida el
21 de octubre de 2026, a partir de las publicaciones ASPRO y AS2K.

Esta norma es aplicable a **AS2K Stable, ASPRO Stable y versiones
estables futuras**. No modifica automáticamente código funcional.

## Estructura obligatoria

Cada proyecto público Stable tendrá:

1. **`README.md` principal**: identidad del producto, plataformas
   admitidas, estado probado, menús y ruta a la documentación.
2. **`stable/`**: controlador/núcleo, frontend/gestor de sesión,
   menús y recursos gráficos, launcher y empaquetado sin duplicidades.
3. **`stable/platform/<equipo>/` o scripts de plataforma**
   separados: constructor **nativo** reproducible, instalación
   independiente, rollback, dependencias y límites de uso.
4. **`stable/RELEASE_MANIFEST.md`**: repositorio, commits fijados,
   blobs/hashes, referencias de equipo y resultados de pruebas
   con separación explícita entre compilación, instalación y
   funcionamiento interactivo.
5. **`docs/`**: contratos de hardware/UI, procedencia,
   cambios, documentación anterior y continuidad canónica.
6. **Rama de versión inmutable/reproducible**, rama de desarrollo
   independiente; sin reescribir commits históricos aprobados.

## Reglas de consolidación

- **Reutilizar literalmente** archivos y conocimiento ya
  verificados; comparar hashes contra referencia instalada
  antes de afirmar equivalencia.
- No reconstruir por sistema, no recrear desde cero emuladores,
  toolchains, entornos o configuraciones que ya funcionan.
- Cambios de menús y funcionalidades solo con instrucción y
  evidencia específica; preservar interfaz existente al simplificar.
- Toda corrección de empaquetado se identifica como **código
  corregido y publicado** hasta ser instalada y validada.
- No declarar PASS de UI o periféricos por compilar o por
  registrar la existencia de opciones de menú.
- Para ARMv7 **Surf compila exclusivamente en Surf**;
  ARM64 Vontar usa su constructor ARM64. T640 nunca sustituye
  una compilación Surf probada.
- STATIC_FIRST; usar las variantes instrumentadas y autorizadas
  para pruebas experimentales; no convertir la versión pública
  Stable en banco de diagnósticos. Pruebas de instalación y
  smoke sin instrumentación se reportan diferenciadamente.
- Respetar presupuestos de Commander por equipo y aprobación
  previa, minimizando llamadas y polling. GitHub/Drive primero
  para fuentes, contratos y documentación.
- Respaldar originales, restaurar donantes y garantizar rollback
  en cada instalación. No borrar ni resetear Git/cachés sin auditoría.
- Nunca incorporar ROMs, DictROMs, firmware, payload binarios
  propietarios, NVRAM, documentos o credenciales a GitHub.
- Publicar fuente con licencias y documentación; adjuntar
  binarios de distribución solo después de las verificaciones
  de procedencia y permisos correspondientes.

## Puertas reales de entrega

**FUENTE PUBLICADA** indica README, código, dependencias y manifest
disponibles, no emulador funcional nuevo.

**BUILD PASS** exige resultado real del compilador y binario validado.

**INSTALL PASS** exige directorios/lanzadores correctos, SHA
identidad con el compilado y rollback preservado.

**GUI/RUNTIME PASS** exige abrir de verdad la interfaz y verificar
LCD, teclado, persistencia, PC, envío/impresión y bootstrap
según el alcance acordado. Un fallo no puede ocultarse bajo
un PASS estático.

## Referencias de implementación

- ASPRO: `SamDelorean/ASPRO-emu/stable/`
- AS2K: `SamDelorean/AS2K-Emulator/stable/`
- Las fuentes históricas aprobadas no se alteran al cambiar
  el modelo de publicación. `as2k-diag` y `asprodiag`
  conservan el carácter y aislamiento originales.

Este diseño será la **estructura de referencia** en las
siguientes entregas y se actualizará por cambios
explícitos, con evidencia y compatibilidad hacia atrás.
