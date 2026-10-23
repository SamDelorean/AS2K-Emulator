# AS2K Stable — manifiesto de publicación de código

**Fecha:** 2026-10-21.
**Repositorio:** `SamDelorean/AS2K-Emulator`.
**Rama de publicación:** `release/stable-2026.10.21-vontar-surf`.

## Procedencia del código

Se preservó la referencia histórica aprobada de Vontar:
`release/vontar-stable-public-20261018`
(commit `d66d8614314eb8bad20fdb4dc1e1aa21e148307d`),
sobre la fuente original AS2K
`36996b91053969661371dc067d49026fab367a47`.
Donante MAME:
`1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`.

En `stable/` se copiaron los **objetos Git originales de código fuente**
sin volver a redactar el motor ni los menús. La instalación ASPRO
recientemente publicada usa la misma estructura de producto,
pero su núcleo/archivos privados siguen independientes.

| Archivo estable | Blob SHA-1 Git de la fuente aprobada |
| --- | --- |
| `src/mame/skeleton/alphasma.cpp` | `d6409067d2c64719e41ac5871952b85f9297b4e0` |
| `frontend/as2k_ui.py` | `767759a0cb3907ce72e91cbbfe260435844db7d3` |
| `frontend/as2k_session.py` | `057356fe49798bc57518f5134bf58a52915a7628` |
| `scripts/build-stable-core.sh` | `82f8582f870c5b930854cfce69da7d21959c75da` |
| `packaging/as2k-launcher.sh` | mismo archivo lanzador de Vontar 18-oct |

La estructura copió adicionalmente las fuentes de los scripts nativos
de Surf del trabajo `feature/stable-payload-auto-boot-b3-20261015`,
para mantener la técnica musl v2 y la separación build/install.
**Solo** el script de instalación Surf se corrigió para incluir
el gestor de sesión que ya existía en Vontar. No se modificó
`src/mame/skeleton/alphasma.cpp` ni la lógica de los menús GTK.

## Evidencia instalada previamente verificada: Vontar

| Recurso instalado | SHA-256 verificado en el acta de Vontar |
| --- | --- |
| `/usr/local/libexec/as2k/as2k-bin` | `099a1113f8c148448e47d0fb86c37e8644c6fbdb3cea261da1fff026e54d2469` |
| `/usr/local/libexec/as2k/frontend/as2k_session.py` | `57d0dd376cb8809858d19179373c8d813ff5eb7be9d0a103d6270904e703bf0f` |
| `/usr/local/libexec/as2k/frontend/as2k_ui.py` | `ff8be74da550720c6e35c25df974d65161ef2b939a978bf0da7763f78b76051a` |
| `/usr/local/bin/as2k` | `bc7c2670c82c53f10275a0ea8d83b09f9696930dee72d897e4e7de8f301720a8` |

Estos valores pertenecen al *snapshot aprobado de 18-oct-2026*;
no son resultado de una comprobación nueva de Vontar durante
esta publicación. El intento posterior de actualizar el despertar
por conexión PC **falló en el enlazado**, y no se presenta como
parte del Stable publicado.

## Evidencia Surf — nativa ARMv7

- Script probado:
  `scripts/surface-native-build-musl-v2-20261017.sh`
  generado por `surface-native-musl-v2-20261017.sh`.
- Estados constatados en Surface:
  `STATUS=PASS, STEP=READY` en
  `status/native-musl-v2-20261017.status` y
  `PASS STEP=READY` en `status/build.status`.
- `BX_MUSL_NATIVE_SYNTAX_PASS`,
  `BX_FULL_LIB_PREFLIGHT_PASS`, compilación de `libbx.a`.
- Objeto y entorno ARMv7 generados **directamente en Surf**, sin T640.
- Instalación AS2K existente comprobada anteriormente; no se
  vuelve a instalar ni se adjudica un SHA actual de Surf sin
  nueva auditoría del ejecutable.
- El **integrador Surf incluido en esta publicación** conserva una
  modificación documental/estática no probada de nuevo en el equipo:
  ahora coloca `as2k_session.py` del paquete estable en lugar
  de omitir el gestor de sesión.

## Cobertura y limitaciones

El snapshot Vontar fue aprobado para uso humano con su frontend.
Esto **no** constituye una ejecución nueva de GUI, ROM, DictROM,
impresora, PC/Send, IR, NVRAM o bootstrap al publicar el repositorio.
Revisar el [acta histórica](docs/VONTAR_STABLE_PUBLIC_20261018.md)
y los [resultados antiguos](docs/STABLE_IMPLEMENTATION_STATUS.md)
para separar pruebas de código y de interfaz.

- **Pendiente de cumplimiento:** política posterior de DictROM
  exclusivamente mediante payload bootstrap; el menú original
  conserva su vía directa anterior.
