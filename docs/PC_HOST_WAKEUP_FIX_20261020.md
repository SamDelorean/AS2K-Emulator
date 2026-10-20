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

**Protección adicional aplicada tras la revisión:** el script dinámico rechaza ejecutables que no se llamen `as2kdiag`, para cumplir la política exclusiva MAME-DIAG. Esta modificación del guion fue estática y no se ha ejecutado con ROM; la validación sintáctica de la versión anterior fue PASS.

## AS2K-DIAG canónico ACTUALIZADO (T640, 20 de octubre de 2026)

**Actualización solicitada completada:** en `/home/spc/Projects/alphasmart/mame-as2k` (rama local `as2k-mame0289-dev`, HEAD base `a4b99b1a700a1d70b93a798fe7833e4cae28c137`) se aplicó el parche DIAG específico generado mediante [`scripts/patch-as2k-diag-pc-host-edge.py`](../scripts/patch-as2k-diag-pc-host-edge.py). Este árbol local ya tenía **modificaciones de usuario en `AGENTS.md` y `src/osd/modules/debugger/none.cpp`**; fueron preservadas sin sobrescritura, checkout, reset ni commit. Sólo `src/mame/skeleton/alphasma.cpp` recibió el nuevo código PC-DIAG. El árbol experimental de MAME-DIAG **no** implementa por sí mismo `PC ON/OFF` ni el puente GTK del estable: se añadió entrada `PC_CONNECTED` para instrumentación, PA0/PA2 e IRQ por transición real (sondeo de 10 ms), sin pulsaciones artificiales ni modificaciones a `Send` de AS2K Stable.

