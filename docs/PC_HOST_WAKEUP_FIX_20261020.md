# AS2K Stable — corrección del despertar por conexión PC

**Fecha:** 20 de octubre de 2026. **Rama de trabajo:** `fix/pc-host-wakeup-20261020`, derivada exactamente de la referencia pública e **inmutable** `release/vontar-stable-public-20261018@d66d8614314eb8bad20fdb4dc1e1aa21e148307d`.

## Defecto real informado

En el AS2K Stable instalado, seleccionar **Conectar PC** desde el menú o atajo no hace que el firmware entre inmediatamente en modo teclado hacia PC; cualquier tecla posterior lo despierta. **Desconectar PC** tampoco devuelve inmediatamente al editor hasta pulsar otra tecla. Send, la conversión física PD0/PD1 a Set 2 y TXT, los archivos y la UI previa ya funcionaban. No reabrir esas piezas.

## Causa localizada en la fuente liberada

En `src/mame/skeleton/alphasma.cpp`, `asma2k_state::ui_process_command()`, rama `PC ON/OFF`, se actualizaba `m_ui_pc_connected` y se cerraba la sesión Send sin generar `MC68HC11_IRQ_LINE`. En cambio, `ui_set_key()`, `ui_press_key()` y `kb_irq()` sí notificaban la IRQ; `kb_matrixl_w()` la libera. La coincidencia con la observación del usuario apunta a que el firmware estaba esperando una interrupción antes de consultar PA0/PA2. **Hipótesis causal hasta validación con firmware ejecutado**, no asumir que el hardware real tiene la misma línea IRQ física.

La entrada alternativa `PC_CONNECTED` mediante Pause/Break tenía el mismo defecto de no notificar. El primer comando de la interfaz marcaba `changed` aunque sólo tomara propiedad del estado físico existente sin cambiarlo, lo que podía provocar un cierre innecesario.

## Modificación acotada

- En la **rama UI**: comparar `connected != pc_connected()` **antes** de cambiar el override; sólo si hay un borde real, mantener el reset del receptor y el cierre previo y generar `m_maincpu->set_input_line(MC68HC11_IRQ_LINE, ASSERT_LINE)`. Registrar `AS2K_PC_HOST_EDGE_WAKE_IRQ source=ui attached=0/1`.
- En el **callback Pause/Break**: ignorar si UI es dueña, o si el bit0 no cambió realmente, y notificar la misma IRQ de una transición física real. Registrar `source=pause`.
- Sin pulsaciones falsas, sin cambios de keymap, sin alterar `Send`, sink, SRAM/NVRAM, ROM privada, HC11 CPU ni cualquier periférico.
- Se preservan los comandos `PC ON/OFF`, los estados UI y la rama de distribución.

## Contratos y pruebas

1. `python3 scripts/test-ui-pc-host-wakeup-static.py`: diez verificaciones deterministas de fuente sin ROM, incluida ausencia de IRQ espuria por comandos duplicados, cobertura menú/atajo, cambio físico real y Send preexistente.
2. `sh scripts/test-ui-pc-host-wakeup-runtime.sh CORE_BIN ROM1 DICTROM SEED_NVRAM_DIR PRIVATE_WORK_DIR`: corrida de firmware AS2K en la variante experimental aislada, **sin tecla alguna** durante el ensayo. Tomar imágenes del editor, modo PC y retorno, enviar PC ON dos veces y PC OFF dos veces, exigir dos únicas IRQ auténticas (uno por cambio) y tres screenshots LCD. **El cambio visual del firmware exige inspección humana de las imágenes**; eventos de menú por sí solos no lo prueban.
3. Reutilizar `scripts/test-ui-send-runtime.sh` y `scripts/test-ui-gtk-live.sh` sólo como **regresiones focalizadas si son necesarias**; no reabrir resultados cerrados.
4. Compilar/testear sólo en trabajo aislado de la T640, con `-j3`; no instalar por encima del binario Vontar de referencia antes de obtener PASS dinámico. Ningún test en emulador MAME genérico o AS2K-STABLE de uso diario; usar variante experimental/DIAG autorizada.

## Estado de evidencia

**`FIX_IMPLEMENTED_SOURCE`, `STATIC/DYNAMIC` se actualizan únicamente con resultados reales.** La corrección de ASPRO-DIAG previamente probada (Host IRQ por borde y TXT exacto) sirve de analogía, **no** como prueba del AS2K en esta rama. No promover `FULL_PASS` ni publicar una nueva versión estable sin compilar y comprobar la transición del firmware sin teclado.

## Distribución

La rama `release/vontar-stable-public-20261018` y la instalación estable Vontar son referencias protegidas. Mantener la rama de corrección separada; no instalar en Vontar ni en Surface RT ni etiquetar release hasta validar. Una vez aprobada, preparar actualización sobre la instalación existente con respaldo previo, preservando el gestor `as2k_session.py` y todos sus accesorios, y sin reconstruir ni reemplazar funciones ajenas.

## Resultado real de la primera validación — T640, 2026-10-20

**VALIDADO EN T640:** rama independiente `fix/pc-host-wakeup-20261020` sobre la referencia release congelada, en checkout propio `/home/spc/Projects/alphasmart/as2k-pc-host-wakeup-fix`. **Una sola llamada Commander**, sin modificaciones a la instalación Vontar, al árbol MAME original ni a la rama release.

`python3 scripts/test-ui-pc-host-wakeup-static.py`: **10/10 PASS**. Concretamente comprobaron el registro de ambas transiciones PC desde la interfaz; comparación de estado físico antes del override; IRQ sólo en borde verdadero; protección del fallback Pause/Break; IRQ en borde Pause/Break; ausencia de pulsación artificial; continuidad del cierre de Send; liberación de IRQ en barrido de matriz; conectividad del menú/atajo al mismo puente; conservación del contrato de dos Send y desconexión.

`sh -n scripts/test-ui-pc-host-wakeup-runtime.sh`: **PASS de sintaxis únicamente**, **NO** ejecución MAME.

[Registro auténtico privado de T640](https://drive.google.com/file/d/1zmGjbidRVKk2D9OylQt5uU__5QcJD3Kb/view): `AS2K_PC_WAKEUP_STATIC_EXIT=0`, `AS2K PC HOST EDGE STATIC CONTRACT: PASS (10/10)`. Los archivos privados `/home/spc/.config/as2k/firmware.bin` y `dictrom.bin` existen, **no se abrieron, copiaron ni publicaron**. El árbol histórico `/home/spc/Projects/alphasmart/as2k-stable-vontar/mame-as3k`, su `out/as2k-bin` y su seed NVRAM no existen en las rutas históricas esperadas; **no asumir que esos objetos siguen disponibles ni ejecutar una compilación masiva improvisada**.

**Estado real:** `SOURCE_FIX_DONE / STATIC_10_OF_10_PASS / RUNTIME_AND_LCD_PENDING / VONTAR_INSTALL_UNMODIFIED`. No se ha probado aún el despertar visual del firmware sobre AS2K ni se ha instalado el parche en Vontar. Se requiere validación dirigida en **MAME-DIAG canónico**, reutilizando el motor e insumos privados ya existentes y sin volver a ensayar Send. Después de PASS se podrá decidir la promoción a stable mediante el flujo de distribución autorizado.

**No afirmar** `AS2K_RUNTIME_PASS` por el éxito previo de ASPRO: son ROM, memoria y plataforma distintas.
