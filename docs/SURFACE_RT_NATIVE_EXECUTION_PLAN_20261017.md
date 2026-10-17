# AS2K Stable — Plan rector exclusivo de compilación nativa en Surface RT

**Fecha:** 2026-10-17. **Prioridad:** ABSOLUTA. **Estado:** PLAN, sin ejecutar Commander. Este documento prevalece sobre TODOS los planes de compilación cruzada T640 del traslado AS2K Stable, incluso los documentos G0–G7. Los registros históricos de la T640 se conservan, pero NO habilitan nuevas acciones.

## Objetivo y exclusiones

Replicar el AS2K Stable terminado de VONTAR X3 en Surface RT/postmarketOS compilando **directamente en Surface RT**. AS2K pin exacto `36996b91053969661371dc067d49026fab367a47`; donor MAME pin exacto `1dc2180181a3b1a21e8761ae40b50a9f55ac4a5b`. Conservar GUI GTK, lanzador, recursos y núcleo; sin nuevas funciones, cambios de menús, bootstrap, DIAG, Writer ni reparaciones funcionales ajenas al port.

**Único host de compilación e instalación: Surface RT, dispositivo Commander `ae7a284a-68e1-49fc-bbd3-537674bc6a17`, nombre `surf`.** No usar T640 para compilar, investigar, transferir o exportar registros. VONTAR solo referencia, sin cambios. Firmware/DictROM/NVRAM, configuración, datos privados y sistema operativo protegidos. No tocar kernel, bootloader, DTB, particiones, Wi-Fi ni actualizar sistema.

## Procedimiento existente obligatorio

Proyecto Surface: `/home/user/Projects/alphasmart/as2k-surf-native`.
- `sources/AS2K-Emulator`, `sources/mame-as3k`: checkouts exactos, ya registrados con PASS.
- `scripts/surface-native-build.sh`: compilación nativa ARMv7, J=1, overlay y restauración segura, **no reconstruir desde cero**.
- `scripts/surface-native-run-after-sources.sh` y `scripts/surface-native-systemd-build.sh`: supervisión desatendida.
- `scripts/surface-native-oom-recovery-launch.sh`: procedimiento histórico de aislamiento systemd y swap temporal de 4 GiB, **no ejecutar ciegamente otra vez**.
- `scripts/surface-native-install.sh`: instalación separada, staging, backup/rollback.
- Estados: `status/environment.status`, `status/sources.status`, `status/systemd-build.status`, `status/native-build-run.status`, `status/build.status`, `status/install.status`.
- Logs: `logs/native-build-runner.log`, `logs/native-build.log`, `logs/systemd-build-meta.log`.
- Binario esperado: `sources/AS2K-Emulator/out/as2k-bin`.
- Unidad histórica: `as2k-surface-native-20261016.service`, anteriormente observada RUNNING el 2026-10-16, estado ACTUAL NO COMPROBADO.
- `tmp/build-extra.swap`: swap temporal de la compilación previa, **no apagar ni borrar sin comprobar que ningún compilador lo usa y que la memoria lo permite**.

## Orden incremental rígido

### N1 — Estado real, SOLO LECTURA (siguiente incremento)

Una única llamada Commander **a SURFACE**, previamente autorizada y debidamente presupuestada, con un solo script de consulta consolidada: `systemctl show as2k-surface-native-20261016.service -p ActiveState -p SubState -p Result -p MainPID -p ControlGroup`; `cat` de estados; `tail` acotado de ambos logs; verificación `ps` del make/cc1plus; `test -f`, `file`, `sha256sum` del binario; `git rev-parse HEAD` y `git status --short --untracked-files=no` de ambos repos; `df -h`, `free -h`, `grep build-extra.swap /proc/swaps`. `journalctl -u ...` acotado solo si ya hay fallo comprobado. Sin mutar ni desplegar scripts, y sin usar T640.

Ramas excluyentes:
- RUNNING real: preservar compilación; no iniciar ni reanudar nada, no limpiar swap. Cierre = RUNNING documentado.
- PASS verificable (`systemd-build.status = PASS STEP=READY`, `native-build-run.status = PASS NATIVE_BUILD_COMPLETE`, `build.status = PASS STEP=READY`, ELF ARM existente): ir N4; no recompilar.
- FAIL/BLOCKED real: capturar causa y continuar N2; no reintentar.
- Desconocido/incoherente: BLOCKED, reconciliar registros/procesos antes de decidir.

### N2 — Diagnóstico estático y corrección limitada (condicional)

