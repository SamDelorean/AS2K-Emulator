# Vontar — corrección de Ver → 100 %, 150 % y 200 % (22-oct-2026)

**Producto:** AS2K-STABLE sobre Armbian aarch64, frontend GTK3.
**Alcance:** solo archivos Python del frontend y gestor de sesión; **NO se reconstruyó MAME** ni se cambiaron ROM, NVRAM, configuración, conexión PC, teclado, infrarrojos o impresora.

## Falla reportada y causa

El menú `Ver` construía correctamente los tres `Gtk.RadioMenuItem` y su callback `_on_scale_selected()` asignaba `self.ui_scale`, pero `_draw_lcd()` ignoraba ese atributo y recalculaba el zoom automáticamente con toda la asignación de `Gtk.DrawingArea`. GTK puede expandir dicha área más allá de `set_size_request()`, que es solamente un tamaño mínimo.

Además, `ManagedWindow.__init__` imponía otra solicitud de tamaño (LCD 2×) directamente, manteniendo seleccionado en el menú el 100 %. El usuario observó que 100/150/200 no producían cambios.

## Corrección aplicada

1. `stable/frontend/as2k_ui.py`: pintar el LCD con `ui_scale` explícito en modo ventana, limitado por el espacio **solo si es inferior**; dibujar centrado y en filtro vecino más cercano. En pantalla completa conservar ajuste al espacio disponible. Invalidar y redibujar al seleccionar escala y al entrar/salir de pantalla completa. Registrar las opciones de menú para mantener sincronía con el modelo.
2. `stable/frontend/as2k_session.py`: quitar la segunda imposición independiente del tamaño LCD; activar el radio `200 %` al crear la ventana integrada para preservar el tamaño inicial previsto. Las tres opciones realizan ahora, nominalmente, 240×36, 360×54 y 480×72 píxeles de salida del LCD.
3. `stable/tests/test_view_scale.py`: prueba sin servidor gráfico, que ejecuta los **métodos reales del código fuente** sobre un contexto Cairo simulado; valida escalas 1.0/1.5/2.0, ancho/alto solicitado, disparo de redibujado, centra/conserva escala en un área mayor, reduce si no cabe y escala automáticamente en pantalla completa. Comprueba también que `ManagedWindow` activa el radio 200 %.

## Verificaciones en Vontar

**Código descargado desde el commit fijo** `7e7f240c925efdba9e805b2d33719ecaca4174be` (rama `fix/stable-gtk-lcd-scale-vontar-20261022`) y cotejado con blobs Git:

- `as2k_ui.py`: `1b8b889d1aeb582c7bae4d0632bda70f669b6c6a`
- `as2k_session.py`: `97803b2dc85c7ca9483ce971aa780d94f13ea6a9`

Antes de instalar, se verificó que la instalación contenía exactamente el frontend Stable previo:

- `as2k_ui.py` SHA-256 `ff8be74da550720c6e35c25df974d65161ef2b939a978bf0da7763f78b76051a`
- `as2k_session.py` SHA-256 `57d0dd376cb8809858d19179373c8d813ff5eb7be9d0a103d6270904e703bf0f`
- Núcleo MAME SHA-256 `313cf536b65b8635d91f16d52d364c0dfd0e018795da63f36c1e73fe5330f5ee` — **sin cambios**.

Resultado registrado en T? **No**; esta corrección se aplicó exclusivamente en **Vontar**. Resultado del despliegue en Vontar:

```
PYTHON3_SYNTAX_PASS
AS2K_STABLE_VIEW_100_150_200_HEADLESS_PASS
SOURCE_SHA_BLOBS_PASS
STATUS=SOURCE_UNIT_TEST_AND_INSTALL_PASS
INSTALLED_BLOBS:
1b8b889d1aeb582c7bae4d0632bda70f669b6c6a
97803b2dc85c7ca9483ce971aa780d94f13ea6a9
```

Los archivos se instalaron mediante reemplazo atómico, sin finalizar deliberadamente el proceso GTK activo. Respaldo privado en Vontar:

`~/.local/share/alphasmart/audits/as2k/view-scale-vontar-20261022/frontend-ui.before.py`

`~/.local/share/alphasmart/audits/as2k/view-scale-vontar-20261022/frontend-session.before.py`

Resultado: `~/.local/share/alphasmart/audits/as2k/view-scale-vontar-20261022/install.status`.

**Precisión:** el transporte remoto notificó una salida de shell no cero por un error de contexto del envoltorio posterior a la impresión de las pruebas y las identidades verificadas; no debe presentarse como prueba de interacción GTK. La validez de la instalación se respalda en los hashes de los archivos efectivamente comprobados y el test de métodos.

## Activación y límite pendiente

La sesión Gtk que hubiese quedado abierta conserva el código Python ya cargado. Se requiere **cerrar y volver a abrir AS2K** para activar esta corrección. No se forzó reinicio ni se interrumpió el usuario. **Pendiente:** comprobación manual en Vontar de que las tres entradas del menú alteran visiblemente el LCD con firmware en ejecución, y que pantalla completa sigue funcionando. Las pruebas sin display **no equivalen** a un PASS GUI interactivo.

Para compilaciones futuras **del núcleo** en Vontar queda la directriz independiente `make -j3`; no se recompiló el núcleo para esta falla.
