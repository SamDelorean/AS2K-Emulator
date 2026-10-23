# AS2K Stable — integración de Vontar y Surf

**Mantenimiento 2026-10-22:** la reparación del menú **Ver →
100 % / 200 % / 300 %** está incluida en `main` y en la
ramas `release/stable-2026.10.22-vontar-view-scale` (primer hotfix)
y `release/stable-2026.10.22-gtk-scale-install-guard` (instaladores
protegidos). Las instalaciones
canónicas comprueban automáticamente el menú antes de copiar el
frontend, y verifican que el archivo instalado corresponde al probado.
La actualización GTK no requiere recompilar MAME. En Vontar quedó
instalada y validada estáticamente; su aceptación visual sigue
pendiente de una reapertura del programa. En Surf se instaló también el frontend corregido posteriormente;
consultar el manifiesto para distinguir sus comprobaciones estáticas de la
aceptación gráfica pendiente.

**Fecha de publicación fuente:** 2026-10-21. **Rama:**
`release/stable-2026.10.21-vontar-surf`.
Este directorio es un paquete de **producto estable** autosuficiente
en fuentes y recursos GTK: conviven núcleo MAME reducido, el gestor
de sesión real de Vontar y la integración nativa para Surf.
**No** contiene firmware, DictROM ni NVRAM.

## Árbol de producto

| Ruta | Función |
| --- | --- |
| `src/mame/skeleton/alphasma.cpp` | Driver AS2K reducido con teclado/LCD, periferia y puente GTK |
| `scripts/build-stable-core.sh` | Constructor que superpone driver/HC11 y restaura donantes |
| `scripts/patch-mc68hc11-{pai,bootstrap}.py` | Contratos HC11 recuperados |
| `frontend/as2k_ui.py` | Menús, pantalla, teclas, Send/Print/IR y capturas |
| `frontend/as2k_session.py` | Gestor de ROM, DictROM, bootstrap, sesión y display integrado |
| `frontend/as2k_pcl_to_pdf.py` | Conversor PCL/PDF |
| `frontend/alphasmart_2000_shortcuts.txt` | Referencia de teclado |
| `packaging/as2k-launcher.sh`, `packaging/as2k.desktop.in` | Lanzador y aplicación de escritorio |
| `scripts/install-stable.sh` | Instalador del producto completo: núcleo + gestor + UI + accesorios |
| `install-as2k-vontar.sh` | Preparación/compilación/instalación Vontar |
| `platform/surf/` | Procedimiento nativo Surface RT, parche musl v2, instalación con rollback |
| `docs/` | Contratos y manifiesto histórico aprobado de Vontar |
| `RELEASE_MANIFEST.md` | Evidencias, hashes y limitaciones |

Los nombres `install-as2k.sh`, `install-as2k-surface.sh` y
`scripts/install-surface-local.sh` quedan **bloqueados** en `main`:
anteriormente descargaban commits viejos que podían reinstalar el
fallo de escalas. Se conservan como antecedentes, pero ahora deben
utilizarse los instaladores canónicos indicados arriba. Los scripts
de *otras ramas históricas* no se modifican automáticamente.

## Menús exactos incluidos

**Archivo:** Abrir ROM, Abrir DictROM, Bootstrap (archivo y desactivar),
captura de pantalla PNG, inicio/detención de grabación MP4, salir.
El gestor añade Abrir ROM bootstrap y uso al arrancar.

**Máquina:** Reiniciar AlphaSmart, PC conectado, Impresora conectada,
Infrarrojo activo; el gestor añade Bootstrap/inicio, selección
stock/DictROM y aplicación mediante reinicio.

**Ver:** 100 %, 200 %, 300 %, pantalla completa, visualización
integrada de un panel o dos ventanas SDL.

**Configuración:** rutas de trabajo, ROM/DictROM/arranque,
RAM/NVRAM, estados, impresión y salidas Send.

**Ayuda:** atajos de teclado y Acerca de. Fila especial:
F1–F8 en la fila superior y Print, Spell, Find, Clear, Home, End, Enter y Send en la inferior. No se muestra botón Esc, pero Escape continúa disponible desde el teclado físico.

Workbench/payload heredado se conserva en el gestor congelado.
Ninguna de esas opciones es una afirmación de nueva prueba de
funcionamiento físico o periféricos tras esta publicación.

## Vontar — Armbian ARM64

