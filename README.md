# AS2K Emulator — AlphaSmart 2000 Stable

**Publicación de código fuente Stable: 2026-10-21.** Distribución pública
del emulador AlphaSmart 2000 (MAME reducido) con **una estructura de producto
común a ASPRO Stable**, sin mezclar el producto con `as2k-diag`.

[**Producto Stable, menús e instalación**](stable/README.md) ·
[**Manifiesto, SHAs y evidencia**](stable/RELEASE_MANIFEST.md) ·
[**Estándar de publicación de nuestros emuladores**](docs/STABLE_RELEASE_STANDARD.md) ·
[**Referencia histórica Vontar aprobada**](stable/docs/VONTAR_STABLE_PUBLIC_20261018.md)

## Productos y plataformas

| Plataforma | Núcleo y uso | Estado documentado |
| --- | --- | --- |
| **Vontar — Armbian AArch64** | Versión reducida `asma2k`, gestor de sesión GTK completo | Referencia instalada aprobada el 18-oct-2026; compilación/instalación ya existentes |
| **Surf — Surface RT / postmarketOS ARMv7/musl** | Compilación **nativa en Surf**, `make -j1`, compatibilidad `bx` musl v2 | Compilación nativa PASS documentada el 17-oct; instalación AS2K presente en Surf; integrador de sesión de este paquete corregido **sin nueva ejecución** |
| **as2k-diag** | Banco de diagnóstico independiente | No se publica ni instala como Stable |

El núcleo Stable no se sustituye por el emulador de pruebas. Tampoco se
recompila desde T640 para Surf ni se fuerza una nueva compilación al publicar
esta estructura. La rama histórica
`release/vontar-stable-public-20261018` se conserva **sin modificaciones**.

## Menús e integración GTK completos

El producto contiene **dos componentes complementarios**:
`stable/frontend/as2k_ui.py` (LCD, teclado y menús base) y
`stable/frontend/as2k_session.py` (gestor real de Vontar, configuración
persistente, bootstrap, display integrado y opciones de sesión).

Menús originales: **Archivo** (Firmware/DictROM, bootstrap, capturas,
grabación y salir); **Máquina** (reinicio, PC, impresora, infrarrojo,
selección de inicio); **Ver** (100 %, 150 %, 200 %, pantalla completa,
ventana integrada/SDL); **Configuración** (ROM, NVRAM, estados y salidas);
**Ayuda** (atajos y acerca de). LCD de 240×36, teclado virtual,
enlace PC/Send, salida PCL/CUPS-PDF y actividad IR.

El lanzador `/usr/local/bin/as2k` abre
`/usr/local/libexec/as2k/frontend/as2k_session.py`, no
el MAME genérico ni una UI de diagnóstico.
Los activos privados permanecen fuera de Git.

## Código nativo por equipo

- [Vontar — constructor e instalador](stable/install-as2k-vontar.sh):
  patrón AS2K aprobado, único driver `asma2k`, GTK completo.
- [Surf — build e instalación](stable/platform/surf/README.md):
  procedimiento nativo ARMv7 con corrección musl v2, respaldos, `-j1`,
  separación build/install y sin compilación cruzada.

**Precaución:** la publicación documenta fuentes/instaladores; no realiza
nuevas intervenciones en los equipos ni es prueba de que una versión
modificada del instalador ya se haya ejecutado allí. El manifiesto distingue
PASS ejecutados, código de integración corregido y pruebas pendientes.

## Cambio de política y limitaciones

Se conserva la **interfaz Vontar realmente aprobada**, incluida su opción
histórica `Arranque directo desde DictROM`. La política posterior del
proyecto requiere que la transición a DictROM ocurra **mediante payload
bootstrap**, sin una vía directa separada; esa reconciliación funcional y
la simplificación cuidadosa de menús están pendientes. **No** se cambió
el núcleo silenciosamente al publicar.

También permanece pendiente la validación específica de la actualización
AS2K de despertar por PC en Vontar, cuya compilación posterior falló al
enlazar. Esta versión no la presenta como instalada.

## Licencias y privacidad

Código fuente público con los avisos de MAME y
[licencia del proyecto](LICENSE). Sin firmware, DictROM, payload binario,
NVRAM/SRAM, documentos del usuario, capturas ni ejecutables públicos
con ROM incorporada. Los usuarios suministran por separado las imágenes
que estén autorizados a utilizar.

[Contrato de UI](stable/docs/UI_CONTRACT.md) ·
[Antecedentes de compilación](stable/docs/STABLE_IMPLEMENTATION_STATUS.md) ·
[Proveniencia](stable/docs/DEPENDENCY_PROVENANCE.md) ·
[Historia de la portada anterior](docs/AS2K_PRE_STABLE_MAIN_README.md)