- **Pendiente:** estado NVRAM tras cierre abrupto del núcleo.
- **Pendiente:** actualización AS2K de despertar por PC Vontar.
- **Pendiente:** prueba interactiva pospublicación de la integración
  GTK completa en Surf.

## Distribución

GitHub incluye **fuentes, scripts y documentación**, no binarios
compilados, firmware, DictROM, payloads propietarios, archivos
NVRAM/RAM, capturas ni datos del usuario. Licencia raíz
`LICENSE` y términos de terceros conservados; no crear
adjuntos binarios públicos sin revisión legal/proveniencia.

## Protección de instalaciones posteriores — escala GTK (22-oct-2026)

- Rama `main` y snapshot `release/stable-2026.10.22-gtk-scale-install-guard`:
  interfaz corregida, gestor de sesión corregido y
  `stable/tests/test_view_scale.py` unidos al código fuente de Stable.
- `stable/scripts/validate-stable-static.sh`: ejecuta el test de
  100/150/200 (también en `--check` Vontar).
- `stable/scripts/install-stable.sh`: bloquea instalaciones si falla la
  regresión y compara los dos Python instalados con los originales
  probados. Se comprueba **antes** de modificar archivos del sistema.
- `stable/platform/surf/surface-native-install.sh`: usa esos mismos
  archivos del checkout Stable actual, ejecuta el test antes de la
  instalación y verifica identidad del frontend instalado.
- `stable/install-as2k-vontar.sh`: `AS2K_JOBS=3` predeterminado,
  sin modificar la pauta nativa `-j1` de Surf.
- Los tres instaladores heredados que podían descargar un commit
  antiguo están bloqueados en `main`; sus fuentes se preservan en
  Git, pero no deben utilizarse para nuevas instalaciones.
- No hubo nueva instalación en Surf ni T; las garantías son del
  código de instalación publicado. La prueba GTK interactiva
  de las tres escalas corresponde a la sesión nueva del usuario.

## Mantenimiento Vontar — hotfix escala GTK (22-oct-2026)

- **Defecto corregido en el frontend Python Stable:** `Ver → 100 % / 150 % / 200 %` asignaba un zoom pero `_draw_lcd()` ignoraba su valor y escalaba según la asignación GTK; `ManagedWindow` imponía además 2× fuera del modelo de menú.
- **Código de instalación verificado en Vontar:** `stable/frontend/as2k_ui.py` blob Git `1b8b889d1aeb582c7bae4d0632bda70f669b6c6a` y `stable/frontend/as2k_session.py` blob Git `97803b2dc85c7ca9483ce971aa780d94f13ea6a9`.
- **Test ejecutado en Vontar:** `AS2K_STABLE_VIEW_100_150_200_HEADLESS_PASS`; validación sintáctica, prueba geométrica 100/150/200, manejo fullscreen y coincidencia de hashes tras instalación.
- **Núcleo Stable no modificado:** SHA-256 `313cf536b65b8635d91f16d52d364c0dfd0e018795da63f36c1e73fe5330f5ee`, ya instalado tras reparación previa del despertar de PC.
- **Pendiente:** cierre/reapertura de la aplicación GTK y validación interactiva del usuario; no registrar `GUI_PASS` hasta observarlo.
- Se conservan los snapshots históricos previos de este manifiesto; sus SHA originales de Vontar no describen automáticamente este hotfix posterior.
- Evidencia, respaldo y diagnóstico: [`stable/docs/VONTAR_VIEW_SCALE_FIX_20261022.md`](docs/VONTAR_VIEW_SCALE_FIX_20261022.md).

## Mantenimiento Surf — hotfix escala GTK instalado (22-oct-2026)

Esta intervención **es posterior** a la publicación del instalador descrita arriba; por tanto, las menciones históricas de “sin nueva instalación” se refieren al momento de publicación, no al estado del hotfix actual.