Analizar la causa a partir del LOG NATIVO de Surface y evidencia del kernel en caso de OOM. Buscar solución anterior en los SH y documentos. No trasladar automáticamente parches originados en T640. Cualquier cambio se limita a infraestructura del builder u overlay reversible si está demostrado; sin editar características funcionales ni revisiones congeladas. Sin `make clean`, duplicación de clones, paquetes o ensayos especulativos. Cierre = diagnóstico demostrable y plan de corrección puntual, con su autorización.

### N3 — Finalización o reanudación nativa (condicional)

Si N1 no acreditó PASS, y solo después de N2/preflight y autorización: reutilizar scripts presentes `surface-native-build.sh` y `surface-native-systemd-build.sh`, ejecutados **en Surface**, J=1, misma caché de objetos y espacio existente, overlay y snapshot persistente, proceso systemd independiente del cgroup Commander, sin solapamiento ni relanzamiento del servicio anterior. Conservar swap temporal mientras sea necesario. Resultado explícito PASS/FAIL/BLOCKED en estados/logs. Cierre PASS exige archivos de estado, binario y validación nativa, no basta `systemd Result=success`.

### N4 — Verificación del ejecutable, sin instalación

Confirmar ELF ARM32 EABI hard-float/musl y dependencias instaladas en Surface; hash SHA-256; ejecutar `as2k-bin -validate` **en Surface**. Verificar procedencia del frontend y lanzador del pin aprobado mediante comparación estática, sin alterar menús. Si FAIL, parar. Cierre = artefacto funcionalmente validado sin instalación.

### N5 — Instalación controlada, con autorización distinta

Revisar primero staging y backups; usar solo `scripts/surface-native-install.sh` con `sudo -n` y rollback, validaciones posteriores, preservar `~/.config/as2k`, `~/.local/share/as2k`, ROM, DictROM y NVRAM. **Prohibido** instalador experimental generado en compilación cruzada (sin rollback) o cualquier `apk add` no requerido. No instalar sin autorización expresa. Cierre = `status/install.status = PASS INSTALLED_ARMV7` y comprobación real, con ruta de respaldo.

### N6 — Validación funcional nativa

Verificar ejecución GUI, carga de firmware propio, teclado y funciones ya existentes; mantener interfaz y política de payload/bootstrap de la revisión aprobada. No abrir labores de corrección de persistencia NVRAM, menús, DictROM u otros proyectos en este plan. Documentar PASS o incidencia separada. Limpiar swap temporal **solo cuando no haya compilación activa y la retirada sea segura**, en incremento controlado; no forzar swapoff por presión de RAM.

## Reglas universales que prevalecen

1. STATIC_FIRST: leer manuales y fuentes, verificar evidencias antes de ejecutar.
2. Commander **solo con autorización explícita por intervención**; máximo **3 llamadas** por intervención autorizada, incluyendo consultas fallidas; ninguna autorización anterior se transfiere. DeviceId obligatorio `ae7a284a-68e1-49fc-bbd3-537674bc6a17`.
3. Una consulta consolidada y scripts desatendidos completos; evitar polling y llamadas de exploración. Salidas `PASS/FAIL/BLOCKED`, logs y checksums; distinguir despacho, compilación e instalación.
4. No repetir pasos cerrados ni descargar/clonar/instalar dependencias/compilar de nuevo sin evidencia que lo exija. Sin `make clean`.
5. No tocar T640 ni VONTAR; preservar instalación, datos personales, firmware, ROM, DictROM y NVRAM.
6. **G0–G4 T640 NO forman parte del plan vigente.** No usar su último fallo `bx/file.cpp` como diagnóstico nativo Surface. Prohibida extracción pendiente de logs en T640.
7. Congelar pin de las revisiones: AS2K `36996b9...` y MAME `1dc2180...`. No añadir cambios de UX ni rediseños.
8. Alto inmediato ante falla o duda material; responder con evidencia y condición de reanudación, no con otra compilación a ciegas.

## Estado inicial del plan

Documentación GitHub revisada a 2026-10-17: preparación nativa de Surface y fuentes **PASS históricos**; compilación nativa `as2k-surface-native-20261016.service` **históricamente iniciada**, resultado final **DESCONOCIDO**. **N1 PENDING, N2/N3 condicionales, N4/N5/N6 no acreditados.** Ninguna llamada Commander o ejecución remota efectuada al redactar este documento. La siguiente acción es únicamente **N1 lectura en Surface** cuando el usuario la autorice.

Referencias: `docs/SURFACE_RT_NATIVE_HANDOFF_20261016.md`, `docs/SURFACE_RT_NATIVE_BUILD_PREPARATION_20261015.md`, `docs/AS2K_STABLE_VONTAR_CHECKPOINT_20261015.md`, `scripts/surface-native-build.sh`, `scripts/surface-native-systemd-build.sh`, `scripts/surface-native-install.sh`.