La referencia histórica **ya aprobada e instalada** está registrada en
`docs/VONTAR_STABLE_PUBLIC_20261018.md`, incluyendo sus hashes.

El ejecutable ARM64 de referencia:
`/usr/local/libexec/as2k/as2k-bin`,
SHA-256 `099a1113f8c148448e47d0fb86c37e8644c6fbdb3cea261da1fff026e54d2469`.

Desde la raíz del *checkout* de este repositorio, solo para verificar
el paquete (sin compilar ni modificar la instalación):

```sh
sh stable/install-as2k-vontar.sh --check
```

Para instalar en una **máquina distinta o actualización explícitamente
autorizada**, `--install` puede descargar dependencias y compilar MAME:
no ejecutarlo únicamente para revisar la publicación. En un sistema con
AS2K ya operativo, preservar binario/GTK, ROM/NVRAM y configuración.

## Surf — Surface RT ARMv7/musl

Se recuperó el procedimiento **nativo** aplicado en Surf, sin T:
MAME `1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`, fuente AS2K
`36996b91053969661371dc067d49026fab367a47`,
`MAKEFLAGS=ARCHITECTURE=`, `PLATFORM=arm`, `NOASM=1`,
`FORCE_DRC_C_BACKEND=1`, `NOWERROR=1`, `OPTIMIZE=1`,
`make -j1`, reutilización de objetos y corrección temporal reversible
de `bx/platform.h`, `bx/file.cpp` y `bx/thread.cpp` para musl.

El script `platform/surf/surface-native-musl-v2-20261017.sh`
documenta el **incremento único de recuperación que ya produjo PASS**.
Sus precondiciones corresponden a un estado histórico previo
(`build.status=FAIL`), por lo que **no debe ejecutarse otra vez**
sobre una Surf que ya compiló y se instaló correctamente.

`platform/surf/surface-native-install.sh` se ajustó en esta publicación
para que incluya **el gestor GTK de sesión de Vontar** y los mismos
menús/recursos, en un staging independiente con rollback.
**Corrección estática publicada, aún sin prueba nueva de ejecución**
sobre la Surf instalada. Véase [guía exclusiva](platform/surf/README.md).

## Separación de recursos

- Núcleo AS2K instalado: `/usr/local/libexec/as2k/as2k-bin`.
- Frontend completo: `/usr/local/libexec/as2k/frontend/`.
- Comando: `/usr/local/bin/as2k`.
- Menú escritorio: `/usr/local/share/applications/as2k.desktop`.
- Configuración y datos privados: `~/.config/as2k`,
  `~/.local/share/as2k` y directorios XDG.

No usar `as2k-diag` para una distribución estable ni el emulador
genérico como sustituto de la UI personalizada.

## Pendientes conscientes

La referencia histórica incluye selección directa de DictROM, anterior
a la política posterior que exige transición exclusivamente por
payload bootstrap. Es necesario auditar/corregir esa característica
en un incremento funcional separado, sin alterar la UI restante.
Siguen sin prueba renovada la interfaz gráfica Surf tras el
integrador publicado, recuperación de NVRAM tras terminación brusca,
y reparación de despertar por PC en Vontar.

### Garantía del menú Ver en instalaciones posteriores

`python3 -B stable/tests/test_view_scale.py` verifica con los métodos
reales de la interfaz las tres escalas de LCD (1×, 2×, 3×), la
selección inicial de 200 % en la ventana integrada, la adaptación a
pantalla completa y la reducción al espacio disponible si es necesario.
Es una prueba automática sin servidor gráfico, no sustituye la
aceptación manual de GTK.

El instalador Vontar la ejecuta mediante
`stable/scripts/validate-stable-static.sh` y vuelve a pasarla antes
de copiar el frontend. El instalador Surf también la ejecuta y
comprueba que `as2k_ui.py` y `as2k_session.py` instalados sean
idénticos a los del paquete fuente.

Después de actualizar una interfaz Python ya abierta, es necesario
cerrar y volver a abrir AS2K para utilizar el código nuevo.
**Vontar compila a `-j3` por defecto; Surf conserva `-j1`**.

[Manifiesto](RELEASE_MANIFEST.md) ·
[Contrato](docs/UI_CONTRACT.md) ·
[Instalación aprobada Vontar](docs/VONTAR_STABLE_PUBLIC_20261018.md).
