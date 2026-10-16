# AS2K Stable — checkpoint funcional VONTAR (2026-10-15)

**Propósito:** conservar un punto de referencia verificable para las siguientes correcciones de menús, **sin modificar ni sustituir la instalación funcional actual**. Este documento no contiene firmware, DictROM ni binarios privados.

## Identidad y estado aprobado

- Dispositivo: VONTAR X3 / Armbian, AArch64.
- Variante: **AS2K Stable**, no AS2K-DIAG.
- Ubicación de instalación: `/usr/local`.
- Lanzador: `/usr/local/bin/as2k`.
- Núcleo MAME: `/usr/local/libexec/as2k/as2k-bin`.
- Interfaz GTK: `/usr/local/libexec/as2k/frontend/as2k_ui.py`.
- Rama de integración: `feature/stable-payload-auto-boot-b3-20261015`.
- Revisión de código **instalada** (PIN usado por el SH): `36996b91053969661371dc067d49026fab367a47`.
- Actualizador de referencia (corrección de permisos de pycache): `scripts/update-vontar-stable-bootstrap.sh` (commit `93aeabeca3be1533a6fa62bfd3577f279656e7a9`).
- Compilación: incremental con `J=3`, sin `make clean` ni repetir las pruebas de DIAG.
- Resultado del job desatendido: `PASS EXIT=0`; `STATIC_PASS`, `BUILD_PASS`, `INSTALLED_PASS_GUI_FUNCTIONAL_PENDING` (2026-10-15, ~21:24 hora de México).
- **Límite de afirmación:** las verificaciones automatizadas de instalación están cerradas. El resultado del SH no equivale a una prueba visual documentada de todos los menús. El usuario realizará las observaciones/validaciones manuales.
- Rutas del log y estado: `/home/spc/as2k-bootstrap-b45.log`, `/home/spc/as2k-bootstrap-b45-stage.log`, `/home/spc/as2k-bootstrap-b45.status`.

## Estado de la interfaz para observaciones posteriores

En **Archivo** aparecen:
- `Abrir ROM…` (firmware principal).
- `Abrir DictROM…` (selección de imagen; no saltar directamente al código DictROM).
- **Bootstrap** → `Abrir ROM payload…` y `Ninguno (arranque normal)`.

La selección de payload remite al núcleo el comando `BOOTSTRAP_FILE` y espera `BOOT_ACK`; `Ninguno` solicita `BOOTSTRAP CLEAR`. El arranque desde DictROM se realiza **únicamente a través del payload**. Con `Ninguno` se vuelve al arranque normal.

**Las observaciones del usuario sobre los menús están pendientes.** No anticipar modificaciones ni eliminar funciones ajenas a esas observaciones.

## Payloads privados instalados para selección manual

Carpeta existente en la VONTAR: `/home/spc/Projects/private/AS2K/`.

| Archivo | Bytes | SHA-256 verificado |
| --- | ---: | --- |
| `payload0.bin` | 127 | `54582354a972848c642b2c87893ae2cc693483eae3d161693edf8f10d26f634a` |
| `payload1.bin` | 180 | `4d4e3e7b62af53bff87f2abc5daa68711c96d84e020f1a4b29ffe59b15b75058` |
| `payload1b.bin` | 185 | `a8d03fb419f8bcb82e4f7332583de92a34faea1edf59c773e5d2658cb39a28c0` |
| `payload2.bin` | 27 | `b46282c155c6656eb21cca8994213622e824e2619fa18d023ce5c108f35a4039` |

Los cuatro archivos se guardaron y se verificaron por SHA-256 en la VONTAR. **No se ejecutaron** durante esa operación. `payload1.bin` es una rutina de programación ZPSD y **no** una prueba ordinaria de arranque. Los binarios privados no deben publicarse en el repositorio.

## Reglas de continuidad

1. **Preservar esta instalación funcional como baseline.** Actualizaciones futuras sólo incrementales, focalizadas y reversibles.
2. **STATIC_FIRST / documentación primero**: analizar cambios mediante GitHub/Drive, sin pruebas exploratorias.
3. **Commander sólo con autorización explícita**, tope de llamadas fijado por el usuario; agrupar ejecuciones en un SH desatendido con PASS/FAIL y logs. `J=3` es la preferencia vigente de compilación.
4. **No repetir las pruebas ya validadas en DIAG** si no cambia su componente ni su contrato.
5. **No tocar archivos personales ni ROMs/DictROM**; no modificar instalaciones o menús fuera del alcance solicitado.
6. Al recibir observaciones de menús, contrastar esta baseline antes de planear el cambio; registrar hallazgos y nuevos commits sin asumir que una observación autoriza una intervención en la VONTAR.