- Equipo: Surf ARMv7, previa coincidencia exacta con los blobs originales `767759a0cb3907ce72e91cbbfe260435844db7d3` (UI) y `057356fe49798bc57518f5134bf58a52915a7628` (sesión).
- Se instalaron solo los dos Python del frontend desde el commit fijo `7e7f240c925efdba9e805b2d33719ecaca4174be`.
- Nuevos blobs verificados tras instalar: UI `1b8b889d1aeb582c7bae4d0632bda70f669b6c6a`; sesión `97803b2dc85c7ca9483ce971aa780d94f13ea6a9`.
- `AS2K_STABLE_VIEW_100_150_200_HEADLESS_PASS`; `VERIFIED_SOURCE_AND_REGRESSION_PASS`; `SURF_SCALE_HOTFIX_INSTALLED_PASS`; salida remota 0.
- No se recompiló ni modificó el núcleo ARMv7 (SHA-256 previamente medido `4577d29cdfff2f5916738d576a024bd4180a8343d6b478c6e9ebd1426b8fdedd`).
- Respaldo de ambos Python anteriores conservado en el espacio privado del usuario. No se alteraron configuraciones, firmware, DictROM, NVRAM, ni se forzó cierre de GTK.
- **GUI_INTERACTIVE=PENDING_REOPEN**: falta cerrar y reabrir AS2K en Surf y comprobar visualmente el cambio 100/150/200 y pantalla completa. No registrar GUI_PASS todavía.
- Registro exacto del despliegue: [`stable/docs/SURF_VIEW_SCALE_FIX_20261022.md`](docs/SURF_VIEW_SCALE_FIX_20261022.md).

## Afinación GTK — botones en dos filas (22-oct-2026)

- Decisión: retirar **solo el botón virtual Esc**; conservar Escape físico.
- Fila superior: F1, F2, F3, F4, F5, F6, F7, F8.
- Fila inferior: Print, Spell, Find, Clear, Home, End, Enter, Send, sin reordenar.
- La corrección reutiliza los comandos de matriz existentes, mantiene desplazamiento horizontal GTK y no altera núcleo, gestor de sesión, archivos privados ni escala LCD.
- Fuente común `stable/frontend/as2k_ui.py`: blob Git `d1ca7cd1d893d01f206872b4a909f6e24a50bb76`; prueba nueva `stable/tests/test_virtual_button_rows.py`.
- **Surf instalado — PASS**: prueba estática `AS2K_STABLE_BUTTON_TWO_ROWS_NO_ESC_STATIC_PASS`, prueba escala `AS2K_STABLE_VIEW_100_150_200_HEADLESS_PASS`, sintaxis PASS, hash del archivo final correcto; backup privado `/home/user/.local/share/alphasmart/audits/as2k/two-button-rows-20261022.XXAPOmOA`.
- **VONTAR instalado — PASS**: mismas pruebas, hash del archivo final correcto; backup privado `/home/spc/.local/share/alphasmart/audits/as2k/two-button-rows-20261022.hu9LzOPj`.
- Ambos procesos terminaron con código 0, sin recompilar ni modificar MAME ni `as2k_session.py` y sin interrumpir la sesión GTK actual.
- **GUI_INTERACTIVE=PENDING_REOPEN** en ambos: la nueva disposición se verá al cerrar y volver a abrir AS2K. Las pruebas estáticas no constituyen aprobación gráfica humana.

## Afinación GTK — filas centradas y botones uniformes (22-oct-2026)

- Ajuste sobre la versión previamente instalada de dos filas. Cada fila se centra horizontalmente como línea de texto independiente; ambos conjuntos tienen ocho botones en el mismo orden aprobado, sin Esc virtual.
- Los 16 botones comparten un Gtk.SizeGroup horizontal persistente, con tamaño mínimo común 72×34 píxeles lógicos GTK. La anchura natural aumenta para todos cuando el texto/tema lo requiera; sin recortes deliberados de Print/Spell/Clear/Enter.
- Fuente canónica `stable/frontend/as2k_ui.py`: blob `67ac14346e0e6f1cee1233ae74de5cc3c31df3d1`; prueba `stable/tests/test_virtual_button_rows.py`: blob `90c11be2bed25c2f3ed3c0ef6370b24c076ae65c`; snapshot del parche `747e10ba76844dfc8f95fc5e9bb920f0ce09c83a`.
- **Surf**: `AS2K_STABLE_BUTTON_TWO_ROWS_NO_ESC_STATIC_PASS`, `AS2K_STABLE_BUTTON_CENTERED_UNIFORM_STATIC_PASS`, `AS2K_STABLE_VIEW_100_150_200_HEADLESS_PASS`, sintaxis PASS; instalación y blob final PASS; salida 0. Respaldo `/home/user/.local/share/alphasmart/audits/as2k/centered-keyrows-20261022.XXcBMkLI`.
- **VONTAR**: idénticas pruebas e instalación PASS; salida 0. Respaldo `/home/spc/.local/share/alphasmart/audits/as2k/centered-keyrows-20261022.j5ipN2iB`.
- Núcleo MAME y gestor de sesión comprobados sin cambios en ambos equipos; sin nueva compilación ni cierre GTK forzado. Dos llamadas Commander por equipo: arranque y comprobación final.
- **GUI_INTERACTIVE=PENDING_REOPEN** en Surf y VONTAR: requieren reapertura manual para confirmar el centrado y la legibilidad con el tema GTK real. No adjudicar GUI_PASS hasta observación.