- **Versión antigua:** `as2kdiag` SHA256 `e55b25dc4540d89c4e292b03a009dd32b4cb396c943aaec9fe3e9dbe828dc7ba`.
- **Versión nueva verificada en T640:** `as2kdiag` SHA256 `771be0f36b6693cfe6ecd1419d51d5597c612fa853e5f4a9de7d35daf9816ada`.
- **Driver antiguo SHA256:** `29d9eea6eec2287c05f5b70d48010bac27caba37642920c87c5bb9002a13eb7d`.
- **Driver modificado SHA256:** `c83b6dd3f528827851680b8333a1e087be31dce956bddd98d6dea734fdb0a832`.
- **Backup local privado:** `/home/spc/Projects/alphasmart/private/diag-pc-wakeup-20261020/as2kdiag.before`; fuente original respaldada en el mismo directorio como `alphasma.cpp.before`.
- **Compilación:** `make -j3 TARGET=mame SUBTARGET=as2kdiag SOURCES=src/mame/skeleton/alphasma.cpp REGENIE=1 TOOLS=0 USE_QTDEBUG=0`, ejecutada en el árbol DIAG existente, con reutilización de objetos; PASS.
- **MAME-DIAG `-validate`: PASS.** **`-listxml asma2k`: PASS**, se comprobó que anuncia `PC_CONNECTED`. Nueva máquina DIAG autónoma funcional como ejecutable, sin reconstruir el firmware.
- [Registro original en Drive](https://drive.google.com/file/d/1Ngb70E359OkspweXBgbxV2V60rsw9Chg/view): `AS2K_DIAG_BINARY_BUILD_VALIDATE_PASS`, `HOST_PORT_LISTXML_PASS`, `AS2K_DIAG_PC_WAKEUP_UPDATE_EXIT=0`.
- **Commander:** tres llamadas en esta intervención: identificación del estado, inspección puntual del driver y lanzamiento integrado de parche + copia de respaldo + compilación + validación, sin sondeos. La evidencia se recuperó exclusivamente de Drive.

**Distinción de resultados:** `DIAG_UPDATED_BUILD_VALIDATE_PASS / FIRMWARE_PC_MODE_DYNAMIC_PENDING`. La compilación y el nuevo puerto no demuestran que la ROM AS2K entre o salga del modo PC sin teclado: ese cambio requiere una comprobación dirigida de firmware con ROM privada y observación LCD, ejecutada **sólo** en el `as2kdiag` actualizado. Tampoco se ha compilado/instalado la rama estable corregida en Vontar ni Surface RT. Conservar ambas restricciones y no trasladar el parche DIAG al driver estable por analogía.

## AS2K-DIAG — primera ejecución dinámica y fallo de inicialización real (2026-10-20)

**Nuevo estado prioritario:** `DIAG_BUILD_VALIDATE_PASS / DIAG_BOOT_FAIL_INPUT_PORT_INIT / FIRMWARE_PC_WAKE_UNTESTED`. La variante previamente actualizada `/home/spc/Projects/alphasmart/mame-as2k/as2kdiag` (SHA-256 `771be0f36b6693cfe6ecd1419d51d5597c612fa853e5f4a9de7d35daf9816ada`) **NO ARRANCA con el parche actual**, pese a `-validate` y `-listxml` exitosos. No utilizar para otras pruebas hasta reparar o restaurar. Binario anterior respaldado en `/home/spc/Projects/alphasmart/private/diag-pc-wakeup-20261020/as2kdiag.before` (SHA-256 `e55b25dc4540d89c4e292b03a009dd32b4cb396c943aaec9fe3e9dbe828dc7ba`).

**Ejecución dirigida:** en la T640 se creó `scripts/as2k-diag-pc-host-edge.lua` (publicado en esta rama) y una NVRAM/ROM staged privada completamente independiente bajo `/home/spc/Projects/alphasmart/private/diag-pc-wakeup-20261020/runtime-w0SqefFy`. Verificaciones de identidad **PASS** antes de arrancar:

- Firmware AS2K v3.14 33,253 B SHA1 `e0b777dc68c671c31ba808e214fb9d2573b9a853`.
- DictROM 131,072 B SHA1 `033094bb850c614008b4ecc2eefbcb01b8a2bcda`.
- CGROM F05 4096 B SHA1 `0196e871584ee5d370856e7307c0f9d1466e3e51`.
- `as2kdiag` SHA256 coincide con versión compilada. La prueba estaba preparada para esperar 12 s, solicitar `PC_CONNECTED=1`, capturar LCD, desconectar `0`, capturar editor sin presionar ninguna tecla y exigir exactamente dos marcadores IRQ; no se alcanzó ninguno de esos eventos.

**Resultado del proceso:** MAME terminó `exit 3` **antes del primer frame y de cargar Lua**, con mensaje inequívoco `Fatal error: Input ports cannot be read at init time!`. Se identificó como causa propia del parche DIAG la instrucción `m_diag_pc_last = BIT(m_diag_pc->read(), 0);` añadida en `asma2k_state::machine_start()`. MAME aún no permite la lectura de inputs en `machine_start`. Otras líneas, como `OPTIONAL as2k_stage0.bin NOT FOUND`, `ks0066_f05.bin ROM NEEDS REDUMP` o el aviso `XDG_RUNTIME_DIR`, **no son la causa fatal observada**. No acusar al firmware ni al modelo de IRQ.

**Corrección estática ya publicada, sin ejecutar todavía:** el script de aplicación original `scripts/patch-as2k-diag-pc-host-edge.py` inicializa ahora `m_diag_pc_last=false` en `machine_start`, dejando el sondeo real al timer de 10 ms post-inicialización. Como el árbol canónico de T ya tenía el parche aplicado, existe un reparador **exact-SHA y de una sola línea** `scripts/repair-as2k-diag-pc-host-startup.py`. Requiere SHA exacto del driver anterior `c83b6dd3f528827851680b8333a1e087be31dce956bddd98d6dea734fdb0a832`, HEAD del árbol DIAG `a4b99b1a700a1d70b93a798fe7833e4cae28c137`, copia privada nueva, y no toca `AGENTS.md` ni `src/osd/modules/debugger/none.cpp`. No repetir la aplicación inicial del parche sobre el árbol ya modificado.

**Siguiente intervención necesaria:** con nueva autorización después de agotar **3/3 llamadas Commander** en este intento (inventario privado acotado, lanzamiento de prueba, diagnóstico del error), ejecutar en **una llamada agrupada**: sincronizar esta rama, aplicar el reparador exact-SHA, `make -j3` incremental exclusivamente AS2K-DIAG, `-validate`/ROM boot y la misma observación Lua, recuperar TXT de marcadores y tres PNG por Drive. Si falla boot, restaurar ejecutable DIAG anterior desde su respaldo privado, sin modificar el estable. No fabricar un PASS ni confundir `MAME -validate` con arranque funcional.

Evidencias privadas, sin ROM:
- [launcher de la primera prueba](https://drive.google.com/file/d/1K9NwPL_3rRpULHmT5W01BcojhJLpikyc/view)
- [diagnóstico exacto stderr MAME](https://drive.google.com/file/d/1ZRkIun1TKy7Y7HSBU0QebB9y3AN6BBUq/view)

**Estado de la instalación Vontar:** intacta. La rama pública congelada permanece intacta. `FULL_AS2K_PC_WAKE_DYNAMIC_PASS` **pendiente**.

## CIERRE MÁS RECIENTE — reparación DIAG y prueba funcional real PASS (20-oct-2026)

**Esta sección prevalece sobre el FAIL de arranque anterior:** `AS2K_DIAG_PC_WAKEUP_BUILD_PASS / IRQ_2_OF_2_PASS / FIRMWARE_PC_ATTACH_DETACH_VISUAL_PASS`. La falla `Input ports cannot be read at init time!` quedó corregida sin reconstruir MAME ni cambiar firmware, inicializando `m_diag_pc_last=false` en `machine_start()`. El timer de 10ms observa el estado real tras iniciar MAME.

### Evidencia auténtica de la T640

- **Una intervención agrupada** reparó la fuente local con verificación del SHA esperado `c83b6dd3f528827851680b8333a1e087be31dce956bddd98d6dea734fdb0a832`, realizó `make -j3` incremental únicamente en la copia canónica MAME-DIAG, verificó `-validate` y ejecutó el firmware AS2K v3.14 legítimo en `as2kdiag` (no Stable). Reutilizó las tres ROM privadas ya verificadas, NVRAM aislada.
- **Ejecutable canónico actualizado, SHA-256** `9131ad29f52cabb5eb0fe5ee651ca02bf6f8b753e510ed5c52247bf0650caa14`, con copia de respaldo original `as2kdiag.before` intacta en la T. Árbol fuente local de MAME-DIAG `as2k-mame0289-dev@a4b99b1a700a1d70b93a798fe7833e4cae28c137`; sigue teniendo modificaciones locales independientes `AGENTS.md` y `src/osd/modules/debugger/none.cpp`, no alteradas ni revertidas.
- **MAME real `exit 0`**; eventos de Lua `PC_ON_SET`, `PORT_ATTACHED_1`, `PC_OFF_SET`, `PORT_DETACHED_0`, `NO_KEY_INJECTION`, `OBSERVATION_COMPLETE`. Se mandó PC ON duplicado y OFF duplicado sin IRQ adicional: **exactamente dos** `AS2K_DIAG_PC_HOST_EDGE_WAKE_IRQ` (`attached=1` y `attached=0`), y no se inyectó ninguna tecla.
- **Capturas LCD reales a 50 Hz, 240×36:**
  - [ANTES, editor vacío con cursor](https://drive.google.com/file/d/1KUuE5ws30nGOI6hx91Wwjqrs5Cej1Zqe/view) SHA-256 `9ff82e663729507bff00730c4f0b1ca06a813289d5dd0feb00fed150a0cc7441`.
  - [CONECTADO, firmware «Attached to PC, emulating keyboard. Press Send key to transfer file 1.»](https://drive.google.com/file/d/1kNPMGih4bWC1UXBKnHINN6vXdt6bLouo/view) SHA-256 `2ca84208a59e82e78f15a08e31df3a9c096e92a0f4c03ae7e75d789dc530beed`.
  - [DESPUÉS, retorno al mismo editor vacío y cursor](https://drive.google.com/file/d/1edCZCHrW_36LicIpIkpuOENEHVDmBF_B/view) SHA-256 **idéntico a ANTES** `9ff82e663729507bff00730c4f0b1ca06a813289d5dd0feb00fed150a0cc7441`.
- Dos cambios de píxeles con contador `2277` para editor→modo PC y modo PC→editor; las dos capturas del editor son **idénticas byte por byte**. Se inspeccionaron visualmente las tres; por tanto **PASS visual de transición inmediata sin tecla**, no sólo PASS de cambio de bit/IRQ.
- [Reporte JSON de ejecución y hashes](https://drive.google.com/file/d/1MNO-CGMSd85leUXR37DJBUHCj021zRVX/view), [eventos](https://drive.google.com/file/d/1rt11z0eiQl8x2kn2yeKtvYUEJJbsZ845/view), [launcher y build/boot reales](https://drive.google.com/file/d/1qdHatCoMUX-VnVzfPivhgFmZGTqq0gXE/view).
- El reporte automático permaneció en `HOST_EDGE_IRQ_PASS_LCD_VISUAL_PENDING` porque la inspección de texto LCD requería observación posterior; **esta sección agrega esa inspección real, sin falsear el JSON**.
- El lanzador inicialmente sólo exportó el registro por una variable RUN en subshell. Se completó la transferencia de **los mismos PNG, eventos y reporte**, sin volver a compilar ni ejecutar MAME. No hay ROM, DictROM ni contenido NVRAM privado publicados en GitHub.

**Estado AS2K-STABLE/Vontar: TODAVÍA NO CORREGIDO NI INSTALADO.** Las rutinas fuente modificadas en la rama `fix/pc-host-wakeup-20261020` son candidatas para un futuro ciclo autorizado de la aplicación estable, y el PASS anterior se refiere exclusivamente a MAME-DIAG. No interpretar el cambio de IRQ DIAG como evidencia dinámica en la interfaz GTK de Stable. No repetir pruebas HC11, LCD o envío Send ya cerradas; para Stable bastará el ensayo dirigido PC ON/OFF menú y atajo sin teclado, sobre un candidato aislado antes de despliegue.
