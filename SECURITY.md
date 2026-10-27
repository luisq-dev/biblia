# Seguridad

No publiques contraseñas, archivos de firma, respaldos JSON personales ni datos de tu dispositivo en las incidencias de este proyecto.

Si encuentras un problema sensible, utiliza la pestaña [Security del repositorio](https://github.com/luisq-dev/biblia/security). El mantenedor debe habilitar los informes privados de vulnerabilidades para recibirlos desde GitHub.

Antes de publicar cambios:

```sh
python3 scripts/check_publication.py --staged --history
```

El verificador revisa los archivos del índice, patrones habituales de claves, rutas personales, correos y, con `--history`, objetos y correos de commits antiguos. No muestra los valores detectados y no reemplaza una revisión manual ni un escáner especializado.

Un `.gitignore` evita nuevos archivos accidentales; no borra secretos de commits antiguos. Si ya se publicó una credencial real, revócala además de limpiar el historial.
