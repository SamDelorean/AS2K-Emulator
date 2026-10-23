# Surf AS2K Stable — corrección de escala GTK (22/10/2026)

Equipo: Surf / Surface RT, postmarketOS ARMv7.
Alcance: solo frontend Python instalado. No recompilación MAME, firmware, DictROM, NVRAM, bootstrap, configuraciones ni reinicio forzado.

## Preflight remoto
- Arquitectura armv7l; sudo sin contraseña disponible.
- UI anterior: Git blob 767759a0cb3907ce72e91cbbfe260435844db7d3; SHA-256 ff8be74da550720c6e35c25df974d65161ef2b939a978bf0da7763f78b76051a.
- Sesión anterior: Git blob 057356fe49798bc57518f5134bf58a52915a7628; SHA-256 57d0dd376cb8809858d19179373c8d813ff5eb7be9d0a103d6270904e703bf0f.
- Núcleo ARMv7: SHA-256 4577d29cdfff2f5916738d576a024bd4180a8343d6b478c6e9ebd1426b8fdedd antes del hotfix; no fue escrito ni recompilado.

## Intervención
Fuentes recuperadas del commit fijo 7e7f240c925efdba9e805b2d33719ecaca4174be.
Se validaron los blobs y ejecutó la prueba headless tests/test_view_scale.py antes de instalar, con staging y renombrado de dos archivos:
- /usr/local/libexec/as2k/frontend/as2k_ui.py: blob 1b8b889d1aeb582c7bae4d0632bda70f669b6c6a
- /usr/local/libexec/as2k/frontend/as2k_session.py: blob 97803b2dc85c7ca9483ce971aa780d94f13ea6a9
- Test fuente: blob c3ba9d44bf8a5abd69e7d276a517a5cacfed37f5

Respaldo de originales: /home/user/.local/share/alphasmart/audits/as2k/surf-view-scale-20261022.XXaeEJmn/
Resultado: install.status dentro de esa carpeta.
Durante la copia de respaldo, cp -p avisó que no podía preservar el propietario root en la copia de usuario; no impidió la copia ni el despliegue.

## Evidencia
PRECHECK_OLD_FRONTEND_MATCH_PASS
AS2K_STABLE_VIEW_100_150_200_HEADLESS_PASS
VERIFIED_SOURCE_AND_REGRESSION_PASS
SURF_SCALE_HOTFIX_INSTALLED_PASS
UI_BLOB=1b8b889d1aeb582c7bae4d0632bda70f669b6c6a
SESSION_BLOB=97803b2dc85c7ca9483ce971aa780d94f13ea6a9
CORE_UNCHANGED
REOPEN_AS2K_FOR_GUI_CHECK
Process exit code = 0.

Estado: SOURCE_UNIT_TEST_AND_INSTALL_PASS. GUI_INTERACTIVE=PENDING_REOPEN.
Falta cerrar y volver a abrir AS2K para comprobar manualmente Ver > 100/150/200 por ciento y fullscreen. No adjudicar GUI_PASS con prueba headless.

Intervención Commander total Surf: tres llamadas (preflight, parche y lectura final); ninguna en Vontar o T. No se requiere repetir compilación ni reinstalación completa.
